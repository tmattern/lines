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
    ldb     Y0+1            ; B = Y (0..199)
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
    ldb     X0+1            ; D = X
    andb    #7              ; A = X MOD 8 (position du pixel dans octet)

    ldx     #MASK_TABLE
    lda     b,x
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
    lbmi    DrawLine_YmXp_8    ; Y dominant, Y-, X+
    lbra    DrawLine_YpXp_8    ; Y dominant, Y+, X+
Yd_Xm:
    ldb     SY
    lbmi    DrawLine_YmXm_8    ; Y dominant, Y-, X-
    lbra    DrawLine_YpXm_8    ; Y dominant, Y+, X-

; ----- X dominant -----
X_Dom:
    ldb     SX
    bmi     Xd_Xm
    ldb     SY
    bmi     DrawLine_XpYm_8    ; X+ dominant, Y-
    bra     DrawLine_XpYp_8    ; X+ dominant, Y+
Xd_Xm:
    ldb     SY
    lbmi    DrawLine_XmYm_8    ; X- dominant, Y-
    lbra    DrawLine_XmYp_8    ; X- dominant, Y+

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

; --------- X+ Y+ (déjà présent) ---------
; DrawLine_XpYp_8
; (cf. ton code existant)

; --------- X+ Y- ---------
DrawLine_XpYm_8:
    lda     DX+1
    inca
    sta     PIX_CPT
    lda     ,u
    ldb     ERR+1
XpYm_Loop_8:
    ora     MASK

    dec     PIX_CPT
    beq     XpYm_EndLine_8

    subb    DY+1
    bpl     XpYm_NoDecY_X_8
    addb    DX+1
    sta     ,u
    leau    -LINE_BYTES,u
    lda     ,u
XpYm_NoDecY_X_8:
    lsr     MASK
    bne     XpYm_Loop_8

    ror     MASK
    sta     ,u
    leau    1,u
    lda     ,u
    bra     XpYm_Loop_8
XpYm_EndLine_8:
    sta     ,u
    puls    d,x,y,u,pc

; --------- X- Y+ ---------
DrawLine_XmYp_8:
    lda     DX+1
    inca
    sta     PIX_CPT
    lda     ,u
    ldb     ERR+1
XmYp_Loop_8:
    ora     MASK

    dec     PIX_CPT
    beq     XmYp_EndLine_8

    subb    DY+1
    bpl     XmYp_NoIncY_X_8
    addb    DX+1
    sta     ,u
    leau    LINE_BYTES,u
    lda     ,u
XmYp_NoIncY_X_8:
    lsl     MASK
    bne     XmYp_Loop_8

    rol     MASK
    sta     ,u
    leau    -1,u
    lda     ,u
    bra     XmYp_Loop_8
XmYp_EndLine_8:
    sta     ,u
    puls    d,x,y,u,pc


; --------- X- Y- ---------
DrawLine_XmYm_8:
    lda     DX+1
    inca
    sta     PIX_CPT
    lda     ,u
    ldb     ERR+1
XmYm_Loop_8:
    ora     MASK

    dec     PIX_CPT
    beq     XmYm_EndLine_8

    subb    DY+1
    bpl     XmYm_NoDecY_X_8
    addb    DX+1
    sta     ,u
    leau    -LINE_BYTES,u
    lda     ,u
XmYm_NoDecY_X_8:
    lsl     MASK
    bne     XmYm_Loop_8

    rol     MASK
    sta     ,u
    leau    -1,u
    lda     ,u
    bra     XmYm_Loop_8
XmYm_EndLine_8:
    sta     ,u
    puls    d,x,y,u,pc

; --------- Y+ X+ ---------
DrawLine_YpXp_8:
    lda     DY+1
    inca
    sta     PIX_CPT
    ldb     ERR+1
    lda     MASK
YpXp_Loop_8:
    ora     ,u
    sta     ,u

    dec     PIX_CPT
    beq     YpXp_EndLine_8

    lda     MASK
    leau    LINE_BYTES,u
    subb    DX+1
    bpl     YpXp_Loop_8

    addb    DY+1
    lsra
    sta     MASK
    bne     YpXp_Loop_8
    lda     #$80
    sta     MASK
    leau    1,u
    bra     YpXp_Loop_8
YpXp_EndLine_8:
    puls    d,x,y,u,pc

; --------- Y+ X- ---------
DrawLine_YpXm_8:
    lda     DY+1
    inca
    sta     PIX_CPT
    ldb     ERR+1
    lda     MASK
YpXm_Loop_8:
    ora     ,u
    sta     ,u

    dec     PIX_CPT
    beq     YpXm_EndLine_8

    lda     MASK
    leau    LINE_BYTES,u
    subb    DX+1
    bpl     YpXm_Loop_8

    addb    DY+1
    lsla
    sta     MASK
    bne     YpXm_Loop_8
    lda     #$01
    sta     MASK
    leau    -1,u
    bra     YpXm_Loop_8
YpXm_EndLine_8:
    puls    d,x,y,u,pc

; --------- Y- X+ ---------
DrawLine_YmXp_8:
    lda     DY+1
    inca
    sta     PIX_CPT
    ldb     ERR+1
    lda     MASK
YmXp_Loop_8:
    ora     ,u
    sta     ,u

    dec     PIX_CPT
    beq     YmXp_EndLine_8

    lda     MASK
    leau    -LINE_BYTES,u
    subb    DX+1
    bpl     YmXp_Loop_8

    addb    DY+1
    lsra
    sta     MASK
    bne     YmXp_Loop_8
    lda     #$80
    sta     MASK
    leau    1,u
    bra     YmXp_Loop_8
YmXp_EndLine_8:
    puls    d,x,y,u,pc

; --------- Y- X- ---------
DrawLine_YmXm_8:
    lda     DY+1
    inca
    sta     PIX_CPT
    ldb     ERR+1
    lda     MASK
YmXm_Loop_8:
    ora     ,u
    sta     ,u

    dec     PIX_CPT
    beq     YmXm_EndLine_8

    lda     MASK
    leau    -LINE_BYTES,u
    subb    DX+1
    bpl     YmXm_Loop_8

    addb    DY+1
    lsla
    sta     MASK
    bne     YmXm_Loop_8
    lda     #$01
    sta     MASK
    leau    -1,u
    bra     YmXm_Loop_8
YmXm_EndLine_8:
    puls    d,x,y,u,pc


; DATA
MASK_TABLE:
        FCB 128,64,32,16,8,4,2,1

