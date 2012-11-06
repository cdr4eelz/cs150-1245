#!/bin/bash

SIMDIR=$HOME/team45/hardware/sim

if [[ -d $SIMDIR ]]; then

cd $SIMDIR
./mk $@

fi
