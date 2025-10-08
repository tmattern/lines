        include "lib/hw/to8_hw.inc"
        include "lib/hw/to8_rom.inc"
        include "lib/variables.asm"


        org     $A000
        lda     #$61
        tfr     a,dp

        orcc    #$50

        jsr     InitScreen

        ; prepare buffer 1
        jsr     ClearScreenRAMA
        lda     #COLOR_WHITE*16 + #COLOR_BLACK
        jsr     TranscodeRamb
        jsr     ClearScreenRAMB
        jsr     WaitVBLAndSwitchBuffer

        ; prepare buffer 2
        jsr     ClearScreenRAMA
        lda     #COLOR_WHITE*16 + #COLOR_BLACK
        jsr     TranscodeRamb
        jsr     ClearScreenRAMB
        jsr     WaitVBLAndSwitchBuffer


Restart:
        lda     #127
        sta     loop_2

        lda     #D3_CAMERA_OFFSET
        sta     d3_camera_offset

; --- Boucle de tracé ---
LoopList:        
        jsr     ClearScreenRAMA

        ldx     #cube3d
        ldy     #cube2d
        jsr     project3d_to_2d

        lda     1,y       ; nb edges
        sta     loop_1
        ldu     2,y       ; points
        ldx     4,y       ; edges

LoopLines:
        ; Charger X0 (U pointe sur tableau)
        lda     ,x+
        lsla
        lsla
        ldy     a,u
        sty     X0

        ; Charger Y0
        adda    #2
        ldy     a,u
        sty     Y0

        ; Charger X1
        lda     ,x+
        lsla
        lsla
        ldy     a,u
        sty     X1

        ; Charger Y1
        adda    #2
        ldy     a,u
        sty     Y1

        jsr     DrawLine

        dec     loop_1
        bne     LoopLines

LoopEnd:
        jsr     WaitVBLAndSwitchBuffer
        
        dec     loop_2
        bne     LoopList
        bra     Restart

        include "lib/bresenham.asm"
        include "lib/clear_screen.asm"
        include "lib/vbl.asm"
        include "3d/cube.inc"
        include "3d/rendering.inc"
