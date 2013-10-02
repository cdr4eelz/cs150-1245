#!/bin/bash

PLANDIR=$HOME/team45/plan
PLANAHD=`which planAhead`
TMPDIR=/scratch/tmp_plan

echo $PLANAHD
ls -al $PLANDIR

if [[ -e $TMPDIR ]]; then
  echo "TMPDIR exists: $(TMPDIR)"
  exit 1
fi

rm -Rf $TMPDIR
mkdir -p $TMPDIR
cd $TMPDIR
$PLANAHD ../CPU.ppr >start.log 2>&1 &
