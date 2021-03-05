# Meta Build System

## Bootstrap / Build

Requirements: `docker`

The `ci.sh` script builds two docker images (`mbs:slim`, `mbs:full`).
These images can be used to run `mbs` on any system with docker support.

An convenient alias can be defined to use `mbs` as a native CLI application.

```bash
alias mbs="docker run --init --rm -ti -v $PWD:$PWD -v /var/run/docker.sock:/var/run/docker.sock -w $PWD mbs:slim"
```

Check out the `ci.sh` script to see this in action: after the build of the docker images we use the `mbs` image to build `mbs` in `mbs`.
