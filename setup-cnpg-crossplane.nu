#!/usr/bin/env nu

source scripts/get-hyperscaler.nu
source scripts/kubernetes.nu
source scripts/ingress.nu
source scripts/storage.nu
source scripts/velero.nu
source scripts/argocd.nu

let hyperscaler = get-hyperscaler

let git_url = git config --get remote.origin.url

open apps/silly-demo.yaml
    | upsert spec.source.repoURL $git_url
    | save apps/silly-demo.yaml --force

open third-party/crossplane-providers.yaml
    | upsert spec.source.repoURL $git_url
    | save third-party/crossplane-providers.yaml --force

do --ignore-errors {
    git add .

    git commit -m "Customizations"

    git push
}

create_kubernetes $hyperscaler "dot2" 1 2 true

(
    helm upgrade --install cnpg cloudnative-pg
        --repo https://cloudnative-pg.github.io/charts
        --namespace cnpg-system --create-namespace --wait
)

apply_argocd

let storage_data = create_storage $hyperscaler false

apply_velero $hyperscaler $storage_data.name

let ingress_data = get_ingress_data $hyperscaler "traefik" "DOT2_"

create_kubernetes $hyperscaler "dot" 1 2 false

(
    helm upgrade --install cnpg cloudnative-pg
        --repo https://cloudnative-pg.github.io/charts
        --namespace cnpg-system --create-namespace --wait
)

apply_argocd

apply_velero $hyperscaler $storage_data.name

let ingress_data = get_ingress_data $hyperscaler

open app/base/ingress.yaml
    | upsert spec.rules.0.host $"silly-demo.($ingress_data.host)"
    | save app/base/ingress.yaml --force

git add .

git commit -m "Customizations"

git push

apply_argocd $"argocd.($ingress_data.host)"

sleep 15sec

(
    kubectl --namespace a-team wait --for=condition=ready pod
        --selector cnpg.io/cluster=silly-demo
)

sleep 5sec

(
    kubectl --namespace a-team wait --for=condition=ready pod
        --selector app.kubernetes.io/instance=silly-demo-videos-atlas-dev-db
)

sleep 5sec

curl -X POST $"http://silly-demo.($ingress_data.host)/video?id=1&title=Video1"

curl -X POST $"http://silly-demo.($ingress_data.host)/video?id=2&title=Video2"

(
    kubectl --namespace crossplane-system
        create secret generic aws-creds
        --from-file creds=./aws-creds.conf
)
