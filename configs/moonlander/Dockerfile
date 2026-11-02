# Build environment for the Moonlander firmware, with the same compiler Oryx builds with
# (Debian bookworm's arm-none-eabi-gcc 12.2)
FROM debian:bookworm-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        binutils-arm-none-eabi gcc-arm-none-eabi libnewlib-arm-none-eabi \
        dfu-util git make python3 python3-pip \
    && rm -rf /var/lib/apt/lists/*
RUN python3 -m pip install --no-cache-dir --break-system-packages qmk \
    && git config --system --add safe.directory '*'

ENV QMK_HOME=/qmk_firmware
WORKDIR /qmk_firmware
