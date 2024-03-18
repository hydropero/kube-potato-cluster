
#!/bin/bash

CGROUP_DATA='GRUB_CMDLINE_LINUX="cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1"'

if grep -Fxq "$CGROUP_DATA" /etc/default/grub
then
    # aggressively disable swap file, it's a persistent little fucker
    sudo apt install -y dphys-swapfile
    sudo dphys-swapfile swapoff
    sudo swapoff /swapfile
    sudo dphys-swapfile uninstall
    update-rc.d dphys-swapfile remove
    sudo rm -f /etc/init.d/dphys-swapfile
    sudo service dphys-swapfile stop
    sudo systemctl disable dphys-swapfile.service
    sudo sed -i 's@/swapfile    none    swap    defaults        0       0@#/swapfile    none    swap    defaults        0       0@g' /etc/fstab


    #verify swap is disable successfully
    FREE_SWAP=$(free | grep Swap | awk '{ print $2$3$4}')
    if [[ "$FREE_SWAP" != "000" ]]
    then
        echo "Swap was not successfully disabled. Investigate why. Exiting script."
        exit 1
    fi


    # Installs containerd (Container Runtime) & additional networking features
    sudo apt install -y containerd containernetworking-plugins

    if test -d /etc/containerd/
        then
            echo "containerd directory exists."
        else
            mkdir /etc/containerd
    fi
        cat <<EOF | sudo tee /etc/containerd/config.toml
        version = 2
        [plugins]
        [plugins."io.containerd.grpc.v1.cri"]
            [plugins."io.containerd.grpc.v1.cri".containerd]
            [plugins."io.containerd.grpc.v1.cri".containerd.runtimes]
                [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
                runtime_type = "io.containerd.runc.v2"
                [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
                    SystemdCgroup = true
EOF
# EOFs must be called at start of line - ie. cannot be indented/spaced forward.

    cat <<-EOF | sudo tee /etc/modules-load.d/k8s.conf
    overlay
    br_netfilter
EOF


    cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
    net.bridge.bridge-nf-call-iptables  = 1
    net.bridge.bridge-nf-call-ip6tables = 1
    net.ipv4.ip_forward                 = 1
EOF


# allows add/removal of modules from kernel
    sudo modprobe overlay
    sudo modprobe br_netfilter
    sudo sysctl --system


##############################
#     installing kubeadm
##############################

    sudo apt install -y apt-transport-https ca-certificates curl
    sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    sudo apt update && sudo apt install -y kubelet kubeadm kubectl && sudo apt-mark hold kubelet kubeadm kubectl 
    # apt-mark hold prevents this package from being auto-updated accidentally.
    

    # How flannel network implementation works - https://blog.laputa.io/kubernetes-flannel-networking-6a1cb1f8ec7c
    cd ~
    wget https://github.com/flannel-io/flannel/releases/download/v0.19.2/flanneld-arm64
    sudo chmod +x flanneld-arm64
    sudo cp flanneld-arm64 /usr/local/bin/flanneld
    sudo mkdir -p /var/lib/k8s/flannel/networks

    echo "All pre-configuration have been completed. Proceed by initializing your Kubernetes Cluster."


else
    sudo apt update -y && sudo apt dist-upgrade -y

    # There are alternative ways to achieve this on Raspberry Pi vs Le Potato and OS version dependent as well.
    sudo sed -i 's/GRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1"/g' /etc/default/grub

    sudo update-grub
    sudo reboot
fi

