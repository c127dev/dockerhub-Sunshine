#!/bin/bash
set -e

# Use ./sunshine-builder.sh --repo <repo_url> --branch <branch_name> --commit <commit> --remove-src --use-ccache

ARGS_SUNSHINE_REPO=""
ARGS_SUNSHINE_BRANCH=""
ARGS_SUNSHINE_COMMIT=""
ARGS_REMOVE_SRC=false
ARGS_USE_CCACHE=false

function print_help() {
  echo "Usage: $0 [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  --repo <repo_url>       Git repository URL to clone"
  echo "  --branch <branch_name>  Branch name to checkout"
  echo "  --commit <commit_hash>  Specific commit hash to checkout"
  echo "  --remove-src            Remove source code before cloning"
  echo "  --use-ccache            Enable CCACHE for compilation"
  echo "  -h, --help              Show this help message and exit"
}

while [[ "$1" == --* ]]; do
  case "$1" in
    --repo)
      ARGS_SUNSHINE_REPO="$2"
      shift 2
      ;;
    --branch)
      ARGS_SUNSHINE_BRANCH="$2"
      shift 2
      ;;
    --commit)
      ARGS_SUNSHINE_COMMIT="$2"
      shift 2
      ;;
    --remove-src)
      ARGS_REMOVE_SRC=true
      shift
      ;;
    --use-ccache)
      ARGS_USE_CCACHE=true
      shift
      ;;
    -h|--help)
      print_help
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      print_help
      exit 1
      ;;
  esac
done

if [ -z "$ARGS_SUNSHINE_REPO" ]; then
  ARGS_SUNSHINE_REPO="${SUNSHINE_REPO:-https://github.com/LizardByte/Sunshine.git}"
fi

if [ -z "$ARGS_SUNSHINE_BRANCH" ]; then
  ARGS_SUNSHINE_BRANCH="${BRANCH:-master}"
fi

echo "=========================================="
echo "Using repository: $ARGS_SUNSHINE_REPO"
echo "Using branch: $ARGS_SUNSHINE_BRANCH"
[ -n "$ARGS_SUNSHINE_COMMIT" ] && echo "Using commit: $ARGS_SUNSHINE_COMMIT"
echo "=========================================="

if [ "$ARGS_REMOVE_SRC" = true ]; then
  echo "Removing existing source directories..."
  rm -rf /src/* /src/.* 2>/dev/null || true
  rm -rf /build-deps/* /build-deps/.* 2>/dev/null || true
fi

if [ -f "/conf/build.env" ]; then
  echo "Loading custom compilation environment from /conf/build.env"
  source "/conf/build.env"
fi

echo "--- Setting up build-deps ---"
if [ -d "/build-deps/.git" ]; then
  echo "Updating existing build-deps repository..."
  cd /build-deps
  git fetch origin
  git reset --hard origin/master
  git clean -fdx
  git submodule update --init --recursive
else
  echo "Cloning build-deps repository..."
  find /build-deps -mindepth 1 -delete 2>/dev/null || true
  git clone --recurse-submodules https://github.com/LizardByte/build-deps.git /build-deps
fi

# Apply build-deps patches if any exist
if [ -d "/patches/build-deps" ]; then
  echo "Applying build-deps patches..."
  cd /build-deps
  patches_applied=false
  for patch in /patches/build-deps/*.patch; do
    if [ -f "$patch" ]; then
      echo "  Applying $patch"
      if git apply --verbose "$patch"; then
        patches_applied=true
      else
        echo "  Warning: Failed to apply patch $patch"
      fi
    fi
  done
  if [ "$patches_applied" = true ]; then
    echo "Committing patches to keep git tree clean..."
    git add -A
    GIT_AUTHOR_NAME="Sunshine Builder" GIT_AUTHOR_EMAIL="builder@sunshine.local" \
    GIT_COMMITTER_NAME="Sunshine Builder" GIT_COMMITTER_EMAIL="builder@sunshine.local" \
    git commit -m "Apply patches" || echo "  Warning: Failed to commit patches"
  fi
fi


echo "Compiling build-deps..."
cd /build-deps
mkdir -p build

# Append CCACHE flags if requested
if [ "$ARGS_USE_CCACHE" = true ]; then
  BUILD_DEPS_CMAKE_FLAGS+=("-DCMAKE_C_COMPILER_LAUNCHER=ccache" "-DCMAKE_CXX_COMPILER_LAUNCHER=ccache")
fi

cmake -B build -S . "${BUILD_DEPS_CMAKE_FLAGS[@]}"

ninja -C build
ninja -C build install

echo "--- Setting up Sunshine ---"
mkdir -p /src
cd /src

if [ -d "/src/.git" ]; then
  echo "Updating existing Sunshine repository..."
  if [ -n "$ARGS_SUNSHINE_COMMIT" ]; then
    if git fetch origin tag "$ARGS_SUNSHINE_COMMIT" 2>/dev/null; then
      git reset --hard FETCH_HEAD
    elif git fetch origin "$ARGS_SUNSHINE_COMMIT" 2>/dev/null; then
      git reset --hard FETCH_HEAD
    else
      echo "Warning: Direct fetch failed. Fetching all tags and resetting..."
      git fetch origin --tags
      git reset --hard "$ARGS_SUNSHINE_COMMIT"
    fi
  else
    git fetch origin
    git reset --hard origin/"$ARGS_SUNSHINE_BRANCH"
  fi
  
  git clean -fdx
  git submodule update --init --recursive
else
  echo "Cloning Sunshine repository..."
  if [ -n "$ARGS_SUNSHINE_COMMIT" ]; then
    # Full clone needed to checkout a specific commit securely
    git clone "$ARGS_SUNSHINE_REPO" /src
    git checkout "$ARGS_SUNSHINE_COMMIT"
  else
    git clone --depth 1 --branch "$ARGS_SUNSHINE_BRANCH" "$ARGS_SUNSHINE_REPO" /src
  fi
  git submodule update --init --recursive
fi

# Apply core sunshine patches if any exist
if [ -d "/patches" ]; then
  echo "Applying core Sunshine patches..."
  cd /src
  patches_applied=false
  for patch in /patches/*.patch; do
    if [ -f "$patch" ]; then
      echo "  Applying $patch"
      if git apply --verbose "$patch"; then
        patches_applied=true
      else
        echo "  Warning: Failed to apply patch $patch"
      fi
    fi
  done
  if [ "$patches_applied" = true ]; then
    echo "Committing patches to keep git tree clean..."
    git add -A
    GIT_AUTHOR_NAME="Sunshine Builder" GIT_AUTHOR_EMAIL="builder@sunshine.local" \
    GIT_COMMITTER_NAME="Sunshine Builder" GIT_COMMITTER_EMAIL="builder@sunshine.local" \
    git commit -m "Apply patches" || echo "  Warning: Failed to commit patches"
  fi
fi

echo "--- Configuring Sunshine Build ---"

# CCACHE Integration
if [ "$ARGS_USE_CCACHE" = true ]; then
  echo "Enabling CCACHE..."
  export CCACHE_DIR=/build/.ccache
  export CCACHE_MAXSIZE=10G
  mkdir -p $CCACHE_DIR
  SUNSHINE_CMAKE_FLAGS+=("-DCMAKE_C_COMPILER_LAUNCHER=ccache" "-DCMAKE_CXX_COMPILER_LAUNCHER=ccache")
fi

rm -rf build && mkdir build && cd build

cmake "${SUNSHINE_CMAKE_FLAGS[@]}" ..

echo "--- Compiling Sunshine ---"
ninja -j$(nproc)

echo "--- Packaging Sunshine (.deb) ---"
cpack -G DEB

echo "--- Copying Artifacts ---"
# Find generated .deb and move it to /build (mapped to host)
find . -name "*.deb" -exec cp {} /build/Sunshine.deb \;

echo "Build process completed successfully!"
echo "Artifact should be available in your host's build directory as Sunshine.deb"
