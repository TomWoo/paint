.text
main: addi $r1, $r0, 0
addi $r30, $r0, 0xb014
loop: sw $r1, 0($r30)
custi1 $r1, $r30, 0
j loop
quit: halt
.data
wow: .word 0x0000B504
mystring: .string ASDASDASDASDASDASD
var: .char Z
label: .char A
heapsize: .word 0x00000003
myheap: .word 0x00000000
