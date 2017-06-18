.include "nes.inc"

.import penguin_set_song
.import penguin_process

.export main
.export nmi_handler
.export irq_handler
.exportzp penguin_zp

.segment "ZEROPAGE"
debug: .res 1
nmi_counter: .res 1
penguin_zp:  .res 12

.segment "CODE"

.proc nmi_handler
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

    ldx #0
    jsr penguin_set_song

    lda #PPUCTRL_NMI_ON
    sta PPUCTRL
loop:
    lda nmi_counter
:
    cmp nmi_counter
    beq :-

    sta debug
    jsr penguin_process
    sta debug
    jmp loop
.endproc

