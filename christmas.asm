;****************************************************************
;iNES header
;****************************************************************
  .inesprg 1  ;2x 16KB PRG code
  .ineschr 1   ;1x  8KB CHR data
  .inesmap 0   ;mapper 0 = NROM, no bank swapping
  .inesmir 1   ;background mirroring

;****************************************************************
;ZP variables
;****************************************************************
  .rsset $0000

pointerBackgroundLowByte .rs 1
pointerBackgroundHighByte .rs 1

sleighTile1x    = $0203
sleighTile2x    = $0207
sleighTile3x    = $020B
sleighTile4x    = $020F

FT_BASE_ADR	= $0300	        ;page in the RAM used for FT2 variables, should be $xx00
FT_TEMP		= $00	        ;3 bytes in zeropage used by the library as a scratchpad
FT_DPCM_OFF	= $c000	        ;$c000..$ffc0, 64-byte steps
FT_SFX_STREAMS	= 4		;number of sound effects played at once, 1..4

FT_DPCM_ENABLE			;undefine to exclude all DMC code
FT_SFX_ENABLE			;undefine to exclude all sound effects code
FT_THREAD
FT_NTSC_SUPPORT			;undefine to exclude NTSC support					

;****************************************************************
;Demo entry point
;****************************************************************

  .bank 0
  .org $C000

  .include "sound/famitone2.asm"
  .include "sound/music.asm"

reset:
  SEI          ; disable IRQs
  CLD          ; disable decimal mode
  LDX #$40
  STX $4017    ; disable APU frame IRQ
  LDX #$FF
  TXS          ; Set up stack
  INX          ; now X = 0
  STX $2000    ; disable NMI
  STX $2001    ; disable rendering
  STX $4010    ; disable DMC IRQs

vblankwait1:       ; First wait for vblank to make sure PPU is ready
  BIT $2002
  BPL vblankwait1

clrmem:
  LDA #$00
  STA $0000, x
  STA $0100, x
  STA $0300, x
  STA $0400, x
  STA $0500, x
  STA $0600, x
  STA $0700, x
  LDA #$FE
  STA $0200, x    ;move all sprites off screen
  INX
  BNE clrmem

vblankwait2:       ; First wait for vblank to make sure PPU is ready
  BIT $2002
  BPL vblankwait2
   
; *************
; Main Code
; *************

LoadPalettes:
  LDA $2002    ; read PPU status to reset the high/low latch
  LDA #$3F
  STA $2006    ; write the high byte of $3F00 address
  LDA #$00
  STA $2006    ; write the low byte of $3F00 address
  LDX #$00
LoadPalettesLoop:
  LDA palette, x        ;load palette byte
  STA $2007             ;write to PPU
  INX                   ;set index to next byte
  CPX #$20            
  BNE LoadPalettesLoop  ;if x = $20, 32 bytes copied, all done

LoadAttribute:
  LDA $2002
  LDA #$23
  STA $2006
  LDA #$C0
  STA $2006
  LDX #$00
LoadAttributeLoop:
  LDA attribute, x
  STA $2007
  INX
  CPX #$02
  BNE LoadAttributeLoop

Loadstart:
  LDA $2002
  LDA #$20
  STA $2006
  LDA #$00
  STA $2006

  LDA #LOW(start)
  STA pointerBackgroundLowByte
  LDA #HIGH(start)
  STA pointerBackgroundHighByte

  LDX #$00
  LDY #$00
.Loop:
  LDA [pointerBackgroundLowByte], y
  STA $2007

  INY
  CPY #$00
  BNE .Loop

  INC pointerBackgroundHighByte
  INX
  CPX #$04
  BNE .Loop

  LDX #LOW(music_music_data)
  LDY #HIGH(music_music_data)
  LDA #$80 ;ntsc mode
  JSR FamiToneInit

  LDA #0
  JSR FamiToneMusicPlay

LoadSprites:
  LDX #$00              ; start at 0
LoadSpritesLoop:
  LDA sleigh, x         ; load data from address (sleigh + x)
  STA $0200, x          ; store into RAM address ($0200 + x)
  INX                   ; X = X + 1
  CPX #$10              ; Compare X to hex $10, decimal 16
  BNE LoadSpritesLoop   ; Branch to LoadSpritesLoop if compare was Not equal to 16
                        ; if compare was equal to 16, continue down

  LDA #%10000000   ; Enable NMI, sprites and background on table 0
  STA $2000
  LDA #%00011110   ; Enable sprites, enable backgrounds
  STA $2001
  LDA #$00         ; No background scrolling
  STA $2006
  STA $2006
  STA $2005
  STA $2005
  
Infinity_and_Beyond:
  JMP Infinity_and_Beyond

;**********************************
;NMI Routine
;**********************************

NMI:
  LDA #$00
  STA $2003  ; set the low byte (00) of the RAM address
  LDA #$02
  STA $4014  ; set the high byte (02) of the RAM address, start the transfer

  INC sleighTile1x
  INC sleighTile2x
  INC sleighTile3x
  INC sleighTile4x

  JSR FamiToneUpdate

  RTI        ; return from interrupt 

  .bank 1
  .org $E000

;****************************************************************
;Data used for demo
;****************************************************************

palette:
  .db $21,$0f,$2a,$30,$21,$30,$07,$1A,$21,$30,$07,$1A,$21,$30,$07,$1A
  .db $21,$06,$16,$26,$21,$30,$07,$1A,$21,$30,$07,$1A,$21,$30,$07,$1A

attribute:
  .db %00000000, %01010101

sleigh:
     ; y   tile attr  x
  .db $c5, $50, $00, $20   ;sprite 0
  .db $c5, $51, $00, $28   ;sprite 1
  .db $cd, $60, $00, $20   ;sprite 2
  .db $cd, $61, $00, $28   ;sprite 3

start:
  .incbin "gfx/christmas.nam"

;****************************************************************
;Vectors
;****************************************************************
  .bank 1
  .org $FFFA     ;first of the three vectors starts here
  .dw NMI    
                
  .dw reset      
                 
  .dw 0     

;****************************************************************
;CHR-ROM data
;****************************************************************
  .bank 2
  .org $0000
  .incbin "gfx/christmas.chr"
