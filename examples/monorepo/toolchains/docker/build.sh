#!/bin/sh

set -e

docker image build --rm --tag ${MBS_ID}:${MBS_CHECKSUM} .
