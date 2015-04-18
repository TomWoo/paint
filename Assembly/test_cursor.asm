.text

## Register assignments

# $r0  - 0
# $r1  - volatile
# $r2  - volatile
# $r3  - volatile
# $r4  - volatile
# $r5  - volatile
# $r6  - volatile
# $r7  - volatile
# $r8  - computation parameter 1
# $r9  - computation parameter 2
# $r10 - computation result
# $r22 - previous keyboard input
# $r24 - old pointer location
# $r25 - current pointer location
# $r26 - pen down (indicates whether to draw a pixel or not
# $r27 - stack pointer
# $r28 - frame pointer
# $r29 - drawing color
# $r30 - keyboard input
# $r31 - return address
# The stack pointer will be used solely for remembering previous pixel state. This may change.

## Begin initialization routine

init:
lw $r27, memBegin($r0) # initialize the stack pointer
lw $r27, memBegin($r0) # initialize the frame pointer
addi $r25, $r0, 2500 # set the initial pointer position (this position is currently arbitrary)
j test # change this to choose which loop to jump to
## End initialization routine

## Begin test program flow. Uncomment first instruction to run main below

test:
jal checkUp
halt
j test

## End test program flow

## Begin main program flow

main: #The main program flow


j main

## End main program flow

## Begin color toggling code

incrementColor: # Increment the index of the color to be drawn. loop at 0
lw $r1, numColors($r0) # Load the number of colors
blt $r29, $r1, 2 # If the drawing color is less than the number of colors, increment the drawing color
addi $r29, $r0, 0# Otherwise set the drawing color to 0
ret
addi $r29, $r29, 1 
ret

decrementColor: #Decrement the index of the color to be drawn. loop at 0
lw $r1, numColors($r0) # Load the number of colors
blt $r29, $r0, 0x2 # If the color index is less than 0, set it to max # colors -1
addi $r29, $r29, -1 # Otherwise decrement the drawing color
ret
addi $r1,$r1,-1
addi $r29, $r1, 0
ret

## End color toggling code

## Begin cursor drawing code

updateCursor: # Updates the cursor location. If the cursor has moved, fills in old space
bne $r25, $r26, drawCursor # If the current position doesn't equal the old position, draw the cursor
ret


drawCursor:
 #First fill in old cursor area with data from memory
#While we haven't emptied the cursor stack, pop off a pixel and write it to the display


#Then draw the new cursor


## End cursor drawing code

## Start keyboard button checking
checkKeys:
bne $r22, $r25, continueChecking # check for change in input
ret # if not, do nothing
continueChecking:
lw $r2, maxPixelIndex($r0) # $r2 = 307200
lw $r3, numReservedPixels($r0) # $r3 = 25600
sub $r4, $r2, $r3 # $r4 = 307200 - 25600 = max number of usable pixels
checkUp:
addi $r1, $r0, 42
bne $r30, $r1, checkDown
addi $r25, $r25, 640 #up
j checkedInput
checkDown:
addi $r1, $r0, 36
bne $r30, $r1, checkLeft
addi $r25, $r25, -640 #down
j checkedInput
checkLeft:
addi $r1, $r0, 22
bne $r30, $r1, checkRight
addi $r25, $r25, -1 #left
j checkedInput
checkRight:
addi $r1, $r0, 40
bne $r30, $r1, checkedInput
addi $r25, $r25, 1 #right
checkedInput:
add $r22, $r25, $r0 # set last pressed key
blt $r30, $r3, wrapBegin2End # if $r30<25600, add number of usable pixels
ret # else return
blt $r2, $r30, wrapEnd2Begin # if $r30>307200, subtract number of usable pixels
ret # else return
wrapBegin2End: add $r30, $r30, $r4
ret
wrapEnd2Begin: sub $r30, $r30, $r4
ret
## End keyboard button checking

.data
numColors: .word 0x8 #8 colors currently supported ROYGBV + Brown + Black
endPixelData: .word 0xDECDEC # A code used to indicate the end of pixel data to be written to
memBegin: .word 0x00010000 # A pointer to the beginning of the memory segment of the program
maxPixelIndex: .word 0x4b000 # Constant 640*480 = 307200
numReservedPixels: .word 0x6400 # Constant 640*40 = 25600 (40 rows)
