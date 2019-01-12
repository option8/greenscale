	DSK GREENSCALE

**************************************************
* Low res monochrome image display
*
*	to do:
*		multiple emulator detection, different color tables
*		GS/large RAM version to load MOAR data.
*		large volume version, load several animations, loop between them on keypress
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
FRAMES			EQU		$1E			; total frames

DELAY			EQU		$1F			; interframe delay amount. 
									; FF=3FPS $80=10FPS $40=24FPS $20=37FPS $10=43FPS $00=46FPS
PAUSED			EQU		$20			; paused state - stop animation

COLORMODE		EQU		$22			; which color mode are we in? which table to draw from

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
HOME 		EQU	$FC58		; clear the text screen
CH        	EQU	$24			; cursor Horiz
CV        	EQU	$25			; cursor Vert
VTAB      	EQU	$FC22       ; Sets the cursor vertical position (from CV)
COUT      	EQU	$FDED       ; Calls the output routine whose address is stored in CSW,
          	   	            ;  normally COUTI
STROUT		EQU	$DB3A 		;Y=String ptr high, A=String ptr low
		
ALTTEXT		EQU	$C055
ALTTEXTOFF	EQU	$C054
	
ROMINIT   	EQU $FB2F
ROMSETKBD 	EQU $FE89
ROMSETVID 	EQU $FE93
	
ALTCHAR		EQU	$C00F		; enables alternative character set - mousetext
	
BLINK		EQU	$F3
SPEED		EQU	$F1

BELL   		EQU	$FF3A     				; Monitor BELL routine
CROUT  		EQU	$FD8E     				; Monitor CROUT routine
PRBYTE 		EQU	$FDDA     				; Monitor PRBYTE routine
MLI    		EQU	$BF00     				; ProDOS system call
OPENCMD		EQU	$C8						; OPEN command index
READCMD		EQU	$CA						; READ command index
CLOSECMD	EQU	$CC						; CLOSE command index


**************************************************
* START - sets up various fiddly zero page bits
**************************************************

				ORG $0800						; PROGRAM DATA STARTS AT $0C00 NOW

				JSR BLOAD						; BLOAD DATA
					
				JSR HOWMANYFRAMES				; how big is the animation data?

				JSR ROMSETVID           	 	; Init char output hook at $36/$37
				JSR ROMSETKBD           	 	; Init key input hook at $38/$39
				JSR ROMINIT               	 	; GR/HGR off, Text page 1
				
				LDA #$00
				STA BLINK						; blinking text? no thanks.
				STA LORES						; low res graphics mode
				STA MIXCLR						; For IIGS - bottom 4 lines to GR

				STA PAUSED						; start not paused
				STA COLORMODE					; start in default, real hardware mode
				
				lda #$01						; disable SHR for IIgs
				sta $c029						; re: John Brooks

				LDA #$30
				STA DELAY						; start with a modest 30FPS 

				lda SETAN3
				sta CLR80VID 					; turn 80 column off


				JSR CLRLORES					; clear screen		
				
				JSR EMULATORCHECK				; check for Virtual II, MicroM8?
				
				BCC STARTANIMATION				; not running in VII, go ahead.
					
				JSR COLORSWAP					; otherwise, swap the color table (#1 is VII)			

**************************************************
*	MAIN LOOP
**************************************************

STARTANIMATION	
				LDA DATAHI			; image data starts at end of code.
				STA IMGHI
				LDA DATALO
				STA IMGLO
				LDA FRAMES
				STA FRAMENUM		; frame #0

EACHFRAME		JSR INTERFRAMEDELAY
				LDX #$00	
				STX PLOTROW
				LDY #$27			; Y IS PLOTCOLUMN

EACHROW			LDA LoLineTableL,X
				STA $0
				LDA LoLineTableH,X
				STA $1       		; now word/pointer at $0+$1 points to screen line 

EACHPIXEL		LDA (IMGLO),Y		; load byte at IMGLO,IMGHI + COLUMN							
				TAX					; look up color from lookup table
WHICHTABLE		LDA COLORTABLE,X			
				STA ($0),Y  		; store byte at LINE + COLUMN
							
DECCOLUMN		DEY					; next column of 2 pixels
				BPL EACHPIXEL		; Y IS PLOTCOLUMN
				LDY #$27			; reset to col 0

INCROW			INC PLOTROW
				LDA IMGLO
				CLC
				ADC #$28
				STA IMGLO
				BCS INCHI

CMPROW			LDX PLOTROW
				CPX #$18
				BNE EACHROW

LOOPTY			DEC FRAMENUM
				BNE EACHFRAME		; next frame in sequence
				BEQ STARTANIMATION	; start over at frame 1

INCHI 			INC IMGHI
				BCS CMPROW

;/MAIN LOOP

**************************************************
*	By popular(?) demand - slows down framerate
*	based on keyboard input
**************************************************
PAUSE			STA PAUSED				; stores #$A0 at PAUSED.
				STA STROBE
;				JMP INTERFRAMEDELAY

INTERFRAMEDELAY						

				LDA KEY					; check for keydown
				CMP PAUSED				; space bar = #$A0
				BEQ UNPAUSE

				LDA PAUSED				; check for paused state
				BNE INTERFRAMEDELAY		; loop forever until space bar
				

CHECKDELAY		LDA KEY					; check for keydown

				CMP #$A0				; space bar, pause
				BEQ PAUSE

				CMP #$AB				; plus
				BEQ INCDELAY			; if EQ, slow down (INC DELAY)
				CMP #$BD				; equals
				BEQ INCDELAY			; if EQ, slow down (INC DELAY)
				CMP #$AD				; minus
				BEQ DECDELAY			; if EQ, speed up (DEC DELAY)

				CMP #$C3				; c
				BEQ SWITCHCOLOR			; if C switch color mode
				CMP #$E3				; C
				BEQ SWITCHCOLOR			; if C switch color mode

				CMP #$CE				; N 
				BEQ SWITCHDATA			; go to next DATA0* file
				CMP #$EE				; N
				BEQ SWITCHDATA			; go to next DATA0* file


XLOOP			LDX DELAY				; typical delay loop

DELAYLOOP		LDY DELAY

YLOOP			DEY
				BNE YLOOP

				DEX
				BNE DELAYLOOP

				RTS
;/INTERFRAMEDELAY				

UNPAUSE			LDA #$0
				STA PAUSED
				STA STROBE
				JMP CHECKDELAY

INCDELAY		STA STROBE
				INC DELAY
				JMP XLOOP

DECDELAY		STA STROBE
				DEC DELAY
				JMP XLOOP

SWITCHCOLOR		STA STROBE
				JSR COLORSWAP
				JMP XLOOP

SWITCHDATA		STA STROBE
				JSR NEXTFILE
				RTS

	
**************************************************
*	Check to see if I'm running in Virtual II or
*	real hardware (or a different emulator)
*	CARRY SET == running in VII
**************************************************
	
EMULATORCHECK	
				LDX #$00
				CLC
CHKVII
				INX
				BEQ FOUNDVII
				LDA $C04F
				BEQ CHKVII
				CLC 				;set return value: no Virtual II
				RTS
FOUNDVII
    			SEC 				;set return value: found Virtual II
    			RTS	
	
	
**************************************************
*	Load "banana" into memory
*	
**************************************************


BLOAD   		JSR	OPEN    				;open "DATA"
       			JSR READ
				JSR CLOSE
       			RTS            				;Otherwise done
				
OPEN 			JSR	MLI       				;Perform call
       			DB	OPENCMD    				;CREATE command number
       			DW	OPENLIST   				;Pointer to parameter list
       			BNE	ERROR     				;If error, display it
       			LDA REFERENCE
       			STA READLIST+1
       			STA CLOSELIST+1
       			RTS				

READ			JSR MLI
				DB	READCMD
				DW	READLIST
       			BNE ERROR					
				RTS

CLOSE			JSR MLI
				DB	CLOSECMD
				DW	CLOSELIST
       			BNE ERROR					
				RTS
				
ERROR  			CMP #$46					; file not found during OPEN? reset to "DATA00"
				BNE PRINTERROR
				LDA #$30
				STA ENDNAME-1
				JMP OPEN
PRINTERROR		JSR	PRBYTE    				;Print error code
       			JSR	BELL      				;Ring the bell
       			JSR	CROUT     				;Print a carriage return
       			RTS				

OPENLIST		DB	$03						; parameter list for OPEN command
				DW	FILENAME
				DA	MLI-$400				; buffer snuggled up tight with PRODOS
REFERENCE		DB	$00						; reference to opened file
			
READLIST		DB	$04
				DB	$00						; REFERENCE written here after OPEN
				DB	<BEGINDATA,>BEGINDATA	; write to end of code
				DB	$FF,$FF					; read as much as $FFFF - should error out with EOF before that.
TRANSFERRED		DB	$00,$00				

CLOSELIST		DB	$01
				DB	$00
				
FILENAME		DB	ENDNAME-NAME 			;Length of name
NAME    		ASC	'/GREENSCALE/DATA00' 		;followed by the name
ENDNAME 		EQU	*


**************************************************
*	How many frames have transferred?
*	up to 32 ($20) based on TRANSFERRED+1
**************************************************
HOWMANYFRAMES	LDX #$00					; X=0
				LDA TRANSFERRED+1			; LDA TRANSFERRED amt hi byte
HOWMANYLOOP		CMP FRAMESTABLE,X			; compare A to FRAMESTABLE,X
				BEQ	HOWMANYSET				; if equal, X frames loaded.
				INX
				CPX	$30						; out of memory around 41 frames.
				BEQ	HOWMANYSET				; max 32 frames
				JMP HOWMANYLOOP				; otherwise, INX, Loop
HOWMANYSET		INX
				STX FRAMES
				RTS
				
**************************************************
*	Swap the color table with one for real
*	hardware/OpenEmulator
*	This works because the color tables are $FF bytes long.
**************************************************

COLORSWAP		INC COLORMODE			; next mode to cycle through

				LDX COLORMODE			; load to X
				CPX #$05				; is it now the text mode?
				BEQ TEXTSWAP
										; otherwise, be sure to be back in GR
				STX LORES				; low res graphics mode
				STX MIXCLR				; For IIGS - bottom 4 lines to GR
				
				CPX #$06				; overrun, back to zero
				BNE SWAPTABLE
				LDX #$0
				STX COLORMODE
				
SWAPTABLE		LDA COLORMODESTABLE,X	; grab table address from LUT
				STA WHICHTABLE+2		; put it in the code
				RTS

TEXTSWAP		STA TXTSET				; set text mode
				JMP SWAPTABLE		   

**************************************************
*	Increment the name of the file to be loaded
*	then trigger the load again.
**************************************************
NEXTFILE		LDY ENDNAME-1			; last char in ascii filename "DATA00" = #$30
				INY
				CPY #$3A				; roll over past "9"?
				BNE SETFILE
				LDY #$30				; reset to "0"
SETFILE			STY ENDNAME-1
				JSR BLOAD
				JSR HOWMANYFRAMES		; how big is the new animation data?
				LDA #$01
				STA FRAMENUM			; start new anim at frame 0
				RTS

**************************************************
* Data Tables
*
* I was looking up each nibble, then converting 
* the two nibbles to a full byte, but it's 
* considerably faster to lookup a full byte at
* a time, skipping manipulating nibbles.
*
**************************************************


COLORTABLE		HEX 00,02,01,04,08,03,06,0C,09,05,0A,07,0B,0E,0D,0F		; for OpenEmulator, real hardware.
				HEX 20,22,21,24,28,23,26,2C,29,25,2A,27,2B,2E,2D,2F
				HEX 10,12,11,14,18,13,16,1C,19,15,1A,17,1B,1E,1D,1F
				HEX 40,42,41,44,48,43,46,4C,49,45,4A,47,4B,4E,4D,4F
				HEX 80,82,81,84,88,83,86,8C,89,85,8A,87,8B,8E,8D,8F
				HEX 30,32,31,34,38,33,36,3C,39,35,3A,37,3B,3E,3D,3F
				HEX 60,62,61,64,68,63,66,6C,69,65,6A,67,6B,6E,6D,6F
				HEX c0,c2,c1,c4,c8,c3,c6,cC,c9,c5,cA,c7,cB,cE,cD,cF
				HEX 90,92,91,94,98,93,96,9C,99,95,9A,97,9B,9E,9D,9F
				HEX 50,52,51,54,58,53,56,5C,59,55,5A,57,5B,5E,5D,5F
				HEX A0,A2,A1,A4,A8,A3,A6,AC,A9,A5,AA,A7,AB,AE,AD,AF
				HEX 70,72,71,74,78,73,76,7C,79,75,7A,77,7B,7E,7D,7F
				HEX B0,B2,B1,B4,B8,B3,B6,BC,B9,B5,BA,B7,BB,BE,BD,BF
				HEX E0,E2,E1,E4,E8,E3,E6,EC,E9,E5,EA,E7,EB,EE,ED,EF
				HEX D0,D2,D1,D4,D8,D3,D6,DC,D9,D5,DA,D7,DB,DE,DD,DF
				HEX F0,F2,F1,F4,F8,F3,F6,FC,F9,F5,FA,F7,FB,FE,FD,FF

V2COLORTABLE	HEX 00,02,06,01,04,05,08,03,0C,09,07,0A,0B,0E,0D,0F		; Low res colors from darkest to lightest for Virtual ][
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
				

THREEGRAYSTABLE	HEX 00,02,02,02,02,06,06,06,06,06,06,07,07,07,07,0F		; W/B and 3 grays/shades of blue
				HEX 20,22,22,22,22,26,26,26,26,26,26,27,27,27,27,2F
				HEX 20,22,22,22,22,26,26,26,26,26,26,27,27,27,27,2F
				HEX 20,22,22,22,22,26,26,26,26,26,26,27,27,27,27,2F
				HEX 20,22,22,22,22,26,26,26,26,26,26,27,27,27,27,2F
				HEX 60,62,62,62,62,66,66,66,66,66,66,67,67,67,67,6F
				HEX 60,62,62,62,62,66,66,66,66,66,66,67,67,67,67,6F
				HEX 60,62,62,62,62,66,66,66,66,66,66,67,67,67,67,6F
				HEX 60,62,62,62,62,66,66,66,66,66,66,67,67,67,67,6F
				HEX 60,62,62,62,62,66,66,66,66,66,66,67,67,67,67,6F
				HEX 60,62,62,62,62,66,66,66,66,66,66,67,67,67,67,6F
				HEX 70,72,72,72,72,76,76,76,76,76,76,77,77,77,77,7F
				HEX 70,72,72,72,72,76,76,76,76,76,76,77,77,77,77,7F
				HEX 70,72,72,72,72,76,76,76,76,76,76,77,77,77,77,7F
				HEX 70,72,72,72,72,76,76,76,76,76,76,77,77,77,77,7F
				HEX F0,F2,F2,F2,F2,F6,F6,F6,F6,F6,F6,F7,F7,F7,F7,FF


MICROM8			HEX 00,02,04,08,0C,01,09,05,06,0E,0D,03,0A,07,0B,0F
				HEX 20,22,24,28,2C,21,29,25,26,2E,2D,23,2A,27,2B,2F
				HEX 40,42,44,48,4C,41,49,45,46,4E,4D,43,4A,47,4B,4F
				HEX 80,82,84,88,8C,81,89,85,86,8E,8D,83,8A,87,8B,8F
				HEX C0,C2,C4,C8,CC,C1,C9,C5,C6,CE,CD,C3,CA,C7,CB,CF
				HEX 10,12,14,18,1C,11,19,15,16,1E,1D,13,1A,17,1B,1F
				HEX 90,92,94,98,9C,91,99,95,96,9E,9D,93,9A,97,9B,9F
				HEX 50,52,54,58,5C,51,59,55,56,5E,5D,53,5A,57,5B,5F
				HEX 60,62,64,68,6C,61,69,65,66,6E,6D,63,6A,67,6B,6F
				HEX E0,E2,E4,E8,EC,E1,E9,E5,E6,EE,ED,E3,EA,E7,EB,EF
				HEX D0,D2,D4,D8,DC,D1,D9,D5,D6,DE,DD,D3,DA,D7,DB,DF
				HEX 30,32,34,38,3C,31,39,35,36,3E,3D,33,3A,37,3B,3F
				HEX A0,A2,A4,A8,AC,A1,A9,A5,A6,AE,AD,A3,AA,A7,AB,AF
				HEX 70,72,74,78,7C,71,79,75,76,7E,7D,73,7A,77,7B,7F
				HEX B0,B2,B4,B8,BC,B1,B9,B5,B6,BE,BD,B3,BA,B7,BB,BF
				HEX F0,F2,F4,F8,FC,F1,F9,F5,F6,FE,FD,F3,FA,F7,FB,FF

VIDHD			HEX 00,02,01,04,08,03,09,05,0A,06,0C,07,0B,0E,0D,0F
				HEX 20,22,21,24,28,23,29,25,2A,26,2C,27,2B,2E,2D,2F
				HEX 10,12,11,14,18,13,19,15,1A,16,1C,17,1B,1E,1D,1F
				HEX 40,42,41,44,48,43,49,45,4A,46,4C,47,4B,4E,4D,4F
				HEX 80,82,81,84,88,83,89,85,8A,86,8C,87,8B,8E,8D,8F
				HEX 30,32,31,34,38,33,39,35,3A,36,3C,37,3B,3E,3D,3F
				HEX 90,92,91,94,98,93,99,95,9A,96,9C,97,9B,9E,9D,9F
				HEX 50,52,51,54,58,53,59,55,5A,56,5C,57,5B,5E,5D,5F
				HEX A0,A2,A1,A4,A8,A3,A9,A5,AA,A6,AC,A7,AB,AE,AD,AF
				HEX 60,62,61,64,68,63,69,65,6A,66,6C,67,6B,6E,6D,6F
				HEX C0,C2,C1,C4,C8,C3,C9,C5,CA,C6,CC,C7,CB,CE,CD,CF
				HEX 70,72,71,74,78,73,79,75,7A,76,7C,77,7B,7E,7D,7F
				HEX B0,B2,B1,B4,B8,B3,B9,B5,BA,B6,BC,B7,BB,BE,BD,BF
				HEX E0,E2,E1,E4,E8,E3,E9,E5,EA,E6,EC,E7,EB,EE,ED,EF
				HEX D0,D2,D1,D4,D8,D3,D9,D5,DA,D6,DC,D7,DB,DE,DD,DF
				HEX F0,F2,F1,F4,F8,F3,F9,F5,FA,F6,FC,F7,FB,FE,FD,FF

TEXTTABLE		ASC	"  '''````~~~^^",A2,A2		; Low res colors from darkest to lightest for Virtual ][
				ASC	"..'''````~~~^^",A2,A2		; A2 = ""
				ASC	"..''~^!ll/?TYYFF"
				ASC	",,''!ll??TTYY7FF"
				ASC	",,''!l??TYYY74FF"
				ASC	"__'!/llLI?7499PP"
				ASC	"--'!/lLII?7499PP"
				ASC	"::!/l)>LJJ7499PP"
				ASC	";;!/l)>CC66999RR"
				ASC	"ii/11)>CCOO999RR"
				ASC	"iil11UUZQGB988RR"
				ASC	"vv1]]EEZQGB888RR"
				ASC	"uu1]]WWZQGB888@@"
				ASC	"oo[[[}}}JJNNMM@@"
				ASC	"wwhhddbbkkKK##**"
				ASC	"mmhhddbbkkKK##&*"



COLORMODESTABLE db >COLORTABLE,>V2COLORTABLE,>THREEGRAYSTABLE,>MICROM8,>VIDHD,>TEXTTABLE

FRAMESTABLE		HEX	03,07,0B,0F,12,16,1A,1E,21,25,29,2D,30,34,38,3C		; how many frames transferred? HI byte lookup table
				HEX	3F,43,47,4B,4E,52,56,5A,5D,61,65,69,6C,70,74,78
				HEX	7B,7F,83,87,8A,8E,92,96,99,9D,A1,A5,A8,AC,B0,B4
				

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

LoLineTable          da    	Lo01,Lo02,Lo03,Lo04
                     da    	Lo05,Lo06,Lo07,Lo08
                     da		Lo09,Lo10,Lo11,Lo12
                     da    	Lo13,Lo14,Lo15,Lo16
                     da		Lo17,Lo18,Lo19,Lo20
                     da		Lo21,Lo22,Lo23,Lo24


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

DATALO				DB	<BEGINDATA
DATAHI				DB	>BEGINDATA

BEGINDATA			EQU *
