#!/bin/sh

set -e

rm -rf .build/
mkdir .build/

# Install dependencies
find .deps/ -name '*.js.tgz' -exec \
    npm install --prefix=.build/ "{}" ";"

case $1 in
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
