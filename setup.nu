#!/usr/bin/env nu

source scripts/get-hyperscaler.nu
source scripts/kubernetes.nu
source scripts/ingress.nu
source scripts/storage.nu
source scripts/velero.nu

let hyperscaler = get-hyperscaler

create_kubernetes $hyperscaler "dot2" 1 2

let storage_data = create_storage $hyperscaler

apply_velero $hyperscaler $storage_data.name

let ingress_data = apply_ingress $hyperscaler "traefik" "DOT2_"

create_kubernetes $hyperscaler "dot" 1 2

apply_velero $hyperscaler $storage_data.name

let ingress_data = apply_ingress $hyperscaler

open app/base/ingress.yaml
    | upsert spec.rules.0.host $"silly-demo.($ingress_data.host)"
    | save app/base/ingress.yaml --force

kubectl apply --filename third-party/namespace-a-team.yaml

kubectl --namespace a-team apply --kustomize app/overlays/minimal

sleep 10sec

curl -X POST $"http://silly-demo.($ingress_data.host)/video?id=1&title=Video1"

curl -X POST $"http://silly-demo.($ingress_data.host)/video?id=2&title=Video2"
