#!/bin/bash

REMOTER=$1
SRCDIR=team45/hardware/src
SIMDIR=team45/hardware/sim/tests

rsync -tr --delete-before --verbose --exclude [id]mem_blk_ram ~/$SRCDIR $REMOTER:~/$SRCDIR
rsync -tr --delete-before --verbose ~/$SIMDIR $REMOTER:~/$SIMDIR


ssh $REMOTER 'cd ~/team45/hardware/sim ; make clean all | tee rtrans.txt'

