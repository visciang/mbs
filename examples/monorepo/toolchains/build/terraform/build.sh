#!/bin/sh

set -e

case $1 in
    init)
        terraform init -backend=false -input=false
        ;;
    fmt)
        terraform fmt -check -diff
        ;;
    validate)
        terraform validate
        ;;
    build)
        rm -rf .build
        mkdir .build
        tar --exclude='.build' -czf .build/terraform.tgz .
        ;;
    *)
        echo "bad target: $1"
        exit 1
        ;;
esac
