	DSK GREENSCALE

**************************************************
* Low res monochrome image display
*
*	to do:
*		detect virtualII vs openemu or real hardware
*		(or other emulator)
*
*		further optimization, to speed up framerate
*
**************************************************
* Variables
**************************************************

ROW				EQU		$FA			; row in pixels - 1-48 (#00-#2F)
COLUMN			EQU		$FB			; col in pixels - 1-40 (#00-#27)

COLOR			EQU		$FC			; index color of pixel to plot - #00-#0F
PLOTCOLOR		EQU		$21			; color to plot - #00-#0F from COLORTABLE
CHAR			EQU		$FD			; byte at PLOTROW,PLOTCOLUMN

PLOTROW			EQU		$FE			; row in text page = ROW/2, remainder = nibble
PLOTCOLUMN		EQU		$FF			; col in text page == COLUMN

IMGHI			EQU		$CE			; image data addres, HI
IMGLO			EQU		$CD			; image data addres, LO

FRAMENUM		EQU		$1D			; which frame of the anim

**************************************************
* Apple Standard Memory Locations
**************************************************
CLRLORES  	EQU	$F832
LORES     	EQU	$C050
TXTSET    	EQU	$C051
MIXCLR    	EQU	$C052
MIXSET    	EQU	$C053
TXTPAGE1  	EQU	$C054
TXTPAGE2  	EQU	$C055
KEY       	EQU	$C000
C80STOREOF	EQU	$C000
C80STOREON	EQU	$C001
STROBE    	EQU	$C010
SPEAKER   	EQU	$C030
VBL       	EQU	$C02E
RDVBLBAR  	EQU	$C019       ;not VBL (VBL signal low
WAIT		EQU	$FCA8 
RAMWRTAUX 	EQU	$C005
RAMWRTMAIN	EQU	$C004
SETAN3    	EQU	$C05E       ;Set annunciator-3 output to 0
SET80VID  	EQU	$C00D       ;enable 80-column display mode (WR-only)
CLR80VID	EQU	$C00C
HOME 		EQU	$FC58			; clear the text screen
CH        	EQU	$24			; cursor Horiz
CV        	EQU	$25			; cursor Vert
VTAB      	EQU	$FC22       ; Sets the cursor vertical position (from CV)
COUT      	EQU	$FDED       ; Calls the output routine whose address is stored in CSW,
          	   	            ;  normally COUTI
STROUT		EQU	$DB3A 		;Y=String ptr high, A=String ptr low
		
ALTTEXT		EQU	$C055
ALTTEXTOFF	EQU	$C054
	
ROMINIT   	EQU    $FB2F
ROMSETKBD 	EQU    $FE89
ROMSETVID 	EQU    $FE93
	
ALTCHAR		EQU		$C00F		; enables alternative character set - mousetext
	
BLINK		EQU		$F3
SPEED		EQU		$F1


**************************************************
* START - sets up various fiddly zero page bits
**************************************************

				ORG $2000						; PROGRAM DATA STARTS AT $2000

				JSR ROMSETVID           	 	; Init char output hook at $36/$37
				JSR ROMSETKBD           	 	; Init key input hook at $38/$39
				JSR ROMINIT               	 	; GR/HGR off, Text page 1
				
				LDA #$00
				STA BLINK						; blinking text? no thanks.
				STA LORES						; low res graphics mode
				STA MIXCLR						; For IIGS

				lda #$01
				sta $c029
				lda SETAN3
				sta CLR80VID 					; turn 80 column off

				JSR CLRLORES					; clear screen		
				
				JMP MAIN

END				STA STROBE
				STA ALTTEXTOFF
				STA TXTSET
				JSR HOME
				RTS						; END	



**************************************************
*	MAIN LOOP
**************************************************

MAIN		
				LDA #$40			; image data starts at $4000
				STA IMGHI
				LDA #$00
				STA IMGLO
				STA FRAMENUM		; frame #0

NEXTFRAME		LDA #$00			
				STA PLOTROW
				TAY					; Y IS PLOTCOLUMN
MAINLOOP
				LDA (IMGLO)			; load byte at IMGLO,IMGHI									
									; look up color from lookup table
				TAX				
				LDA COLORTABLEV2,X
				STA CHAR			; put that converted BYTE into CHAR	
				
PLOTCHAR
				LDX PLOTROW
				LDA LoLineTableL,X
				STA $0
				LDA LoLineTableH,X
				STA $1       		; now word/pointer at $0+$1 points to screen line 
LOADQUICK		
				LDA CHAR
				STA ($0),Y  		; store byte at LINE + COLUMN
				
				INC IMGLO			; increment IMGLO
				BNE INCCOLUMN		; not rolled over, skip
				INC IMGHI			; if IMGLO == 0 increment IMGHI

INCCOLUMN							; next column of 2 pixels
				INY					; Y IS PLOTCOLUMN
				CPY #$28			; loop at col 40
				BNE MAINLOOP		
				LDY #$0				; reset to col 0
INCROW			INC PLOTROW
				LDA PLOTROW
				CMP #$18
				BNE MAINLOOP

LOOPTY			INC FRAMENUM
				LDA FRAMENUM
				CMP #$08			; *** how many frames? ***
				BEQ MAIN
				JMP NEXTFRAME		; wait for input...				

			   

**************************************************
* Data Tables
*
* I was looking up each nibble, then converting 
* the two nibbles to a full byte, but it's 
* considerably faster to lookup a full byte at
* a time, skipping manipulating nibbles.
*
**************************************************

COLORTABLEV2	HEX 00,02,06,01,04,05,08,03,0C,09,07,0A,0B,0E,0D,0F		; Low res colors from darkest to lightest for Virtual ][
				HEX 20,22,26,21,24,25,28,23,2C,29,27,2A,2B,2E,2D,2F
				HEX 60,62,66,61,64,65,68,63,6C,69,67,6A,6B,6E,6D,6F
				HEX 10,12,16,11,14,15,18,13,1C,19,17,1A,1B,1E,1D,1F
				HEX 40,42,46,41,44,45,48,43,4C,49,47,4A,4B,4E,4D,4F
				HEX 50,52,56,51,54,55,58,53,5C,59,57,5A,5B,5E,5D,5F
				HEX 80,82,86,81,84,85,88,83,8C,89,87,8A,8B,8E,8D,8F
				HEX 30,32,36,31,34,35,38,33,3C,39,37,3A,3B,3E,3D,3F
				HEX C0,C2,C6,C1,C4,C5,C8,C3,CC,C9,C7,CA,CB,CE,CD,CF
				HEX 90,92,96,91,94,95,98,93,9C,99,97,9A,9B,9E,9D,9F
				HEX 70,72,76,71,74,75,78,73,7C,79,77,7A,7B,7E,7D,7F
				HEX A0,A2,A6,A1,A4,A5,A8,A3,AC,A9,A7,AA,AB,AE,AD,AF
				HEX B0,B2,B6,B1,B4,B5,B8,B3,BC,B9,B7,BA,BB,BE,BD,BF
				HEX E0,E2,E6,E1,E4,E5,E8,E3,EC,E9,E7,EA,EB,EE,ED,EF
				HEX D0,D2,D6,D1,D4,D5,D8,D3,DC,D9,D7,DA,DB,DE,DD,DF
				HEX F0,F2,F6,F1,F4,F5,F8,F3,FC,F9,F7,FA,FB,FE,FD,FF
				
				
				
				
				
COLORTABLE		HEX 00,02,01,04,08,03,06,0C,09,05,0A,07,0B,0E,0D,0F		; Same, for OpenEmulator, real hardware.




**************************************************
* Lores/Text lines
* Thanks to Dagen Brock for this.
**************************************************
Lo01                 equ   $400
Lo02                 equ   $480
Lo03                 equ   $500
Lo04                 equ   $580
Lo05                 equ   $600
Lo06                 equ   $680
Lo07                 equ   $700
Lo08                 equ   $780
Lo09                 equ   $428
Lo10                 equ   $4a8
Lo11                 equ   $528
Lo12                 equ   $5a8
Lo13                 equ   $628
Lo14                 equ   $6a8
Lo15                 equ   $728
Lo16                 equ   $7a8
Lo17                 equ   $450
Lo18                 equ   $4d0
Lo19                 equ   $550
Lo20                 equ   $5d0
* the "plus four" lines
Lo21                 equ   $650
Lo22                 equ   $6d0
Lo23                 equ   $750
Lo24                 equ   $7d0

; alt text page lines
Alt01                 equ   $800
Alt02                 equ   $880
Alt03                 equ   $900
Alt04                 equ   $980
Alt05                 equ   $A00
Alt06                 equ   $A80
Alt07                 equ   $B00
Alt08                 equ   $B80
Alt09                 equ   $828
Alt10                 equ   $8a8
Alt11                 equ   $928
Alt12                 equ   $9a8
Alt13                 equ   $A28
Alt14                 equ   $Aa8
Alt15                 equ   $B28
Alt16                 equ   $Ba8
Alt17                 equ   $850
Alt18                 equ   $8d0
Alt19                 equ   $950
Alt20                 equ   $9d0
* the "plus four" lines
Alt21                 equ   $A50
Alt22                 equ   $Ad0
Alt23                 equ   $B50
Alt24                 equ   $Bd0




LoLineTable          da    	Lo01,Lo02,Lo03,Lo04
                     da    	Lo05,Lo06,Lo07,Lo08
                     da		Lo09,Lo10,Lo11,Lo12
                     da    	Lo13,Lo14,Lo15,Lo16
                     da		Lo17,Lo18,Lo19,Lo20
                     da		Lo21,Lo22,Lo23,Lo24

; alt text page
AltLineTable         da    	Alt01,Alt02,Alt03,Alt04
                     da    	Alt05,Alt06,Alt07,Alt08
                     da		Alt09,Alt10,Alt11,Alt12
                     da    	Alt13,Alt14,Alt15,Alt16
                     da		Alt17,Alt18,Alt19,Alt20
                     da		Alt21,Alt22,Alt23,Alt24


** Here we split the table for an optimization
** We can directly get our line numbers now
** Without using ASL
LoLineTableH         db    >Lo01,>Lo02,>Lo03
                     db    >Lo04,>Lo05,>Lo06
                     db    >Lo07,>Lo08,>Lo09
                     db    >Lo10,>Lo11,>Lo12
                     db    >Lo13,>Lo14,>Lo15
                     db    >Lo16,>Lo17,>Lo18
                     db    >Lo19,>Lo20,>Lo21
                     db    >Lo22,>Lo23,>Lo24
LoLineTableL         db    <Lo01,<Lo02,<Lo03
                     db    <Lo04,<Lo05,<Lo06
                     db    <Lo07,<Lo08,<Lo09
                     db    <Lo10,<Lo11,<Lo12
                     db    <Lo13,<Lo14,<Lo15
                     db    <Lo16,<Lo17,<Lo18
                     db    <Lo19,<Lo20,<Lo21
                     db    <Lo22,<Lo23,<Lo24

; alt text page
AltLineTableH        db    >Alt01,>Alt02,>Alt03
                     db    >Alt04,>Alt05,>Alt06
                     db    >Alt07,>Alt08,>Alt09
                     db    >Alt10,>Alt11,>Alt12
                     db    >Alt13,>Alt14,>Alt15
                     db    >Alt16,>Alt17,>Alt18
                     db    >Alt19,>Alt20,>Alt21
                     db    >Alt22,>Alt23,>Alt24
AltLineTableL        db    <Alt01,<Alt02,<Alt03
                     db    <Alt04,<Alt05,<Alt06
                     db    <Alt07,<Alt08,<Alt09
                     db    <Alt10,<Alt11,<Alt12
                     db    <Alt13,<Alt14,<Alt15
                     db    <Alt16,<Alt17,<Alt18
                     db    <Alt19,<Alt20,<Alt21
                     db    <Alt22,<Alt23,<Alt24
