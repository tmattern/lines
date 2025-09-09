; Bresenham 16 bits, 6809, VRAM $4000, 320x200, 1bpp
; Compatible lwasm. Variables en $6100, code à $A000. setdp $61 obligatoire.
;
; Entrée :
;   X0, Y0, X1, Y1 (16 bits, hi/lo, dans $6100-$6107)
; Trace la ligne (X0,Y0)-(X1,Y1) en VRAM $4000
; (change les valeurs ci-dessous pour tester d'autres lignes)

X0VAL   equ     $0000
Y0VAL   equ     $0000
X1VAL   equ     $013F    ; 319
Y1VAL   equ     $00C7    ; 199

        org     $6100
X0:     rmb     2
Y0:     rmb     2
X1:     rmb     2
Y1:     rmb     2
X:      rmb     2
Y:      rmb     2
DX:     rmb     2
DY:     rmb     2
SX:     rmb     1
SY:     rmb     1
ERR:    rmb     2
TMP:    rmb     2
BITMASK:rmb     1

        org     $A000
VRAM_BASE equ   $4000

; ====== EXEMPLE D'APPEL ======
Start:
        setdp   $61

        ldd     #X0VAL
        std     X0
        ldd     #Y0VAL
        std     Y0
        ldd     #X1VAL
        std     X1
        ldd     #Y1VAL
        std     Y1

        jsr     DrawLine
        rts

; ====== ROUTINE BRESENHAM UNIVERSELLE ======
; Entrée : X0,Y0,X1,Y1 en RAM
DrawLine:
        ; X = X0
        ldd     X0
        std     X
        ; Y = Y0
        ldd     Y0
        std     Y

        ; DX = abs(X1-X0)
        ldd     X1
        subd    X0
        bpl     DXP
        nega
        negb
        sbcb    #0
DXP:    std     DX

        ; SX = (X1 > X0) ? 1 : -1
        ldd     X1
        subd    X0
        bpl     SXP
        lda     #-1
        bra     SXS
SXP:    lda     #1
SXS:    sta     SX

        ; DY = abs(Y1-Y0)
        ldd     Y1
        subd    Y0
        bpl     DYP
        nega
        negb
        sbcb    #0
DYP:    std     DY

        ; SY = (Y1 > Y0) ? 1 : -1
        ldd     Y1
        subd    Y0
        bpl     SYP
        lda     #-1
        bra     SYS
SYP:    lda     #1
SYS:    sta     SY

        ; On va déterminer si DX > DY (axe X dominant) ou l'inverse
        ldd     DX
        cmpd    DY
        bhs     XDOMINANT
        ; --- Y dominant ---
        ; ERR = DY/2
        ldd     DY
        lsra
        rorb
        std     ERR
        bra     LoopY

; --- Axe X dominant ---
XDOMINANT:
        ; ERR = DX/2
        ldd     DX
        lsra
        rorb
        std     ERR

LoopX:  ; boucle principale X dominant
        jsr     PlotPixel

        ldd     X
        cmpd    X1
        bne     NotEndX
        ldd     Y
        cmpd    Y1
        beq     EndLine
NotEndX:
        ldd     ERR
        subd    DY
        std     ERR
        bpl     NoIncY_X
        ; Y += SY
        lda     Y+1
        adda    SY
        sta     Y+1
        ldd     ERR
        addd    DX
        std     ERR
NoIncY_X:
        ; X += SX
        lda     X+1
        adda    SX
        sta     X+1
        bra     LoopX

; --- Axe Y dominant ---
LoopY:
        jsr     PlotPixel

        ldd     X
        cmpd    X1
        bne     NotEndY
        ldd     Y
        cmpd    Y1
        beq     EndLine
NotEndY:
        ldd     ERR
        subd    DX
        std     ERR
        bpl     NoIncX_Y
        ; X += SX
        lda     X+1
        adda    SX
        sta     X+1
        ldd     ERR
        addd    DY
        std     ERR
NoIncX_Y:
        ; Y += SY
        lda     Y+1
        adda    SY
        sta     Y+1
        bra     LoopY

EndLine:
        jsr     PlotPixel
        rts

; ====== PLOT PIXEL (X,Y) ======
; Allume le pixel (X,Y) dans la VRAM $4000 (320x200, 1bpp)
PlotPixel:
        ; Adresse = VRAM_BASE + Y*40 + (X>>3)
        lda     Y+1
        ldb     #40
        mul
        addd    #VRAM_BASE
        std     TMP
        lda     X+1
        lsra
        lsra
        lsra
        adda    TMP+1
        sta     TMP+1
        ; Bitmask
        lda     X+1
        anda    #7
        eora    #7
        ldb     #1
        pshs    a
        lda     ,s+
        beq     BitMaskReady
BitMaskLoop:
        lslb
        deca
        bne     BitMaskLoop
BitMaskReady:
        stb     BITMASK
        ldx     TMP
        lda     ,x
        ora     BITMASK
        sta     ,x
        rts