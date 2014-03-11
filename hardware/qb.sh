#!/bin/bash

if [[ "$1"=="" ]]; then
  make clean
fi

make $1 2>&1 | tee qb.log | grep -f cfg/sparse.grep

#clear
reset

egrep --color build/ml505top/*.log -e 'warning'
egrep --color build/ml505top/*.log -e 'error'
