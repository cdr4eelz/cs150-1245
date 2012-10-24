#!/bin/bash

PLANDIR=$HOME/team45/plan
PLANAHD=`which planAhead`

echo $PLANAHD
ls -al $PLANDIR

if [[ -d ~/team45/plan ]]; then

rm -Rf ~/team45/plan/tmp
mkdir -p ~/team45/plan/tmp
cd ~/team45/plan/tmp
$PLANAHD ../CPU.ppr >start.log 2>&1 &

fi
