## Introduction

### What MBS is not

Well, first it is not Bazel :) .. joking.

It's all about **tradeoff**. We should do one thing and do it well. This can't be considered without a clear context that defines where we would like to operate; and different context means different requirements, different expectations and so different definition of "one thing done well".

What we are trying to target here is a simple thing to operate in the context of project oriented monorepositories with a number N of components where N is such that you can run a full build of it on a single machine (you can run means you accept the time it could take to complete a full build on you n-cpu-core host).

That's obviously the worst case, normally we only work on a very small subset of the components and at the "higher level" of the dependency graph. So we won't rebuild the world every time.
This is true unless you are working on a toolchain used by a lot of components.

In this context, we can build a tool that can stay simple because it doesn't have to deal with monsters, monorepository hosting thousands of components. When you really need this level of complexity other horizontaly scalable solutions are needed, at the price of infrastructure and tools complexity.


### Motivation

Soon or later most medium sized organization reach the point where they have to **standardize and normalize the CI / CD workflow** across products, teams etc.

Someone goes to the "million multi-repository jungle" and internal artifact hell versioning / compatibility matrix, while others opt to a single mono-repo or few of them. It's a matter of trade offs, considering the projects organization, teams, products, silos, people locations / offices, etc.
In general, no matter if you go for a single mono-repo or few projects oriented mono-repos, you need a standardized glue to keep things sorted and manageable, to make the dev (and ops) life easier / deterministic.

### Terminology
- **Toolchain**: defines your "build" / "deploy" recipes, standardized and parameterizable.
- **Component**: a sofware component, a piece of software with well defined functionalities and boundaries that can be build to a target artifact (via a toolchain). A component could be also a deployable target or not (for example a library that is only consumed by other components in the build phase).

In other words we can think about *toolchains* as "functions" that turns *components* into *artifacts*. If you think about it, also *toolchains* are components, in fact there's a special "bootstrapping" *toolchain*, docker, that is able to turn a *toolchain component* into a toolchain (artifact).

MBS in a "high order function" that you feed with your mono-repo (a set of components and toolchain components) and gives you back the artifacts of your components built with your toolchain built with docker...

Later on, we will see how `mbs` "builds" `mbs`, as an example of these concepts.

### Use case

As explained above, `mbs` is mostly targeted at mono-repository, and if you landed here I think you know what I'm talking about (more info at [awesome-monorepo](https://github.com/korfuri/awesome-monorepo)).

It naturally feets well with domain / component oriented design.

Remember that, like every tool, `mbs` / mono-repos / etc. are just patterns and guidelines, not a silver bullet, and should not be misused otherwise you will shoot that silver bullet in your feet. So it's essential to correctly design modules / components, their boundaries / what (business) logic we put into them and the dependecies we introduce beetween them.

### A bit of history

TODO:
extra reference to monorepo or other similar tools/solutions: cmake / ninja / doit / bazel / baur / please / hearthly / waypoint / gitlab / "pipelines in general".

TODO: describe the language oriented approach used by some tools (NPM workspaces, Elixir umbrella, GO, Rust cargo workspaces, ...), there the driver (obviously) is the language in mbs is the domain where you can develop together different things.