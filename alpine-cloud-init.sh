# Create main cloud.cfg (Alpine-adapted minimal version)
cat > mnt/etc/cloud/cloud.cfg << 'EOF'
# Minimal Alpine/Rackspace cloud.cfg
users:
  - default
disable_root: false  # Alpine allows root; adjust
preserve_hostname: false
datasource_list: [ ConfigDrive ]
cloud_init_modules:
  - seed_random
  - bootcmd
  - write-files
  - growpart
  - resizefs
  - set_hostname
  - update_etc_hosts
  - users-groups
  - ssh
cloud_config_modules:
  - disk_setup
  - mounts
  - set-passwords
  - package-update-upgrade-install
  - runcmd
cloud_final_modules:
  - scripts-per-boot
  - final-message
system_info:
  distro: alpine
  default_user:
    name: alpine
    lock_passwd: false
    groups: [wheel]
    sudo: []  # Use doas
    shell: /bin/ash
  paths:
    cloud_dir: /var/lib/cloud/
package_mirrors:
  - failsafe:
      primary: http://dl-cdn.alpinelinux.org/alpine/edge/main
      security: http://dl-cdn.alpinelinux.org/alpine/edge/community
ssh_svcname: sshd  # Alpine's service name
EOF

# Add Rackspace override
mkdir -p mnt/etc/cloud/cloud.cfg.d
cat > mnt/etc/cloud/cloud.cfg.d/10_rackspace.cfg << 'EOF'
# Rackspace-specific: Disable network config to avoid DHCP fallback
network:
  config: disabled
EOF
