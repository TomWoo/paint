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
# $r23 - program flow stack pointer
# $r24 - old pointer location
# $r25 - current pointer location
# $r26 - pen down (indicates whether to draw a pixel or not
# $r27 - stack pointer
# $r28 - frame pointer
# $r29 - drawing color
# $r30 - keyboard input
# $r31 - return address
# The stack pointer will be used solely for remembering previous pixel state. This may change.
# Pixels are stored in the following format [25:8] = Pixel index (Address), [7:0] = color index
# The custi1 and custi2 operations are used for storing to the display and loading from the display memory, respectively

## Begin initialization routine

init:
lw $r27, pixelMemBegin($r0) # initialize the stack pointer
lw $r28, pixelMemBegin($r0) # initialize the frame pointer
lw $r23,  programMemBegin($r0) # initialize the program flow stack pointer
addi $r25, $r0, 2500 # set the initial pointer position (this position is currently arbitrary)
j test # change this to choose which loop to jump to
## End initialization routine

## Begin test program flow. Uncomment first instruction to run main below

test:
jal checkKeys
jal updateCursor
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
bne $r25, $r24, drawCursor # If the current position doesn't equal the old position, draw the cursor
ret

drawCursor:
#First fill in old cursor area with data from memory
#While we haven't emptied the cursor stack, pop off a pixel and write it to the display
fillOld: blt $r27, $r28, doneFilling # if our current stack pointer is less than the frame pointer, we're done
lw $r2, 0($r27) # Load the pixel at our current stack pointer
sra $r3, $r2, 8 # Extract the pixel address
addi $r5, $r0, 255 #Create a mask for extracting color
or $r4, $r2, $r5 # Extract the color index of the pixel
custi1 $r3, $r2, 0 #Write this old color data to the display
addi $r27,$r27,-1 # Subtract 1 from the stack pointer
j fillOld

doneFilling: # If we're done filling in the old cursor, fill in the new cursor
addi $r27, $r28, 0 # set our stack pointer to the frame pointer
lw $r2, cursorColor($r0) # load the cursor color
custi2 $r3, $r25,0 # load the old pixel color
sll $r4, $r25, 8 # shift over the pixel address
or $r4, $r4, $r3 # or the bits together to create the pixel representation
sw $r4, 0($r27) # store the pixel onto the stack
addi $r27, $r27, 1 # increment the stack pointer

#Then draw the new cursor
custi1 $r2, $r25, 0 # fill the location of the current cursor with a color

#If the pen is down, fill the space where the pen used to be with the drawing color
addi $r5, $r0, 1
blt $r26, $r5, updateOldCursor #If the pen down value is 0 or less, don't store the pixel value
custi1 $r24, $r29, 0 #Otherwise, set the previous pixel's value to be the color value that we are writing
#TODO for bigger line widths, just modify the fill code to fill the color instead of the old color  and take off the above line
#Set the old cursor value to be the current cursor value
updateOldCursor: addi $r24, $r25,0
ret

## End cursor drawing code


## Start keyboard button checking

checkKeys:
#TODO check for a key to change the drawing color/whether a pen is up or down
bne $r22, $r30, continueChecking # check for change in input
ret # if not, do nothing
continueChecking:
lw $r2, maxPixelIndex($r0) # $r2 = 307200
lw $r3, numReservedPixels($r0) # $r3 = 25600
sub $r4, $r2, $r3 # $r4 = 307200 - 25600 = max number of usable pixels
checkUp:
addi $r1, $r0, 42
bne $r30, $r1, checkDown
addi $r25, $r25, -640 #up
j checkedInput
checkDown:
addi $r1, $r0, 36
bne $r30, $r1, checkLeft
addi $r25, $r25, 640 #down
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
add $r22, $r30, $r0 # set last pressed key
blt $r25, $r3, wrapBegin2End # if $r25<25600, add number of usable pixels. Too high up
blt $r2, $r25, wrapEnd2Begin # if $r25>307200, subtract number of usable pixels. Too low down
ret # else return
wrapBegin2End: add $r25, $r25, $r4
ret
wrapEnd2Begin: sub $r25, $r25, $r4
ret

## End keyboard button checking


.data
numColors: .word 0x8 #8 colors currently supported ROYGBV + Brown + Black
cursorColor: .word 0x2 #The color index currently being used for the cursor color
pixelMemBegin: .word 0x00010000 # A pointer to the beginning of the pixel memory segment of the program
programMemBegin: .word 0x00001000 #A pointer to the beginning of the program memory segment
maxPixelIndex: .word 0x4b000 # Constant 640*480 = 307200
numReservedPixels: .word 0x6400 # Constant 640*40 = 25600 (40 rows)

