#!/usr/bin/env bash

# Copyright (c) 2021-2025 community-scripts ORG
# Author: tremor021
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/YuukanOO/seelf

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get install -y \
  make \
  gcc
msg_ok "Installed Dependencies"

install_go
NODE_VERSION="22" install_node_and_modules

msg_info "Setting up seelf. Patience"
RELEASE=$(curl -fsSL https://api.github.com/repos/YuukanOO/seelf/releases/latest | grep "tag_name" | awk '{print substr($2, 3, length($2)-4) }')
curl -fsSL "https://github.com/YuukanOO/seelf/archive/refs/tags/v${RELEASE}.tar.gz" -o $(basename "https://github.com/YuukanOO/seelf/archive/refs/tags/v${RELEASE}.tar.gz")
tar -xzf v"${RELEASE}".tar.gz
mv seelf-"${RELEASE}"/ /opt/seelf
cd /opt/seelf
$STD make build
PASS=$(openssl rand -base64 18 | tr -dc 'a-zA-Z0-9' | head -c13)
{
  echo "ADMIN_EMAIL=admin@example.com"
  echo "ADMIN_PASSWORD=$PASS"
} | tee .env ~/seelf.creds >/dev/null

echo "${RELEASE}" >/opt/seelf_version.txt
SEELF_ADMIN_EMAIL=admin@example.com SEELF_ADMIN_PASSWORD=$PASS ./seelf serve &>/dev/null &
sleep 5
kill $!
msg_ok "Done setting up seelf"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/seelf.service
[Unit]
Description=seelf Service
After=network.target

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=/opt/seelf
ExecStart=/opt/seelf/./seelf serve
Restart=always

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now seelf
msg_ok "Created Service"

motd_ssh
customize

# Cleanup
msg_info "Cleaning up"
rm -f ~/v"${RELEASE}".tar.gz
rm -f "$temp_file"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"

motd_ssh
customize
