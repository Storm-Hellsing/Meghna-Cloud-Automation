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

            if [ -f /etc/wireguard/wg0.conf ]; then

                echo "Warning: wg0.conf already exists. Please inspect it before proceeding."

            else

                umask 077
                wg genkey > privatekey
                wg pubkey < privatekey > publickey

                PRIVATE_KEY=$(<privatekey)
                PUBLIC_KEY=$(<publickey)
                DNS_SERVER="8.8.8.8, 8.8.4.4, 1.1.1.1"
                
                while true; do

                    read -p "Enter Network Interface Address with Subnet [default: 10.10.10.1/24]: " NET_INT_ADDR
                    NET_INT_ADDR=${NET_INT_ADDR:-10.10.10.1/24}

                    if [[ $NET_INT_ADDR =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/([1-9]|[12][0-9]|3[0-2])$ ]]; then

                        break

                    else

                        echo "Invalid IP address or subnet format. Please try again."

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

                    echo "----------------------------------------------------------------"
                    echo "Server Configuration Details"
                    echo "----------------------------------------------------------------"
                    echo "PrivateKey = $PRIVATE_KEY"
                    echo "Address = $NET_INT_ADDR"
                    echo "Listening Port = $LISTEN_PORT"
                    echo "DNS Server = $DNS_SERVER"
                    echo "----------------------------------------------------------------"
                
            fi

        ;;
    
    2)

        echo ""
        echo "----------------------"
        echo "Client Configurations"
        echo "----------------------"
        echo ""

        if [ ! -d /etc/wireguard/clients ]; then

            mkdir /etc/wireguard/clients

            if [ -f /etc/wireguard/wg0.conf ]; then

                while true; do

                read -p "Enter the number of users to create [1-100]: " NUM_USERS

                if [[ $NUM_USERS =~ ^[0-9]+$ ]] && [ $NUM_USERS -ge 1 ] && [ $NUM_USERS -le 100 ]; then

                    break

                else

                    echo "Invalid number of users. Please enter a number between 1 and 100."

                fi

                done

                SERVER_NET_INT_ADDR=$(grep "^Address" wg0.conf | cut -d' ' -f3)
                SERVER_IP=$(echo $SERVER_NET_INT_ADDR | cut -d'/' -f1)
                SERVER_SUBNET=$(echo $SERVER_NET_INT_ADDR | cut -d'/' -f2)

                IFS='.' read -r -a IP_ARRAY <<< "$SERVER_IP"
                BASE_IP="${IP_ARRAY[0]}.${IP_ARRAY[1]}.${IP_ARRAY[2]}"

                cd /etc/wireguard/clients

                for ((i=1; i<=NUM_USERS; i++)); do

                    umask 077
                    wg genkey > client_privatekey_$i
                    wg pubkey < client_privatekey_$i > client_publickey_$i
                    wg genpsk > client_presharedkey_$i

                    CLIENT_PRIVATE_KEY=$(<client_privatekey_$i)
                    CLIENT_PUBLIC_KEY=$(<client_publickey_$i)
                    CLIENT_PRESHARED_KEY=$(<client_presharedkey_$i)

                    CLIENT_IP="${BASE_IP}.$((i+1))/$SERVER_SUBNET"

                    cat << EOF > client_$i.conf
[Interface]
PrivateKey = $CLIENT_PRIVATE_KEY
Address = $CLIENT_IP
DNS = $DNS_SERVER

[Peer]
PublicKey = $PUBLIC_KEY
PresharedKey = $CLIENT_PRESHARED_KEY
Endpoint = <server-ip>:51820
AllowedIPs = 0.0.0.0/0
EOF

                    echo "Client configuration file client_$i.conf has been created."

                done
        
            else

            echo "Server Configuration File is not Found. Please check, if the server configuration file is named different other than wg0.conf or create server configuration file first."

            fi
            
        elif [ -d /etc/wireguard/clients ]; then

            if [ -f /etc/wireguard/wg0.conf ]; then

                while true; do

                read -p "Enter the number of users to create [1-100]: " NUM_USERS

                if [[ $NUM_USERS =~ ^[0-9]+$ ]] && [ $NUM_USERS -ge 1 ] && [ $NUM_USERS -le 100 ]; then

                    break

                else

                    echo "Invalid number of users. Please enter a number between 1 and 100."

                fi

                done

                SERVER_NET_INT_ADDR=$(grep "^Address" wg0.conf | cut -d' ' -f3)
                SERVER_IP=$(echo $SERVER_NET_INT_ADDR | cut -d'/' -f1)
                SERVER_SUBNET=$(echo $SERVER_NET_INT_ADDR | cut -d'/' -f2)

                IFS='.' read -r -a IP_ARRAY <<< "$SERVER_IP"
                BASE_IP="${IP_ARRAY[0]}.${IP_ARRAY[1]}.${IP_ARRAY[2]}"

                cd /etc/wireguard/clients

                for ((i=1; i<=NUM_USERS; i++)); do

                    umask 077
                    wg genkey > client_privatekey_$i
                    wg pubkey < client_privatekey_$i > client_publickey_$i
                    wg genpsk > client_presharedkey_$i

                    CLIENT_PRIVATE_KEY=$(<client_privatekey_$i)
                    CLIENT_PUBLIC_KEY=$(<client_publickey_$i)
                    CLIENT_PRESHARED_KEY=$(<client_presharedkey_$i)

                    CLIENT_IP="${BASE_IP}.$((i+1))/$SERVER_SUBNET"

                    cat << EOF > client_$i.conf
[Interface]
PrivateKey = $CLIENT_PRIVATE_KEY
Address = $CLIENT_IP
DNS = $DNS_SERVER

[Peer]
PublicKey = $PUBLIC_KEY
PresharedKey = $CLIENT_PRESHARED_KEY
Endpoint = <server-ip>:51820
AllowedIPs = 0.0.0.0/0
EOF

                    echo "Client configuration file client_$i.conf has been created."

                done
        
            else

            echo "Server Configuration File is not Found. Please check, if the server configuration file is named different other than wg0.conf or create server configuration file first."

            fi
        fi


    ;;

      
    esac
fi