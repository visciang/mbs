#!/bin/sh

set -e

mkdir /tmp/workdir
cp terraform.tgz /tmp/workdir/
cd /tmp/workdir
tar xzf terraform.tgz

case $1 in
    apply_plan)
        terraform init -input=false
        terraform plan
        ;;
    destroy_plan)
        terraform init -input=false
        terraform plan -destroy
        ;;
    apply)
        terraform init -input=false
        terraform apply -auto-approve -input=false
        ;;
    destroy)
        terraform init -input=false
        terraform destroy -auto-approve -input=false
        ;;
    *)
        echo "bad target: $1"
        exit 1
        ;;
esac
