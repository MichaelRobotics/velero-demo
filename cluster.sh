#!/bin/bash

# Source additional scripts (if they are available in your Bash environment)
source scripts/get-hyperscaler.sh
source scripts/kubernetes.sh
source scripts/ingress.sh
source scripts/storage.sh
source scripts/velero.sh
source scripts/argocd.sh

# Get the hyperscaler
hyperscaler=$(get_hyperscaler)

# Get the Git URL
git_url=$(git config --get remote.origin.url)

# Update YAML files with the Git URL
sed -i "s|spec.source.repoURL.*|spec.source.repoURL: $git_url|" apps/silly-demo.yaml
sed -i "s|spec.source.repoURL.*|spec.source.repoURL: $git_url|" third-party/crossplane-providers.yaml

# Git operations
{
    git add .
    git commit -m "Customizations"
    git push
}

# Create Kubernetes cluster
create_kubernetes "$hyperscaler" "dot2" 1 2 true

# Helm install for CloudNative PG
helm upgrade --install cnpg cloudnative-pg \
    --repo https://cloudnative-pg.github.io/charts \
    --namespace cnpg-system --create-namespace --wait

# Apply ArgoCD
apply_argocd "" false
kubectl apply --filename argocd-third-party.yaml

# Create storage
storage_data=$(create_storage "$hyperscaler" false)

# Apply Velero
apply_velero "$hyperscaler" "$storage_data"

# Conditional setup for AWS or Google Cloud
if [ "$hyperscaler" == "aws" ]; then
    kubectl --namespace crossplane-system create secret generic aws-creds \
        --from-file creds=./aws-creds.conf
else
    start "https://console.developers.google.com/apis/api/sqladmin.googleapis.com/overview?project=$PROJECT_ID"
    echo -e "\033[1;33mENABLE\033[0m the API.\nPress any key to continue."
    read -n 1

    sa="devops-toolkit@$PROJECT_ID.iam.gserviceaccount.com"

    gcloud iam service-accounts create devops-toolkit --project "$PROJECT_ID"
    gcloud projects add-iam-policy-binding --role roles/admin --member "serviceAccount:$sa" --project "$PROJECT_ID"
    gcloud iam service-accounts keys create gcp-creds.json --project "$PROJECT_ID" --iam-account "$sa"

    kubectl --namespace crossplane-system create secret generic gcp-creds \
        --from-file creds=./gcp-creds.json
fi

# Get ingress data
ingress_data=$(get_ingress_data "$hyperscaler" "traefik" "DOT2_")

# Apply ArgoCD for ingress
apply_argocd "argocd.$ingress_data" false

# Create another Kubernetes cluster
create_kubernetes "$hyperscaler" "dot" 1 2 false

# Helm install for CloudNative PG
helm upgrade --install cnpg cloudnative-pg \
    --repo https://cloudnative-pg.github.io/charts \
    --namespace cnpg-system --create-namespace --wait

# Apply ArgoCD
apply_argocd

# Apply Velero
apply_velero "$hyperscaler" "$storage_data"

# Update ingress YAML
sed -i "s|spec.rules[0].host.*|spec.rules[0].host: silly-demo.$ingress_data|" app/base/ingress.yaml

# Google-specific setup (if using Google Cloud)
if [ "$hyperscaler" == "google" ]; then
    sed -i "s|spec.projectID.*|spec.projectID: $PROJECT_ID|" crossplane-provider-configs/config-google.yaml
fi

# Git operations again
git add .
git commit -m "Customizations"
git push

# Apply ArgoCD for ingress again
apply_argocd "argocd.$ingress_data" false

# Wait for pods to be ready
sleep 15
kubectl --namespace a-team wait --for=condition=ready pod --selector cnpg.io/cluster=silly-demo

sleep 5
kubectl --namespace a-team wait --for=condition=ready pod --selector app.kubernetes.io/instance=silly-demo-videos-atlas-dev-db

# Test the application with curl
curl -X POST "http://silly-demo.$ingress_data/video?id=1&title=Video1"
curl -X POST "http://silly-demo.$ingress_data/video?id=2&title=Video2"

# Apply credentials again based on hyperscaler
if [ "$hyperscaler" == "aws" ]; then
    kubectl --namespace crossplane-system create secret generic aws-creds \
        --from-file creds=./aws-creds.conf
else
    kubectl --namespace crossplane-system create secret generic gcp-creds \
        --from-file creds=./gcp-creds.json
fi

# Apply infrastructure YAML based on hyperscaler
kubectl --namespace infra apply --filename "infra/$hyperscaler.yaml"
