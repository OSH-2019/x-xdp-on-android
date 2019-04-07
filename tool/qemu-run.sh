#!/bin/bash

qemu-system-x86_64 -vga std \
                   -m 2048 \
                   -soundhw ac97 \
                   -device virtio-net,netdev=net0 \
                   -netdev user,id=net0,hostfwd=udp::9999-:9999 \
                   -hda "$1" \
                   -monitor stdio \
                   -vnc localhost:0 \
                   -machine accel=kvm 
