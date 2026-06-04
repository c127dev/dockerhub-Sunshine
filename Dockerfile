FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# [2026-06-03 05:58:42.166]: Error: Couldn't find any of the following libraries: [libavahi-client.so.3, libavahi-client.so]

RUN apt update && apt -y --no-install-recommends --fix-missing install \
    libcurl4 \
    libdrm2 \
    libgbm1 \
    libevdev2 \
    libnuma1 \
    libopus0 \
    libpulse0 \
    libva2 \
    libva-drm2 \
    libwayland-client0 \
    libx11-6 \
    miniupnpc \
    libcurl4t64 \
    libdrm2 \
    libevdev2 \
    libglib2.0-0t64 \
    libicu74 \
    libminiupnpc17 \
    libnuma1 \
    libpipewire-0.3-0t64 \
    libpulse0 \
    libva-drm2 \
    libva2 \
    libavahi-common3 \
    libavahi-client3 \
    libvulkan1 \
    libegl1 \
    libgl1-mesa-dri \
    mesa-va-drivers \
    libdrm-amdgpu1

# Copy compilated deb file and install it
COPY build/Sunshine.deb /app/Sunshine.deb
RUN dpkg -i /app/Sunshine.deb
RUN rm -f /app/Sunshine.deb

# Cleanup apt to reduce image size
RUN rm -rf /var/lib/apt/lists/*

# Run sunshine-server
CMD ["/usr/local/bin/sunshine"]
