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
#lw $r27, pixelMemBegin($r0) # initialize the stack pointer
addi $r27, $r0, 0x00010000 # -- changed
nop
nop
nop
nop
#lw $r28, pixelMemBegin($r0) # initialize the frame pointer
addi $r28, $r0, 0x00010000 # -- changed
nop
nop
nop
nop
#lw $r23, programMemBegin($r0) # initialize the program flow stack pointer
addi $r23, $r0, 0x00001000 # -- changed
nop
nop
nop
nop
addi $r25, $r0, 64500 # set the initial pointer position (this position is currently arbitrary) # -- changed from dec
nop
nop
nop
addi $r24, $r0, 64499 # set initial old pointer position (this position is currently arbitrary) # -- changed from dec
nop
nop
nop
nop
addi $r29,$r0,0x13 # Make the initial drawing color 19 (white) # -- changed from 2
nop
nop
nop
nop
#addi $r26, $r0, 1 # pen down initially?? # -- changed
nop
nop
nop
nop
j test # change this to choose which loop to jump to
nop
nop
nop
nop
## End initialization routine
nop
nop
nop
nop

nop
nop
nop
nop
## Begin test program flow. Uncomment first instruction to run main below
nop
nop
nop
nop

nop
nop
nop
nop
test:
nop
nop
nop
nop
jal checkKeys
nop
nop
nop
nop
jal updateCursor
nop
nop
nop
nop
#jal drawSelectedLine
nop
nop
nop
nop
j test
nop
nop
nop
nop

nop
nop
nop
nop
## End test program flow
nop
nop
nop
nop

nop
nop
nop
nop
## Begin main program flow
nop
nop
nop
nop

nop
nop
nop
nop
main: #The main program flow
nop
nop
nop
nop

nop
nop
nop
nop

nop
nop
nop
nop
j main
nop
nop
nop
nop

nop
nop
nop
nop
## End main program flow
nop
nop
nop
nop

nop
nop
nop
nop
## Begin color toggling code
nop
nop
nop
nop

nop
nop
nop
nop
incrementColor: # Increment the index of the color to be drawn. loop at 0
nop
nop
nop
nop
#lw $r1, numColors($r0) # Load the number of colors
addi $r1, $r0, 20 # -- changed
nop
nop
nop
nop
blt $r29, $r1, addincthing # If the drawing color is less than the number of colors, increment the drawing color
nop
nop
nop
nop
addi $r29, $r0, 1 # Otherwise set the drawing color to 1 -- changed from 0 to 1
nop
nop
nop
nop
ret

nop
nop
nop
nop
addincthing: addi $r29, $r29, 1
nop
nop
nop
nop
j checkedInput # -- changed from ret, I also removed decrementColor (did not have any effect)
nop
nop
nop
nop

nop
nop
nop
nop
## End color toggling code
nop
nop
nop
nop

nop
nop
nop
nop
## Begin cursor drawing code
nop
nop
nop
nop

nop
nop
nop
nop
updateCursor: # Updates the cursor location. If the cursor has moved, fills in old space
nop
nop
nop
nop
bne $r25, $r24, drawCursor # If the current position doesn't equal the old position, draw the cursor
nop
nop
nop
nop
ret
nop
nop
nop
nop

nop
nop
nop
nop
drawCursor:
nop
nop
nop
nop
#First fill in old cursor area with data from memory
nop
nop
nop
nop
#While we haven't emptied the cursor stack, pop off a pixel and write it to the display
nop
nop
nop
nop
fillOld: blt $r27, $r28, doneFilling # if our current stack pointer is less than the frame pointer, we're done
nop
nop
nop
nop
lw $r2, 0($r27) # Load the pixel at our current stack pointer
nop
nop
nop
nop
sra $r3, $r2, 8 # Extract the pixel address
nop
nop
nop
nop
addi $r5, $r0, 255 #Create a mask for extracting color
nop
nop
nop
nop
or $r4, $r2, $r5 # Extract the color index of the pixel
nop
nop
nop
nop
custi1 $r4, $r3, 0 #Write this old color data to the display
nop
nop
nop
nop
addi $r27,$r27,-1 # Subtract 1 from the stack pointer
nop
nop
nop
nop
j fillOld
nop
nop
nop
nop

nop
nop
nop
nop
doneFilling: # If we're done filling in the old cursor, fill in the new cursor
nop
nop
nop
nop
addi $r27, $r28, 0 # set our stack pointer to the frame pointer
nop
nop
nop
nop
#lw $r2, cursorColor($r0) # load the cursor color
addi $r2, $r0, 2 # -- changed
nop
nop
nop
nop
custi2 $r3, $r25,0 # load the old pixel color
nop
nop
nop
nop
sll $r4, $r25, 8 # shift over the pixel address
nop
nop
nop
nop
or $r4, $r4, $r3 # or the bits together to create the pixel representation
nop
nop
nop
nop
sw $r4, 0($r27) # store the pixel onto the stack
nop
nop
nop
nop
addi $r27, $r27, 1 # increment the stack pointer
nop
nop
nop
nop

nop
nop
nop
nop
#Then draw the new cursor
nop
nop
nop
nop
addi $r3, $r0, 1 # fill the location of the current cursor with a color
nop
nop
nop
nop

nop
nop
nop
nop
#If the pen is down, fill the space where the pen used to be with the drawing color
nop
nop
nop
nop
addi $r5, $r0, 1
nop
nop
nop
nop
blt $r26, $r5, updateOldCursor #If the pen down value is 0 or less, don't store the pixel value
nop
nop
nop
nop
custi1 $r29, $r24, 0 #Otherwise, set the previous pixel's value to be the color value that we are writing -- switched args??
nop
nop
nop
nop
#TODO for bigger line widths, just modify the fill code to fill the color instead of the old color  and take off the above line
nop
nop
nop
nop
#Set the old cursor value to be the current cursor value
custi1 $r29, $r25, 0 # fill the location of the current cursor with a color
nop
nop
nop
nop
updateOldCursor: addi $r24, $r25,0
nop
nop
nop
nop
noDrawCursor:ret
nop
nop
nop
nop

nop
nop
nop
nop
## End cursor drawing code
nop
nop
nop
nop

nop
nop
nop
nop

nop
nop
nop
nop
## Start keyboard button checking
nop
nop
nop
nop

nop
nop
nop
nop
checkKeys:
nop
nop
nop
nop
bne $r22, $r30, checkUp # check for change in input -- moved continueChecking (loading constants) to run during checkedInput
nop
nop
nop
nop
ret # if not, do nothing
nop
nop
nop
nop
checkUp:
nop
nop
nop
nop
addi $r1, $r0, 117
nop
nop
nop
nop
bne $r30, $r1, checkDown
nop
nop
nop
nop
addi $r25, $r25, -640 #up
nop
nop
nop
nop
j checkedInput
nop
nop
nop
nop
checkDown:
nop
nop
nop
nop
addi $r1, $r0, 114
nop
nop
nop
nop
bne $r30, $r1, checkLeft
nop
nop
nop
nop
addi $r25, $r25, 640 #down
nop
nop
nop
nop
j checkedInput
nop
nop
nop
nop
checkLeft:
nop
nop
nop
nop
addi $r1, $r0, 107
nop
nop
nop
nop
bne $r30, $r1, checkRight
nop
nop
nop
nop
addi $r25, $r25, -1 #left
nop
nop
nop
nop
j checkedInput
nop
nop
nop
nop

nop
nop
nop
nop
checkRight:
nop
nop
nop
nop
addi $r1, $r0, 116
nop
nop
nop
nop
bne $r30, $r1, checkPageUp
nop
nop
nop
nop
addi $r25, $r25, 1 #right
nop
nop
nop
nop
j checkedInput
nop
nop
nop
nop

nop
nop
nop
nop
checkPageUp:
addi $r1, $r0, 0x3C
nop
nop
nop
nop
bne $r30, $r1, checkPageDown
nop
nop
nop
nop
addi $r26, $r0, 0 #pen up
nop
nop
nop
nop
j checkedInput
nop
nop
nop
nop
checkPageDown:
addi $r1, $r0, 0x43
nop
nop
nop
nop
bne $r30, $r1, checkHome
nop
nop
nop
nop
addi $r26, $r0, 1 #pen down
nop
nop
nop
nop
j checkedInput
nop
nop
nop
nop

nop
nop
nop
nop
checkHome:
nop
nop
nop
nop
addi $r1, $r0, 0x24
nop
nop
nop
nop
bne $r30, $r1, checkedInput
nop
nop
nop
nop
#If we pressed home, increment the color that we are drawing with the pen
nop
nop
nop
nop
#lw $r1, numColors($r0) # Load the number of colors
addi $r1, $r0, 20 # -- changed
nop
nop
nop
nop
blt $r29, $r1, addincthing # If the drawing color is less than the number of colors, increment the drawing color
nop
nop
nop
nop
addi $r29, $r0, 1 # Otherwise set the drawing color to 1 -- changed from 0 to 1
nop
nop
nop
nop
j checkedInput
nop
nop
nop
nop

nop
nop
nop
nop
checkedInput:
nop
nop
nop
nop
#lw $r2, maxPixelIndex($r0) # $r2 = 307200
addi $r2, $r0, 11 # -- changed
nop
nop
nop
nop
#lw $r3, numReservedPixels($r0) # $r3 = 25600
addi $r3, $r0, 26240 # -- changed
nop
nop
nop
nop
mul $r4, $r2, $r3 # $r4 = 307200 - 26240 = max number of usable pixels
#addi $r4, $r0, 280960 # -- changed
nop
nop
nop
nop
#lw $r5, numRowPixels($r0) # $r5 = 640
addi $r5, $r0, 640 # -- added
nop
nop
nop
nop
add $r22, $r30, $r0 # set last pressed key
nop
nop
nop
nop
blt $r25, $r3, boundTop # if $r25<25600, add by number of usable pixels. Too high up # -- changed
nop
nop
nop
nop
blt $r4, $r25, boundBottom # if $r25>280960, subtract by number of usable pixels. Too low down # -- changed
nop
nop
nop
nop
ret # else return
nop
nop
nop
nop
boundTop: addi $r25, $r25, 640 # -- changed
nop
nop
nop
nop
ret
nop
nop
nop
nop
boundBottom: addi $r25, $r25, -640 # -- changed
nop
nop
nop
nop
ret
nop
nop
nop
nop

nop
nop
nop
nop
## End keyboard button checking

.data
numColors: .word 20 #10 colors currently supported ROYGBV + Brown + Black
cursorColor: .word 0x2 #The color index currently being used for the cursor color
pixelMemBegin: .word 0x00010000 # A pointer to the beginning of the pixel memory segment of the program
programMemBegin: .word 0x00001000 #A pointer to the beginning of the program memory segment
maxPixelIndex: .word 307200 # Constant 640*480 = 307200
numReservedPixels: .word 25600 # Constant 640*40 = 25600 (40 rows)
topFeatureDimension: .word 30 #Dimensions of top feature
colorLineLocation: .word 32 # the location of the color line
numRowPixels: .word 640 # number of row pixels -- added but unused