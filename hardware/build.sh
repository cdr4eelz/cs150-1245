#!/bin/bash -buxE

if   [[ "$0" == "./m" ]]; then
  D_BLD="build"
elif [[ "$0" == "./n" ]]; then
  D_BLD="$0_bld"
else
  D_BLD="/scratch/$0_build_$USER"
fi

D_CFG="$0_cfg"
F_PID="$0.pid"
F_OUT="$0.out"
F_ERR="$0.err"
echo "$0: $@"
echo "  $D_CFG, $F_PID, $F_OUT, $F_ERR"
echo "  $D_BLD"
# exit 0

if [ -e "$F_PID" ]; then
  echo "ALREADY RUNNING:"
  cat $F_PID
  exit 1
fi

rm -Rf $F_PID #Shouldn't exist
touch $F_PID #Temporary (don't know pid yet)

#Start fresh logs (out & err)
echo -e "MAKE '$0': $@" |tee $F_OUT $F_ERR
date |tee -a $F_OUT $F_ERR
echo -e "\n\n" |tee -a $F_OUT $F_ERR

#Run the make itself (as sub-process)
export D_CFG
export D_BLD
make -f Makefile.x $@ > >(tee -a $F_OUT | grep --context=3 -n -f sparse.grep) 2> >(tee -a $F_ERR >&2) #&
#PID="$!"
#echo "PID: $PID" |tee $F_PID #Flag as running (real PID now)
#wait $PID
PID=87

echo -e "\n\n*** DONE ($PID) ***\n" |tee -a $F_OUT $F_ERR
date |tee -a $F_OUT $F_ERR
rm $F_PID

exit 0
