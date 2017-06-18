.importzp penguin_zp
.export penguin_process
.export penguin_set_song

ptr_temp             = penguin_zp +  0
track_ptr            = penguin_zp +  2
square1_pattern_ptr  = penguin_zp +  4
square2_pattern_ptr  = penguin_zp +  6
triangle_pattern_ptr = penguin_zp +  8
noise_pattern_ptr    = penguin_zp + 10

PMEM = $100 + 22

track_step          = PMEM + 0

square1_note        = PMEM +  1
square1_vol_duty_y  = PMEM +  2
square1_pitch_y     = PMEM +  3
square1_pitch_hi    = PMEM +  4
square1_pitch_bend  = PMEM +  5 ; 2 bytes
square1_stack       = PMEM +  7
 
square2_note        = PMEM +  8
square2_vol_duty_y  = PMEM +  9
square2_pitch_y     = PMEM + 10
square2_pitch_hi    = PMEM + 11
square2_pitch_bend  = PMEM + 12 ; 2 bytes
square2_stack       = PMEM + 14

triangle_note       = PMEM + 15
triangle_vol_duty_y = PMEM + 16
triangle_pitch_y    = PMEM + 17
triangle_pitch_bend = PMEM + 18 ; 2 bytes
triangle_stack      = PMEM + 20

noise_note          = PMEM + 21
noise_vol_duty_y    = PMEM + 22
noise_stack         = PMEM + 23

PMEM2 = PMEM+24

stack_temp    = PMEM2 + 0
pattern_left  = PMEM2 + 1

noise_mask    = PMEM2 +  2
triangle_mask = PMEM2 +  3
square2_mask  = PMEM2 +  4
square1_mask  = PMEM2 +  5

track_speed   = PMEM2 +  6
track_start   = PMEM2 +  7 ; 2 bytes
track_end     = PMEM2 +  9 ; 2 bytes

noise_stack_next    = PMEM2 + 12
triangle_stack_next = PMEM2 + 13
square2_stack_next  = PMEM2 + 14
square1_stack_next  = PMEM2 + 15

debug = 0

.macro beq_aligned label
    beq label
    .assert .hibyte(*) = .hibyte(label), error, "beq misaligned"
.endmacro

.macro bne_aligned label
    bne label
    .assert .hibyte(*) = .hibyte(label), error, "bne misaligned"
.endmacro

.macro bcs_aligned label
    bcs label
    .assert .hibyte(*) = .hibyte(label), error, "bcs misaligned"
.endmacro

.macro bcc_aligned label
    bcc label
    .assert .hibyte(*) = .hibyte(label), error, "bcc misaligned"
.endmacro

.macro bvs_aligned label
    bvs label
    .assert .hibyte(*) = .hibyte(label), error, "bvs misaligned"
.endmacro

.macro bvc_aligned label
    bvc label
    .assert .hibyte(*) = .hibyte(label), error, "bvc misaligned"
.endmacro

.macro bpl_aligned label
    bpl label
    .assert .hibyte(*) = .hibyte(label), error, "bpl misaligned"
.endmacro

.macro bmi_aligned label
    bmi label
    .assert .hibyte(*) = .hibyte(label), error, "bmi misaligned"
.endmacro

.segment "MUSIC_DATA"
.include "music.inc"

.segment "PENGUIN"
.linecont +
; Note table borrowed from GGsound borrowed from periods.s from Famitracker
.define note_table \
    $07F1,$077F,$0713,$06AD,$064D,$05F3,$059D,$054C,$0500,$04B8,$0474,$0434,\
    $03F8,$03BF,$0389,$0356,$0326,$02F9,$02CE,$02A6,$0280,$025C,$023A,$021A,\
    $01FB,$01DF,$01C4,$01AB,$0193,$017C,$0167,$0152,$013F,$012D,$011C,$010C,\
    $00FD,$00EF,$00E1,$00D5,$00C9,$00BD,$00B3,$00A9,$009F,$0096,$008E,$0086,\
    $007E,$0077,$0070,$006A,$0064,$005E,$0059,$0054,$004F,$004B,$0046,$0042,\
    $003F,$003B,$0038,$0034,$0031,$002F,$002C,$0029,$0027,$0025,$0023,$0021,\
    $001F,$001D,$001B,$001A,$0018,$0017,$0015,$0014,$0013,$0012,$0011,$0010,\
    $000F,$000E,$000D

; Unused.
.define pal_note_table\
    $0760,$06F6,$0692,$0634,$05DB,$0586,$0537,$04EC,$04A5,$0462,$0423,$03E8,\
    $03B0,$037B,$0349,$0319,$02ED,$02C3,$029B,$0275,$0252,$0231,$0211,$01F3,\
    $01D7,$01BD,$01A4,$018C,$0176,$0161,$014D,$013A,$0129,$0118,$0108,$00F9,\
    $00EB,$00DE,$00D1,$00C6,$00BA,$00B0,$00A6,$009D,$0094,$008B,$0084,$007C,\
    $0075,$006E,$0068,$0062,$005D,$0057,$0052,$004E,$0049,$0045,$0041,$003E,\
    $003A,$0037,$0034,$0031,$002E,$002B,$0029,$0026,$0024,$0022,$0020,$001E,\
    $001D,$001B,$0019,$0018,$0016,$0015,$0014,$0013,$0012,$0011,$0010,$000F,\
    $000E,$000D,$000C
.linecont -

note_table_lo: .lobytes note_table
track_step_function_lo:
    .byt .lobyte(update_variables)
    .byt .lobyte(update_triangle_noise)
    .byt .lobyte(update_squares)
    .byt .lobyte(update_pattern_ptrs)
    .repeat 37
        .byt .lobyte (update_null)
    .endrepeat
note_table_hi: .hibytes note_table
track_step_function_hi:
    .byt .hibyte(update_variables)
    .byt .hibyte(update_triangle_noise)
    .byt .hibyte(update_squares)
    .byt .hibyte(update_pattern_ptrs)
    .repeat 37
        .byt .hibyte (update_null)
    .endrepeat
.assert .lobyte(note_table_lo) = 0, error, "note_table misaligned"
.assert .lobyte(note_table_hi) = 128, error, "note_table misaligned"

.align 256
update_squares:
    ; Total = 4+2+3+78+76 = 163 cycles
    pla
    nop
    .byt $04, $00 ; IGN (3 cycles)

    ; square1
    ; 6+2+70 = 78 cycles
    lsr square1_mask
    bcc_aligned @dontChangeSquare1

    ; Total = 2+29+16+23 = 70 cycles

    ; 2 cycles
    ldy #0

    ; 5+5+4+3+4+3+5 = 29 cycles
    inc square1_pattern_ptr+0
    lax (square1_pattern_ptr), y
    lda square1_instrument_lo, x
    sta ptr_temp+0
    lda square1_instrument_hi, x
    sta ptr_temp+1
    inc square1_pattern_ptr+0
    
    ; 4+2+4+2+2+2 = 16 cycles
    lda square1_stack
    eor #%01000000
    sta square1_stack_next
    tax
    axs #.lobyte(-6)
    txs

    ; 5+6+6+6 = 23 cycles
    jmp (ptr_temp)
@dontChangeSquare1:
    ; Stall 69 cycles
    .byt $04, $00 ; IGN (3 cycles)
    ldy #13
:
    dey
    bne_aligned :-
square1_instrument_assign_return:

    ; square2
    ; 6+2+68 = 76 cycles
    lsr square2_mask
    bcc_aligned @dontChangeSquare2

    ; Total = 29+16+23 = 68

    ; Y = 0
    
    ; 5+5+4+3+4+3+5 = 29 cycles
    inc square2_pattern_ptr+0
    lax (square2_pattern_ptr), y
    lda square2_instrument_lo, x
    sta ptr_temp+0
    lda square2_instrument_hi, x
    sta ptr_temp+1
    inc square2_pattern_ptr+0

    ; 4+2+4+2+2+2 = 16 cycles
    lda square2_stack
    eor #%01000000
    sta square2_stack_next
    tax
    axs #.lobyte(-6)
    txs

    ; 5+6+6+6 = 23 cycles
    jmp (ptr_temp)
@dontChangeSquare2:
    ; Stall 67 cycles
    .byt $04, $00 ; IGN (3 cycles)
    ldy #12
:
    dey
    bne_aligned :-
    jmp track_step_return


update_triangle_noise:
    ; Total = 4+4+4+3+78+70 = 148 cycles
    pla
    pla
    pla
    .byt $04, $00 ; IGN (3 cycles)

    ; triangle
    ; 6+2+70 = 78 cycles
    lsr triangle_mask
    bcc_aligned @dontChangeTriangle

    ; Total = 2+29+16+23 = 70 cycles

    ; 2 cycles
    ldy #0
    
    ; 5+5+4+3+4+3+5 = 29 cycles
    inc triangle_pattern_ptr+0
    lax (triangle_pattern_ptr), y
    lda triangle_instrument_lo, x
    sta ptr_temp+0
    lda triangle_instrument_hi, x
    sta ptr_temp+1
    inc triangle_pattern_ptr+0

    ; 4+2+4+2+2+2 = 16 cycles
    lda triangle_stack
    eor #%01000000
    sta triangle_stack_next
    tax
    axs #.lobyte(-6)
    txs

    ; 5+6+6+6 = 23 cycles
    jmp (ptr_temp)
@dontChangeTriangle:
    ; Stall 69 cycles
    .byt $04, $00 ; IGN (3 cycles)
    ldy #13
:
    dey
    bne_aligned :-
triangle_instrument_assign_return:

    ; noise
    ; 6+2+62 = 70 cycles
    lsr noise_mask
    bcc_aligned @dontChangeNoise

    ; Total = 29+16+17 = 62 cycles

    ; Y = 0

    ; 5+5+4+3+4+3+5 = 29 cycles
    inc noise_pattern_ptr+0
    lax (noise_pattern_ptr), y
    lda noise_instrument_lo, x
    sta ptr_temp+0
    lda noise_instrument_hi, x
    sta ptr_temp+1
    inc noise_pattern_ptr+0

    ; 4+2+4+2+2+2 = 16 cycles
    lda noise_stack
    eor #%01000000
    sta noise_stack_next
    tax
    axs #.lobyte(-4)
    txs

    ; 5+6+6 = 17 cycles
    jmp (ptr_temp)
@dontChangeNoise:
    ; Stall 61 cycles
    nop
    ldy #11
:
    dey
    bne_aligned :-
    jmp track_step_return


update_variables:
    ; Total = 2+4+6+27+36+39+39+7+3 = 163

    nop
    pla

    ; 2+2+2 = 6 cycles
    ldy #0
    ldx #.lobyte(noise_stack)
    txs

    ; Noise
    ; 4+4+2+17 = 27 cycles
    lda noise_stack_next
    cmp noise_stack
    bne_aligned :+
        ; 4+4+2+2+2+3 = 17 cycles
        pla
        pla
        txa
        axs #3
        txs
        jmp :++
:
        ; 3*3 + 7 = 16 cycles
        pha ; noise_stack
        tya ; A = 0
        pha ; noise_vol_duty_y
        lda (noise_pattern_ptr), y
        pha ; noise_note
:

    ; Triangle
    ; 4+4+2+26 = 36 cycles
    lda triangle_stack_next
    cmp triangle_stack
    bne_aligned :+
        ; 2+3+4+4+4+2+2+2+3 = 26 cycles
        tsx
        pha
        pla
        pla
        pla
        txa
        axs #6
        txs
        jmp :++
:
        ; 3*6 + 7 = 25 cycles
        pha ; triangle_stack
        tya ; A = 0
        pha ; triangle_pitch_bend+1
        pha ; triangle_pitch_bend+0
        pha ; triangle_pitch_y
        pha ; triangle_vol_duty_y
        lda (triangle_pattern_ptr), y
        pha ; triangle_note
:

        
    ; Square2
    ; 4+4+2+29 = 39 cycles
    lda square2_stack_next
    cmp square2_stack
    bne_aligned :+
        ; 2+2+4+4+4+4+2+2+2+3 = 29 cycles
        nop
        tsx
        pla
        pla
        pla
        pla
        txa
        axs #7
        txs
        jmp :++
:
        ; 3*7 + 7 = 28 cycles
        pha ; square2_stack
        tya ; A = 0
        pha ; square2_pitch_bend+1
        pha ; square2_pitch_bend+0
        php ; square2_pitch_hi
        pha ; square2_pitch_y
        pha ; square2_vol_duty_y
        lda (square2_pattern_ptr), y
        pha ; square2_note
:

    ; Square1
    ; 4+4+2+29 = 39 cycles
    lda square1_stack_next
    cmp square1_stack
    bne_aligned :+
        ; 2+2+4+4+4+4+2+2+2+3 = 29 cycles
        nop
        tsx
        pla
        pla
        pla
        pla
        txa
        axs #7
        txs
        jmp :++
:
        ; 3*7 + 7 = 28 cycles
        pha ; square1_stack
        tya ; A = 0
        pha ; square1_pitch_bend+1
        pha ; square1_pitch_bend+0
        php ; square1_pitch_hi
        pha ; square1_pitch_y
        pha ; square1_vol_duty_y
        lda (square1_pattern_ptr), y
        pha ; square1_note
:

    ; 4+3 = 7 cycles
    lda track_speed
    pha ; track_step

    ; 3 cycles
    jmp track_step_return

; Call this function every frame in your NMI or whatever to play the music.
; Last measurement = 760 cycles (not counting JSR)
penguin_process:
    tsx
    stx stack_temp

    dec track_step
    ldx track_step
    lda track_step_function_lo, x
    sta ptr_temp+0
    lda track_step_function_hi, x
    sta ptr_temp+1
    jmp (ptr_temp)

update_null:
    pla
    pla
    nop
    jmp :+
doneAdvancePattern:
    ; Stall 156 cycles
    dec pattern_left
:
    ldy #28
:
    dey
    bne_aligned :-
    nop
    nop
    nop
    jmp track_step_return
update_pattern_ptrs:
    ; Total = 4+2+157 = 163 cycles
    ldy pattern_left
    bne_aligned doneAdvancePattern

    ; Total = 82+39+36 = 157 cycles

    ; (2+5+3)*8+2 = 82 cycles
    lda (track_ptr), y
    sta square1_pattern_ptr+0
    iny
    lda (track_ptr), y
    sta square1_pattern_ptr+1
    iny
    lda (track_ptr), y
    sta square2_pattern_ptr+0
    iny
    lda (track_ptr), y
    sta square2_pattern_ptr+1
    iny
    lda (track_ptr), y
    sta triangle_pattern_ptr+0
    iny
    lda (track_ptr), y
    sta triangle_pattern_ptr+1
    iny
    lda (track_ptr), y
    sta noise_pattern_ptr+0
    iny
    lda (track_ptr), y
    sta noise_pattern_ptr+1
    sty pattern_left ; Y = 7

    ; 3+2+2+2+3+4+2+4+2+2+2+2+3+3+3 = 39 cycles
    lax track_ptr+0
    axs #.lobyte(-8)
    lda #0
    tay                 ; Set Y = 0 for mask loads.              
    adc track_ptr+1
    cmp track_end+1
    bcc_aligned :++
    cpx track_end+0
:
    bcs_aligned @resetTrack
    nop
    nop
    nop
    jmp @storeTrack
:
    jmp :--
@resetTrack:
    ldx track_start+0
    lda track_start+1
@storeTrack:
    stx track_ptr+0
    sta track_ptr+1

    ; (5+4)*4 = 36 cycles
    lda (square1_pattern_ptr), y
    sta square1_mask
    lda (square2_pattern_ptr), y
    sta square2_mask
    lda (triangle_pattern_ptr), y
    sta triangle_mask
    lda (noise_pattern_ptr), y
    sta noise_mask

    ; Fall-through
square2_instrument_assign_return:
noise_instrument_assign_return:
track_step_return:
    ldx square1_stack
    txs

    ; Square1: Volume & Duty
    ldy square1_vol_duty_y
    rts
square1_vol_duty_return:
    .byt $90, $00       ; BCC to even-out cycles
    sta $4000
    iny
    sty square1_vol_duty_y

    ; Square1: Pitch
    ldx #0
    ldy square1_pitch_y
    rts
square1_pitch_return:
    .byt $90, $00       ; BCC to even-out cycles
    bmi_aligned :+
    .byt $04            ; IGN (zeropage)
:
    dex
    clc
    adc square1_pitch_bend+0
    sta square1_pitch_bend+0
    txa
    adc square1_pitch_bend+1
    sta square1_pitch_bend+1
    iny
    sty square1_pitch_y

    ; Square1 Arpeggio
    lax square1_note
    rts                 ; AXS
square1_arpeggio_return:
    .byt $04, $00       ; IGN (zeropage) to waste 3 cycles
    clc
    lda note_table_lo, x
    adc square1_pitch_bend+0
    sta $4002
    lda note_table_hi, x
    adc square1_pitch_bend+1
    and #%00000111
    cmp square1_pitch_hi
    beq_aligned :+
    sta $4003
    jmp :++
:   nop
    nop
    nop
:   sta square1_pitch_hi


    ; Square2
    ldx square2_stack
    txs

    ; Square2: Volume & Duty
    ldy square2_vol_duty_y
    rts
square2_vol_duty_return:
    .byt $90, $00       ; BCC to even-out cycles
    sta $4004
    iny
    sty square2_vol_duty_y

    ; Square2: Pitch
    ldx #0
    ldy square2_pitch_y
    rts
square2_pitch_return:
    .byt $90, $00       ; BCC to even-out cycles
    bmi_aligned :+
    .byt $04            ; IGN (zeropage)
:
    dex
    clc
    adc square2_pitch_bend+0
    sta square2_pitch_bend+0
    txa
    adc square2_pitch_bend+1
    sta square2_pitch_bend+1
    iny
    sty square2_pitch_y

    ; Square2: Arpeggio
    lax square2_note
    rts                 ; AXS
square2_arpeggio_return:
    .byt $04, $00       ; IGN (zeropage) to waste 3 cycles
    clc
    lda note_table_lo, x
    adc square2_pitch_bend+0
    sta $4006
    lda note_table_hi, x
    adc square2_pitch_bend+1
    and #%00000111
    cmp square2_pitch_hi
    beq_aligned :+
    sta $4007
    jmp :++
:   nop
    nop
    nop
:   sta square2_pitch_hi

    ; Triangle
    ldx triangle_stack
    txs

    ; Triangle: Volume & Duty
    ldy triangle_vol_duty_y
    rts
triangle_vol_duty_return:
    .byt $90, $00       ; BCC to even-out cycles
    ldx #%00001111
    axs #2
    arr #%00001111
    sta $4008
    iny
    sty triangle_vol_duty_y

    ; Triangle: Pitch
    ldx #0
    ldy triangle_pitch_y
    rts
triangle_pitch_return:
    .byt $90, $00       ; BCC to even-out cycles
    bmi_aligned :+
    .byt $04            ; IGN (zeropage)
:
    dex
    clc
    adc triangle_pitch_bend+0
    sta triangle_pitch_bend+0
    txa
    adc triangle_pitch_bend+1
    sta triangle_pitch_bend+1
    iny
    sty triangle_pitch_y

    ; Triangle: Arpeggio
    lax triangle_note
    rts                 ; AXS
triangle_arpeggio_return:
    .byt $04, $00       ; IGN (zeropage) to waste 3 cycles
    clc
    lda note_table_lo, x
    adc triangle_pitch_bend+0
    sta $400A
    lda note_table_hi, x
    adc triangle_pitch_bend+1
    and #%00000111
    sta $400B

    lda #%10000000
    sta $4017

    ; Noise
    ldx noise_stack
    txs

    ; Noise: Volume & Duty
    ldy noise_vol_duty_y
    rts
noise_vol_duty_return:
    .byt $90, $00       ; BCC to even-out cycles
    sta $400C
    iny
    sty noise_vol_duty_y

    ; Noise: Arpeggio
    lax noise_note
    rts                 ; AXS
noise_arpeggio_return:
    .byt $04, $00       ; IGN (zeropage) to waste 3 cycles
    lda #%00001111
    sax $400E

    ldx stack_temp
    txs
    rts


.proc penguin_set_song
    lda tracks_speed, x
    sta track_speed

    lda tracks_lo, x
    sta track_ptr+0
    sta track_start+0
    lda tracks_hi, x
    sta track_ptr+1
    sta track_start+1

    inx
    lda tracks_lo, x
    sta track_end+0
    lda tracks_hi, x
    sta track_end+1

    lda #3
    sta track_step

    lda #%00001111
    sta $4015

    ldx #%11110000
    stx $4008
    stx $400C

    ldx #$00
    stx $400F
    stx pattern_left
:
    lda reset_instruments, x
    sta $100, x
    inx
    cpx #22
    bne :-

    lda #.lobyte(PMEM-5)
    sta noise_stack_next
    sta noise_stack
    lda #.lobyte(PMEM-5-6)
    sta triangle_stack_next
    sta triangle_stack
    lda #.lobyte(PMEM-5-6*2)
    sta square2_stack_next
    sta square2_stack
    lda #.lobyte(PMEM-5-6*3)
    sta square1_stack_next
    sta square1_stack

    rts
.endproc

