#!/bin/bash

source "$(dirname $0)/../utils.sh"

paru -S $(cat $USER_HOME/.scripts/packages/CORE.txt)
if $NVIDIA_GPU; then
    paru -S $(cat $USER_HOME/.scripts/packages/AMD.txt)
fi

gh extension install dlvhdr/gh-dash
