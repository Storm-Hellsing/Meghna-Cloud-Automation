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

            cd /etc/wireguard/
            umask 077
            wg genkey > privatekey
            wg pubkey < privatekey > publickey

            PRIVATE_KEY=$(<privatekey)
            PUBLIC_KEY=$(<publickey)
            
            read -p "Enter Network Interface Address: " NET_INT_ADDR
            read -p "Enter Listening Port of the Server: " LISTEN_PORT
            



        ;;
    
    esac
fi