#!/usr/bin/env bash

# Compatibility functions for Linux
if [[ "$(uname)" == "Linux" ]]; then
  # Uncomment these lines if you want to ensure the usage of GNU coreutils and utilities
  # (on Arch Linux, these are usually already in place)
  
  # Use GNU coreutils if available
  if [ -d "/usr/bin" ]; then
    export PATH="/usr/bin:$PATH"  # Usually, this is the default on Arch
  fi
  
  # Use GNU awk if available (again, typically already installed)
  if [ -d "/usr/bin" ]; then
    export PATH="/usr/bin:$PATH"
  fi
  
  # Use GNU sed if available
  if [ -d "/usr/bin" ]; then
    export PATH="/usr/bin:$PATH"
  fi
  
  # Use bc (again, commonly available in most Linux distros)
  if [ -d "/usr/bin" ]; then
    export PATH="/usr/bin:$PATH"
  fi
fi
