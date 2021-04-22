
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

Note: these variables can be referenced in the "toolchain_opts" list.

### Dependencies directory

Dependencies target are made available to the toolchain in the components base directory under `.deps/`. The toolchain will see all the targets from the **transive dependency closure** of the component.

For example if a component A depends on a component B (that targets `b1.bin` and `b2.bin`) that depends on a component C (that targets `c1.bin`), then component A toolchains will see under `.deps/A/{b1.bin,b2.bin,c1.bin}`.

### Dependencies change

Given a component C dependent on another component D, if we detect a change in D then C is also re-built. In C's toolchain, as the first steps we normally install the component dependencies (public and internal dependencies).

Internal dependencies are normally copied / installed so that they are visible in the component's build context and can be consumed in the build process.

Now, if we execute this step unconditionally every time we run a component's build, we would install all the internal dependencies and maybe re-trigger their build wasting time. This re-build normally happens when we (or the language) share packages in source form and not compiled form, or when the language builder looks at timestamps (not checksums) to re-build its targets.

This problem is addressed with the "deps_change_step" in the toolchain manifest, it will be executed as the very first step if and only if a dependency change. For example if you change a component source file and no dependency is changed, only the toolchain steps will be executed.
