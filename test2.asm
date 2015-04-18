.text
main: addi $r1, $r0, 0
addi $r3, $r0, 0xb014
sw $r1, 0($r3)
loop: addi $r2, $r0, 0xb014
add $r0, $r0, $r0
add $r0, $r0, $r0
add $r0, $r0, $r0
add $r0, $r0, $r0
add $r2, $r2, $r30
add $r0, $r0, $r0
add $r0, $r0, $r0
add $r0, $r0, $r0
add $r0, $r0, $r0
sw $r1, 0($r2)
add $r0, $r0, $r0
add $r0, $r0, $r0
add $r0, $r0, $r0
add $r0, $r0, $r0
j loop
quit: halt
.data
wow: .word 0x0000B504
mystring: .string ASDASDASDASDASDASD
var: .char Z
label: .char A
heapsize: .word 0x00000003
myheap: .word 0x00000000
