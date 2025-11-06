#!/bin/sh
set -e
setup-apkrepos -cf
apk add --no-cache bash sudo cloud-init e2fsprogs

# Xen drivers
sed -i 's/^features=.*/features="base ide scsi ext4 xen-blk"/' /etc/mkinitfs/mkinitfs.conf
printf "xen-netfront\n" > /etc/modules-load.d/xen-netfront.conf

mkdir -p /etc/cloud/cloud.cfg.d

cat > /etc/cloud/cloud.cfg.d/10_rackspace.cfg <<'EOF'
datasource_list: [ ConfigDrive, None ]
disable_root: True
ssh_pwauth: True
ssh_deletekeys: False
ssh_genkeytypes:  ~
syslog_fix_perms: ~
resize_rootfs: noblock
preserve_hostname: False
manage_etc_hosts: localhost
network:
  config: disabled
EOF

cat > /etc/cloud/cloud.cfg <<'EOF'
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
  distro: alpine
  paths:
    cloud_dir: /var/lib/cloud
    templates_dir: /etc/cloud/templates
  ssh_svcname: sshd

cloud_init_modules:
  - migrator
  - seed_random
  - bootcmd
  - write-files
  - set_hostname
  - update_hostname
  - update_etc_hosts
  - ca-certs
  - rsyslog
  - users-groups
  - ssh
  - growpart
  - resizefs
  - update_etc_hosts

cloud_config_modules:
  - disk_setup
  - mounts
  - locale
  - set-passwords
  - package-update-upgrade-install
  - timezone
  - runcmd
  - locale
  - set-passwords
  - timezone
  - puppet
  - chef
  - ansible
  - salt-minion
  - mcollective
  - disable-ec2-metadata

cloud_final_modules:
  - rightscale_userdata
  - scripts-vendor
  - scripts-per-once
  - scripts-per-boot
  - scripts-per-instance
  - scripts-user
  - ssh-authkey-fingerprints
  - keys-to-console
  - final-message
  - mounts
  - ssh-import-id
  - locale
  - set-passwords
  - network
  - package-update-upgrade-install
  - write-files-deferred
  - puppet
  - chef
  - ansible
  - mcollective
  - salt-minion
  - reset_rmc
  - install-hotplug
  - phone-home
  - power-state-change
EOF

# Rebuild & go
mkinitfs -c /etc/mkinitfs/mkinitfs.conf $(uname -r)
setup-cloud-init
rc-update add sshd boot

