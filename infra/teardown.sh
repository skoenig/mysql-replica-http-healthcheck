#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="$1"  # pass the project ID to delete

if [[ -z "$PROJECT_ID" ]]; then
  echo "Usage: $0 <PROJECT_ID>"
  exit 1
fi

echo ">> Deleting project $PROJECT_ID ..."
gcloud projects delete "$PROJECT_ID" --quiet

echo "[DONE] Project $PROJECT_ID deletion requested. Deletion may take several minutes to complete."
