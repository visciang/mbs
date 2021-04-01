#!/bin/sh

set -e

case $1 in
    init)
        terraform init -backend=false -input=false
        ;;
    validate)
        terraform validate
        ;;
    build)
        tar --exclude='.build/' -czf .build/terraform.tgz .
        ;;
    *)
        echo "bad target: $1"
        exit 1
        ;;
esac
