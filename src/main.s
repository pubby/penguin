.include "nes.inc"
.include "sfx.inc"

.import penguin_init_ntsc
.import penguin_init_pal
.import penguin_set_song
.import penguin_process

.export main
.export nmi_handler
.export irq_handler
.exportzp penguin_zp

.segment "ZEROPAGE"
debug: .res 1
nmi_counter: .res 1
penguin_zp:  .res 14

buttons_read:    .res 1
buttons_held:    .res 1
buttons_pressed: .res 1

.segment "CODE"

.proc read_gamepad

    rts
.endproc


.proc nmi_handler
    pha
    txa
    pha
    tya
    pha

    lda #1
    sta buttons_read
    sta GAMEPAD1
    lda #0
    sta GAMEPAD1
loadGamepadLoop:
    lda GAMEPAD1        ; Read a single button from the controller.
    and #%00000011      ; Ignore bits from Zappers, Power Pads, etc.
    cmp #1              ; Clear carry if A==0, set carry if A>=1.
    rol buttons_read     ; Store the carry bit in 'buttons_read', rotating left.
    bcc loadGamepadLoop ; Stop the loop after 8 iterations.

    ; 'buttons_read' is ready. Now update 'buttons_held' and 'buttons_pressed'.
    lda buttons_held
    eor #$FF
    and buttons_read
    sta buttons_pressed
    lda buttons_read
    sta buttons_held

    sta debug
    jsr penguin_process
    sta debug

    pla
    tay
    pla
    tax
    pla

    inc nmi_counter
    rti
.endproc

.proc irq_handler
    rti
.endproc

.proc main
    lda #0
    sta PPUCTRL
    sta PPUMASK

    jsr penguin_init_ntsc

    ldx #0
    jsr penguin_set_song

    lda #PPUCTRL_NMI_ON
    sta PPUCTRL
loop:
    lda nmi_counter
:
    cmp nmi_counter
    beq :-

    lda buttons_pressed
    and #BUTTON_UP
    beq :+
    jsr square1_sfx_0
:
    lda buttons_pressed
    and #BUTTON_DOWN
    beq :+
    jsr square2_sfx_0
:
    lda buttons_pressed
    and #BUTTON_LEFT
    beq :+
    jsr triangle_sfx_0
:
    lda buttons_pressed
    and #BUTTON_RIGHT
    beq :+
    jsr noise_sfx_0
:
    jmp loop
.endproc

