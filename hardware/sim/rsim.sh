#!/bin/bash

REMOTER=$1
SRCDIR=team45/hardware/src
SIMDIR=team45/hardware/sim/tests
RSYNC="rsync -rtc --delete-before --verbose"

$RSYNC --exclude [id]mem_blk_ram ~/$SRCDIR/ $REMOTER:~/$SRCDIR
$RSYNC ~/$SIMDIR/ $REMOTER:~/$SIMDIR


ssh $REMOTER 'cd ~/team45/hardware/sim ; make clean all | tee rtrans.txt'

