#!/usr/bin/env bash

set -eu

if [ "$#" -ne 1 ] || [ -z "$1" ]
then
  echo "$0 <model>" >&2
  exit 1
fi
MODEL="$1"

if [ ! -d "models/${MODEL}" ]
then
  echo "model '${MODEL}' not found" >&2
  exit 1
fi

: \
  "${DOCKER:=$(command -v docker || command -v podman)}" \
  "${DOCKER_VOLUME_OPTIONS=z}"

if [ -z "${DOCKER_VOLUME_OPTIONS}" ]
then
  VOLUME_OPTIONS=''
else
  VOLUME_OPTIONS=":${DOCKER_VOLUME_OPTIONS}"
fi

set -x
mkdir -p build
"$DOCKER" build \
  --build-arg=MODEL="${MODEL}" \
  --volume="${PWD}/build:/opt/firmware-open/build${VOLUME_OPTIONS}" \
  .
set +x

echo "Built firmware artifacts at: ./build/${MODEL}"
