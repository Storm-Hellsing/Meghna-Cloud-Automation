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

    read -p "Enter Your Choise [1 or 2]: " choice

    case $choice in
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

        ;;
    
    esac
fi