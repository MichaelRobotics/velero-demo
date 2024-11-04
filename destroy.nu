#!/usr/bin/env nu

source scripts/kubernetes.nu
source scripts/storage.nu

let hyperscaler = $env.HYPERSCALER
let storage_name = $env.STORAGE_NAME

destroy_kubernetes $hyperscaler "dot"

destroy_storage $hyperscaler $storage_name

rm --force .env
