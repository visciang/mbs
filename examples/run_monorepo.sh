#!/bin/sh

set -e

../mbs.sh version
../mbs.sh --help
../mbs.sh build ls
../mbs.sh build ls --verbose
../mbs.sh deploy ls
../mbs.sh deploy ls --verbose
../mbs.sh deploy tree
../mbs.sh build outdated
../mbs.sh build tree
../mbs.sh build run --verbose
../mbs.sh build graph
