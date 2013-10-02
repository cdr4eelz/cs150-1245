#!/bin/bash

echo -e "\nIMPACT: $1\n\n"
if [ "$1" == "reset" ]; then
  echo -e "cleancablelock\nexit\n" | impact -batch
else
  echo -e "setMode -bscan\nsetCable -port auto\nidentify\nassignFile -p 5 -file ##BITFILE##\nprogram -p 5\nquit\n" \
   | sed -e s:##BITFILE##:$1:g \
   | impact -batch
fi
echo -e "\n\nDONE.\n"
