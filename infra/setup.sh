#!/usr/bin/env bash
set -euo pipefail

source .env

IMAGE_URL="https://github.com/skoenig/mysql-replica-http-healthcheck/releases/download/debian-11-5.7-20251006-2257-7ae71f71/mysql-debian-11-5.7-20251006-2257-7ae71f71.qcow2"
IMAGE_NAME=$(basename "$IMAGE_URL" .qcow2)
PROJECT_ID="test-infra-$(date +%s)"

echo ">> Creating project $PROJECT_ID ..."
gcloud projects create "$PROJECT_ID" --name="$PROJECT_ID"

# Link billing account
gcloud billing projects link "$PROJECT_ID" --billing-account="$BILLING_ACCOUNT_ID"

# Set project as default
gcloud config set project "$PROJECT_ID"

PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")
CB_SA="${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com"

echo ">> Enabling required APIs..."
gcloud services enable \
    compute.googleapis.com \
    cloudbuild.googleapis.com \
    storage.googleapis.com \
    cloudresourcemanager.googleapis.com

echo ">> Granting Cloud Build SA required IAM roles..."
ROLES=(
  roles/compute.admin
  roles/iam.serviceAccountUser
  roles/iam.serviceAccountTokenCreator
  roles/compute.storageAdmin
)

for role in "${ROLES[@]}"
do
  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --quiet \
  --member="serviceAccount:$CB_SA" \
  --role="$role"
done

echo ">> Creating Cloud Build pipeline to import VM image..."
cat > cloudbuild.yaml <<EOF
steps:
  - name: 'gcr.io/cloud-builders/curl'
    args:
      - -L
      - -o
      - /workspace/${IMAGE_NAME}.qcow2
      - ${IMAGE_URL}

  - name: 'gcr.io/cloud-builders/gcloud'
    args:
      - compute
      - images
      - import
      - ${IMAGE_NAME//.}
      - --cmd-deprecated
      - --storage-location=$REGION
      - --source-file=/workspace/${IMAGE_NAME}.qcow2

  - name: 'gcr.io/cloud-builders/gcloud'
    entrypoint: 'bash'
    args:
      - -c
      - |
        echo "Cleaning up QCOW2 file..."
        rm -f /workspace/${IMAGE_NAME}.qcow2
EOF

gcloud builds submit --config cloudbuild.yaml --no-source

echo "[DONE] Setup complete, project details:"
echo "Project ID: $PROJECT_ID"
echo "Project Number: $PROJECT_NUMBER"
echo "Cloud Build SA: $CB_SA"
echo "Image Name: ${IMAGE_NAME//.}"

echo region=\"$REGION\" > terraform.tfvars
echo project_id=\"$PROJECT_ID\" >> terraform.tfvars
printf 'images=["%s"]\n' "${IMAGE_NAME//.}" >> terraform.tfvars
