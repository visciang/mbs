# MBS - a Meta Build System

## Introduction

A **Meta Build System** to organizate / build / release / deploy a large ~~micro~~ service oriented mono-repository with focus on **consistency**, **reproducibility** and **extensibility**.

Docker **containerization** technology is used both to run `mbs` and to define your own standardized toolchains to build and deploy your software components.

With MBS you can easly define the toolchains to build the different type of software components in you mono-repo and express the **dependency graph** among them (DAG), to consistently build only what's really changed (**checksum** based) and **cache** the results, a radically different approach to "git trigger based" pipeline services.

This will give you highly **parallelized** and fast builds for free that you can consistenly run on your dev machine (exactly like your CI runner) without any need for specific software installed but only docker and your mono-repo.

The user experience we aim to is to give you a (meta) build system that let you properly work in a mono-repo that you feel like a modular monolith, but is built and deployed like a ~~micro~~ service oriented solution.

TODO explain that:
The system scales well, but:
... vertical build scalability (maybe evaluate orizontal scalability later on, later, later)
... the git repo should fit in the dev machine

### Terminology
- **Toolchain**: defines your "build" / "deploy" recipes, standardized and parameterizable.
- **Component**: a sofware component, a piece of software with well defined functionalities and boundaries that can be build to a target artifact (via a toolchain). Acomponent could be also a deployable target or not (for example a library that is only consumed by other components)

In other words we can think about *toolchains* as "functions" that turns *components* into *artifacts*. If you think about it, also *toolchains* are components, in fact there's a special "bootstrapping" *toolchain*, docker, that is able to turn a *toolchain component* into a toolchain (artifact).
MBS in a "high order function" that you feed with your mono-repo (a set of components and toolchain components) and gives you back the artifacts of your components built with your toolchain built with docker...

Later on, we will see how `mbs` "builds" `mbs`, as an example of these concepts.

### Motivation

Soon or later most medium sized organization reach the point where they have to **standardize / normalize the CI/CD workflow** across products, teams etc.

Someone goes to the "million multi-repository jungle" and internal artifact hell versioning / compatibility matrix, while others opt to a single mono-repo or few of them. It's a matter of trade offs, considering the projects organization, teams, products, silos, people locations / offices, etc.
In general, no matter if you go for a single mono-repo or few projects oriented mono-repos, you need the glue (a standardized one) to keep things sorted and managable, to make the dev (and ops) life easier / deterministic.

### Use case

As explained above, `mbs` is mostly targeted at mono-repository, and if you landed here I think you know what I'm talking about (more info at [awesome-monorepo](https://github.com/korfuri/awesome-monorepo)).

It naturally feets well with domain / component oriented design.

Remember that, like every tool, `mbs` / mono-repos / etc. are just patterns and guidelines, not a silver bullet, and should not be misused otherwise you will shoot that silver bullet in your feet. So is essential to correclty design modules / components, their boundaries / what (business) logic we put into them and the dependecies we introduce beetween them.

### A bit of history

TODO:
extra reference to monorepo or other similar tools/solutions: cmake / ninja / doit / baur / please / hearthly / waypoint / gitlab / "pipelines in general"

## The build -> release -> deploy flow

TODO: few words about CI / CD. The real CI / CD (merge on master -> deploy production). More "waterfall" deploy cycles with "environments".

## Getting Started

To start playing with some toy examples, let's build first `mbs` (run `./ci.sh`, the only requirement is docker) and then `source mbs.sh` or `source mbs.fish` and play with `mbs`!

For example run `mbs --help` and `mbs build ls`, it will list also some examples included in the repository under `examples/monorepo/`.

TODO: a quick tour based on the example/
TODO: A word about building `mbs` in `mbs`


## CLI interface

The information below are available via `mbs --help` or `mbs <COMMAND> <SUBCOMMAND> --help`.

### Commands

- **version**:           Show the mbs version
- **build graph**:       Generate dependency graph
- **build ls**:          List available targets
- **build outdated**:    Show outdated targets
- **build run**:         Run a target build
- **build shell**:       Interactive toolchain shell
- **build tree**:        Display a dependency tree
- **release**:           Make a deployable release
- **deploy graph**:      Generate dependency graph
- **deploy ls**:         List available targets
- **deploy run**:        Run a release deploy
- **deploy tree**:       Display a dependency tree

## Configuration

### Environment variables

Environment variable that you can pass to `mbs`:

- `LOG_LEVEL`: set log level. For exmaple `LOG_LEVEL="debug` to turn on debug logs.
- `LOG_COLOR`: enable / disable color. For example `LOG_LEVEL="true"`, `LOG_LEVEL="false"`.

### Global configuration

`.mbs-config.json`

```js
{
    // parallelism: [optional] run parallelism (default: available cores)
    "parallelism": 16,
    // cache
    "cache": {
        // where to store the file artifacts cache (relative path to the repository root)
        "dir": ".mbs-cache"
    },
    // timeout: [optional] components build global timeout sec (default: infinity)
    "timeout": 3600
}
```

### Toolchain manifest (`.mbs-toolchain.json`)

```js
{
    // toolchain identifier
    "id": "toolchain-abc",
    // timeout: [optional] toolchain build timeout sec (default: global | :infinity)
    "timeout": 3600,
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

### Component build manifest (`.mbs-build.json`)

```js
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
            "xyz-target.bin"
        ],
        // build "dependencies", components this build depends on.
        // This is the element that define the build graph.
        // These dependencies will run before the current component and their target
        // will be available to this component
        "dependencies": [
            "xyz-library"
        ]
    }
}
```

### Component deploy manifest (`.mbs-deploy.json`)

```js
{
    // component identifier
    "id": "component-xyz",
    // timeout: [optional] components deploy timeout sec (default: global | :infinity)
    "timeout": 3600,
    "component": {
        // toolchain used to deploy the component's target
        "toolchain": "toolchain-abc",
        // toolchain run options (passed to every toolchain "step" commands)
        "toolchain_opts": ["--type", "app"],
        // toolchain deployed artifacts (this should be a subset of targets in the same component .mbs-build.json manifest)
        "files": [
            "xyz-target.bin"
        ],
        // deploy "dependencies".
        // This is the element that define the deploy graph.
        // These dependencies will run before the current component.
        "dependencies": [
            "xyz-infrastructure"
        ]
    }
}
```

## Toolchains development

Every mbs toolchains is defined by a docker image (ref manifest field: `dockefile`) and package all the specific tooling for a particular job. A toolchain encode the recipe for building targets out of components in discrete steps (ref manifest field: `steps`).

### Interface

The toolchain interface is very simple and CLI oriented.

Let's say we have a component:

```js
{
    "id": "make_coffee",
    "component": {
        "toolchain": "toolchain-build-cmake",
        "toolchain_opts": ["--param1", "a", "--switch2"],
        "files": [
            "CMakeLists.txt",
            "main.c"
        ],
        "targets": [
            "build/make_coffee"
        ]
    }
}
```

that is build with the cmake toolchain:

```js
{
    "id": "toolchain-build-cmake",
    "toolchain": {
        "dockerfile": "Dockerfile",
        "files": [
            "build.sh"
        ],
        "steps": [
            "build",
            "lint",
            "test",
            ...
        ]
    }
}
```

When we `mbs build run make_coffee`, `mbs` will apply the toolchain recipe to build the component (after building any upstream dependency, toolchain included, if needed).

By abstraction, if we think the toolchain as an "executable binary", the build process will be:

```sh
cd monorepo/components/make_coffee
toolchain-build-cmake "build" --param1 a --switch 2
toolchain-build-cmake "lint" --param1 a --switch 2
toolchain-build-cmake "test" --param1 a --switch 2
...

```

And at the end it expect to find the component target `build/make_coffee`.

### Environment variables

A set of predefined environment variables are available in the toolchain run context:

- `MBS_ID`: the component identifier (ref .mbs-*.json `id` field)
- `MBS_CWD`: component current working directory
- `MBS_CHECKSUM`: component checksum
- `MBS_CHECKSUM_<deps_name_normalized>`: one for every deps, the dependency checksum. For example, give a dependency named `my-lib` we will have `MBS_CHECKSUM_MY_LIB`.
- `MBS_DIR_<deps_name_normalized>`: one for every deps, the path to the directory where we can find the dependency targets. For example, give a dependency named `my-lib` we will have `MBS_DIR_MY_LIB`.

## MBS Development

Development should aim to correctness, simplicity, sensible defaults and "small" codebase (with very few dependencies).

### Bootstrap / Build

Requirements: `docker`

The `ci.sh` script builds two docker images (`mbs:slim`, `mbs:full`).
These images can be used to run `mbs` on any system with docker support.

A convenient alias can be defined to use `mbs` as a native CLI application. Pay attention to the `$PWD` in the alias, it will use the cwd from within you issue the `mbs` aliased command. So it won't work if don't issue it from the repo root directory.

```bash
alias mbs="\
    docker run --init --rm -ti \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v $PWD:$PWD -w $PWD \
        -e MBS_ROOT=$PWD \
        mbs:full
"
```

It's definetely better to use a wrapper script like [mbs.sh](./mbs.sh) in this repository, the script should be include and committed in your repository. The script can also be "sourced": `source mbs.sh`.
