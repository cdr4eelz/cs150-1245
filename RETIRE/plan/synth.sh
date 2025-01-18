#!/bin/bash

SYNDIR=$HOME/team45/hardware

if [[ -d $SYNDIR ]]; then

cd $SYNDIR
./q $@

fi
