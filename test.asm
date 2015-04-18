.text addi $r1, $r0, 20
#comment
addi $r2, $r0, 10
add $r3, $r2, $r1
sub $r4, $r2,$r1
and $r5, $r2, $r1
or $r6, $r2, $r1
sll $r7, $r2, 2
sra $r8, $r2, 2
setx 1
setx 2
blt  $r1, $r2, bltbad 
blt $r2, $r1, bltgood
bltbad: halt
bltgood: setx 3
bne $r6, $r3, bnebad
bne $r6, $r1, bnegood
bnebad: halt
bnegood: setx 4
j jumppass
halt
jumppass: setx 5
jal jaltest
halt
setx 6
j swlwtest
jaltest: addi $r31, $r31, 2
nop
nop
nop
jr $r31
halt
swlwtest: setx 7
lw $r28, 0($r0)
setx 8
sw $r28, 0($r6)
lw $r26, 0($r6)
addi $r26, $r26, 0
addi $r28, $r28, 0
bne $r26, $r28, quit
setx 9
addi $r2, $r0, 0x1
addi $r1, $r0, 0x284
custi1 $r2, $r1, 0
custi2 $r3, $r1, 0
custi2 $r3, $r1, 0
custi2 $r3, $r1, 0
custi2 $r3, $r1, 0
bne $r3, $r2, quit
nop
nop
nop
setx 10
nop
nop
nop
nop
quit: addi $r25, $r25, 1
sw $r25, 0($r6)
halt
j quit

.data
wordy: .word 0xFEEDFEED

