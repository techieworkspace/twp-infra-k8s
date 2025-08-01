#!/bin/bash

# Install essential packages.
echo "Installing essential packages."
sudo dnf install -y vim

# Remove Swap volume. 
# For more inforamtion see this: https://fedoraproject.org/wiki/Changes/SwapOnZRAM
echo "Removing swap volume."
sudo dnf remove -y zram-generator-defaults

# Install essential packages for K8s.
echo "Installing essential packages for K8s."
sudo dnf install -y ebtables ethtool socat conntrack iptables iproute-tc

# Append local DNS entires for K8s control plane and worker node.
echo "Appending local DNS entries for K8s control plane and workder node"
sudo cat <<EOF >> /etc/hosts
10.1.1.5 cpn-01.k8s.compute.internal
10.1.1.6 cpn-02.k8s.compute.internal
10.1.1.7 cpn-03.k8s.compute.internal
10.1.2.5 wn-01.k8s.compute.internal
10.1.2.6 wn-02.k8s.compute.internal
10.1.2.7 wn-02.k8s.compute.internal
EOF

# # Forwarding IPv4 and letting iptables see bridged traffic
# echo "Enabling overlay and br_netfilter kernel module for forwarding IPv4 and and letting iptables see bridged traffic."
# # Enable overlay and br_netfilter kernel module.
# cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
# overlay
# br_netfilter
# EOF
# sudo modprobe overlay
# sudo modprobe br_netfilter
# sysctl params required by setup, params persist across reboots
sudo cat <<EOF >> /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward                 = 1
vm.swappiness                       = 0
EOF
# Apply sysctl params without reboot
sudo sysctl --system

# Download directory.
DOWNLOAD_DIR="/usr/local/bin"
sudo mkdir -p "$DOWNLOAD_DIR"

# Install runc.
echo "Installing runc."
RUNC_VERSION="1.1.15"
sudo curl -L -o /usr/local/sbin/runc "https://github.com/opencontainers/runc/releases/download/v${RUNC_VERSION}/runc.amd64"
sudo chmod ugo+x /usr/local/sbin/runc

# Install containerd.
echo "Installing containerd."
CONTAINERD_VERSION="1.7.22"
ARCH="amd64"
DEST="/usr/local"
curl -L "https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/containerd-${CONTAINERD_VERSION}-linux-${ARCH}.tar.gz" | sudo tar -C $DEST -xz
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/^\([[:space:]]*SystemdCgroup = \).*/\1true/' /etc/containerd/config.toml

# Start containerd via systemd
echo "Starting containerd via systemd."
sudo mkdir -p /usr/local/lib/systemd/system
curl -sSL "https://raw.githubusercontent.com/containerd/containerd/main/containerd.service" | sudo tee /usr/local/lib/systemd/system/containerd.service
sudo systemctl daemon-reload
sudo systemctl enable --now containerd

# Install CNI plugins.
echo "Installing CNI plugins."
CNI_PLUGINS_VERSION="v1.3.0"
ARCH="amd64"
DEST="/opt/cni/bin"
sudo mkdir -p "$DEST"
curl -L "https://github.com/containernetworking/plugins/releases/download/${CNI_PLUGINS_VERSION}/cni-plugins-linux-${ARCH}-${CNI_PLUGINS_VERSION}.tgz" | sudo tar -C "$DEST" -xz

# Install commandline utility for CRI.
echo "Installing command line utility for CRI."
CRICTL_VERSION="v1.31.0"
ARCH="amd64"
curl -L "https://github.com/kubernetes-sigs/cri-tools/releases/download/${CRICTL_VERSION}/crictl-${CRICTL_VERSION}-linux-${ARCH}.tar.gz" | sudo tar -C $DOWNLOAD_DIR -xz
sudo cat <<EOF >> /etc/crictl.yaml
runtime-endpoint: unix:///var/run/containerd/containerd.sock
image-endpoint: unix:///var/run/containerd/containerd.sock
timeout: 10
debug: true
EOF

# Install kubeadm, kubelet, and kubectl.
echo "Installing kubeadm, kubelet, and kubectl."
RELEASE="v1.31.1"
ARCH="amd64"
cd $DOWNLOAD_DIR
sudo curl -L --remote-name-all https://dl.k8s.io/release/${RELEASE}/bin/linux/${ARCH}/{kubeadm,kubelet,kubectl}
sudo chmod +x {kubeadm,kubelet,kubectl}

RELEASE_VERSION="v0.16.2"
curl -sSL "https://raw.githubusercontent.com/kubernetes/release/${RELEASE_VERSION}/cmd/krel/templates/latest/kubelet/kubelet.service" | sed "s:/usr/bin:${DOWNLOAD_DIR}:g" | sudo tee /usr/lib/systemd/system/kubelet.service
sudo mkdir -p /usr/lib/systemd/system/kubelet.service.d
curl -sSL "https://raw.githubusercontent.com/kubernetes/release/${RELEASE_VERSION}/cmd/krel/templates/latest/kubeadm/10-kubeadm.conf" | sed "s:/usr/bin:${DOWNLOAD_DIR}:g" | sudo tee /usr/lib/systemd/system/kubelet.service.d/10-kubeadm.conf
sudo systemctl daemon-reload
sudo systemctl enable --now kubelet
