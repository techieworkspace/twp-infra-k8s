#!/bin/bash

# Install essential packages.
sudo dnf install -y tree unzip vim

# Create K8s configuratin directory and change ownership.
export PROJECT_DIR=/opt/k8s
sudo mkdir -p $PROJECT_DIR
sudo chown -R vagrant:vagrant $PROJECT_DIR

# Configure static IP address.
cat <<NET_CONFIG_EOF | sudo tee /etc/NetworkManager/system-connections/eth1.ini
[connection]
id=eth1_connection
uuid=727cb087-42ce-3ffa-aea3-83bf907feb21
type=802-3-ethernet
interface-name=eth1
autoconnect=true

[ethernet]

[ipv4]
address1=10.1.2.5/24
method=manual

[ipv6]
addr-gen-mode=default
method=disabled

NET_CONFIG_EOF
sudo chmod 600 /etc/NetworkManager/system-connections/eth1.ini
