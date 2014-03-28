#!/bin/bash

cd ~/finder
HOST=`hostname --short` #`uname -n`
LOG="${HOST}_look.log"

echo -e "\n\n--- $HOST ---\n" >$HOST
date >>$HOST
w >>$HOST

echo -e "\n\n--- IDENTIFY ---\n" >>$HOST
echo -e "${XILINX}\n"
cat _identify.batch | sed "s/##HOST##/${HOST}/g" \
  | impact -batch >> $HOST 2>&1
echo -e "\n\n--- ---\n" >>$HOST

