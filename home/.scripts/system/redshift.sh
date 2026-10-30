#!/bin/bash

time=$(date "+%H")
if [[ $time -ge 20 || $time -le 6 ]]; then
	redshift-toggle 
	
else
	redshift-toggle
fi
