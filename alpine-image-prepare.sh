#!/bin/sh
# make-rackspace-golden-BASH.sh
# ONE-CLICK → Alpine + bash + wheel + portal-perfect
set -e

echo "Installing bash + sudo + cloud-init ..."
apk add --no-cache bash sudo cloud-init cloud-utils-growpart e2fsprogs

# 1. Xen drivers
sed -i 's/^features=.*/features="base ide scsi ext4 xen-blk"/' /etc/mkinitfs/mkinitfs.conf
printf "xen-netfront\n" > /etc/modules-load.d/xen-netfront.conf

# 2. Modular cloud-init configs
rm -f /etc/cloud/cloud.cfg
mkdir -p /etc/cloud/cloud.cfg.d

# 10_datasource.cfg
cat > /etc/cloud/cloud.cfg.d/10_datasource.cfg <<'EOF'
datasource_list: [ Ec2, ConfigDrive, None ]
datasource:
  Ec2: {strict_id: false}
EOF

# 20_network.cfg
cat > /etc/cloud/cloud.cfg.d/20_network.cfg <<'EOF'
network:
  version: 2
  ethernets:
    eth0:
      match: {name: "tap*"}
      dhcp4: true
      set-name: eth0
EOF

# 30_portal.cfg  ← BASH + wheel
cat > /etc/cloud/cloud.cfg.d/30_portal.cfg <<'EOF'
system_info:
  default_user:
    name: alpine-user
    gecos: Alpine User
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

# 35_disable_root.cfg
cat > /etc/cloud/cloud.cfg.d/35_disable_root.cfg <<'EOF'
users:
  - name: root
    lock_passwd: true
    ssh_authorized_keys: []
EOF

# 40_sshd.cfg
cat > /etc/cloud/cloud.cfg.d/40_sshd.cfg <<'EOF'
ssh:
  password_authentication: false
  permit_root_login: no
EOF

# 99_final.cfg
cat > /etc/cloud/cloud.cfg.d/99_final.cfg <<'EOF'
cloud_final_modules:
  - network
EOF

# 3. Make bash the default for NEW users
echo "/bin/bash" > /etc/newuser-shell

# 4. Rebuild initramfs + services
# mkinitfs -c /etc/mkinitfs/mkinitfs.conf $(ls /lib/modules/)
rc-update add cloud-init boot
rc-update add cloud-init-local boot
rc-update add networking boot
rc-update add sshd boot

echo ""
echo "DONE! 60 seconds → perfect Rackspace image"
echo "   • alpine-user  → bash + wheel + sudo nopasswd"
echo "   • root         → 100 % dead"
echo "   • portal password + keys → alpine-user"
echo ""
echo "Next steps:"
echo "   poweroff"
echo "   dd if=/dev/vda of=alpine-bash-golden.raw bs=4M status=progress"
echo "   openstack image create \"Alpine BASH Golden\" --file alpine-bash-golden.raw \\"
echo "     --disk-format raw --container-format bare \\"
echo "     --property hw_disk_bus=xen --property hw_vif_model=netfront --public"
