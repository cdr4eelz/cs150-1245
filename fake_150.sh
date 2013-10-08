# Filename: .bashrc
# Description: Sources in on the class MASTER version for settings information
# 
# Please (DO NOT) edit this file unless you are sure of what you are doing.
# This file and other dotfiles have been written to work with each other.
# Any change that you are not sure off can break things in an unpredicatable
# ways.

# Set the Class MASTER variable and source the class master version of .cshrc

export MASTER=cs150
#[[ -z ${MASTER} ]] && export MASTER=${LOGNAME%-*}
[[ -z ${MASTERDIR} ]] && export MASTERDIR=$(eval echo ~${MASTER})

## Set up class wide settings
#for file in ${MASTERDIR}/adm/bashrc.d/* ; do [[ -x ${file} ]] && . "${file}"; done

# Set up local settings
#for file in ${HOME}/bashrc.d/* ; do [[ -x ${file} ]] && . "${file}"; done

export PATH=/usr/local/bin:/usr/sww/bin:/usr/bin:/bin:/usr/ucb:/usr/sfw/bin:/share/b/runas/${ARCH}:/share/b/bin

unset XILINX
if [[ -d /opt/Xilinx/default ]]; then
  . /opt/Xilinx/default/ISE_DS/settings64.sh
elif [[ -d /opt/Xilinx/14.6 ]]; then
  . /opt/Xilinx/14.6/ISE_DS/settings64.sh
elif [[ -d /opt/Xilinx/14.1 ]]; then
  . /opt/Xilinx/14.1/ISE_DS/settings64.sh
else
  . /opt/Xilinx/14.*/ISE_DS/settings64.sh
fi

#export PATH=/usr/local/cuda-4.2/bin:/Developer/NVIDIA/CUDA-5.0/bin:$PATH
#export DYLD_LIBRARY_PATH=/Developer/NVIDIA/CUDA-5.0/lib:$DYLD_LIBRARY_PATH
#export LD_LIBRARY_PATH=/usr/local/cuda-4.2/lib64:$LD_LIBRARY_PATH

unalias rm 2>/dev/null
unalias cp 2>/dev/null
unalias mv 2>/dev/null
 
export PATH=${HOME}/team45/bin:${HOME}/bin:/opt/modeltech/bin:$PATH

export TERMINFO=~/.terminfo

export EDITOR=vi
export VISUAL=gedit
