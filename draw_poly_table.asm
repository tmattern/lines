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
PIX_CPT:rmb     1




; --- Boucle de tracé ---

        org     $A000

Start:
        lda     #$61
        tfr     a,dp
        
        ldu     #LINES_TABLE

LoopLines:
        ; Charger X0 (U pointe sur tableau)
        ldd     0,u
        bmi     LoopEnd
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
        bra     LoopLines

LoopEnd:
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
    STD     ,X++
    pshs    d,x,y,u

    ; ---- Calcul DX = abs(X1 - X0), SX, PIX_CPT, ERR ----
    ldd     X1          ; D = X1
    subd    X0          ; D = X1 - X0 (signé)
    std     DX
    bpl     DX_Pos
    coma
    comb
    addd    #1
    std     DX
    lsra
    rorb
    std     ERR
    lda     #$FF        ; SX = -1
    sta     SX
    bra     DY_Calc
DX_Pos:
    lsra
    rorb
    std     ERR
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

Dominant:
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

; ---- Comparaison DX vs DY ----
    ldd     DX
    cmpd    DY
    bhs     X_Dom   ; DX >= DY → X dominant

; ----- Y dominant -----
Y_Dom:
    ldb     SX
    bmi     Yd_Xm
    ldb     SY
    lbmi    DrawLine_YmXp    ; Y dominant, Y-, X+
    lbra    DrawLine_YpXp    ; Y dominant, Y+, X+
Yd_Xm:
    ldb     SY
    lbmi    DrawLine_YmXm    ; Y dominant, Y-, X-
    lbra    DrawLine_YpXm    ; Y dominant, Y+, X-

; ----- X dominant -----
X_Dom:
    ldb     SX
    bmi     Xd_Xm
    ldb     SY
    bmi     DrawLine_XpYm    ; X+ dominant, Y-
    bra     DrawLine_XpYp_8    ; X+ dominant, Y+
Xd_Xm:
    ldb     SY
    lbmi    DrawLine_XmYm    ; X- dominant, Y-
    lbra    DrawLine_XmYp    ; X- dominant, Y+

; --- Octant X+ Y+  ---
DrawLine_XpYp_8:
    lda     DX+1
    inca
    sta     PIX_CPT
    lda     ,u
    ldb     ERR+1
XpYp_Loop_8:
    ora     MASK

    dec     PIX_CPT
    beq     XpYp_EndLine_8

    subb    DY+1
    bpl     XpYp_NoIncY_X_8
    addb    DX+1
    sta     ,u
    leau    LINE_BYTES,u
    lda     ,u
XpYp_NoIncY_X_8:
    lsr     MASK
    beq     XpYp_NextByte_X_8
    bra     XpYp_Loop_8
XpYp_NextByte_X_8:
    ror     MASK
    sta     ,u
    leau    1,u
    lda     ,u
    bra     XpYp_Loop_8
XpYp_EndLine_8:
    sta     ,u
    puls    d,x,y,u,pc

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
    std     ERR
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
    bra     YpXm_PostDecX
YpXm_NoDecX_Y:
    std     ERR
    lda     MASK
YpXm_PostDecX:
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
    std     ERR

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
    bra     YmXp_PostIncX
YmXp_NoIncX_Y:
    std     ERR
    lda     MASK
YmXp_PostIncX:
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
    std     ERR
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
    bra     YmXm_PostDecX
YmXm_NoDecX_Y:
    std     ERR
    lda     MASK
YmXm_PostDecX:
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
TEST    FDB 160,100,51,97
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
; Fin de table
        FDB $FFFF,$FFFF,$FFFF,$FFFF

; Voiture de course centrée, segments 16 bits, format FDB x0,y0,x1,y1
CAR_LINES:
; Voiture de course stylisée - segments 16 bits centrés, résolution 320x200
; Format FDB x0,y0,x1,y1
        FDB $0096,$0018,$0094,$001A
        FDB $0094,$001A,$0092,$001C
        FDB $0092,$001C,$0090,$001E
        FDB $0090,$001E,$008E,$0020
        FDB $008E,$0020,$008C,$0022
        FDB $008C,$0022,$008A,$0025
        FDB $008A,$0025,$0088,$0028
        FDB $0088,$0028,$0087,$002B
        FDB $0087,$002B,$0086,$002E
        FDB $0086,$002E,$0085,$0031
        FDB $0085,$0031,$0085,$0034
        FDB $0085,$0034,$0085,$0037
        FDB $0085,$0037,$0086,$003A
        FDB $0086,$003A,$0087,$003D
        FDB $0087,$003D,$0088,$0040
        FDB $0088,$0040,$008A,$0043
        FDB $008A,$0043,$008C,$0046
        FDB $008C,$0046,$008F,$0049
        FDB $008F,$0049,$0092,$004C
        FDB $0092,$004C,$0096,$004F
        FDB $0096,$004F,$009A,$0052
        FDB $009A,$0052,$009F,$0055
        FDB $009F,$0055,$00A4,$0058
        FDB $00A4,$0058,$00A9,$005B
        FDB $00A9,$005B,$00AE,$005E
        FDB $00AE,$005E,$00B2,$0061
        FDB $00B2,$0061,$00B6,$0064
        FDB $00B6,$0064,$00B9,$0067
        FDB $00B9,$0067,$00BC,$006A
        FDB $00BC,$006A,$00BE,$006D
        FDB $00BE,$006D,$00C0,$0070
        FDB $00C0,$0070,$00C1,$0073
        FDB $00C1,$0073,$00C2,$0076
        FDB $00C2,$0076,$00C3,$0079
        FDB $00C3,$0079,$00C3,$007C
        FDB $00C3,$007C,$00C2,$007F
        FDB $00C2,$007F,$00C1,$0082
        FDB $00C1,$0082,$00C0,$0085
        FDB $00C0,$0085,$00BE,$0088
        FDB $00BE,$0088,$00BC,$008B
        FDB $00BC,$008B,$00B9,$008E
        FDB $00B9,$008E,$00B6,$0091
        FDB $00B6,$0091,$00B2,$0094
        FDB $00B2,$0094,$00AE,$0097
        FDB $00AE,$0097,$00A9,$009A
        FDB $00A9,$009A,$00A4,$009D
        FDB $00A4,$009D,$009F,$00A0
        FDB $009F,$00A0,$009A,$00A3
        FDB $009A,$00A3,$0096,$00A6
        FDB $0096,$00A6,$0092,$00A9
        FDB $0092,$00A9,$008F,$00AC
        FDB $008F,$00AC,$008C,$00AF
        FDB $008C,$00AF,$008A,$00B2
        FDB $008A,$00B2,$0088,$00B5
        FDB $0088,$00B5,$0087,$00B8
        FDB $0087,$00B8,$0086,$00BB
        FDB $0086,$00BB,$0085,$00BE
        FDB $0085,$00BE,$0085,$00C1
        FDB $0085,$00C1,$0085,$00C4
        FDB $0085,$00C4,$0086,$00C7
        FDB $0086,$00C7,$0087,$00CA
        FDB $0087,$00CA,$0088,$00CD
        FDB $0088,$00CD,$008A,$00D0
        FDB $008A,$00D0,$008C,$00D3
        FDB $008C,$00D3,$008E,$00D6
        FDB $008E,$00D6,$0090,$00D8
        FDB $0090,$00D8,$0092,$00DA
        FDB $0092,$00DA,$0094,$00DC
        FDB $0094,$00DC,$0096,$00DE
        FDB $0096,$00DE,$0099,$00E0
        FDB $0099,$00E0,$009C,$00E2
        FDB $009C,$00E2,$009F,$00E4
        FDB $009F,$00E4,$00A2,$00E6
        FDB $00A2,$00E6,$00A5,$00E8
        FDB $00A5,$00E8,$00A8,$00EA
        FDB $00A8,$00EA,$00AB,$00EC
        FDB $00AB,$00EC,$00AE,$00EE
        FDB $00AE,$00EE,$00B1,$00F0
        FDB $00B1,$00F0,$00B4,$00F2
        FDB $00B4,$00F2,$00B7,$00F4
        FDB $00B7,$00F4,$00BA,$00F6
        FDB $00BA,$00F6,$00BD,$00F8
        FDB $00BD,$00F8,$00C0,$00FA
        FDB $00C0,$00FA,$00C2,$00FC
        FDB $00C2,$00FC,$00C4,$00FE
        FDB $00C4,$00FE,$00C6,$0100
        FDB $00C6,$0100,$00C8,$0102
        FDB $00C8,$0102,$00C9,$0104
        FDB $00C9,$0104,$00CA,$0106
        FDB $00CA,$0106,$00CB,$0108
        FDB $00CB,$0108,$00CB,$010A
        FDB $00CB,$010A,$00CB,$010C
        FDB $00CB,$010C,$00CA,$010E
        FDB $00CA,$010E,$00C9,$0110
        FDB $00C9,$0110,$00C8,$0112
        FDB $00C8,$0112,$00C6,$0114
        FDB $00C6,$0114,$00C4,$0116
        FDB $00C4,$0116,$00C2,$0118
        FDB $00C2,$0118,$00C0,$011A
        FDB $00C0,$011A,$00BD,$011C
        FDB $00BD,$011C,$00BA,$011E
        FDB $00BA,$011E,$00B7,$0120
        FDB $00B7,$0120,$00B4,$0122
        FDB $00B4,$0122,$00B1,$0124
        FDB $00B1,$0124,$00AE,$0126
        FDB $00AE,$0126,$00AB,$0128
        FDB $00AB,$0128,$00A8,$012A
        FDB $00A8,$012A,$00A5,$012C
        FDB $00A5,$012C,$00A2,$012E
        FDB $00A2,$012E,$009F,$0130
        FDB $009F,$0130,$009C,$0132
        FDB $009C,$0132,$0099,$0134
        FDB $0099,$0134,$0096,$0136
        FDB $0096,$0136,$0094,$0138
        FDB $0094,$0138,$0092,$013A
        FDB $0092,$013A,$0090,$013C
        FDB $0090,$013C,$008E,$013E
        FDB $008E,$013E,$008C,$0140
        FDB $008C,$0140,$008A,$0143
        FDB $008A,$0143,$0088,$0146
        FDB $0088,$0146,$0087,$0149
        FDB $0087,$0149,$0086,$014C
        FDB $0086,$014C,$0085,$014F
        FDB $0085,$014F,$0085,$0152
        FDB $0085,$0152,$0085,$0155
        FDB $0085,$0155,$0086,$0158
        FDB $0086,$0158,$0087,$015B
        FDB $0087,$015B,$0088,$015E
        FDB $0088,$015E,$008A,$0161
        FDB $008A,$0161,$008C,$0164
        FDB $008C,$0164,$008E,$0167
        FDB $008E,$0167,$0090,$0169
        FDB $0090,$0169,$0092,$016B
        FDB $0092,$016B,$0094,$016D
        FDB $0094,$016D,$0096,$016F
        FDB $0096,$016F,$0099,$0171
        FDB $0099,$0171,$009C,$0173
        FDB $009C,$0173,$009F,$0175
        FDB $009F,$0175,$00A2,$0177
        FDB $00A2,$0177,$00A5,$0179
        FDB $00A5,$0179,$00A8,$017B
        FDB $00A8,$017B,$00AB,$017D
        FDB $00AB,$017D,$00AE,$017F
        FDB $00AE,$017F,$00B1,$0181
        FDB $00B1,$0181,$00B4,$0183
        FDB $00B4,$0183,$00B7,$0185
        FDB $00B7,$0185,$00BA,$0187
        FDB $00BA,$0187,$00BD,$0189
        FDB $00BD,$0189,$00C0,$018B
        FDB $00C0,$018B,$00C2,$018D
        FDB $00C2,$018D,$00C4,$018F
        FDB $00C4,$018F,$00C6,$0191
        FDB $00C6,$0191,$00C8,$0193
        FDB $00C8,$0193,$00C9,$0195
        FDB $00C9,$0195,$00CA,$0197
        FDB $00CA,$0197,$00CB,$0199
        FDB $00CB,$0199,$00CB,$019B
        FDB $00CB,$019B,$00CB,$019D
        FDB $00CB,$019D,$00CA,$019F
        FDB $00CA,$019F,$00C9,$01A1
        FDB $00C9,$01A1,$00C8,$01A3
        FDB $00C8,$01A3,$00C6,$01A5
        FDB $00C6,$01A5,$00C4,$01A7
        FDB $00C4,$01A7,$00C2,$01A9
        FDB $00C2,$01A9,$00C0,$01AB
        FDB $00C0,$01AB,$00BD,$01AD
        FDB $00BD,$01AD,$00BA,$01AF
        FDB $00BA,$01AF,$00B7,$01B1
        FDB $00B7,$01B1,$00B4,$01B3
        FDB $00B4,$01B3,$00B1,$01B5
        FDB $00B1,$01B5,$00AE,$01B7
        FDB $00AE,$01B7,$00AB,$01B9
        FDB $00AB,$01B9,$00A8,$01BB
        FDB $00A8,$01BB,$00A5,$01BD
        FDB $00A5,$01BD,$00A2,$01BF
        FDB $00A2,$01BF,$009F,$01C1
        FDB $009F,$01C1,$009C,$01C3
        FDB $009C,$01C3,$0099,$01C5
        FDB $0099,$01C5,$0096,$01C7
        FDB $0096,$01C7,$0094,$01C9
        FDB $0094,$01C9,$0092,$01CB
        FDB $0092,$01CB,$0090,$01CD
        FDB $0090,$01CD,$008E,$01CF
        FDB $008E,$01CF,$008C,$01D2
        FDB $008C,$01D2,$008A,$01D5
        FDB $008A,$01D5,$0088,$01D8
        FDB $0088,$01D8,$0087,$01DB
        FDB $0087,$01DB,$0086,$01DE
        FDB $0086,$01DE,$0085,$01E1
        FDB $0085,$01E1,$0085,$01E4
        FDB $0085,$01E4,$0085,$01E7
        FDB $0085,$01E7,$0086,$01EA
        FDB $0086,$01EA,$0087,$01ED
        FDB $0087,$01ED,$0088,$01F0
        FDB $0088,$01F0,$008A,$01F3
        FDB $008A,$01F3,$008C,$01F6
        FDB $008C,$01F6,$008F,$01F9
        FDB $008F,$01F9,$0092,$01FC
        FDB $0092,$01FC,$0096,$01FF
        FDB $0096,$01FF,$009A,$0202
        FDB $009A,$0202,$009F,$0205
        FDB $009F,$0205,$00A4,$0208
        FDB $00A4,$0208,$00A9,$020B
        FDB $00A9,$020B,$00AE,$020E
        FDB $00AE,$020E,$00B2,$0211
        FDB $00B2,$0211,$00B6,$0214
        FDB $00B6,$0214,$00B9,$0217
        FDB $00B9,$0217,$00BC,$021A
        FDB $00BC,$021A,$00BE,$021D
        FDB $00BE,$021D,$00C0,$0220
        FDB $00C0,$0220,$00C1,$0223
        FDB $00C1,$0223,$00C2,$0226
        FDB $00C2,$0226,$00C3,$0229
        FDB $00C3,$0229,$00C3,$022C
        FDB $00C3,$022C,$00C2,$022F
        FDB $00C2,$022F,$00C1,$0232
        FDB $00C1,$0232,$00C0,$0235
        FDB $00C0,$0235,$00BE,$0238
        FDB $00BE,$0238,$00BC,$023B
        FDB $00BC,$023B,$00B9,$023E
        FDB $00B9,$023E,$00B6,$0241
        FDB $00B6,$0241,$00B2,$0244
        FDB $00B2,$0244,$00AE,$0247
        FDB $00AE,$0247,$00A9,$024A
        FDB $00A9,$024A,$00A4,$024D
        FDB $00A4,$024D,$009F,$0250
        FDB $009F,$0250,$009A,$0253
        FDB $009A,$0253,$0096,$0256
        FDB $0096,$0256,$0092,$0259
        FDB $0092,$0259,$008F,$025C
        FDB $008F,$025C,$008C,$025F
        FDB $008C,$025F,$008A,$0262
        FDB $008A,$0262,$0088,$0265
        FDB $0088,$0265,$0087,$0268
        FDB $0087,$0268,$0086,$026B
        FDB $0086,$026B,$0085,$026E
        FDB $0085,$026E,$0085,$0271
        FDB $0085,$0271,$0085,$0274
        FDB $0085,$0274,$0086,$0277
        FDB $0086,$0277,$0087,$027A
        FDB $0087,$027A,$0088,$027D
        FDB $0088,$027D,$008A,$0280
        FDB $008A,$0280,$008C,$0283
        FDB $008C,$0283,$008E,$0286
        FDB $008E,$0286,$0090,$0288
        FDB $0090,$0288,$0092,$028A
        FDB $0092,$028A,$0094,$028C
        FDB $0094,$028C,$0096,$028E
        FDB $0096,$028E,$0099,$0290
        FDB $0099,$0290,$009C,$0292
        FDB $009C,$0292,$009F,$0294
        FDB $009F,$0294,$00A2,$0296
        FDB $00A2,$0296,$00A5,$0298
        FDB $00A5,$0298,$00A8,$029A
        FDB $00A8,$029A,$00AB,$029C
        FDB $00AB,$029C,$00AE,$029E
        FDB $00AE,$029E,$00B1,$02A0
        FDB $00B1,$02A0,$00B4,$02A2
        FDB $00B4,$02A2,$00B7,$02A4
        FDB $00B7,$02A4,$00BA,$02A6
        FDB $00BA,$02A6,$00BD,$02A8
        FDB $00BD,$02A8,$00C0,$02AA
        FDB $00C0,$02AA,$00C2,$02AC
        FDB $00C2,$02AC,$00C4,$02AE
        FDB $00C4,$02AE,$00C6,$02B0
        FDB $00C6,$02B0,$00C8,$02B2
        FDB $00C8,$02B2,$00C9,$02B4
        FDB $00C9,$02B4,$00CA,$02B6
        FDB $00CA,$02B6,$00CB,$02B8
        FDB $00CB,$02B8,$00CB,$02BA
        FDB $00CB,$02BA,$00CB,$02BC
        FDB $00CB,$02BC,$00CA,$02BE
        FDB $00CA,$02BE,$00C9,$02C0
        FDB $00C9,$02C0,$00C8,$02C2
        FDB $00C8,$02C2,$00C6,$02C4
        FDB $00C6,$02C4,$00C4,$02C6
        FDB $00C4,$02C6,$00C2,$02C8
        FDB $00C2,$02C8,$00C0,$02CA
        FDB $00C0,$02CA,$00BD,$02CC
        FDB $00BD,$02CC,$00BA,$02CE
        FDB $00BA,$02CE,$00B7,$02D0
        FDB $00B7,$02D0,$00B4,$02D2
        FDB $00B4,$02D2,$00B1,$02D4
        FDB $00B1,$02D4,$00AE,$02D6
        FDB $00AE,$02D6,$00AB,$02D8
        FDB $00AB,$02D8,$00A8,$02DA
        FDB $00A8,$02DA,$00A5,$02DC
        FDB $00A5,$02DC,$00A2,$02DE
        FDB $00A2,$02DE,$009F,$02E0
        FDB $009F,$02E0,$009C,$02E2
        FDB $009C,$02E2,$0099,$02E4
        FDB $0099,$02E4,$0096,$02E6
        FDB $0096,$02E6,$0094,$02E8
        FDB $0094,$02E8,$0092,$02EA
        FDB $0092,$02EA,$0090,$02EC
        FDB $0090,$02EC,$008E,$02EF
        FDB $008E,$02EF,$008C,$02F2
        FDB $008C,$02F2,$008A,$02F5
        FDB $008A,$02F5,$0088,$02F8
        FDB $0088,$02F8,$0087,$02FB
        FDB $0087,$02FB,$0086,$02FE
        FDB $0086,$02FE,$0085,$0301
        FDB $0085,$0301,$0085,$0304
        FDB $0085,$0304,$0085,$0307
        FDB $0085,$0307,$0086,$030A
        FDB $0086,$030A,$0087,$030D
        FDB $0087,$030D,$0088,$0310
        FDB $0088,$0310,$008A,$0313
        FDB $008A,$0313,$008C,$0316
        FDB $008C,$0316,$008F,$0319
        FDB $008F,$0319,$0092,$031C
        FDB $0092,$031C,$0096,$031F
        FDB $0096,$031F,$0099,$0322
        FDB $0099,$0322,$009C,$0325
        FDB $009C,$0325,$009F,$0328
        FDB $009F,$0328,$00A2,$032B
        FDB $00A2,$032B,$00A5,$032E
        FDB $00A5,$032E,$00A8,$0331
        FDB $00A8,$0331,$00AB,$0334
        FDB $00AB,$0334,$00AE,$0337
        FDB $00AE,$0337,$00B1,$033A
        FDB $00B1,$033A,$00B4,$033D
        FDB $00B4,$033D,$00B7,$0340
        FDB $00B7,$0340,$00BA,$0343
        FDB $00BA,$0343,$00BD,$0346
        FDB $00BD,$0346,$00C0,$0349
        FDB $00C0,$0349,$00C2,$034C
        FDB $00C2,$034C,$00C4,$034F
        FDB $00C4,$034F,$00C6,$0352
        FDB $00C6,$0352,$00C8,$0355
        FDB $00C8,$0355,$00C9,$0358
        FDB $00C9,$0358,$00CA,$035B
        FDB $00CA,$035B,$00CB,$035E
        FDB $00CB,$035E,$00CB,$0361
        FDB $00CB,$0361,$00CB,$0364
        FDB $00CB,$0364,$0096,$0018
        FDB $FFFF,$FFFF,$FFFF,$FFFF