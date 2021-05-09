## Hermetic execution and sandboxing

### Hermetic

A correct build (reproductible and deterministic) should be **hermetic** or, in other words, every build should see only files, dependencies and environment variables explicitely declared as build inputs.

A pure hermetic build should be "fully vendored", every dependency should be part of the repository (everything build from vendored sources). Now, not everyone can vendor the world and the tradeoff is to accept external dependencies from external repo (hexpm, pypi, npm, ...) trying to limit the non-determinism with the locking mechanism of the different package managers.

Another important aspect is about our source files and dependencies: the build should see only the files explicitly declared as input for our components build.

### Sandboxing

`mbs` can run the build in two modes: sandboxed or not.

In **sandbox** mode the build run in isolation. Every components build get its files and dependencies, and it run in an isolated context. When we mention dependencies we mean the targets and the source (the component dir) of the dependencies. No files can go out of this context, only the build targets are extracted and cached after a successful build.
The sandbox mode is what should be used in CI or even during development to check that the build is hermetic and consistent.

In **non sandbox** mode the build run in the repository context. Every component build directly run in the components directory, sharing the host filesystem. It means the toolchain wiil see what's there and will write build file there (making the git directory "dirty").
The non-sandbox mode is the default and is tipically used during development.

