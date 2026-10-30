#!/bin/bash

if [ -z ${SUDO_USER} ]; then
    export USER_HOME="$HOME"
else
    export USER_HOME="/home/${SUDO_USER}"
fi

if lspci | grep -i NVIDIA &>/dev/null; then
    export NVIDIA_GPU=true
else
    export NVIDIA_GPU=false
fi

# The laptop by its firmware name ("ROG Flow Z13" -> rog-flow-z13): install steps that only fit one
# machine live in install/machines/$MACHINE.sh.
MACHINE=$(cat /sys/class/dmi/id/product_family 2>/dev/null || cat /sys/class/dmi/id/product_name 2>/dev/null)
export MACHINE=$(echo "$MACHINE" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-//; s/-$//')
