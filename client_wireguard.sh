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
                CLIENT_PRIVATE_KEY=$(wg genkey)
                CLIENT_PUBLIC_KEY=$(echo $CLIENT_PRIVATE_KEY | wg pubkey)
                CLIENT_PRESHARED_KEY=$(wg genpsk)
                DNS_SERVER="8.8.8.8, 8.8.4.4, 1.1.1.1"

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
                while [[ "$CLIENT_IP" == "$SERVER_PRIVATE_IP" || "$CLIENT_IP" == *".0" || "$CLIENT_IP" == *".255" ]]; do
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
                done

                CLIENT_CONFIG="/etc/wireguard/clients/client${i}.conf"
                cat << EOF >$CLIENT_CONFIG
[Interface]
PrivateKey = $CLIENT_PRIVATE_KEY
Address = $CLIENT_IP/32
DNS = $DNS_SERVER

[Peer]
PublicKey = $(grep "PrivateKey" /etc/wireguard/wg0.conf | awk '{print $3}')
PresharedKey = $CLIENT_PRESHARED_KEY
Endpoint = $SERVER_PUBLIC_IP:$SERVER_LISTENING_PORT
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF

                echo "Client $i configuration created with IP $CLIENT_IP"
            
            cat << EOF >>/etc/wireguard/wg0.conf

#User - ${i}
[Peer]
PublicKey = $CLIENT_PUBLIC_KEY
PresharedKey = $CLIENT_PRESHARED_KEY
AllowedIPs = $CLIENT_IP/32
EOF

                echo "Peer Added in the Server"

            done

        else

            echo "Public IP confirmation failed."
            
        fi

        if systemctl enable wg-quick@wg0; then

            echo "Wireguard Services Enabled Successfully"

            if systemctl start wg-quick@wg0; then

            echo "Wireguard Server Started Successfully"

        else

            echo "Failed to Start the Server. Check Status."

        fi

        else

            echo "Failed to Enable the Services. Check Status."

        fi
    fi
fi