#!/bin/sh
# =============================================================================
# make-rackspace-golden.sh
# One-click golden image for Rackspace Public Cloud (XenServer)
# Run inside a fresh Alpine 3.20 cloud VM
# =============================================================================

set -e  # stop on any error

echo "=== Installing packages ==="
setup-apkrepos -cf
apk add --no-cache cloud-init cloud-utils-growpart e2fsprogs

echo "=== 1. Xen disk driver (xen-blk) ==="
sed -i 's/^features=.*/features="base ide scsi ext4 xen-blk"/' /etc/mkinitfs/mkinitfs.conf

echo "=== 2. Xen network driver (xen-netfront) ==="
printf "xen-netfront\n" > /etc/modules-load.d/xen-netfront.conf

echo "=== 3. Remove stock cloud.cfg (survives upgrades) ==="
rm -f /etc/cloud/cloud.cfg

echo "=== 4. Create modular config directory ==="
mkdir -p /etc/cloud/cloud.cfg.d

echo "=== 5. Datasource (Rackspace = EC2) ==="
cat > /etc/cloud/cloud.cfg.d/10_datasource.cfg <<'EOF'
datasource_list: [ Ec2, ConfigDrive, None ]
datasource:
  Ec2:
    strict_id: false
EOF

echo "=== 6. Network (tap* → eth0) ==="
cat > /etc/cloud/cloud.cfg.d/20_network.cfg <<'EOF'
network:
  version: 2
  ethernets:
    eth0:
      match: {name: "tap*"}
      dhcp4: true
      set-name: eth0
EOF

echo "=== 7. Portal magic (password + keys + hostname) ==="
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

echo "=== 8. Force network stage ==="
cat > /etc/cloud/cloud.cfg.d/99_final.cfg <<'EOF'
cloud_final_modules:
  - network
EOF

echo "=== 9. Rebuild initramfs ==="
KERNEL=$(ls /lib/modules/ | head -1)
mkinitfs -c /etc/mkinitfs/mkinitfs.conf "$KERNEL"

echo "=== 10. Enable services ==="
rc-update add cloud-init boot
rc-update add cloud-init-local boot
rc-update add networking boot

echo ""
echo "GOLDEN IMAGE READY!"
echo "   1. Shut down the VM"
echo "   2. dd the disk:  dd if=/dev/vda of=alpine-rackspace-golden.raw bs=4M status=progress"
echo "   3. Upload with:"
echo "        openstack image create \"Alpine 3.20 Rackspace Golden\" \\"
echo "          --disk-format raw --container-format bare \\"
echo "          --property hw_disk_bus=xen --property hw_vif_model=netfront \\"
echo "          --file alpine-rackspace-golden.raw --public"
echo ""
echo "From now on: Customer Portal → pick this image → type name/password/keys → DONE"
