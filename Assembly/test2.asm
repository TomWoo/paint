.text
main: addi $r1, $r0, 0
addi $r3, $r0, 0x25864
sw $r1, 0($r3)
j main
quit: halt
.data
wow: .word 0x0000B504
mystring: .string ASDASDASDASDASDASD
var: .char Z
label: .char A
heapsize: .word 0x00000003
myheap: .word 0x00000000
