#!/bin/sh

set -e

setup_workdir() {
    mkdir /tmp/workdir
    cp terraform.tgz /tmp/workdir/
    cd /tmp/workdir
    tar xzf terraform.tgz
}

case $1 in
    apply_plan)
        setup_workdir
        terraform init -input=false
        terraform plan
        ;;
    destroy_plan)
        setup_workdir
        terraform init -input=false
        terraform plan -destroy
        ;;
    apply)
        cd /tmp/workdir
        terraform init -input=false
        terraform apply -auto-approve -input=false
        ;;
    destroy)
        cd /tmp/workdir
        terraform init -input=false
        terraform destroy -auto-approve -input=false
        ;;
    *)
        echo "bad target: $1"
        exit 1
        ;;
esac
