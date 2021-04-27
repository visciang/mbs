#!/bin/sh

set -e

case $1 in
    step_1)
        echo "RUN step_1"
        touch $MBS_ID.target_1
        ;;
    step_2)
        echo "RUN step_2"
        touch $MBS_ID.target_2
        ;;
esac
