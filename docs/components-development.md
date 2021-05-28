## Components development

While working on a component sometime is convenient to "jump into" the toolchain of that component to manualy build / test and iterate using the very same environment of mbs.

```sh
./mbs.sh build shell component_xyz
```

This will first build all the dependencies of component_xyz, start all the side-car services and the open a shell in the toolchain context.
