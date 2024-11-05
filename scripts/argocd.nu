#!/usr/bin/env nu

def apply_argocd [host_name = "", ingress_class_name = "traefik"] {

    let git_url = git config --get remote.origin.url

    if host_name != "" {

        open argocd-values.yaml
            | upsert server.ingress.ingressClassName $ingress_class_name
            | upsert server.ingress.hostname $host_name
            | save argocd-values.yaml --force

    }

    open argocd-apps.yaml
        | upsert spec.source.repoURL $git_url
        | save argocd-apps.yaml --force

    open argocd-third-party.yaml
        | upsert spec.source.repoURL $git_url
        | save argocd-third-party.yaml --force

    (
        helm upgrade --install argocd argo-cd
            --repo https://argoproj.github.io/argo-helm
            --namespace argocd --create-namespace
            --values argocd-values.yaml --wait
    )

    kubectl apply --filename argocd-apps.yaml

    kubectl apply --filename argocd-third-party.yaml

}