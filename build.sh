#!/bin/bash
set -e

USE_LOCAL_SRC=true
USE_CCACHE=true
REMOVE_SRC=false

DEFAULT_DIR_SRC="./src"
DEFAULT_DIR_BUILD="./build"
DEFAULT_DIR_BUILD_DEPS="./build-deps"
DEFAULT_DIR_CONF="./conf"
DEFAULT_FILE_DEB="Sunshine.deb"

CONTAINER_NAME_BUILD="sunshine-build"
CONTAINER_NAME="sunshine"

function print() {
  local level
  local message="$2"

  if [ "$1" -eq 0 ]; then
    level="INFO"
  elif [ "$1" -eq 1 ]; then
    level="WARNING"
  elif [ "$1" -eq 2 ]; then
    level="ERROR"
  else
    level="UNKNOWN"
  fi
  echo -e "[$level] $message"
}

function make_dir_if_not_exists() {
  local dir="$1"
  if [ ! -d "$dir" ]; then
    print 0 "Creating directory: $dir"
    mkdir -p "$dir"
  else
    print 0 "Directory already exists: $dir"
  fi
}

if [ "$USE_LOCAL_SRC" = true ]; then
  make_dir_if_not_exists "$DEFAULT_DIR_SRC"
  print 0 "Using local src directory: $DEFAULT_DIR_SRC"
fi

make_dir_if_not_exists "$DEFAULT_DIR_BUILD"
make_dir_if_not_exists "$DEFAULT_DIR_BUILD_DEPS"
make_dir_if_not_exists "$DEFAULT_DIR_CONF"

if [ ! -f "$DEFAULT_DIR_BUILD/$DEFAULT_FILE_DEB" ]; then
  print 0 "Building Docker image for build environment"
  docker build -t $CONTAINER_NAME_BUILD -f Dockerfile.build .
  print 0 "Container built successfully"

  print 0 "Compiling project with Docker container"
  /bin/bash -c "
  docker run --rm -it \
    -v $(pwd)/scripts:/usr/local/bin \
    -v $(pwd)/patches:/patches \
    -v $(pwd)/build:/build \
    -v $(pwd)/conf:/conf \
    -v $(pwd)/build-deps:/build-deps \
    $(if [ "$USE_LOCAL_SRC" = true ]; then echo "-v $(pwd)/src:/src"; fi) \
    $CONTAINER_NAME_BUILD sunshine-builder.sh \
    $(if [ "$SUNSHINE_REPO" ]; then echo "--repo $SUNSHINE_REPO"; fi) \
    $(if [ "$SUNSHINE_BRANCH" ]; then echo "--branch $SUNSHINE_BRANCH"; fi) \
    $(if [ "$SUNSHINE_COMMIT" ]; then echo "--commit $SUNSHINE_COMMIT"; fi) \
    $(if [ "$USE_CCACHE" = true ]; then echo "--use-ccache"; fi) \
    $(if [ "$REMOVE_SRC" = true ]; then echo "--remove-src"; fi)
  "
fi

print 0 "Building Docker image for runtime environment"
docker build -t $CONTAINER_NAME -f Dockerfile .
print 0 "Container built successfully"
