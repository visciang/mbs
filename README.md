# MBS - a Monorepo Build System

*DISCLAIMER: this is a personal POC, it's not used in any product, it's not supported or sponsored by any company. Feel free to play with it and if interested keep in touch.*

A fully dockerized **Monorepo Build System** to build, release and deploy a large service oriented mono-repository with focus on **consistency**, **reproducibility** and **extensibility**.

**Containerization** is used both to run `mbs` and to define your own standardized toolchains to build and deploy your software components.

With MBS you can define the toolchains to build and deploy the different type of software components in you mono-repo and express the **dependency graph** among them (DAG), to consistently build only what's really changed (**checksum** based) and **cache** the results, a radically different approach to "git trigger based" pipeline services. Even the toolchains used to build your components should be part of the repository: change a toolchain -> rebuild everything that depends on the toolchain.

![image info](./docs/schema-deps-graph.png)

This will give you **parallelized** fast builds for free that can consistenly run on your dev machine (exactly like your CI runner) without any need for specific software installed, but only docker and your mono-repo.

The user experience we aim to is a build system that let you properly work in a mono-repo that you feel like a modular monolith, but is built and deployed like a service oriented solution.

To summarize:
- build / release / deploy support
- first class DAG dependencies (parallelized execution)
- language independent (polyglot monorepo)
- checksum based diff detection
- sandboxed build
- no development environment on your machine, just docker (and the possibility the execute a container in privileged mode)

## Vision

Imagine a place where:
- you can define in a single repository all the pieces of a project (or multiple projects): infrastructure, applications, ops tools, toolchains to build or deploy everything in the repo. All these pieces versioned together so that you can easily work orthogonally through the stack with a single view, atomic commits, explicit dependencies and no internal versioning.
- you can onboard in almost zero time: get access to the code, clone it on a dev machine with docker, build / test / develop everything in the repo, no matter the language, runtime, framework... without the need too install any software on the host.
- you can have (if you want) a very consistent way of doing things (no snowflakes).

## Documentation
  * [Introduction](docs/introduction.md)
  * [Architecture and workflow](docs/architecture-and-workflow.md)
  * [Hermetic execution and sandboxing](docs/hermetic-execution-and-sandboxing.md)
  * [Getting Started](docs/getting-started.md)
  * [CLI interface](docs/cli-interface.md)
  * [Configuration](docs/configuration.md)
  * [Toolchains development](docs/toolchains-development.md)
  * [Components development](docs/components-development.md)

## Live demo

### Basic build

[![asciicast](https://asciinema.org/a/qD31M65fXERAWFNlRbIIlI1a4.svg)](https://asciinema.org/a/qD31M65fXERAWFNlRbIIlI1a4)

### Dependencies and changes

[![asciicast](https://asciinema.org/a/fwnUh7imRYHAof669bpSP4OwE.svg)](https://asciinema.org/a/fwnUh7imRYHAof669bpSP4OwE)

### Sandboxed execution

[![asciicast](https://asciinema.org/a/IN3OPJhjKpwRPA5dBqeJty4EZ.svg)](https://asciinema.org/a/IN3OPJhjKpwRPA5dBqeJty4EZ)

### Build development shell

[![asciicast](https://asciinema.org/a/06xg1ia6ClqCBDiYFLKVWZdTS.svg)](https://asciinema.org/a/06xg1ia6ClqCBDiYFLKVWZdTS)

### Release, deploy, destroy

[![asciicast](https://asciinema.org/a/sKEWH3tcyl8sszpSps39T8BgF.svg)](https://asciinema.org/a/sKEWH3tcyl8sszpSps39T8BgF)
