#!/bin/sh
# make-rackspace-2025-FINAL.sh
set -e

echo "0. ENABLE REPOS"
setup-apkrepos -cf

echo "1. INSTALL PACKAGES"
apk add --no-cache bash sudo cloud-init cloud-utils-growpart e2fsprogs

echo "2. XEN DRIVERS"
sed -i 's/^features=.*/features="base ide scsi ext4 xen-blk"/' /etc/mkinitfs/mkinitfs.conf
printf "xen-netfront\n" > /etc/modules-load.d/xen-netfront.conf

echo "3. CLOUD-INIT CONFIGS"
rm -f /etc/cloud/cloud.cfg
mkdir -p /etc/cloud/cloud.cfg.d

cat > /etc/cloud/cloud.cfg.d/00_configdrive.cfg <<'EOF'
datasource_list: [ ConfigDrive ]
datasource:
  ConfigDrive:
    dsmode: local
    config_disks:
      - label: config-2
      - label: CONFIG-2
      - label: cidata
      - label: CIDATA
EOF

cat > /etc/cloud/cloud.cfg.d/20_network.cfg <<'EOF'
network:
  version: 2
  ethernets:
    eth0:
      match: {name: "tap*"}
      dhcp4: true
      set-name: eth0
EOF

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

cat > /etc/cloud/cloud.cfg.d/35_root_dead.cfg <<'EOF'
users:
  - name: root
    lock_passwd: true
    ssh_authorized_keys: []
EOF

cat > /etc/cloud/cloud.cfg.d/40_sshd.cfg <<'EOF'
ssh:
  password_authentication: false
  permit_root_login: no
EOF

cat > /etc/cloud/cloud.cfg.d/99_final.cfg <<'EOF'
cloud_final_modules:
  - network
EOF

echo "4. REBUILD INITRAMFS – FIXED"
KERNEL=$(uname -r)
echo "   Using kernel: $KERNEL"
mkinitfs -c /etc/mkinitfs/mkinitfs.conf "$KERNEL"

echo "5. ENABLE SERVICES"
rc-update add cloud-init-local boot
rc-update add cloud-init       boot
rc-update add networking       boot
rc-update add sshd             boot

echo ""
echo "GOLDEN IMAGE 100 % READY"
echo "   poweroff"
echo "   dd if=/dev/vda of=alpine-rackspace-2025.raw bs=4M status=progress"
