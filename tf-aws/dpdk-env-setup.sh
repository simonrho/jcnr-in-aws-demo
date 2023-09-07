#!/bin/bash

set -x

FLAG_FILE="/var/tmp/rebooted_once"

# Check if script has been run post-reboot
if [ -f "$FLAG_FILE" ]; then
    echo "This script has previously been executed and the system rebooted."    
    exit 0
fi

# Check the distribution from /etc/os-release
DISTRO=$(cat /etc/os-release | grep ^ID= | cut -d'=' -f2 | tr -d '"')
DISTRO_LIKE=$(cat /etc/os-release | grep ^ID_LIKE= | cut -d'=' -f2 | tr -d '"')

if [[ "$DISTRO" != "amzn" && "$DISTRO" != "centos" && "$DISTRO_LIKE" != "rhel" && "$DISTRO" != "fedora" ]]; then
    echo "This script is only intended for Amazon Linux, CentOS, RHEL, or Fedora systems."
    exit 1
fi

# Generate network configuration script for detected interfaces
sudo cat > /usr/local/bin/configure_network.sh << 'EOF'
#!/bin/bash

IFACE="$1"
CONFIG_FILE="/etc/sysconfig/network-scripts/ifcfg-$IFACE"

# If configuration doesn't exist for the interface, create one
if [ ! -f "$CONFIG_FILE" ]; then
    cat > "$CONFIG_FILE" << EOL
DEVICE=$IFACE
BOOTPROTO=dhcp
DEFROUTE=no
ONBOOT=yes
TYPE=Ethernet
PERSISTENT_DHCLIENT=yes
DHCP_ARP_CHECK=no
MTU=9000
EOL
fi
EOF

# Grant execute permissions to the script
sudo chmod +x /usr/local/bin/configure_network.sh

# Add a udev rule to trigger network configuration on new interfaces
sudo cat > /etc/udev/rules.d/90-network.rules << 'EOF'
ACTION=="add", SUBSYSTEM=="net", NAME=="eth*", RUN+="/usr/local/bin/configure_network.sh %k"
EOF

# Reload the udev rules
sudo udevadm control --reload

for iface in $(ls /sys/class/net | grep -E 'eth[1-9]+$'); do
    sudo /usr/local/bin/configure_network.sh "$iface"
done

echo "Configuration applied to existing ethN interfaces."


# Create an post-dhcp-bound-event script to manage iptables rules upon DHCP lease acquisition
sudo cat > /etc/dhcp/dhclient-exit-hooks.d/post-dhcp-bound-event.sh << 'EOF'
#!/bin/bash

# Exit if the interface is eth0
if [ "$interface" == "eth0" ]; then
    exit 0
fi

# Execute commands if the DHCP reason is BOUND (new lease obtained)
if [[ "$reason" == "BOUND" ]] || [[ "$reason" == "REBOOT" ]]; then
    # Insert rules if they don't exist
    iptables -S INPUT | grep -q "\-i $interface \-j ACCEPT" || iptables -I INPUT 1 -i "$interface" -j ACCEPT
    iptables -S OUTPUT | grep -q "\-o $interface \-j ACCEPT" || iptables -I OUTPUT 1 -o "$interface" -j ACCEPT
    iptables -S FORWARD | grep -q "\-i $interface \-j ACCEPT" || iptables -I FORWARD 1 -i "$interface" -j ACCEPT
    iptables -S FORWARD | grep -q "\-o $interface \-j ACCEPT" || iptables -I FORWARD 1 -o "$interface" -j ACCEPT
    iptables -t nat -S PREROUTING | grep -q "\-i $interface \-j ACCEPT" || iptables -t nat -I PREROUTING 1 -i "$interface" -j ACCEPT
    iptables -t nat -S POSTROUTING | grep -q "\-o $interface \-j ACCEPT" || iptables -t nat -I POSTROUTING 1 -o "$interface" -j ACCEPT
fi

env | sort > /var/tmp/dhclient_variables_"$interface".env

EOF

# Grant execute permissions
sudo chmod +x /etc/dhcp/dhclient-exit-hooks.d/post-dhcp-bound-event.sh


# Load vfio-pci module and configure IOMMU parameters on boot
# Create the service file using a heredoc
sudo cat << 'EOF' > /etc/systemd/system/vfio-setup.service
[Unit]
Description=VFIO Setup Service
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/sh -c "modprobe vfio-pci && echo 1 > /sys/module/vfio/parameters/enable_unsafe_noiommu_mode && echo 1 > /sys/module/vfio_iommu_type1/parameters/allow_unsafe_interrupts"
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd, enable and start the service
sudo systemctl daemon-reload
sudo systemctl enable vfio-setup
sudo systemctl start vfio-setup

# Configure vfio-pci for loading on boot
sudo echo "vfio-pci" > /etc/modules-load.d/vfio-pci.conf
sudo echo "options vfio enable_unsafe_noiommu_mode=1" > /etc/modprobe.d/vfio-noiommu.conf
sudo echo "vfio_iommu_type1" > /etc/modules-load.d/vfio_iommu_type1.conf
sudo echo "options vfio_iommu_type1 allow_unsafe_interrupts=1" > /etc/modprobe.d/vfio_iommu_type1.conf

# Disable Transparent Huge Pages (THP)
echo "Turning off Transparent Huge Pages..."
sudo echo never > /sys/kernel/mm/transparent_hugepage/enabled
sudo echo never > /sys/kernel/mm/transparent_hugepage/defrag

# Check for 1G Huge Page capability and allocate if available
grep -q pdpe1gb /proc/cpuinfo || (echo "Error: CPU lacks 1G huge pages support." && exit 1)
echo "Setting up 16x 1G Huge Pages..."
sudo echo 16 > /sys/kernel/mm/hugepages/hugepages-1048576kB/nr_hugepages
sudo echo 0 > /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages

# If 2M Huge Pages are mounted, unmount them
sudo mountpoint -q /mnt/huge && echo "Unmounting 2M Huge Pages..." && umount /mnt/huge

# Mount the 1G Huge Pages directory
sudo mkdir -p /mnt/huge1G
sudo mount -t hugetlbfs -o pagesize=1G none /mnt/huge1G
echo "1G Huge Pages mounted under /mnt/huge1G"

# Add mount point to fstab to persist across reboots
grep -q "/mnt/huge1G" /etc/fstab || (echo "Updating fstab..." && sudo echo "hugetlbfs /mnt/huge1G hugetlbfs pagesize=1G 0 0" >> /etc/fstab)

# Update GRUB with hugepages and IOMMU settings
grep -q "=1G hugepagesz=1G hugepages=16 intel_iommu=on iommu=pt transparent_hugepage=never" /etc/default/grub || (sudo sed -i -r 's/^(GRUB_CMDLINE_LINUX_DEFAULT=)"(.*)"/\1"\2 default_hugepagesz=1G hugepagesz=1G hugepages=16 intel_iommu=on iommu=pt transparent_hugepage=never"/' /etc/default/grub && sudo grub2-mkconfig -o /boot/grub2/grub.cfg)

# Mark that the system will be rebooted by creating a flag file
sudo touch "$FLAG_FILE"

# Ensure that all filesystem writes are flushed and committed to disk
sudo sync

# Notify of the impending reboot and then reboot the machine
echo "Initiating reboot..."
sudo reboot
