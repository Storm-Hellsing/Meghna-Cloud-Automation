# WireGuard Server Configuration Script

This script automates the setup and configuration of a WireGuard VPN server on a Linux system. It installs necessary dependencies, configures network settings, generates keys, and sets up the WireGuard server.

## Prerequisites

- Root privileges are required to run this script.
- Ensure that your system has `curl`, `iptables`, and `awk` installed.

## Usage

1. **Clone the repository or download the script:**

   ```sh
   git clone https://github.com/Storm-Hellsing/Meghna-Cloud-Automation/WireGuard.git
   cd WireGuard
   ```

2. **Make the script executable:**

   ```sh
   chmod +x server_wireguard.sh
   ```
   ```sh
   chmod +x client_wireguard.sh
   ```

3. **Run the script:**

Make sure to run the Server configuration Script First if you are configuring the sever for the first time. 

   ```sh
   sudo ./server_wireguard.sh
   ```

Then run the Client configuration Script

   ```sh
   sudo ./client_wireguard.sh
   ```

## Script Details

### Server Configuration

1. **Check for Root Privileges:**
   The script checks if it is run with root privileges. If not, it exits with a permission denied message.

2. **Install Dependencies:**
   - Checks if `resolvconf` or `systemd-resolved` is installed. If not, it installs `resolvconf`.
   - Checks if `wireguard` is installed. If not, it installs `wireguard`.

3. **Enable IP Forwarding:**
   - Adds `net.ipv4.ip_forward=1` to `/etc/sysctl.conf` if not already present.
   - Adds `net.ipv6.conf.all.forwarding=1` to `/etc/sysctl.conf` if not already present.
   - Applies the changes using `sysctl -p`.

4. **Generate Server Keys:**
   - Generates a private key and a public key for the server.
   - Stores the keys in `/etc/wireguard/privatekey` and `/etc/wireguard/publickey`.

5. **Configure WireGuard Server:**
   - Prompts the user to enter the network interface address with subnet (default: `10.10.10.1/24`).
   - Prompts the user to enter the listening port of the server (default: `51820`).
   - Automatically detects the network interface.
   - Creates the WireGuard configuration file `/etc/wireguard/wg0.conf` with the specified settings.

6. **Enable and Start WireGuard Service:**
   - Checks if the WireGuard service is enabled. If not, it enables the service.
   - Checks if the WireGuard service is active. If not, it starts the service. If it is active, it restarts the service.

## iptables Rules
The script sets up iptables rules to allow traffic forwarding and NAT (Network Address Translation) for the WireGuard interface. The following rules are added to the WireGuard configuration file:

### PostUp Rules:

` iptables -A FORWARD -i wg0 -o $INTERFACE -j ACCEPT:` Allows forwarding of packets from the WireGuard interface (wg0) to the detected network interface ($INTERFACE).

` iptables -t nat -A POSTROUTING -o $INTERFACE -j MASQUERADE:` Enables NAT for outgoing packets on the detected network interface ($INTERFACE).

### PreDown Rules:

`iptables -D FORWARD -i wg0 -o $INTERFACE -j ACCEPT:` Removes the forwarding rule when the WireGuard interface is brought down.

`iptables -t nat -D POSTROUTING -o $INTERFACE -j MASQUERADE:` Removes the NAT rule when the WireGuard interface is brought down.

### Client Configuration

1. **Generate Client Keys:**
   - Generates private, public, and preshared keys for each client.
   - Stores the keys in `/etc/wireguard/clients/client{n}_privatekey`, `/etc/wireguard/clients/client{n}_publickey`, and `/etc/wireguard/clients/client{n}_presharedkey`.

2. **Assign Client IP Addresses:**
   - Ensures that each client gets a unique IP address within the specified subnet.
   - Checks for existing client configuration files and IP addresses to avoid conflicts.

3. **Create Client Configuration Files:**
   - Creates a configuration file for each client in `/etc/wireguard/clients/client{n}.conf`.
   - Adds the client as a peer in the server configuration file `/etc/wireguard/wg0.conf`.

## Example Output

```sh
┓ ┏  ┓          ┏┳┓                                
┃┃┃┏┓┃┏┏┓┏┳┓┏┓   ┃ ┏┓                              
┗┻┛┗ ┗┗┗┛┛┗┗┗    ┻ ┗┛                              
┓ ┏•             ┓  ┏┓            ┳      ┓┓   •    
┃┃┃┓┏┓┏┓┏┓┓┏┏┓┏┓┏┫  ┗┓┏┓┏┓┓┏┏┓┏┓  ┃┏┓┏╋┏┓┃┃┏┓╋┓┏┓┏┓
┗┻┛┗┛ ┗ ┗┫┗┻┗┻┛ ┗┻  ┗┛┗ ┛ ┗┛┗ ┛   ┻┛┗┛┗┗┻┗┗┗┻┗┗┗┛┛┗
         ┛                                         

Permission Denied: Root Previlages Required

----------------------
Server Configurations
----------------------

Installing Depedencies.../

-------------------------------
ResolvConf is already installed.
-------------------------------

Installing WireGuard.../

-------------------------------
WireGuard is already installed.
-------------------------------

Adding NET FORWARDING for IPV4 AND IPC 6.../

IPV4 Net Forwarding already exsists. Ignoring it
IPV6 Net Forwarding already exsists. Ignoring it

wg0.conf has been created with the specified configurations. Server Configuration is now Successfully Complete.

----------------------------------------------------------------
Server Configuration Details
----------------------------------------------------------------
PrivateKey = <private_key>
Address = 10.10.10.1/24
Listening Port = 51820
DNS Server = 8.8.8.8, 8.8.4.4, 1.1.1.1
----------------------------------------------------------------

Enabling Wireguard Services...
The WireGuard service is already enabled.
The WireGuard service is already active. Restarting the service...
WireGuard service restarted successfully.
```

## Troubleshooting

- **Permission Denied:** Ensure you run the script with root privileges.
- **Dependency Installation Failed:** Check your internet connection and package manager settings.
- **Service Enable/Start Failed:** Check the status of the WireGuard service using `systemctl status wg-quick@wg0`.

## License

This project is licensed under the MIT License. See the LICENSE file for details.

## Contributing

Contributions are welcome! Please open an issue or submit a pull request for any improvements or bug fixes.

## Acknowledgements

- WireGuard - A fast, modern, and secure VPN tunnel.
- resolvconf - A framework for managing `/etc/resolv.conf`.

---
