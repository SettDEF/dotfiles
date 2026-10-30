#!/bin/bash
NAME="Xperia"
MAC=$(bluetoothctl devices | grep $NAME | awk '{print $2}')

if [ -z ${bluetoothctl}]; then
	bluetoothctl connect $MAC
else
	sudo pacman -Sy bluez bluez-utils
fi
