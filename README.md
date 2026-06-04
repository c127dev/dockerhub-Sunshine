# Hardened Sunshine Build Environment

This project is an act of security and functionality of Sunshine Game Streaming, the main reason to use it, its because it enables Sunshine multi-session for multi-screens!

And also adds somehardening to it, like running as non-root user and many other security features, so its recommended using **podman** instead of docker, beign rootless it makes so much diffcult to exploit if a compromise occurs.

## Build

There is a script that handles the build process, if you dont pass any arguments, it will use the values defined in the build script.

```bash
./build.sh
```

There are some variables to customize image building like:
- SUNSHINE_REPO: The repository to clone from (default: https://github.com/LizardByte/Sunshine)
- SUNSHINE_BRANCH: The branch to clone from (default: master)
- SUNSHINE_COMMIT: The commit to clone from (default: latest commit hash)
- USE_CCACHE: Enable ccache for build (default: true)
- REMOVE_SRC: Remove src directory before build (default: false)

## Usage
```
docker run --rm -it \
    --read-only \
    --name sunshine \
    --device /dev/dri \
    --device /dev/uinput \
    --security-opt label=disable \
    --security-opt seccomp=unconfined \
    -v /run/user/$(id -u)/pulse:/tmp/pulse \
    -v ~/.config/pulse/cookie:/tmp/pulse-cookie:ro \
    -e PULSE_COOKIE=/tmp/pulse-cookie \
    -e PULSE_SERVER=unix:/tmp/pulse \
    -e DISPLAY=$DISPLAY \
    -v $XDG_RUNTIME_DIR/$WAYLAND_DISPLAY:/tmp/wayland-0 \
    -e XDG_RUNTIME_DIR=/tmp \
    -e WAYLAND_DISPLAY=wayland-0 \
    -p 47984-47990:47984-47990/tcp \
    -p 48010:48010/tcp \
    -p 47998-48000:47998-48000/udp \
    -p 48002:48002/udp \
    -p 48010:48010/udp \
    sunshine /bin/bash
```