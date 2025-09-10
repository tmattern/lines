; Bresenham universel 16 bits, 6809
; X et Y courants dans registres X et Y (16 bits)
; Incrémentation avec LEAX A,X et LEAY A,Y (A signé)
; SX et SY en direct page (8 bits signés)
; VRAM $4000, 320x200 (1bpp)
; Compatible lwasm, setdp $61

X0VAL   equ $0000
Y0VAL   equ $0000
X1VAL   equ $013F    ; 319
Y1VAL   equ $00C7    ; 199

        org     $6100
X0:     rmb     2
Y0:     rmb     2
X1:     rmb     2
Y1:     rmb     2
DX:     rmb     2
DY:     rmb     2
SX:     rmb     1    ; 8 bits signé
SY:     rmb     1
ERR:    rmb     2
TMP:    rmb     2
BITMASK:rmb     1

        org     $A000
VRAM_BASE equ   $4000

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

; ===== Routine Bresenham universelle 16 bits, LEAX/LEAY =====
DrawLine:
        ; X = X0, Y = Y0
        ldd     X0
        std     TMP
        ldx     TMP
        ldd     Y0
        std     TMP
        ldy     TMP

        ; DX = abs(X1-X0)
        ldd     X1
        subd    X0
        bpl     DXP
        nega
        negb
        sbcb    #0
DXP:    std     DX

        ; SX = (X1 > X0) ? +1 : -1 (sur 8 bits)
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

        ; SY = (Y1 > Y0) ? +1 : -1 (sur 8 bits)
        ldd     Y1
        subd    Y0
        bpl     SYP
        lda     #-1
        bra     SYS
SYP:    lda     #1
SYS:    sta     SY

        ; Axe principal
        ldd     DX
        cmpd    DY
        bhs     XDOMINANT
        ; --- Y dominant ---
        ldd     DY
        lsra
        rorb
        std     ERR
        bra     LoopY

; --- Axe X dominant ---
XDOMINANT:
        ldd     DX
        lsra
        rorb
        std     ERR

LoopX:  jsr     PlotPixelXY

        ; Test fin
        cmpx    X1
        bne     NotEndX
        cmpy    Y1
        beq     EndLine
NotEndX:
        ldd     ERR
        subd    DY
        std     ERR
        bpl     NoIncY_X
        lda     SY
        leay    a,y
        ldd     ERR
        addd    DX
        std     ERR
NoIncY_X:
        lda     SX
        leax    a,x
        bra     LoopX

LoopY:  jsr     PlotPixelXY

        ; Test fin
        cmpx    X1
        bne     NotEndY
        cmpy    Y1
        beq     EndLine
NotEndY:
        ldd     ERR
        subd    DX
        std     ERR
        bpl     NoIncX_Y
        lda     SX
        leax    a,x
        ldd     ERR
        addd    DY
        std     ERR
NoIncX_Y:
        lda     SY
        leay    a,y
        bra     LoopY

EndLine:
        jsr     PlotPixelXY
        rts

; ====== PLOT PIXEL (X,Y dans registres) ======
; Routine PlotPixelXY pour 6809, écran 320x200 1bpp (VRAM $4000), X: 0..319, Y: 0..199
; X = registre 16 bits (colonne), Y = registre 16 bits (ligne, seul l'octet bas utilisé)
; Utilise TMP (2 octets) et BITMASK (1 octet) en direct page

; Entrées : X = abscisse (0..319), Y = ordonnée (0..199)
; Ecrase : D, TMP, BITMASK, X

PlotPixelXY:
        ; 1. Calcul adresse début de ligne : VRAM_BASE + Y*40
        tfr     y,d             ; D = Y (0..199)
        lda     #40
        mul                     ; D = Y * 40
        addd    #VRAM_BASE      ; D = adresse de début de la ligne
        std     TMP             ; TMP = base de la ligne

        ; 2. Calcul de l'octet de colonne : (X/8) sur 16 bits
        tfr     x,d             ; D = X (0..319)
        lsra                    ; décalage 1 bit à droite
        rorb
        lsrb                    ; décalage 2
        lsrb                    ; décalage 3 => D = X / 8 (0..39)
        addd    TMP             ; D = adresse exacte du pixel
        std     TMP

        ; 3. Construction du masque de bit pour le pixel
        tfr     x,d             ; D = X
        andb    #7              ; A = X MOD 8 (position du pixel dans octet)
        eorb    #7              ; inversion pour bit haut à gauche
        lda     #1
BitMaskLoop:
        cmpb    #0
        beq     BitMaskReady
        lsla
        decb
        bra     BitMaskLoop
BitMaskReady:
        sta     BITMASK         ; masque prêt

        ; 4. Allumer le pixel
        ldu     TMP             ; X = adresse octet dans VRAM
        lda     ,u              ; lit l'octet
        ora     BITMASK         ; ajoute le pixel
        sta     ,u              ; écrit l'octet

        rts