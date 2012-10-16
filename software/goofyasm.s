; Consider whether it is arbitrary to load immediate values
;  into a register with basically equivalent commands:
; ori, addiu, xori (watch out for addiu)

; Let #X be some 16'dX (16-bit immediate value)
ori       $1, $0, #X
addiu     $2, $0, #X
addu      $3, $0, $1
addu      $4, $0, $2
; What can we say about resulting values of $1, $2, $3, $4

slti      
