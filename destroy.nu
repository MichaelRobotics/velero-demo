#!/usr/bin/env nu

source scripts/kubernetes.nu
source scripts/storage.nu

let hyperscaler = $env.HYPERSCALER
let storage_name = $env.STORAGE_NAME

do --ignore-errors {
    (
        kubectl --namespace infra delete
            --filename $"infra/($hyperscaler).yaml"
    )
}

destroy_kubernetes $hyperscaler "dot2" false

destroy_kubernetes $hyperscaler "dot" false

destroy_storage $hyperscaler $storage_name true

rm --force .env
