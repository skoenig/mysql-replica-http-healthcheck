#!/usr/bin/env bash
set -euo pipefail

# Determine the latest image folder
folders=$(rsync --list-only "rsync://$IMAGE_PATH/" \
  | awk '{print $NF}' \
  | grep -E '^[0-9]{8}-[0-9]+/?$' \
  | sed 's:/$::')

if [ -z "$folders" ]
then
  echo "No dated folders found"
  exit 1
fi

latest_folder=$(printf '%s\n' $folders | sort -t- -k1,1n -k2,2n | tail -n1)
IMAGE_BASE_URL="https://${IMAGE_PATH}/${latest_folder}"
IMAGE_NAME="${DEBIAN_VERSION}-${IMAGE_FLAVOR}-${latest_folder}.qcow2"

# Check if the image URL is accessible
curl -sSf --head "${IMAGE_BASE_URL}/${IMAGE_NAME}" >/dev/null

# Get the short commit hash
COMMIT_SHORT=$(git rev-parse --short=8 HEAD)

# Assemble the release tag
RELEASE_TAG="${DEBIAN_VERSION}-${MYSQL_VERSION}-${latest_folder}-${COMMIT_SHORT}"

if [[ "${GITHUB_OUTPUT:-}" != "" ]]
then
  echo "image_base_url=$IMAGE_BASE_URL" >> "$GITHUB_OUTPUT"
  echo "image_name=$IMAGE_NAME" >> "$GITHUB_OUTPUT"
  echo "release_tag=$RELEASE_TAG" >> "$GITHUB_OUTPUT"
  echo "mysql_version=$MYSQL_VERSION" >> "$GITHUB_OUTPUT"
else
  echo -n "-var image_base_url=$IMAGE_BASE_URL "
  echo -n "-var image_name=$IMAGE_NAME "
  echo -n "-var release_tag=$RELEASE_TAG "
  echo -n "-var mysql_version=$MYSQL_VERSION "
fi
