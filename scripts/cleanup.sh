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
