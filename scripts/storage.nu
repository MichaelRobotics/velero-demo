#!/usr/bin/env nu

def create_storage [provider: string] {

    let bucket = $"dot-(date now | format date "%Y%m%d%H%M%S")"
    $"export STORAGE_NAME=($bucket)\n" | save --append .env

    if $provider == "aws" {

        (
            aws s3api create-bucket --bucket $bucket
                --region us-east-1
        )
        
        aws iam create-user --user-name velero
        
        (
            aws iam put-user-policy --user-name velero
                --policy-name velero
                --policy-document file://aws-storage-policy.json
        )
        
        let access_key_id = (
            aws iam create-access-key --user-name velero
                | from json
                | get AccessKey.AccessKeyId
        )
        $"export STORAGE_ACCESS_KEY_ID=($access_key_id)\n"
            | save --append .env

    } else if $provider == "google" {

        (
            gcloud storage buckets create $"gs://($bucket)"
                --project $env.PROJECT_ID --location us-east1
        )

        (
            gcloud iam service-accounts create velero
                --project $env.PROJECT_ID --display-name "Velero"
        )

        let sa_email = $"velero@($env.PROJECT_ID).iam.gserviceaccount.com"

        (
            gcloud iam roles create velero.server
                --project $env.PROJECT_ID
                --file google-permissions.yaml
        )

        (
            gcloud projects add-iam-policy-binding $env.PROJECT_ID
                --member $"serviceAccount:($sa_email)"
                --role $"projects/($env.PROJECT_ID)/roles/velero.server"
        )

        (
            gsutil iam ch
                $"serviceAccount:($sa_email):objectAdmin"
                $"gs://($bucket)"
        )

        (
            gcloud iam service-accounts keys create
                google-creds.json --iam-account $sa_email
        )

    } else {

        print $"(ansi red_bold)($provider)(ansi reset) is not a supported."
        exit 1

    }

    {name: $bucket}

}

def destroy_storage [provider: string, storage_name: string] {

    if $provider == "aws" {

        (
            aws iam delete-access-key --user-name velero
                --access-key-id $env.STORAGE_ACCESS_KEY_ID
                --region us-east-1
        )

        (
            aws iam delete-user-policy --user-name velero
                --policy-name velero
                --region us-east-1
        )

        aws iam delete-user --user-name velero

        (        
            aws s3 rm $"s3://($storage_name)" --recursive
                --include "*"
        )

        (
            aws s3api delete-bucket --bucket $storage_name
                --region us-east-1
        )

    } else {

        print $"(ansi red_bold)($provider)(ansi reset) is not a supported."
        exit 1

    }

}
