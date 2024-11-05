#!/usr/bin/env nu

source scripts/get-hyperscaler.nu
source scripts/kubernetes.nu
source scripts/ingress.nu
source scripts/storage.nu
source scripts/velero.nu

let hyperscaler = get-hyperscaler

let git_url = git config --get remote.origin.url

create_kubernetes $hyperscaler "dot2" 1 2

let storage_data = create_storage $hyperscaler

apply_velero $hyperscaler $storage_data.name

create_kubernetes $hyperscaler "dot" 1 2

apply_velero $hyperscaler $storage_data.name

let ingress_data = get_ingress_data $hyperscaler

open app/ingress.yaml
    | upsert spec.rules.0.host $"silly-demo.($ingress_data.host)"
    | save app/ingress.yaml --force

kubectl --namespace a-team apply --filename app/

sleep 10sec

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
