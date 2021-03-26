#!/bin/sh

set -e

rm -rf .build/
mkdir .build/

MBS_DIR_VARS=$(env | grep -o -E "MBS_DIR_[^=]+" || echo "")
for MBS_DIR_VAR in $MBS_DIR_VARS; do
    echo "Copy dependency $MBS_DIR_VAR in context"
    npm install --prefix=.build/ $(printenv $MBS_DIR_VAR)/*.tgz
done

case $1 in
    build)
        npm ci
        npm pack
        mv *.tgz node_modules/
        ;;
    *)
        echo "bad target: $1"
        exit 1
        ;;
esac
