#include "types.h"
#include "benchmark.h"
#include "ascii.h"
#include "stdio.h"

#define DATA    ((int32_t *) 0x10012000)
#define COUNT   ((int32_t *) 0x10012000)

static volatile char state = 'r';

int main(int argc, char **argv) {
    int tstart, tend;
    char s[100];
    while (1) {
        switch (state) {
            case 'r': // register variable addi
                tstart = *COUNT;
                r100m();
                tend = *COUNT;
                sprintf(s,"r: %d", tstart-tend);
                out(s);
                break;
            case 'R': // register variable, plusone function call
                break;
            case 'v': // volatile variable, addi
                break;
            case 'V': // volatile variable, plusone function call
                break;
            default: // print error? (optional)
                break;
        }
    }
}


/*
//------------------------------------
r100M:
addi $t0, $0, 0
la $t1, 10^7
loop:
addi $t0, $t0, 1
bne $t0, $t1, loop
nop
//------------
lw $t0, b
nop
addi $t0, $t0, 1
sw $t0, b
//-----------
addi $a0, $t0, 0
jal addone
nop
addi $t0, $v0, 0
*/
