#!/usr/bin/env nu

def apply_argocd [host_name: string, ingress_class_name = "traefik"] {

    let git_url = git config --get remote.origin.url

    open argocd-values.yaml
        | upsert server.ingress.ingressClassName $ingress_class_name
        | upsert server.ingress.hostname $host_name
        | save argocd-values.yaml --force

    open argocd-app.yaml
        | upsert spec.source.repoURL $git_url
        | save argocd-app.yaml --force

    (
        helm upgrade --install argocd argo-cd
            --repo https://argoproj.github.io/argo-helm
            --namespace argocd --create-namespace
            --values argocd-values.yaml --wait
    )

    kubectl apply --filename argocd-app.yaml

}