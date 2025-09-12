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


        setdp   $61
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
MASK    rmb     1
ADDR    rmb     2
TMP:    rmb     2
LOOP_ID:rmb     1




; --- Boucle de tracé ---

        org     $A000

Start:
        lda     #$61
        tfr     a,dp
        
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
        stb     LOOP_ID
        bne     LoopLines

        rts


; Routine Bresenham optimisée pour 6809, 320x200, 1bpp, VRAM $4000
; Entrées : X0, Y0, X1, Y1 (16 bits, page directe)
; Variables temporaires : DX, DY, SX, SY, ERR (16 bits), MASK (8 bits)
; Adresse VRAM de travail dans X
; Utilise : A, B, X, Y, U
VRAM_BASE equ   $4000
LINE_BYTES  equ 40     ; 320/8 octets par ligne


; Entrée : X0, Y0, X1, Y1 (16 bits, direct page, big endian)
; Variables : DX, DY (16 bits), SX, SY (8 bits)
; Appelle la bonne routine de tracé par branchement relatif

DrawLine:
    pshs    d,x,y,u

    ; ---- Calcul DX = abs(X1 - X0), SX ----
    ldd     X1          ; D = X1
    subd    X0          ; D = X1 - X0 (signé)
    std     DX
    bpl     DX_Pos
    coma
    comb
    addd    #1
    std     DX
    lda     #$FF        ; SX = -1
    sta     SX
    bra     DY_Calc
DX_Pos:
    lda     #1
    sta     SX

DY_Calc:
    ; ---- Calcul DY = abs(Y1 - Y0), SY ----
    ldd     Y1
    subd    Y0
    std     DY
    bpl     DY_Pos
    coma
    comb
    addd    #1
    std     DY
    lda     #$FF
    sta     SY
    bra     Dominant
DY_Pos:
    lda     #1
    sta     SY

; 1. Calcul adresse début de ligne : VRAM_BASE + Y*40
    ldd     Y0              ; B = Y (0..199)
    lda     #40
    mul                     ; D = Y * 40
    addd    #VRAM_BASE      ; D = adresse de début de la ligne
    std     TMP             ; TMP = base de la ligne

; 2. Calcul de l'octet de colonne : (X/8) sur 16 bits
    ldd     X0              ; D = X (0..319)
    lsra                    ; décalage 1 bit à droite
    rorb
    lsrb                    ; décalage 2
    lsrb                    ; décalage 3 => D = X / 8 (0..39)
    addd    TMP             ; D = adresse exacte du pixel
    std     ADDR            ; TODO: variable inutile ?

; 3. Construction du masque de bit pour le pixel
    ldd     X0              ; D = X
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
    sta     MASK            ; masque prêt

; ---- Registres DrawLine
; x : X
; y : Y
; u : adresse VRAM
    ldx     X0
    ldy     Y0
    ldu     ADDR

Dominant:
; ---- Comparaison DX vs DY ----
    ldd     DX
    cmpd    DY
    bhs     X_Dom   ; DX >= DY → X dominant

; ----- Y dominant -----
Y_Dom:
    ldb     SX
    bmi     Yd_Xm
    ldb     SY
    lbmi     DrawLine_YmXp    ; Y dominant, Y-, X+
    lbra     DrawLine_YpXp    ; Y dominant, Y+, X+
Yd_Xm:
    ldb     SY
    lbmi     DrawLine_YmXm    ; Y dominant, Y-, X-
    lbra     DrawLine_YpXm    ; Y dominant, Y+, X-

; ----- X dominant -----
X_Dom:
    ldb     SX
    bmi     Xd_Xm
    ldb     SY
    bmi     DrawLine_XpYm    ; X+ dominant, Y-
    bra     DrawLine_XpYp    ; X+ dominant, Y+
Xd_Xm:
    ldb     SY
    lbmi     DrawLine_XmYm    ; X- dominant, Y-
    bra     DrawLine_XmYp    ; X- dominant, Y+

; --- Octant X+ Y+  ---
DrawLine_XpYp:
    lda     MASK
XpYp_Loop:
    ora     ,u
    sta     ,u

    cmpx    X1
    beq    XpYp_EndLine

    ldd     ERR
    subd    DY
    bpl     XpYp_NoIncY_X
    addd    DX
    leau    LINE_BYTES,u
XpYp_NoIncY_X:
    std     ERR

    leax    1,x
    lda     MASK
    lsra
    beq     XpYp_NextByte_X
    sta     MASK
    bra     XpYp_Loop
XpYp_NextByte_X:
    lda     #$80
    sta     MASK
    leau    1,u
    bra     XpYp_Loop
XpYp_EndLine:
    puls    d,x,y,u,pc

; --- Octant X+ Y- ---
DrawLine_XpYm:
    lda     MASK
XpYm_Loop:
    ora     ,u
    sta     ,u

    cmpx    X1
    beq     XpYm_EndLine

    ldd     ERR
    subd    DY
    bpl     XpYm_NoDecY_X
    addd    DX
    leau    -LINE_BYTES,u
XpYm_NoDecY_X:
    std     ERR

    leax    1,x
    lda     MASK
    lsra
    beq     XpYm_NextByte_X
    sta     MASK
    bra     XpYm_Loop
XpYm_NextByte_X:
    lda     #$80
    sta     MASK
    leau    1,u
    bra     XpYm_Loop
XpYm_EndLine:
    puls    d,x,y,u,pc


; --- Octant X- Y+ ---
DrawLine_XmYp:
    lda     MASK
XmYp_Loop:
    ora     ,u
    sta     ,u

    cmpx    X1
    beq     XmYp_EndLine

    ldd     ERR
    subd    DY
    bpl     XmYp_NoIncY_X
    addd    DX
    leau    LINE_BYTES,u
XmYp_NoIncY_X:
    std     ERR

    leax    -1,x
    lda     MASK
    lsla
    beq     XmYp_NextByte_X
    sta     MASK
    bra     XmYp_Loop
XmYp_NextByte_X:
    lda     #$01
    sta     MASK
    leau    -1,u
    bra     XmYp_Loop
XmYp_EndLine:
    puls    d,x,y,u,pc

; --- Octant X- Y- ---
DrawLine_XmYm:
    lda     MASK
XmYm_Loop:
    ora     ,u
    sta     ,u

    cmpx    X1
    beq     XmYm_EndLine

    ldd     ERR
    subd    DY
    bpl     XmYm_NoDecY_X
    addd    DX
    leau    -LINE_BYTES,u
XmYm_NoDecY_X:
    std     ERR

    leax    -1,x
    lda     MASK
    lsla
    beq     XmYm_NextByte_X
    sta     MASK
    bra     XmYm_Loop
XmYm_NextByte_X:
    lda     #$01
    sta     MASK
    leau    -1,u
    bra     XmYm_Loop
XmYm_EndLine:
    puls    d,x,y,u,pc

; --- Octant Y+ X+ (Y dominant, X+) ---
DrawLine_YpXp:
    lda     MASK
YpXp_Loop:
    ora     ,u
    sta     ,u

    cmpy    Y1
    beq     YpXp_EndLine

    ldd     ERR
    subd    DX
    bpl     YpXp_NoIncX_Y
    addd    DY
    std     ERR
    leax    1,x
    lda     MASK
    lsra
    beq     YpXp_NextByte_Y
    sta     MASK
    bra     YpXp_PostIncX
YpXp_NextByte_Y:
    lda     #$80
    sta     MASK
    leau    1,u
    bra     YpXp_PostIncX
YpXp_NoIncX_Y:
    std     ERR
    lda     MASK
YpXp_PostIncX:
    leay    1,y
    leau    LINE_BYTES,u
    bra     YpXp_Loop
YpXp_EndLine:
    puls    d,x,y,u,pc

; --- Octant Y+ X- (Y dominant, X-) ---
DrawLine_YpXm:
    lda     MASK
YpXm_Loop:
    ora     ,u
    sta     ,u

    cmpy    Y1
    beq     YpXm_EndLine

    ldd     ERR
    subd    DX
    bpl     YpXm_NoDecX_Y
    addd    DY
    leax    -1,x
    lda     MASK
    lsla
    beq     YpXm_NextByte_Y
    sta     MASK
    bra     YpXm_PostDecX
YpXm_NextByte_Y:
    lda     #$01
    sta     MASK
    leau    -1,u
YpXm_PostDecX:
YpXm_NoDecX_Y:
    std     ERR

    leay    1,y
    leau    LINE_BYTES,u
    bra     YpXm_Loop
YpXm_EndLine:
    puls    d,x,y,u,pc

; --- Octant Y- X+ (Y dominant, X+) ---
DrawLine_YmXp:
    lda     MASK
YmXp_Loop:
    ora     ,u
    sta     ,u

    cmpy    Y1
    beq     YmXp_EndLine

    ldd     ERR
    subd    DX
    bpl     YmXp_NoIncX_Y
    addd    DY
    leax    1,x
    lda     MASK
    lsra
    beq     YmXp_NextByte_Y
    sta     MASK
    bra     YmXp_PostIncX
YmXp_NextByte_Y:
    lda     #$80
    sta     MASK
    leau    1,u
YmXp_PostIncX:
YmXp_NoIncX_Y:
    std     ERR

    leay    -1,y
    leau    -LINE_BYTES,u
    bra     YmXp_Loop
YmXp_EndLine:
    puls    d,x,y,u,pc

; --- Octant Y- X- (Y dominant, X-) ---
DrawLine_YmXm:
    lda     MASK
YmXm_Loop:
    ora     ,u
    sta     ,u

    cmpy    Y1
    beq     YmXm_EndLine

    ldd     ERR
    subd    DX
    bpl     YmXm_NoDecX_Y
    addd    DY
    leax    -1,x
    lda     MASK
    lsla
    beq     YmXm_NextByte_Y
    sta     MASK
    bra     YmXm_PostDecX
YmXm_NextByte_Y:
    lda     #$01
    sta     MASK
    leau    -1,u
YmXm_PostDecX:
YmXm_NoDecX_Y:
    std     ERR

    leay    -1,y
    leau    -LINE_BYTES,u
    bra     YmXm_Loop
YmXm_EndLine:
    puls    d,x,y,u,pc


; DATA
LINES_COUNT  equ 200
LINES_TABLE:
        ; Format : X0, Y0, X1, Y1 (16 bits big endian, 200 segments)
        FDB 160,100,250,101
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
