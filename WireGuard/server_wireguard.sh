#!/bin/bash

echo "
┓ ┏  ┓          ┏┳┓                                
┃┃┃┏┓┃┏┏┓┏┳┓┏┓   ┃ ┏┓                              
┗┻┛┗ ┗┗┗┛┛┗┗┗    ┻ ┗┛                              
┓ ┏•             ┓  ┏┓            ┳      ┓┓   •    
┃┃┃┓┏┓┏┓┏┓┓┏┏┓┏┓┏┫  ┗┓┏┓┏┓┓┏┏┓┏┓  ┃┏┓┏╋┏┓┃┃┏┓╋┓┏┓┏┓
┗┻┛┗┛ ┗ ┗┫┗┻┗┻┛ ┗┻  ┗┛┗ ┛ ┗┛┗ ┛   ┻┛┗┛┗┗┻┗┗┗┻┗┗┗┛┛┗
         ┛                                         
"

if [ $(id -u) -ne 0 ]; then 
    
    echo "Permission Denied: Root Previlages Required"

else

    echo ""
    echo "----------------------"
    echo "Server Configurations"
    echo "----------------------"
    echo ""
    echo "Installing Depedencies.../"
    echo ""

    if dpkg -l | grep -q "resolvconf" || dpkg -l | grep -q "systemd-resolved"; then

        echo "-------------------------------"
        echo "ResolvConf is already installed."         
        echo "-------------------------------"
                
    elif sudo apt install resolvconf -y; then

        echo "-----------------------------------"
        echo "ResolvConf is successfully installed"
        echo "-----------------------------------"

    fi

    echo ""
    echo "Installing WireGuard.../"
    echo ""

    if dpkg -l | grep -q "wireguard"; then

        echo "-------------------------------"
        echo "WireGuard is already installed."         
        echo "-------------------------------"
                
    elif sudo apt install wireguard -y; then

        echo "-----------------------------------"
        echo "WireGuard is successfully installed"
        echo "-----------------------------------"

    fi

    echo ""
    echo "Adding NET FORWARDING for IPV4 AND IPC 6.../"
    echo ""
                
    if ! grep -q "^net.ipv4.ip_forward=1" /etc/sysctl.conf; then

        cat << EOF >> /etc/sysctl.conf
net.ipv4.ip_forward=1
EOF

    else

        echo "IPV4 Net Forwarding already exsists. Ignoring it"

    fi

    if ! grep -q "^net.ipv6.conf.all.forwarding=1" /etc/sysctl.conf; then

    cat << EOF >> /etc/sysctl.conf
net.ipv6.conf.all.forwarding=1
EOF

    else

        echo "IPV6 Net Forwarding already exsists. Ignoring it"

    fi

    echo ""

    sysctl -p

    echo ""

    if [ -f /etc/wireguard/wg0.conf ]; then

        echo "Warning: wg0.conf already exists. Please inspect it before proceeding."

    else

        umask 077
        wg genkey > /etc/wireguard/privatekey
        wg pubkey < /etc/wireguard/privatekey > /etc/wireguard/publickey

        PRIVATE_KEY=$(</etc/wireguard/privatekey)
        PUBLIC_KEY=$(</etc/wireguard/publickey)
        DNS_SERVER="8.8.8.8, 8.8.4.4, 1.1.1.1"

        while true; do
        
            read -p "Enter Network Interface Address with Subnet [default: 10.10.10.1/24]: " NET_INT_ADDR
            NET_INT_ADDR=${NET_INT_ADDR:-10.10.10.1/24}

            if [[ $NET_INT_ADDR =~ ^([0-9]{1,3}\.){3}[1-9][0-9]{0,2}/([1-9]|[12][0-9]|3[0-1])$ ]] && [[ ${NET_INT_ADDR##*/} -gt 8 && ${NET_INT_ADDR##*/} -lt 32 ]]; then

                break

            else

                echo "Invalid IP address or subnet format. Please try again. Subnet must be greater than 8 and less than 32, and the fourth octet cannot be 0."

            fi

        done

        while true; do

            read -p "Enter Listening Port of the Server [default: 51820]: " LISTEN_PORT
            LISTEN_PORT=${LISTEN_PORT:-51820}

            if [[ $LISTEN_PORT =~ ^[0-9]+$ ]] && [ $LISTEN_PORT -ge 1 ] && [ $LISTEN_PORT -le 65535 ]; then

                break

            else

                echo "Invalid port number. Please enter a number between 1 and 65535."

            fi

        done

        # Automatically detect the network interface
        INTERFACE=$(ip -o -4 route show to default | awk '{print $5}')

        cat << EOF > /etc/wireguard/wg0.conf
[Interface]
PrivateKey = $PRIVATE_KEY
Address = $NET_INT_ADDR
ListenPort = $LISTEN_PORT
DNS = $DNS_SERVER

PostUp = iptables -A FORWARD -i wg0 -o $INTERFACE -j ACCEPT
PostUp = iptables -t nat -A POSTROUTING -o $INTERFACE -j MASQUERADE
PreDown = iptables -D FORWARD -i wg0 -o $INTERFACE -j ACCEPT
PreDown = iptables -t nat -D POSTROUTING -o $INTERFACE -j MASQUERADE
EOF

        echo ""
        echo "wg0.conf has been created with the specified configurations. Server Configuration is now Successfully Complete."
        echo ""
        
        echo "----------------------------------------------------------------"
        echo "Server Configuration Details"
        echo "----------------------------------------------------------------"
        echo "PrivateKey = $PRIVATE_KEY"
        echo "Address = $NET_INT_ADDR"
        echo "Listening Port = $LISTEN_PORT"
        echo "DNS Server = $DNS_SERVER"
        echo "----------------------------------------------------------------"

        echo "Enabling Wireguard Services..."
        
        # Check if the service is enabled
        if systemctl is-enabled --quiet wg-quick@wg0; then

            echo "The WireGuard service is already enabled."

        else

            if systemctl enable wg-quick@wg0; then

                echo "WireGuard service enabled successfully."

            else

                echo "Failed to enable the WireGuard service. Check status."
                exit 1

            fi

        fi

        # Check if the service is enabled
        if systemctl is-enabled --quiet wg-quick@wg0; then

            echo "The WireGuard service is already enabled."

        else

            if systemctl enable wg-quick@wg0; then

                echo "WireGuard service enabled successfully."

            else

                echo "Failed to enable the WireGuard service. Check status."
                exit 1

            fi

        fi

        # Check if the service is active
        if systemctl is-active --quiet wg-quick@wg0; then

            echo "The WireGuard service is already active. Restarting the service..."

            if systemctl restart wg-quick@wg0; then

                echo "WireGuard service restarted successfully."

            else

                echo "Failed to restart the WireGuard service. Check status."
                exit 1

            fi

        else

            echo "The WireGuard service is inactive. Starting the service..."

            if systemctl start wg-quick@wg0; then

                echo "WireGuard service started successfully."

            else

                echo "Failed to start the WireGuard service. Check status."
                exit 1

            fi
            
        fi
                
    fi
fi