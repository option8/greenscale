	DSK GREENSCALE

**************************************************
* Autoplaying version for Bad Apple demo
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

IMGLO			EQU		$CD			; image data addres, LO
IMGHI			EQU		$CE			; image data addres, HI

SEEDADDRLO		EQU		$CB			;	db <TABLESEED
SEEDADDRHI		EQU		$CC			;	db >TABLESEED

FRAMENUM		EQU		$1D			; which frame of the anim
FRAMES			EQU		$1E			; total frames

DELAY			EQU		$1F			; interframe delay amount. 
									; FF=3FPS $80=10FPS $40=24FPS $20=37FPS $10=43FPS $00=46FPS
PAUSED			EQU		$20			; paused state - stop animation

COLORMODE		EQU		$22			; which color mode are we in? which table to draw from
TABLEOFFSET		EQU		$23	

AUTOPLAYTIMER	EQU		$EB			; how many loops has the animation played? 
AUTOPLAY		EQU		$EC			; Autoplay mode or not

;from ProRWTS2
;subdirectory support
bloklo			EQU		$46
blokhi			EQU		$47

;to detect file not found
status			EQU		$50

;file read support
sizelo			EQU		$52
sizehi			EQU		$53
ldrlo			EQU		$55
ldrhi			EQU		$56

;file open support
namlo			EQU		$57
namhi			EQU		$58

;rewind support
blkidx			EQU		$5e
bleftlo			EQU		$60
blefthi			EQU		$61

;API
hddopendir		EQU		$BD03
hddrdwrpart		EQU		$BD00
hddblockhi		EQU		$BD06
hddblocklo		EQU		$BD04


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

				LDA #>SUBDIRNAME
				STA namhi
				LDA #<SUBDIRNAME
				STA namlo
				JSR hddopendir					;open subdirectory
				LDA blokhi
				STA hddblockhi
				LDA bloklo
				STA hddblocklo					;make it permanent

				JSR BLOAD						; BLOAD DATA
					
				JSR HOWMANYFRAMES				; how big is the animation data?

				JSR ROMSETVID           	 	; Init char output hook at $36/$37
				JSR ROMSETKBD           	 	; Init key input hook at $38/$39
				JSR ROMINIT               	 	; GR/HGR off, Text page 1
				
				LDA #$00
				STA BLINK						; blinking text? no thanks.
				STA LORES						; low res graphics mode

				STA PAUSED						; start not paused
				STA COLORMODE					; start in default, real hardware mode
				STA AUTOPLAYTIMER				; reset timer for autoplay
				STA AUTOPLAY					; autoplay off by default
DETECTGS		
				SEC               				;Set carry bit (flag)
				JSR $FE1F         				;Call to the monitor
				BCS NOTGS    					;If carry is still set, then old machine
				;BCC ISGS    					;If carry is clear, then new machine
				
ISGS			lda #$01						; disable SHR for IIgs
				sta $c029						; re: John Brooks
												; need to skip this if on IIe card, otherwise goes to alt ROM
				STA MIXCLR						; For IIGS - bottom 4 lines to GR

NOTGS			LDA #$30
				STA DELAY						; start with a modest 30FPS 

;				lda SETAN3						; *** does something strange to low res
				sta CLR80VID 					; turn 80 column off

				JSR CLRLORES					; clear screen		
				
				JSR EMULATORCHECK				; check for Virtual II, MicroM8					

				LDY COLORMODE					; colormode set by EMULATORCHECK, or 00
				LDA SEEDSTABLELO,Y				; which "Seed" table to generate from
				STA SEEDADDRLO					

				LDA SEEDSTABLEHI,Y					
				STA SEEDADDRHI					
				
				JSR GENERATETABLE				; create a 256byte table from 16bytes. Magic!

**************************************************
*	MAIN LOOP
**************************************************

STARTANIMATION	
				LDA FRAMES
				STA FRAMENUM		; frame #0

EACHFRAME
				LDA DATAHI			; image data starts at end of code.
				STA IMGHI
				LDA DATALO
				STA IMGLO

				LDA #3
				STA sizehi
				LDA #$C0
				STA sizelo
				LDA #>BEGINDATA
				STA ldrhi
				LDA #<BEGINDATA
				STA ldrlo
				JSR hddrdwrpart		;read a frame of data

				JSR INTERFRAMEDELAY
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

				JSR NEXTFILE		; LOAD NEXT FILE IN SEQUENCE
				JMP STARTANIMATION

INCHI 			INC IMGHI
				BCS CMPROW

;/MAIN LOOP

**************************************************
*	By popular(?) demand - slows down framerate
*	based on keyboard input
**************************************************
PAUSE			STA PAUSED				; stores #$A0 at PAUSED.
				STA STROBE

INTERFRAMEDELAY						
				INC AUTOPLAYTIMER		; played a frame, increment autoplay timer
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
				

				CMP #$C1				; a
				BEQ AUTOSWITCH			; if A turn on/off autoplay
				CMP #$E1				; A
				BEQ AUTOSWITCH			; if A turn on/off autoplay

				LDA AUTOPLAY
				BEQ XLOOP				; autoplay = 0, skip the auto switch
				LDA AUTOPLAYTIMER		; reset timer for autoplay
				BEQ SWITCHDATA			; auto switch after 256 frames displayed


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

AUTOSWITCH		STA STROBE
				LDA AUTOPLAY
				BEQ AUTOPLAYON			; if it's 0, inc to 1
				DEC AUTOPLAY			; otherwise, dec to 0
				JMP AUTOPLAYSET
AUTOPLAYON		INC AUTOPLAY
AUTOPLAYSET		RTS

	
**************************************************
*	Check to see if I'm running in Virtual II or
*	real hardware (or a different emulator)
*	CARRY SET == running in VII
**************************************************
	
EMULATORCHECK	
				LDX #$00			; reset X and Y
				LDY #$00			
				CLC					; CARRY=VII found

CHKVII								; if C04F is and stays zero, INC X
				INX					; if X rolls over to zero, it's VII
				BEQ FOUNDVII
				LDA $C04F
				BEQ CHKVII			; 0, then may be VII
				
CHKM8			INY					; now to check for MICROM8	
				CPY #$FF
				BEQ FOUNDM8			
				CMP #$2E						
				BEQ CHKM8			; it's #$2E. Does it stay that way?
				
				CLC 				;set return value: no Virtual II or M8
				RTS
FOUNDVII
    			SEC 				;set return value: found Virtual II
				JSR COLORSWAP		; otherwise, swap the color table (#1 is VII)	
    			RTS	

FOUNDM8			ADC #$80			; add over 128 = set OVerflow
				INC COLORMODE		; next color mode
				JSR COLORSWAP		; otherwise, swap the color table (#2 is M8)	
				RTS
	
	
**************************************************
*	Load "banana" into memory
*	
**************************************************


BLOAD
				LDA #>FILENAME
				STA namhi
				LDA #<FILENAME
				STA namlo
				LDA #0
				STA sizehi
				STA sizelo			;no pre-read needed
				JSR hddopendir			;open "data"
				LDA status
				STA blkidx
				BEQ GOODOPEN
				LDA #$30
				STA ENDNAME-1
				STA ENDNAME-2
				STA ENDNAME-3
				BNE BLOAD
GOODOPEN			RTS

SUBDIRNAME		DB	ENDSUB-SUBNAME 			;Length of name
SUBNAME			ASC	'DATA'			;followed by the name
ENDSUB			EQU	*

FILENAME		DB	ENDNAME-NAME 			;Length of name
NAME    		ASC	'DATA000' 			;followed by the name
ENDNAME 		EQU	*


**************************************************
*	How many frames in the file?
**************************************************
HOWMANYFRAMES			LDX #0
COUNTFRAMES			INX
				SEC
				LDA bleftlo
				SBC #$C0
				STA bleftlo
				LDA blefthi
				SBC #3
				STA blefthi
				ORA bleftlo
				BNE COUNTFRAMES
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

NEWTABLE		
				LDA SEEDSTABLELO,X
				STA SEEDADDRLO

				LDA SEEDSTABLEHI,X
				STA SEEDADDRHI
				
				JSR GENERATETABLE		; create a 256byte table from 16bytes. Magic!

				LDA COLORTABLEHI		; grab table address for LUT
				STA WHICHTABLE+2		; put it in the code
				RTS

TEXTSWAP		STA TXTSET				; set text mode
SWAPTABLE		LDA TEXTTABLEHI			; grab table address for LUT
				STA WHICHTABLE+2		; put it in the code
				LDX #$FF
				STX COLORMODE
				RTS



**************************************************
*	Increment the name of the file to be loaded
*	then trigger the load again.
**************************************************
NEXTFILE		LDY ENDNAME-1			; last char in ascii filename "DATA000" = #$30
				INY
				CPY #$3A				; roll over past "xx9"?
				BNE SETFILE
				LDY #$30				; reset to "0"
				LDX ENDNAME-2
				INX
				CPX #$3A				; roll over past "x90"?
				BNE SETFILE10
				LDX #$30				; reset to "00"
				INC ENDNAME-3			; add 100
SETFILE10		STX ENDNAME-2
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

**************************************************
*	Generates a 256 byte table, given a pattern of
*	16 bytes. With more color tables in the program,
*	this saves me more than 1K of memory
**************************************************

GENERATETABLE					
				; start with address of "seed"
				LDA #$FF				; TABLEOFFSET = FF
				STA TABLEOFFSET			; where in the COLORTABLE I'm writing
				
				LDA #$0F				; for X F to 0
				STA $07

GENXLOOP		LDA #$0F				; for Y F to 0
				STA $06

GENYLOOP		
;				STY	$06					; hang onto Y
				LDY $07
				LDA (SEEDADDRLO),Y			; (A=0F)
				ROL						; ROLx4 (A=20)
				ROL
				ROL
				ROL						
				LDY $06					; get Y back
				ADC (SEEDADDRLO),Y 		; (A=FF)
;				STY $06					; store Y at $06 for safekeeping
				LDY TABLEOFFSET			
				STA COLORTABLE,Y
				DEC TABLEOFFSET
;				LDY $06
;				DEY
				DEC $06
				BPL	GENYLOOP			; if Y = FF, next X
GENDECX			DEC $07
				BPL	GENXLOOP			; if X=FF, done
GENRTS			RTS
;/GENERATETABLE				



TABLESEED		HEX 00,02,01,04,08,03,06,0C,09,05,0A,07,0B,0E,0D,0F
V2COLORTABLE	HEX 00,02,06,01,04,05,08,03,0C,09,07,0A,0B,0E,0D,0F		; Low res colors from darkest to lightest for Virtual ][
MICROM8			HEX 00,02,04,08,0C,01,09,05,06,0E,0D,03,0A,07,0B,0F
THREEGRAYSTABLE	HEX 00,02,02,02,02,06,06,06,06,06,06,07,07,07,07,0F		; W/B and 3 grays/shades of blue
VIDHD			HEX 00,02,01,04,08,03,09,05,0A,06,0C,07,0B,0E,0D,0F

SEEDSTABLEHI 	db >TABLESEED,>V2COLORTABLE,>MICROM8,>THREEGRAYSTABLE,>VIDHD
SEEDSTABLELO 	db <TABLESEED,<V2COLORTABLE,<MICROM8,<THREEGRAYSTABLE,<VIDHD



COLORTABLE		DS 256,$FF

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

TEXTTABLEHI		db >TEXTTABLE
COLORTABLEHI	db >COLORTABLE


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
