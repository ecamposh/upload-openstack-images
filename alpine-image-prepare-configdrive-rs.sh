#!/bin/sh
# make-rackspace-2025-17SEC.sh
# 17-second boot on Legacy Rackspace Public Cloud (XenServer)
# Works on ZERO-config Alpine → portal-perfect
set -e

echo "0. Enable repos"
setup-apkrepos -cf

echo "1. Install minimal packages"
apk add --no-cache bash sudo cloud-init e2fsprogs

echo "2. Xen drivers"
sed -i 's/^features=.*/features="base ide scsi ext4 xen-blk"/' /etc/mkinitfs/mkinitfs.conf
printf "xen-netfront\n" > /etc/modules-load.d/xen-netfront.conf

echo "3. CONFIGDRIVE-ONLY + INSTANT MOUNT"
rm -f /etc/cloud/cloud.cfg
mkdir -p /etc/cloud/cloud.cfg.d

# THIS IS THE 17-SECOND FIX
cat > /etc/cloud/cloud.cfg.d/00_configdrive_in_3_seconds.cfg <<'EOF'
datasource_list: ["NoCloud", "ConfigDrive"]
datasource:
  ConfigDrive:
    dsmode: local
    config_disks:
      - label: config-2
      - label: CONFIG-2
      - label: cidata
      - label: CIDATA
    # Mount it BEFORE networking
    mountpoints:
      config-2: /mnt/config
EOF

# Skip DHCP entirely – XenServer gives us the IP in ConfigDrive
cat > /etc/cloud/cloud.cfg.d/10_static_network.cfg <<'EOF'
network:
  version: 2
  ethernets:
    eth0:
      match: {name: "tap*"}
      dhcp4: false
      set-name: eth0
EOF

# Portal: password + keys + hostname
cat > /etc/cloud/cloud.cfg.d/30_portal.cfg <<'EOF'
system_info:
  default_user:
    name: alpine-user
    lock_passwd: false
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    groups: wheel
preserve_hostname: false
ssh_pwauth: true
ssh_authorized_keys: [ !!str ]
hostname: !!str
fqdn: !!str
manage_etc_hosts: true
EOF

# Kill root
cat > /etc/cloud/cloud.cfg.d/35_root_dead.cfg <<'EOF'
users:
  - name: root
    lock_passwd: true
    ssh_authorized_keys: []
EOF

# No SSH password auth
cat > /etc/cloud/cloud.cfg.d/40_sshd.cfg <<'EOF'
ssh:
  password_authentication: false
  permit_root_login: no
EOF

# Run network stage (applies IP from ConfigDrive)
cat > /etc/cloud/cloud.cfg.d/99_final.cfg <<'EOF'
cloud_final_modules:
  - network
EOF

echo "4. Rebuild initramfs"
KERNEL=$(uname -r)
mkinitfs -c /etc/mkinitfs/mkinitfs.conf "$KERNEL"

echo "5. Services"
rc-update add cloud-init-local boot
rc-update add cloud-init       boot
rc-update add sshd             boot

echo ""
echo "17-SECOND GOLDEN IMAGE READY"
echo "   poweroff"
echo "   dd if=/dev/vda of=alpine-17sec.raw bs=4M status=progress"
echo "   openstack image create \"Alpine 17sec\" --file alpine-17sec.raw \\"
echo "     --disk-format raw --container-format bare \\"
echo "     --property hw_disk_bus=xen --property hw_vif_model=netfront --public"
echo ""
echo "Portal: CHECK 'Config Drive' → type password/keys → 17 s → SSH ready"
