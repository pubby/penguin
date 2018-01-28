.importzp penguin_zp
.export penguin_init_ntsc
.export penguin_init_pal
.export penguin_process
.export penguin_set_song

.include "sfx.inc"

penguin_ptr_temp     = penguin_zp +  0
track_ptr            = penguin_zp +  2
note_table_ptr       = penguin_zp +  4
square1_pattern_ptr  = penguin_zp +  6
square2_pattern_ptr  = penguin_zp +  8
triangle_pattern_ptr = penguin_zp + 10
noise_pattern_ptr    = penguin_zp + 12

stack_temp    = $100
pattern_left  = $101

PMEM = $102 + 22

track_step          = PMEM + 0

square1_note        = PMEM +  1
square1_vol_duty_y  = PMEM +  2
square1_pitch_y     = PMEM +  3
square1_pitch_bend  = PMEM +  4 ; 2 bytes
square1_pitch_hi    = PMEM +  6
square1_stack       = PMEM +  7
 
square2_note        = PMEM +  8
square2_vol_duty_y  = PMEM +  9
square2_pitch_y     = PMEM + 10
square2_pitch_bend  = PMEM + 11 ; 2 bytes
square2_pitch_hi    = PMEM + 13
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

noise_mask    = PMEM2 +  0
triangle_mask = PMEM2 +  1
square2_mask  = PMEM2 +  2
square1_mask  = PMEM2 +  3

track_speed   = PMEM2 +  4
track_start   = PMEM2 +  5 ; 2 bytes
track_end     = PMEM2 +  7 ; 2 bytes

noise_stack_next    = PMEM2 + 9
triangle_stack_next = PMEM2 + 10
square2_stack_next  = PMEM2 + 11
square1_stack_next  = PMEM2 + 12

sfx_noise_play = PMEM2 + 13
sfx_stack_temp = PMEM2 + 14

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
.include "music_data.inc"

.segment "SFX_DATA"
.include "sfx_data.inc"

.segment "PENGUIN"
; Note table borrowed from GGsound borrowed from periods.s from Famitracker
ntsc_note_table:
.word $07F1,$077F,$0713,$06AD,$064D,$05F3,$059D,$054C,$0500,$04B8,$0474,$0434
.word $03F8,$03BF,$0389,$0356,$0326,$02F9,$02CE,$02A6,$0280,$025C,$023A,$021A
.word $01FB,$01DF,$01C4,$01AB,$0193,$017C,$0167,$0152,$013F,$012D,$011C,$010C
.word $00FD,$00EF,$00E1,$00D5,$00C9,$00BD,$00B3,$00A9,$009F,$0096,$008E,$0086
.word $007E,$0077,$0070,$006A,$0064,$005E,$0059,$0054,$004F,$004B,$0046,$0042
.word $003F,$003B,$0038,$0034,$0031,$002F,$002C,$0029,$0027,$0025,$0023,$0021
.word $001F,$001D,$001B,$001A,$0018,$0017,$0015,$0014,$0013,$0012,$0011,$0010
.word $000F,$000E,$000D
track_step_function_lo:
    .byt .lobyte(update_variables)
    .byt .lobyte(update_triangle_noise)
    .byt .lobyte(update_squares)
    .byt .lobyte(update_pattern_ptrs)
    .repeat 78
        .byt .lobyte (update_null)
    .endrepeat

pal_note_table:
.word $0760,$06F6,$0692,$0634,$05DB,$0586,$0537,$04EC,$04A5,$0462,$0423,$03E8
.word $03B0,$037B,$0349,$0319,$02ED,$02C3,$029B,$0275,$0252,$0231,$0211,$01F3
.word $01D7,$01BD,$01A4,$018C,$0176,$0161,$014D,$013A,$0129,$0118,$0108,$00F9
.word $00EB,$00DE,$00D1,$00C6,$00BA,$00B0,$00A6,$009D,$0094,$008B,$0084,$007C
.word $0075,$006E,$0068,$0062,$005D,$0057,$0052,$004E,$0049,$0045,$0041,$003E
.word $003A,$0037,$0034,$0031,$002E,$002B,$0029,$0026,$0024,$0022,$0020,$001E
.word $001D,$001B,$0019,$0018,$0016,$0015,$0014,$0013,$0012,$0011,$0010,$000F
.word $000E,$000D,$000C
track_step_function_hi:
    .byt .hibyte(update_variables)
    .byt .hibyte(update_triangle_noise)
    .byt .hibyte(update_squares)
    .byt .hibyte(update_pattern_ptrs)
    .repeat 78
        .byt .hibyte (update_null)
    .endrepeat

.assert .lobyte(ntsc_note_table) = 0, error, "ntsc_note_table misaligned"
.assert .lobyte(pal_note_table)  = 0, error, "pal_note_table misaligned"

.align 256
update_variables:
    ; Total = 6+27+38+41+41+7+3 = 163 cycles

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
    ; 4+2+4+3+25 = 38 cycles
    lda triangle_stack_next
    beq_aligned @triangleSFX
    cmp triangle_stack
    bne_aligned :++
    beq_aligned :+
@triangleSFX:
        nop
        nop
        nop
        nop
:
        ; 2+4+4+4+2+2+2+3 = 23 cycles
        tsx
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
    ; 4+2+4+3+28 = 41 cycles
    lda square2_stack_next
    beq_aligned @square2SFX
    cmp square2_stack
    bne_aligned :++
    beq_aligned :+
@square2SFX:
        nop
        nop
        nop
        nop
:
        ;  26 cycles
        ; 2+4+3+4+4+2+2+2+3
        tsx
        pla
        pha
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
        php ; square2_pitch_hi
        pha ; square2_pitch_bend+1
        pha ; square2_pitch_bend+0
        pha ; square2_pitch_y
        pha ; square2_vol_duty_y
        lda (square2_pattern_ptr), y
        pha ; square2_note
:

    ; Square1
    ; 4+2+4+3+28 = 41 cycles
    lda square1_stack_next
    beq_aligned @square1SFX
    cmp square1_stack
    bne_aligned :++
    beq_aligned :+
@square1SFX:
        nop
        nop
        nop
        nop
:
        ;  26 cycles
        ; 2+4+3+4+4+2+2+2+3
        tsx
        pla
        pha
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
        php ; square1_pitch_hi
        pha ; square1_pitch_bend+1
        pha ; square1_pitch_bend+0
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


update_squares:
    ; Total = 2+3+80+78 = 163 cycles
    nop
    .byt $04, $00 ; IGN (3 cycles)

    ; square1
    ; 6+2+72 = 80 cycles
    lsr square1_mask
    bcc_aligned @dontChangeSquare1

    ; Total = 2+29+18+23 = 72 cycles

    ; 2 cycles
    ldy #0

    ; 5+5+4+3+4+3+5 = 29 cycles
    inc square1_pattern_ptr+0
    lax (square1_pattern_ptr), y
    lda square1_instrument_lo, x
    sta penguin_ptr_temp+0
    lda square1_instrument_hi, x
    sta penguin_ptr_temp+1
    inc square1_pattern_ptr+0
    
    ; 4+2+2+4+2+2+2 = 18 cycles
    lda square1_stack_next
    beq_aligned @square1SFX
    eor #%01000000
    sta square1_stack_next
    tax
    axs #.lobyte(-6)
    txs

    ; 5+6+6+6 = 23 cycles
    jmp (penguin_ptr_temp)
@square1SFX:
    ; Stall 34 cycles
    ldy #6
    jmp :+
@dontChangeSquare1:
    ; Stall 71 cycles
    ldy #14
:
    dey
    bne_aligned :-
square1_instrument_assign_return:

    ; square2
    ; 6+2+70 = 78 cycles
    lsr square2_mask
    bcc_aligned @dontChangeSquare2

    ; Total = 29+18+23 = 70

    ; Y = 0
    
    ; 5+5+4+3+4+3+5 = 29 cycles
    inc square2_pattern_ptr+0
    lax (square2_pattern_ptr), y
    lda square2_instrument_lo, x
    sta penguin_ptr_temp+0
    lda square2_instrument_hi, x
    sta penguin_ptr_temp+1
    inc square2_pattern_ptr+0

    ; 4+2+2+4+2+2+2 = 18 cycles
    lda square2_stack_next
    beq_aligned @square2SFX
    eor #%01000000
    sta square2_stack_next
    tax
    axs #.lobyte(-6)
    txs

    ; 5+6+6+6 = 23 cycles
    jmp (penguin_ptr_temp)
@square2SFX:
    ; Stall 34 cycles
    nop
    ldy #5
    jmp :+
@dontChangeSquare2:
    ; Stall 69 cycles
    ldy #13
:
    dey
    bne_aligned :-
    jmp track_step_return


update_triangle_noise:
    ; Total = 4+3+80+76 = 163 cycles
    pla
    .byt $04, $00 ; IGN (3 cycles)

    ; triangle
    ; 6+2+72 = 80 cycles
    lsr triangle_mask
    bcc_aligned @dontChangeTriangle

    ; Total = 2+29+18+23 = 72 cycles

    ; 2 cycles
    ldy #0
    
    ; 5+5+4+3+4+3+5 = 29 cycles
    inc triangle_pattern_ptr+0
    lax (triangle_pattern_ptr), y
    lda triangle_instrument_lo, x
    sta penguin_ptr_temp+0
    lda triangle_instrument_hi, x
    sta penguin_ptr_temp+1
    inc triangle_pattern_ptr+0

    ; 4+2+2+4+2+2+2 = 18 cycles
    lda triangle_stack_next
    beq_aligned @triangleSFX
    eor #%01000000
    sta triangle_stack_next
    tax
    axs #.lobyte(-6)
    txs

    ; 5+6+6+6 = 23 cycles
    jmp (penguin_ptr_temp)
@triangleSFX:
    ; Stall 34 cycles
    ldy #6
    jmp :+
@dontChangeTriangle:
    ; Stall 71 cycles
    ldy #14
:
    dey
    bne_aligned :-
triangle_instrument_assign_return:

    ; noise
    ; 6+2+68 = 76 cycles
    lsr noise_mask
    bcc_aligned @dontChangeNoise

    ; Total = 29+22+17 = 68 cycles

    ; Y = 0

    ; 5+5+4+3+4+3+5 = 29 cycles
    inc noise_pattern_ptr+0
    lax (noise_pattern_ptr), y
    lda noise_instrument_lo, x
    sta penguin_ptr_temp+0
    lda noise_instrument_hi, x
    sta penguin_ptr_temp+1
    inc noise_pattern_ptr+0

    ; 4+2+4+2+4+2+2+2 = 22 cycles
    lda sfx_noise_play
    bne_aligned @noiseSFX
    lda noise_stack
    eor #%01000000
    sta noise_stack_next
    tax
    axs #.lobyte(-4)
    txs

    ; 5+6+6 = 17 cycles
    jmp (penguin_ptr_temp)
@noiseSFX:
    ; Stall 32 cycles
    nop
    .byt $04, $00       ; IGN (zeropage) to waste 3 cycles
    ldy #4
    jmp :+
@dontChangeNoise:
    ; Stall 61 cycles
    ldy #12
    .byt $04, $00       ; IGN (zeropage) to waste 3 cycles
:
    dey
    bne_aligned :-
    jmp track_step_return

; Call this function every frame in your NMI or whatever to play the music.
; Last measurement = 784 cycles (not counting JSR)
penguin_process:
    tsx
    stx stack_temp

    dec track_step
    ldx track_step
    lda track_step_function_lo, x
    sta penguin_ptr_temp+0
    lda track_step_function_hi, x
    sta penguin_ptr_temp+1
    jmp (penguin_ptr_temp)

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
    ldy #0
    ldx square1_pitch_y
    rts
square1_pitch_return:
    .byt $90, $00       ; BCC to even-out cycles
    bmi_aligned :+
    .byt $04            ; IGN (zeropage)
:
    dey
    clc
    adc square1_pitch_bend+0
    sta square1_pitch_bend+0
    tya
    adc square1_pitch_bend+1
    sta square1_pitch_bend+1

    ; Square1 Arpeggio
    sec
    lda square1_note
    rts
square1_arpeggio_sfx_return:
    .byt $0C            ; IGN (absolute) to waste 4 cycles
square1_arpeggio_return:
    .byt $04, $00       ; IGN (zeropage) to waste 3 cycles
    inx
    stx square1_pitch_y
    tay
    clc
    lda (note_table_ptr), y
    adc square1_pitch_bend+0
    sta $4002
    iny
    lda (note_table_ptr), y
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
done_square1:

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
    ldy #0
    ldx square2_pitch_y
    rts
square2_pitch_return:
    .byt $90, $00       ; BCC to even-out cycles
    bmi_aligned :+
    .byt $04            ; IGN (zeropage)
:
    dey
    clc
    adc square2_pitch_bend+0
    sta square2_pitch_bend+0
    tya
    adc square2_pitch_bend+1
    sta square2_pitch_bend+1

    ; Square2: Arpeggio
    sec
    lda square2_note
    rts
square2_arpeggio_sfx_return:
    .byt $0C            ; IGN (absolute) to waste 4 cycles
square2_arpeggio_return:
    .byt $04, $00       ; IGN (zeropage) to waste 3 cycles
    inx
    stx square2_pitch_y
    tay
    clc
    lda (note_table_ptr), y
    adc square2_pitch_bend+0
    sta $4006
    iny
    lda (note_table_ptr), y
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
done_square2:

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
    ldy #0
    ldx triangle_pitch_y
    rts
triangle_pitch_return:
    .byt $90, $00       ; BCC to even-out cycles
    bmi_aligned :+
    .byt $04            ; IGN (zeropage)
:
    dey
    clc
    adc triangle_pitch_bend+0
    sta triangle_pitch_bend+0
    tya
    adc triangle_pitch_bend+1
    sta triangle_pitch_bend+1

    ; Triangle: Arpeggio
    sec
    lda triangle_note
    rts
triangle_arpeggio_sfx_return:
    .byt $0C            ; IGN (absolute) to waste 4 cycles
triangle_arpeggio_return:
    .byt $04, $00       ; IGN (zeropage) to waste 3 cycles
    inx
    stx triangle_pitch_y
    tay
    clc
    lda (note_table_ptr), y
    adc triangle_pitch_bend+0
    sta $400A
    iny
    lda (note_table_ptr), y
    adc triangle_pitch_bend+1
    and #%00000111
    sta $400B

    lda #%10000000
    sta $4017
done_triangle:

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
    rts
noise_arpeggio_sfx_return:
    .byt $0C            ; IGN (absolute) to waste 4 cycles
noise_arpeggio_return:
    .byt $04, $00       ; IGN (zeropage) to waste 3 cycles
    lda #%00001111
    sax $400E
done_noise:

    ldx stack_temp
    txs
    rts

penguin_init_ntsc:
    lda #.lobyte(ntsc_note_table)
    sta note_table_ptr+0
    lda #.hibyte(ntsc_note_table)
    sta note_table_ptr+1
    rts

penguin_init_pal:
    lda #.lobyte(pal_note_table)
    sta note_table_ptr+0
    lda #.hibyte(pal_note_table)
    sta note_table_ptr+1
    rts

penguin_set_song:
    lda tracks_speed, x
    sta track_speed
    sta track_step

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

    lda #%00001000
    sta $4001
    sta $4005

    lda #%00001111
    sta $4015

    ldx #%11110000
    stx $4008
    stx $400C

    ; SAX = store 0
    sax $400F
    sax pattern_left
    sax sfx_noise_play

    tsx
    stx sfx_stack_temp
    ldx #.lobyte(PMEM-1)
    txs
    ldy #0

    jmp init_noise
end_noise_sfx:
    lda #%00110000
    sta $400C

    ldx #.lobyte(PMEM-1)
    txs
init_noise:
    lda #0
    sta sfx_noise_play
@noise_silent_instrument:
    jsr @noise_silent_vol_duty
    nop
    nop
    jmp noise_arpeggio_sfx_return
@noise_silent_vol_duty:
    jsr @noise_silent_instrument_return
    nop
    nop
    nop
    sec
    lda #%00110000
    jmp noise_vol_duty_return
@noise_silent_instrument_return:
    ;2+4+6+6+2+4+4+2+2+3
    tsx
    stx noise_stack
    stx noise_stack_next
    tya
    beq_aligned :+
    jmp done_noise
:
    ; 2+4+6+6+2+4+4+2+2+3

init_triangle:
@triangle_silent_instrument:
    jsr @triangle_silent_pitch
    nop
    nop
    jmp triangle_arpeggio_sfx_return
@triangle_silent_pitch:
    jsr @triangle_silent_vol_duty
    nop
    nop
    nop
    sec
    lda #0
    jmp triangle_pitch_return
@triangle_silent_vol_duty:
    jsr @triangle_silent_instrument_return
    nop
    nop
    nop
    sec
    lda #%00110000
    jmp triangle_vol_duty_return
@triangle_silent_instrument_return:
    tsx
    stx triangle_stack
    stx triangle_stack_next
    tya
    beq_aligned :+
    jmp done_triangle
:

init_square2:
@square2_silent_instrument:
    jsr @square2_silent_pitch
    nop
    nop
    jmp square2_arpeggio_sfx_return
@square2_silent_pitch:
    jsr @square2_silent_vol_duty
    nop
    nop
    nop
    sec
    lda #0
    jmp square2_pitch_return
@square2_silent_vol_duty:
    jsr @square2_silent_instrument_return
    nop
    nop
    nop
    sec
    lda #%00110000
    jmp square2_vol_duty_return
@square2_silent_instrument_return:
    tsx
    stx square2_stack
    stx square2_stack_next
    tya
    beq_aligned :+
    jmp done_square2
:

init_square1:
@square1_silent_instrument:
    jsr @square1_silent_pitch
    nop
    nop
    jmp square1_arpeggio_sfx_return
@square1_silent_pitch:
    jsr @square1_silent_vol_duty
    nop
    nop
    nop
    sec
    lda #0
    jmp square1_pitch_return
@square1_silent_vol_duty:
    jsr square1_silent_instrument_return
    nop
    nop
    nop
    sec
    lda #%00110000
    jmp square1_vol_duty_return
square1_silent_instrument_return:
    tsx
    stx square1_stack
    stx square1_stack_next
    tya
    beq_aligned :+
    jmp done_square1
:

    ldx sfx_stack_temp
    txs
    rts

end_square1_sfx:
    ; Stall 94 cycles:
    .byt $04, $00 ; IGN (3 cycles)
    ldx #18
:
    dex
    bne_aligned :-
    lda #%00110000
    sta $4000
    lax square1_stack
    axs #.lobyte(-6)
    txs
    jmp init_square1

end_square2_sfx:
    ; Stall 94 cycles:
    .byt $04, $00 ; IGN (3 cycles)
    ldx #18
:
    dex
    bne_aligned :-
    lda #%00110000
    sta $4004
    lax square2_stack
    axs #.lobyte(-6)
    txs
    jmp init_square2

end_triangle_sfx:
    ; Stall 93 cycles:
    nop
    ldx #18
:
    dex
    bne_aligned :-
    lda #%00110000
    sta $4008
    lax triangle_stack
    axs #.lobyte(-6)
    txs
    jmp init_triangle


square2_sfx_call_return:
    ldx #.lobyte(square2_pitch_hi)
    .byt $0C            ; IGN (absolute)
square1_sfx_call_return:
    ldx #.lobyte(square1_pitch_hi)
    txs
    php ; pitch_hi
triangle_sfx_call_return_impl:
    lda #0
    pha ; pitch_bend+1
    pha ; pitch_bend+0
    pha ; pitch_y
    pha ; vol_duty_y
    ldx sfx_stack_temp
    txs
    rts

triangle_sfx_call_return:
    ldx #.lobyte(triangle_pitch_bend+1)
    txs
    jmp triangle_sfx_call_return_impl

noise_sfx_call_return:
    lda #0
    sta noise_vol_duty_y
    ldx sfx_stack_temp
    txs
    rts

