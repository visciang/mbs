#!/bin/sh

set -e

case $1 in
    deps_change)
        rm -rf .build/
        mkdir .build/

        find .deps/ -name '*.js.tgz' -exec \
            npm install --prefix=.build/ "{}" ";"
        ;;
    build)
        npm ci
        npm pack

        find . -maxdepth 1 -name '*.tgz' -exec \
            sh -c 'mv {} node_modules/$(basename {} .tgz).js.tgz' ";"
        ;;
    *)
        echo "bad target: $1"
        exit 1
        ;;
esac
