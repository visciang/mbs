#!/bin/sh

set -e

case $1 in
    step_1)
        echo "RUN step_1"
        truncate -s 100000 $MBS_ID.target_1
        ;;
    step_2)
        echo "RUN step_2"
        truncate -s 200000 $MBS_ID.target_2
        ;;
esac
