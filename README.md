# MBS - a Meta Build System

## Introduction

A **Meta Build System** to organizate / build / release/ deploy a large ~~micro~~ service oriented mono-repository with focus on **consistency**, **reproducibility** and **extensibility**.

Docker **containerization** technology is used both to run `mbs` and to define your own standardized toolchains to build your software components.

With MBS you can easly define the toolchains to build the different type of software components in you mono-repo and express the **dependency graph** among them, to consistently build only what's really changed (**checksum** based) and **cache** the results. This will give you highly **parallelized** and fast builds for free that you can consistenly run on your dev machine (exactly like your CI runner) without any need of specific software installed but only docker and your mono-repo.

The system scales well, but:
... vertical build scalability (maybe evaluate orizontal scalability later on, later, later)
... the git repo should fit in the dev machine

## Development

Development should aim to correctness, simplicity, sensible defaults and "small" codebase (with very few dependencies).

### Bootstrap / Build

Requirements: `docker`

The `ci.sh` script builds two docker images (`mbs:slim`, `mbs:full`).
These images can be used to run `mbs` on any system with docker support.

A convenient alias can be defined to use `mbs` as a native CLI application.

```bash
alias mbs="docker run --init --rm -ti -v /var/run/docker.sock:/var/run/docker.sock -v $PWD:$PWD -w $PWD -e MBS_ROOT=$PWD mbs:full"
```

or better use a wrap script like the `mbs.sh` one in this reposository.

### Terminology
- Toolchain: defines your "build" recipes, standardized and parametrizable.
- Component: a sofware component, a piece of software with well defined functionalities and boundaries that can be build to a target artifact.

### Motivation
- Soon or later most medium size organization reach the point where they have to standardize / normalize the CI/CD workflow across product, teams etc.
- a way to work consistently in a non-silos base organization
- making the Dev (and Ops) life easier / deterministic
- toolchains as part of the deps graph

### Use case
- monorepo
- feets well with domain oriented design
- feels like a modular monolith, build and deploy like a ~~micro~~ service oriented solution
- a warn on correctly design dependencies

### A bit of history

Extra reference to monorepo or other similar tools/solutions

- cmake / ninja / doit / baur / please / hearthly / gitlab / "pipelines"

## Getting Started

A quick tour based on the example/

A word about building `mbs` in `mbs`

## Development reference

## CLI interface

### command

### debug

LOG_LEVEL="debug"

### Global configuration
`.mbs-config.json`

```json
{
    // parallelism: [optional] run parallelism (default: available cores)
    "parallelism": 16,
    // cache
    "cache": {
        // where to store the file artifacts cache
        "dir": ".mbs-cache"
    },
    // timeout: [optional] components build global timeout sec (default: infinity)
    "timeout": 3600
}
```

### Toolchain manifest

```json
{
    // toolchain identifier
    "id": "toolchain-abc",
    "toolchain": {
        // toolchain dockerfile
        "dockerfile": "Dockerfile",
        // build "input" files (glob expression allowed)
        // these are the files "watched" for changes
        // define this list very carefully
        "files": [
            "build.sh"
        ],
        // toolchains steps
        // the toolchain will be executed calling the toolchain docker image with
        // the following steps as command, sequentially
        "steps": [
            "deps",
            "compile",
            "lint",
            "test",
            "build"
        ]
    }
}
```

### Component manifest

```json

{
    // component identifier
    "id": "component-xyz",
    // timeout: [optional] components build timeout sec (default: global | :infinity)
    "timeout": 3600,
    "component": {
        // toolchain used to build the component
        "toolchain": "toolchain-abc",
        // toolchain run options (passed to every toolchain "step" commands)
        "toolchain_opts": ["--type", "app"],
        // build "input" files (glob expression allowed)
        // these are the files "watched" for changes
        // define this list very carefully
        "files": [
            "**/*.c",
            // glob negation via "!"
            "!example/**/*"
        ],
        // build output targets
        // target supported are files (via file:// scheme or no scheme)
        // and docker images (docker://)
        "targets": [
            "xxx"
        ]
    }
}
```
