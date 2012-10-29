#!/bin/bash

REMOTER=$1
TARG=$2

echo "SIM $TARG on $REMOTER..."

BASEDIR=team45/hardware
RSYNC="rsync -rtc --delete-before --verbose"

$RSYNC --exclude [id]mem_blk_ram ~/$BASEDIR/src/ $REMOTER:~/$BASEDIR/src
$RSYNC ~/$BASEDIR/sim/tests/ $REMOTER:~/$BASEDIR/sim/tests


ssh $REMOTER "cd ~/$BASEDIR/sim ; make $TARG | tee results/rsim.log"

$RSYNC $REMOTER:~/$BASEDIR/sim/results/ ~/$BASEDIR/sim/results

