#!/bin/bash

qemu-img create -f qcow2 "$2" 10G

qemu-system-x86_64 -vga std \
                   -m 2048 -smp 2 \
                   -soundhw ac97 \
                   -net nic,model=virtio -net user \
                   -cdrom "$1" \
                   -hda "$2" \
                   -boot d \
                   -machine accel=kvm
