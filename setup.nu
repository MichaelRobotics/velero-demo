#!/usr/bin/env nu

source scripts/get-hyperscaler.nu
source scripts/kubernetes.nu
source scripts/ingress.nu
source scripts/storage.nu
source scripts/velero.nu
source scripts/argocd.nu

let hyperscaler = get-hyperscaler

create_kubernetes $hyperscaler "dot2" 1 2

create_kubernetes $hyperscaler "dot" 1 2

let ingress_data = apply_ingress $hyperscaler

let storage_data = create_storage $hyperscaler

apply_velero $hyperscaler $storage_data.name

(
    helm upgrade --install cnpg cloudnative-pg
        --repo https://cloudnative-pg.github.io/charts
        --namespace cnpg-system --create-namespace --wait
)

(
    helm upgrade --install atlas-operator
        oci://ghcr.io/ariga/charts/atlas-operator
        --namespace atlas-operator --create-namespace --wait
)

open app/ingress.yaml
    | upsert spec.rules.0.host $"silly-demo.($ingress_data.host)"
    | save app/ingress.yaml --force

let git_url = git config --get remote.origin.url

open apps/silly-demo.yaml
    | upsert spec.source.repoURL $git_url
    | save apps/silly-demo.yaml --force

apply_argocd $"argocd.($ingress_data.host)"

git add .

git commit -m "Customizations"

git push

kubectl create namespace a-team






(
    kubectl --namespace a-team wait --for=condition=ready pod
        --selector cnpg.io/cluster=silly-demo
)

sleep 5sec

(
    kubectl --namespace a-team wait --for=condition=ready pod
        --selector app.kubernetes.io/instance=silly-demo-videos-atlas-dev-db
)

curl -X POST $"http://silly-demo.($ingress_data.host)/video?id=1&title=Video1"

curl -X POST $"http://silly-demo.($ingress_data.host)/video?id=2&title=Video2"
