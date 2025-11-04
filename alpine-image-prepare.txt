apk add cloud-init cloud-utils-growpart e2fsprogs && \
sed -i 's/^features=.*/features="base ide scsi ext4 xen-blk"/' /etc/mkinitfs/mkinitfs.conf && \
echo "xen-netfront" > /etc/modules-load.d/xen-netfront.conf && \
rm -f /etc/cloud/cloud.cfg && \
mkdir -p /etc/cloud/cloud.cfg.d && \
cat > /etc/cloud/cloud.cfg.d/10_datasource.cfg <<'EOF'
datasource_list: [ Ec2, ConfigDrive, None ]
datasource:
  Ec2:
    strict_id: false
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
    name: root
    lock_passwd: false
    shell: /bin/ash
preserve_hostname: false
ssh_pwauth: true
ssh_authorized_keys:
  - !!str
hostname: !!str
fqdn: !!str
manage_etc_hosts: true
EOF
cat > /etc/cloud/cloud.cfg.d/99_final.cfg <<'EOF'
cloud_final_modules:
  - network
EOF
mkinitfs -c /etc/mkinitfs/mkinitfs.conf $(ls /lib/modules/) && \
rc-update add cloud-init boot && \
rc-update add cloud-init-local boot && \
rc-update add networking boot && \
echo "Golden image ready – dd to raw and upload!"
