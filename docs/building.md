# Building

After cloning the repo, ensure all submodules are cloned:

```
git submodule update --init --checkout --recursive
```

Also ensure you have Git LFS installed; if it wasn't installed when cloning the
repository, you'll need to pull the LFS objects with:

```
git lfs pull
```

## Containerized build

If you have a Docker-compatible CLI installed as `docker`, you can build the
firmware entirely within a container. For example, to build for QEMU:

```
./scripts/build-docker.sh qemu
```

The available targets for building are the model folders in `models/`.

This build script will produce artifacts ready for flashing under `./build/`.

You can also run the containerized build directly, with variations of:

```
docker build --build-arg=MODEL=qemu -v $PWD/build:/opt/firmware-open/build .
```

## Host build

You can alternatively build the firmware within your host environment; the
scripts currently support Debian, Fedora and Arch Linux.

Dependencies can be installed with the provided scripts.

```
./scripts/install-deps.sh
./scripts/install-rust.sh
./scripts/coreboot-sdk.sh
./ec/scripts/deps.sh
```

If rustup was installed for the first time, it will be required to source the
environment file it installed to use the correct Rust toolchain.

```
. ~/.cargo/env
```

A script is provided to build the firmware. For example, to build for QEMU:

```
./scripts/build.sh qemu
```

## Next steps

Once built, the firmware must be flashed to use. Several scripts are available
to flash the new firmware, depending on how it is going to be written.

- `scripts/qemu.sh`: [Run the firmware in QEMU](./debugging.md#using-qemu) (specific to the QEMU model)
- `scripts/flash.sh`: Flash using firmware-update
- `scripts/ch341a-flash.sh`: Flash using a CH341A programmer
- `scripts/spipi-flash.sh`: Flash using a Raspberry Pi

See [Flashing firmware](./flashing.md) for more details.
