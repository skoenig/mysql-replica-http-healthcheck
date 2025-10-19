#!/usr/bin/env bash
set -eu

# cleanup
apt-get -y purge manpages man-db info vim-runtime
apt-get -y autoremove --purge
apt-get -y clean

rm -rf /var/lib/apt/lists/*
rm -rf /var/cache/apt/*

# lock default user
passwd --lock debian

# prepare image for first boot
rm -rf /tmp/*
echo "uninitialized" > /etc/machine-id
rm -f /var/lib/dbus/machine-id
rm -f /etc/ssh/ssh_host_*