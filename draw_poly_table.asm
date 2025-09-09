; Bresenham 16 bits, 6809, code à $A000, variables à $6100
; Compatible lwasm, 320x200, VRAM $4000
; Corrigé : gestion correcte du pas principal (axe dominant)
; Utilise setdp $61

; Constantes :
X0VAL   equ     $0000       ; X0 = 0
Y0VAL   equ     $0000       ; Y0 = 0
X1VAL   equ     $013F       ; X1 = 319
Y1VAL   equ     $00C7       ; Y1 = 199

        org     $6100

X0:     rmb     2           ; X0 (hi/lo)
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

VRAM_BASE   equ $4000

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

; --- Routine de tracé de ligne Bresenham 16 bits ---
; Entrée : X0,Y0,X1,Y1 initialisés
; Sortie : trace la ligne en VRAM $4000

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
        bpl     DXpos
        nega
        negb
        sbcb    #0
DXpos:  std     DX

        ; SX = +1 ou -1 selon X1-X0
        ldd     X1
        subd    X0
        bpl     SxPos
        lda     #-1
        bra     SxSet
SxPos:  lda     #1
SxSet:  sta     SX

        ; DY = -abs(Y1-Y0) (on garde DY négatif pour l'algo)
        ldd     Y0
        subd    Y1
        bpl     DYpos
        nega
        negb
        sbcb    #0
DYpos:  std     DY

        ; SY = +1 ou -1 selon Y1-Y0
        ldd     Y1
        subd    Y0
        bpl     SyPos
        lda     #-1
        bra     SySet
SyPos:  lda     #1
SySet:  sta     SY

        ; ERR = DX + DY
        ldd     DX
        addd    DY
        std     ERR

Loop:
        ; --- Plot pixel (X,Y) ---
        lda     Y+1            ; Y lo
        ldb     #40
        mul
        addd    #VRAM_BASE
        std     TMP

        lda     X+1            ; X lo
        lsra
        lsra
        lsra                  ; X >> 3
        adda    TMP+1
        sta     TMP+1

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

        ; Fin ? (X==X1 && Y==Y1)
        ldd     X
        cmpd    X1
        bne     NotEnd
        ldd     Y
        cmpd    Y1
        beq     EndLine
NotEnd:

        ; e2 = 2*ERR
        ldd     ERR
        addd    ERR

        ; Si e2 >= DY (DY est négatif) alors avancer X
        ldx     #DY
        ldd     ERR
        addd    ERR
        cmpd    DY
        blt     SkipX
        ; ERR += DY
        ldd     ERR
        addd    DY
        std     ERR
        lda     X+1
        adda    SX
        sta     X+1
SkipX:

        ; Si e2 <= DX alors avancer Y
        ldd     ERR
        addd    ERR
        cmpd    DX
        bgt     SkipY
        ; ERR += DX
        ldd     ERR
        addd    DX
        std     ERR
        lda     Y+1
        adda    SY
        sta     Y+1
SkipY:

        bra     Loop

EndLine:
        rts