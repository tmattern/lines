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
LOOP_ID:rmb     1



; --- Boucle de tracé ---

        org     $A000
VRAM_BASE equ   $4000

Start:
        setdp   $61

        ldu     #LINES_TABLE
        ldb     #LINES_COUNT
        stb     LOOP_ID

LoopLines:
        ; Charger X0 (U pointe sur tableau)
        ldd     0,u
        std     X0
        ; Charger Y0
        ldd     2,u
        std     Y0
        ; Charger X1
        ldd     4,u
        std     X1
        ; Charger Y1
        ldd     6,u
        std     Y1

        jsr     DrawLine

        leau    8,u
        ldb     LOOP_ID
        decb
        bne     LoopLines

        rts


; ===== Routine Bresenham universelle 16 bits, LEAX/LEAY =====
DrawLine:
        pshs    a,b
        ; X = X0, Y = Y0
        ldx     X0
        ldy     Y0

        ; DX = abs(X1-X0)
        ldd     X1
        subd    X0
        bpl     DXP
        coma
        comb
        addd    #1
DXP:    std     DX

        ; SX = (X1 > X0) ? +1 : -1 (sur 8 bits)
        ldd     X1
        subd    X0
        bpl     SXP
        lda     #$FF
        bra     SXS
SXP:    lda     #$01
SXS:    sta     SX

        ; DY = abs(Y1-Y0)
        ldd     Y1
        subd    Y0
        bpl     DYP
        coma
        comb
        addd    #1
DYP:    std     DY

        ; SY = (Y1 > Y0) ? +1 : -1 (sur 8 bits)
        ldd     Y1
        subd    Y0
        bpl     SYP
        lda     #$FF
        bra     SYS
SYP:    lda     #$01
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

        ; retour
        puls a,b,pc

; ====== PLOT PIXEL (X,Y dans registres) ======
; Routine PlotPixelXY pour 6809, écran 320x200 1bpp (VRAM $4000), X: 0..319, Y: 0..199
; X = registre 16 bits (colonne), Y = registre 16 bits (ligne, seul l'octet bas utilisé)
; Utilise TMP (2 octets) et BITMASK (1 octet) en direct page

; Entrées : X = abscisse (0..319), Y = ordonnée (0..199)
; Ecrase : D, TMP, BITMASK, X

PlotPixelXY:
        pshs    a,b,u
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

        ; retour
        puls a,b,u,pc

; DATA
LINES_COUNT  equ 200
LINES_TABLE:
        ; Format : X0, Y0, X1, Y1 (16 bits big endian, 200 segments)
        FDB 160,100,250,100
        FDB 160,100,249,103
        FDB 160,100,249,106
        FDB 160,100,249,108
        FDB 160,100,248,111
        FDB 160,100,247,114
        FDB 160,100,246,117
        FDB 160,100,245,120
        FDB 160,100,244,123
        FDB 160,100,243,126
        FDB 160,100,241,129
        FDB 160,100,240,132
        FDB 160,100,238,135
        FDB 160,100,236,138
        FDB 160,100,234,141
        FDB 160,100,232,144
        FDB 160,100,230,147
        FDB 160,100,227,149
        FDB 160,100,225,152
        FDB 160,100,222,155
        FDB 160,100,219,157
        FDB 160,100,217,160
        FDB 160,100,213,162
        FDB 160,100,210,164
        FDB 160,100,207,166
        FDB 160,100,204,168
        FDB 160,100,201,170
        FDB 160,100,197,172
        FDB 160,100,194,173
        FDB 160,100,190,175
        FDB 160,100,186,176
        FDB 160,100,183,178
        FDB 160,100,179,179
        FDB 160,100,175,180
        FDB 160,100,171,181
        FDB 160,100,167,182
        FDB 160,100,163,183
        FDB 160,100,159,183
        FDB 160,100,155,184
        FDB 160,100,151,184
        FDB 160,100,147,184
        FDB 160,100,143,184
        FDB 160,100,139,183
        FDB 160,100,135,183
        FDB 160,100,131,182
        FDB 160,100,127,181
        FDB 160,100,123,180
        FDB 160,100,119,179
        FDB 160,100,115,178
        FDB 160,100,111,176
        FDB 160,100,108,175
        FDB 160,100,104,173
        FDB 160,100,101,172
        FDB 160,100,97,170
        FDB 160,100,94,168
        FDB 160,100,91,166
        FDB 160,100,88,164
        FDB 160,100,85,162
        FDB 160,100,83,160
        FDB 160,100,81,157
        FDB 160,100,78,155
        FDB 160,100,75,152
        FDB 160,100,73,149
        FDB 160,100,70,147
        FDB 160,100,68,144
        FDB 160,100,66,141
        FDB 160,100,64,138
        FDB 160,100,62,135
        FDB 160,100,60,132
        FDB 160,100,59,129
        FDB 160,100,57,126
        FDB 160,100,56,123
        FDB 160,100,55,120
        FDB 160,100,54,117
        FDB 160,100,53,114
        FDB 160,100,52,111
        FDB 160,100,51,108
        FDB 160,100,51,106
        FDB 160,100,51,103
        FDB 160,100,50,100
        FDB 160,100,51,97
        FDB 160,100,51,94
        FDB 160,100,51,91
        FDB 160,100,52,88
        FDB 160,100,53,85
        FDB 160,100,54,82
        FDB 160,100,55,79
        FDB 160,100,56,76
        FDB 160,100,57,73
        FDB 160,100,59,70
        FDB 160,100,60,67
        FDB 160,100,62,64
        FDB 160,100,64,61
        FDB 160,100,66,58
        FDB 160,100,68,55
        FDB 160,100,70,52
        FDB 160,100,73,50
        FDB 160,100,75,47
        FDB 160,100,78,45
        FDB 160,100,81,43
        FDB 160,100,83,40
        FDB 160,100,85,38
        FDB 160,100,88,36
        FDB 160,100,91,34
        FDB 160,100,94,32
        FDB 160,100,97,30
        FDB 160,100,101,28
        FDB 160,100,104,27
        FDB 160,100,108,25
        FDB 160,100,111,24
        FDB 160,100,115,22
        FDB 160,100,119,21
        FDB 160,100,123,20
        FDB 160,100,127,19
        FDB 160,100,131,18
        FDB 160,100,135,17
        FDB 160,100,139,17
        FDB 160,100,143,16
        FDB 160,100,147,16
        FDB 160,100,151,16
        FDB 160,100,155,16
        FDB 160,100,159,16
        FDB 160,100,163,17
        FDB 160,100,167,17
        FDB 160,100,171,18
        FDB 160,100,175,19
        FDB 160,100,179,20
        FDB 160,100,183,21
        FDB 160,100,186,22
        FDB 160,100,190,24
        FDB 160,100,194,25
        FDB 160,100,197,27
        FDB 160,100,201,28
        FDB 160,100,204,30
        FDB 160,100,207,32
        FDB 160,100,210,34
        FDB 160,100,213,36
        FDB 160,100,217,38
        FDB 160,100,219,40
        FDB 160,100,222,43
        FDB 160,100,225,45
        FDB 160,100,227,47
        FDB 160,100,230,50
        FDB 160,100,232,52
        FDB 160,100,234,55
        FDB 160,100,236,58
        FDB 160,100,238,61
        FDB 160,100,240,64
        FDB 160,100,241,67
        FDB 160,100,243,70
        FDB 160,100,244,73
        FDB 160,100,245,76
        FDB 160,100,246,79
        FDB 160,100,247,82
        FDB 160,100,248,85
        FDB 160,100,249,88
        FDB 160,100,249,91
        FDB 160,100,249,94
        FDB 160,100,249,97
        FDB 160,100,250,100
        ; (Total : 200 lignes, motif étoile sur cercle)
