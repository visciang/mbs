#!/bin/sh

set -e

TYPE="wheel"

args()
{
    options=$(
        getopt --long type: --long compile-opts: -- "$@"
    )
    if [ $? != 0 ]; then
        echo "Incorrect option provided"
        exit 1
    fi

    eval set -- "$options"

    while true; do
        case "$1" in
        --type)
            shift;
            TYPE=$1
            ;;
        --)
            shift
            break
            ;;
        esac
        shift
    done
}
 
args $0 "$@"

case $1 in
    build)
        case $TYPE in
            wheel)
                python -m build
                ;;
            zipapp)
                pip install -r requirements.txt --upgrade --target ./$MBS_ID/
                rm -rf ./$MBS_ID/*.dist-info
                python -m zipapp $MBS_ID -p "/usr/bin/env python"
                ;;
            *)
                echo "Unknown build type: $TYPE"
                exit 1
                ;;
        esac
        ;;
    *)
        echo "bad target: $1"
        exit 1
        ;;
esac
