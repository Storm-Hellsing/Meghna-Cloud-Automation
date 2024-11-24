#!/bin/bash

echo "┓ ┏  ┓          ┏┳┓                  
┃┃┃┏┓┃┏┏┓┏┳┓┏┓   ┃ ┏┓                
┗┻┛┗ ┗┗┗┛┛┗┗┗    ┻ ┗┛                
                                     
┓ ┏•    ┏┓       ┓  ┳      ┓┓   •    
┃┃┃┓┏┓┏┓┃┓┓┏┏┓┏┓┏┫  ┃┏┓┏╋┏┓┃┃┏┓╋┓┏┓┏┓
┗┻┛┗┛ ┗ ┗┛┗┻┗┻┛ ┗┻  ┻┛┗┛┗┗┻┗┗┗┻┗┗┗┛┛┗
                                     "

if [ $(id -u) -ne 0 ]; then 
    
    echo "Permission Denied: Root Previlages Required"

else

    echo "Choose for Sever Configuration/Client Configuration
                
            1. Sever Configuration
            2. Client Configuration
                                    "

    read -p "Enter Your Choise [1 or 2]: " CHOICE

    case $CHOICE in
        1)
            echo ""
            echo "----------------------"
            echo "Server Configurations"
            echo "----------------------"
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

            cd /etc/wireguard/

            if [ -f wg0.conf ]; then

                echo "Warning: wg0.conf already exists. Please inspect it before proceeding."

            else

                umask 077
                wg genkey > privatekey
                wg pubkey < privatekey > publickey

                PRIVATE_KEY=$(<privatekey)
                PUBLIC_KEY=$(<publickey)
                DNS_GOOGLE="8.8.8.8, 8.8.4.4"
                DNS_CLOUDFLARE="1.1.1.1"
                
                read -p "Enter Network Interface Address [default: 10.10.10.1]: " NET_INT_ADDR
                NET_INT_ADDR=${NET_INT_ADDR:-10.10.10.1}

                read -p "Enter Listening Port of the Server [default: 51820]: " LISTEN_PORT
                LISTEN_PORT=${LISTEN_PORT:-51820}

                echo "Select DNS Server:
                            
                            1. Google DNS Server
                            2. Cloudflare DNS Server" 
                            
                read -p "Enter Your Choice [1 or 2]: " DNS_CHOICE

                case $DNS_CHOICE in
                    1)
                        DNS_SERVER=$DNS_GOOGLE
                        ;;
                    2)
                        DNS_SERVER=$DNS_CLOUDFLARE
                        ;;
                    *)
                        echo "Invalid choice, defaulting to Google DNS Server."
                        DNS_SERVER=$DNS_GOOGLE
                        ;;
                esac

                # Automatically detect the network interface
                INTERFACE=$(ip -o -4 route show to default | awk '{print $5}')

                cat << EOF > wg0.conf
[Interface]
Address = $NET_INT_ADDR
ListenPort = $LISTEN_PORT
PrivateKey = $PRIVATE_KEY
DNS = $DNS_SERVER

PostUp = iptables -A FORWARD -i telecash-vpn -o $INTERFACE -j ACCEPT
PostUp = iptables -t nat -A POSTROUTING -o $INTERFACE -j MASQUERADE
PreDown = iptables -D FORWARD -i telecash-vpn -o $INTERFACE -j ACCEPT
PreDown = iptables -t nat -D POSTROUTING -o $INTERFACE -j MASQUERADE
EOF

                    echo "wg0.conf has been created with the specified configurations. Server Configuration is now Successfully Complete."

                    echo "----------------------------------------"
                    echo "Server Configuration Details"
                    echo "PrivateKey = $PRIVATE_KEY"
                    echo "Network Interface Address: $NET_INT_ADDR"
                    echo "Listening Port: $LISTEN_PORT"
                    echo "DNS Server: $DNS_SERVER"
                    echo "----------------------------------------"
                
            fi

        ;;
    
    esac
fi