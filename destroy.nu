#!/usr/bin/env nu

source scripts/kubernetes.nu
source scripts/storage.nu

do --ignore-errors {
    kubectl --namespace infra apply --filename infra/aws.yaml
}

let hyperscaler = $env.HYPERSCALER
let storage_name = $env.STORAGE_NAME

destroy_kubernetes $hyperscaler "dot2" false

destroy_kubernetes $hyperscaler "dot" false

destroy_storage $hyperscaler $storage_name true

rm --force .env
