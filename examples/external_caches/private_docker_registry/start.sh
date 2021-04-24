#!/bin/sh

set -e

docker run --rm -d -p 5000:5000 --name registry registry:2.7.1
