# agogpixel/foundation-dfromd

[agogpixel/foundation](https://github.com/agogpixel/foundation) with 'Docker from Docker' functionality.

## Usage

When no `CMD` is provided, container will run as a daemon.

- Root user, with daemon: `docker run [-d] --mount source=/var/run/docker.sock,target=/var/run/docker-host.sock,type=bind agogpixel/foundation-dfromd`
- Root user, no daemon: `docker run -it --rm --mount source=/var/run/docker.sock,target=/var/run/docker-host.sock,type=bind agogpixel/foundation-dfromd <cmd>`

- Non-root user, with daemon: `docker run [-d] --user non-root --mount source=/var/run/docker.sock,target=/var/run/docker-host.sock,type=bind agogpixel/foundation-dfromd`
- Non-root user, no daemon: `docker run -it --rm --user non-root --mount source=/var/run/docker.sock,target=/var/run/docker-host.sock,type=bind agogpixel/foundation-dfromd <cmd>`

## Build

Images built via [docker buildx bake](https://docs.docker.com/engine/reference/commandline/buildx_bake/). See [docker-bake.hcl](./docker-bake.hcl) for details.

### Arguments

- `foundation_version`: `agogpixel/foundation` version [tag](https://hub.docker.com/r/agogpixel/foundation/tags?page=1&ordering=last_updated) (default: `latest`).
- `source_socket`: Docker daemon source socket (host) (default: `/var/run/docker-host.sock`).
- `target_socket`: Docker daemon target socket (container) (default: `/var/run/docker.sock`).

## Test

Images tested via bash script:

```shell
bash test.sh agogpixel/foundation-dfromd:<tag>
```

## Contributing

Discuss the change you wish to make via issue or email.

## License

Licensed under the [MIT License](./LICENSE).

## Acknowledgments

- [microsoft/vscode-dev-containers (docker-from-docker)](https://github.com/microsoft/vscode-dev-containers/tree/main/containers/docker-from-docker)
