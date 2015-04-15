.text
main: addi $r2, $r0, 0x1
addi $r1, $r0, 0x284
sw $r2, 0($r1)
addi $r1, $r1, 0x280
sw $r2, 0($r1)
addi $r1, $r1, 0x280
sw $r2, 0($r1)
addi $r1, $r1, 0x280
sw $r2, 0($r1)
addi $r1, $r1, 0x280
sw $r2, 0($r1)
addi $r1, $r1, 0x280
sw $r2, 0($r1)
quit: halt
.data
wow: .word 0x0000B504
mystring: .string ASDASDASDASDASDASD
var: .char Z
label: .char A
heapsize: .word 0x00000003
myheap: .word 0x00000000
