#!/bin/bash

echo "
┓ ┏  ┓          ┏┳┓                             
┃┃┃┏┓┃┏┏┓┏┳┓┏┓   ┃ ┏┓                           
┗┻┛┗ ┗┗┗┛┛┗┗┗    ┻ ┗┛                           
┓ ┏•             ┓  ┏┓┓•       ┳      ┓┓   •    
┃┃┃┓┏┓┏┓┏┓┓┏┏┓┏┓┏┫  ┃ ┃┓┏┓┏┓╋  ┃┏┓┏╋┏┓┃┃┏┓╋┓┏┓┏┓
┗┻┛┗┛ ┗ ┗┫┗┻┗┻┛ ┗┻  ┗┛┗┗┗ ┛┗┗  ┻┛┗┛┗┗┻┗┗┗┻┗┗┗┛┛┗
         ┛                                      
"

if [ $(id -u) -ne 0 ]; then 

    echo "Permission Denied: Root Privileges Required"

else 

    if [ ! -f /etc/wireguard/wg0.conf ]; then

        echo "Server configuration not found. Please configure the server first."

    else

        SERVER_PUBLIC_IP=$(curl -s ifconfig.me)
        read -p "Is this the correct public IP of the server - $SERVER_PUBLIC_IP? [Y/N]: " CONFIRM_IP
        CONFIRM_IP=${CONFIRM_IP:-Y}
        
        if [ $CONFIRM_IP == "y" ] || [ $CONFIRM_IP == "Y" ]; then

            SERVER_IP_BLOCK=$(grep "Address" /etc/wireguard/wg0.conf | awk '{print $3}')
            SERVER_PRIVATE_IP=$(echo $SERVER_IP_BLOCK | cut -d '/' -f1)
            SERVER_SUBNET=$(echo $SERVER_IP_BLOCK | cut -d '/' -f2)
            SERVER_LISTENING_PORT=$(grep "ListenPort" /etc/wireguard/wg0.conf | awk '{print $3}')

            TOTAL_IPS=$((2**(32-SERVER_SUBNET)))
            AVAILABLE_IPS=$((TOTAL_IPS - 2))

            echo ""
            echo "The server is configured with the private IP block: $SERVER_IP_BLOCK"
            echo "You can create up to $AVAILABLE_IPS clients."
            echo ""

            if [ ! -d /etc/wireguard/clients ]; then

                mkdir /etc/wireguard/clients

            fi

            while true; do

                read -p "How many clients would you like to create? " NUM_CLIENTS
                if [[ $NUM_CLIENTS =~ ^[0-9]+$ ]] && [ $NUM_CLIENTS -le $AVAILABLE_IPS ] && [ $NUM_CLIENTS -ge 1 ]; then

                    break

                else

                    echo "Invalid number of clients. Please enter a number between 1 and $AVAILABLE_IPS."

                fi

            done

            IFS='.' read -r -a OCTETS <<< "$SERVER_PRIVATE_IP"

            for ((i=1; i<=NUM_CLIENTS; i++)); do
                
                umask 077

                # Find the first available client number
                CLIENT_NUM=1
                while [ -f /etc/wireguard/clients/client${CLIENT_NUM}.conf ]; do
                    CLIENT_NUM=$((CLIENT_NUM + 1))
                done

                wg genkey > /etc/wireguard/clients/client${CLIENT_NUM}_privatekey
                wg pubkey < /etc/wireguard/clients/client${CLIENT_NUM}_privatekey > /etc/wireguard/clients/client${CLIENT_NUM}_publickey
                wg genpsk > /etc/wireguard/clients/client${CLIENT_NUM}_presharedkey
                
                CLIENT_PRIVATE_KEY=$(</etc/wireguard/clients/client${CLIENT_NUM}_privatekey)
                CLIENT_PUBLIC_KEY=$(</etc/wireguard/clients/client${CLIENT_NUM}_publickey)
                CLIENT_PRESHARED_KEY=$(</etc/wireguard/clients/client${CLIENT_NUM}_presharedkey)
                SERVER_PUBLIC_KEY=$(</etc/wireguard/publickey) 
                DNS_SERVER="8.8.8.8, 8.8.4.4, 1.1.1.1"

                # Find the first available client IP
                while true; do
                    OCTETS[3]=$((OCTETS[3] + 1))
                    for ((j=3; j>=0; j--)); do
                        if [ ${OCTETS[j]} -gt 254 ]; then
                            OCTETS[j]=1
                            if [ $j -gt 0 ]; then
                                OCTETS[$((j-1))]=$((OCTETS[$((j-1))] + 1))
                            fi
                        fi
                    done

                    CLIENT_IP="${OCTETS[0]}.${OCTETS[1]}.${OCTETS[2]}.${OCTETS[3]}"
                    if ! grep -q "$CLIENT_IP" /etc/wireguard/wg0.conf; then
                        break
                    fi
                done

                CLIENT_CONFIG="/etc/wireguard/clients/client${CLIENT_NUM}.conf"
                cat << EOF >$CLIENT_CONFIG
[Interface]
PrivateKey = $CLIENT_PRIVATE_KEY
Address = $CLIENT_IP/32
DNS = $DNS_SERVER

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
PresharedKey = $CLIENT_PRESHARED_KEY
Endpoint = $SERVER_PUBLIC_IP:$SERVER_LISTENING_PORT
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF

                echo "Client $CLIENT_NUM configuration created with IP $CLIENT_IP"
            
                cat << EOF >>/etc/wireguard/wg0.conf

#User - ${CLIENT_NUM}
[Peer]
PublicKey = $CLIENT_PUBLIC_KEY
PresharedKey = $CLIENT_PRESHARED_KEY
AllowedIPs = $CLIENT_IP/32
EOF
                rm /etc/wireguard/clients/client${CLIENT_NUM}_privatekey
                rm /etc/wireguard/clients/client${CLIENT_NUM}_publickey
                rm /etc/wireguard/clients/client${CLIENT_NUM}_presharedkey

                echo "Peer Added in the Server"

            done

        else

            echo "Public IP confirmation failed."
            
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