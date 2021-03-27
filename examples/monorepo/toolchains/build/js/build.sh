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

        for TGZ in *.tgz; do
            mv $TGZ node_modules/$(basename $TGZ .tgz).js.tgz
        done
        ;;
    *)
        echo "bad target: $1"
        exit 1
        ;;
esac
