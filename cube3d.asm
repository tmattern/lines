; ========== CONSTANTES ECRAN ==========
SCREEN_CX   equ 160         ; milieu X écran (320/2)
SCREEN_CY   equ 100         ; milieu Y écran (200/2)
FOCAL       equ 160         ; focale pour perspective (ajustable)
Z_OFFSET    equ 160         ; décalage Z pour éviter z=0

; ========== TABLE DES SOMMETS DU CUBE ========== 
; 8 sommets (x, y, z) signés sur 8 bits
CubeVertices:
    fcb  -32, -32, -32   ; 0
    fcb   32, -32, -32   ; 1
    fcb   32,  32, -32   ; 2
    fcb  -32,  32, -32   ; 3
    fcb  -32, -32,  32   ; 4
    fcb   32, -32,  32   ; 5
    fcb   32,  32,  32   ; 6
    fcb  -32,  32,  32   ; 7

; ========== TABLE DES ARETES ==========
; Paires d'indices de sommets (0..7)
CubeEdges:
    fcb 0,1, 1,2, 2,3, 3,0   ; face avant
    fcb 4,5, 5,6, 6,7, 7,4   ; face arrière
    fcb 0,4, 1,5, 2,6, 3,7   ; liaisons
    fcb $FF                  ; fin

; ========== TABLES SINUS/COSINUS ==========
; Table sinus/cosinus sur 256 valeurs (0..255, un tour)
; Format signé, Q7 : -128..+127 <=> -1.0..+0.992
SinTable:    ; ... à générer en Python ou à la main pour 256 valeurs
    fcb 0,3,6,9,13,16,19,22,25,28,31,34,37,40,43,46
    fcb 49,52,55,58,61,64,67,70,73,75,78,81,83,86,88,91
    ; ... compléter jusqu'à 256 éléments ...

; Pour cosinus, c'est SinTable + 64 (décalé d’1/4 de tour)
    
; ========== ZONE TRAVAIL ==========
RotatedVertices:   rmb 24     ; 8 sommets × 3 octets
ProjectedPoints:   rmb 16     ; 8 sommets × 2 octets (x,y écran)

; ========== ANGLES DE ROTATION ==========
AngleX:    fcb 0
AngleY:    fcb 0
AngleZ:    fcb 0

; ========== BOUCLE PRINCIPALE ==========
CubeLoop:
    jsr RotateCube
    jsr ProjectCube
    jsr DrawCube
    ; Incrémente les angles pour l’animation
    inc  AngleX
    inc  AngleY
    inc  AngleZ
    ; Attente/rafraichissement écran ici
    bra  CubeLoop

; ========== ROUTINE DE ROTATION ==========
; Entrée : CubeVertices, AngleX/Y/Z
; Sortie : RotatedVertices (x', y', z')
RotateCube:
    ldb  #8
    ldx  #CubeVertices
    ldy  #RotatedVertices

RotLoop:
    lda  ,x+           ; x
    sta  tmp_x
    lda  ,x+           ; y
    sta  tmp_y
    lda  ,x+           ; z
    sta  tmp_z

    ; ---- Rotation autour X ----
    lda  tmp_y
    ldb  AngleX
    addb #64           ; cos = sin(angle+64)
    andb #$FF
    ldu  #SinTable
    ldb  b,u           ; cosX en B
    jsr  mul_q7        ; A = tmp_y * cosX / 128
    sta  tmp_t1        ; t1 = y*cosX

    lda  tmp_z
    ldb  AngleX
    andb #$FF
    ldu  #SinTable
    ldb  b,u           ; sinX en B
    jsr  mul_q7        ; A = tmp_z * sinX / 128
    sta  tmp_t2        ; t2 = z*sinX

    lda  tmp_t1
    suba tmp_t2
    sta  tmp_yx        ; y' = y*cosX - z*sinX

    lda  tmp_y
    ldb  AngleX
    andb #$FF
    ldu  #SinTable
    ldb  b,u           ; sinX en B
    jsr  mul_q7
    sta  tmp_t3        ; y*sinX

    lda  tmp_z
    ldb  AngleX
    addb #64
    andb #$FF
    ldu  #SinTable
    ldb  b,u           ; cosX en B
    jsr  mul_q7
    sta  tmp_t4        ; z*cosX

    lda  tmp_t3
    adda tmp_t4
    sta  tmp_zx        ; z' = y*sinX + z*cosX

    ; ---- Rotation autour Y ----
    lda  tmp_x
    ldb  AngleY
    addb #64
    andb #$FF
    ldu  #SinTable
    ldb  b,u
    jsr  mul_q7
    sta  tmp_t5        ; x*cosY

    lda  tmp_zx
    ldb  AngleY
    andb #$FF
    ldu  #SinTable
    ldb  b,u
    jsr  mul_q7
    sta  tmp_t6        ; z'*sinY

    lda  tmp_t5
    adda tmp_t6
    sta  tmp_xy        ; x' = x*cosY + z'*sinY

    lda  tmp_zx
    ldb  AngleY
    addb #64
    andb #$FF
    ldu  #SinTable
    ldb  b,u
    jsr  mul_q7
    sta  tmp_t7        ; z'*cosY

    lda  tmp_x
    ldb  AngleY
    andb #$FF
    ldu  #SinTable
    ldb  b,u
    jsr  mul_q7
    sta  tmp_t8        ; x*sinY

    lda  tmp_t7
    suba tmp_t8
    sta  tmp_zy        ; z'' = z'*cosY - x*sinY

    ; ---- Rotation autour Z ----
    lda  tmp_xy
    ldb  AngleZ
    addb #64
    andb #$FF
    ldu  #SinTable
    ldb  b,u
    jsr  mul_q7
    sta  tmp_t9        ; x'*cosZ

    lda  tmp_yx
    ldb  AngleZ
    andb #$FF
    ldu  #SinTable
    ldb  b,u
    jsr  mul_q7
    sta  tmp_t10       ; y'*sinZ

    lda  tmp_t9
    suba tmp_t10
    sta  ,y+           ; x final

    lda  tmp_xy
    ldb  AngleZ
    andb #$FF
    ldu  #SinTable
    ldb  b,u
    jsr  mul_q7
    sta  tmp_t11       ; x'*sinZ

    lda  tmp_yx
    ldb  AngleZ
    addb #64
    andb #$FF
    ldu  #SinTable
    ldb  b,u
    jsr  mul_q7
    sta  tmp_t12       ; y'*cosZ

    lda  tmp_t11
    adda tmp_t12
    sta  ,y+           ; y final

    lda  tmp_zy
    sta  ,y+           ; z final

    decb
    bne  RotLoop
    rts

; ========== MULTIPLICATION Q7 ==========
; Entrée : A=valeur, B=coeff -128..+127 (Q7)
; Sortie : A = (A*B)/128
mul_q7:
    pshs d
    mul
    ; résultat 16 bits, A=msb, B=lsb
    ; décalage de 7 -> on prend (A << 1) | (B >> 7)
    aslb
    rol  a
    puls d,pc

; ========== PROJECTION PERSPECTIVE ==========
; Utilise : x2d = (x * FOCAL) / (z + Z_OFFSET) + SCREEN_CX
;           y2d = (y * FOCAL) / (z + Z_OFFSET) + SCREEN_CY
; Division par 256 : on prend le MSB
ProjectCube:
    ldb  #8
    ldx  #RotatedVertices
    ldy  #ProjectedPoints

ProjLoop:
    lda  2,x           ; z
    adda #Z_OFFSET
    ; protection contre z trop petit (évite division par zéro)
    cmpa #16
    bhs  .okz
    lda #16
.okz
    sta  tmp_zp

    ; X écran
    lda  ,x            ; x
    ldb  #FOCAL
    mul                ; D = x * FOCAL
    ldb  tmp_zp
    jsr  div256        ; D / z'
    adda #SCREEN_CX
    sta  ,y+           ; X écran

    ; Y écran
    lda  1,x           ; y
    ldb  #FOCAL
    mul
    ldb  tmp_zp
    jsr  div256
    adda #SCREEN_CY
    sta  ,y+           ; Y écran

    leax 3,x
    decb
    bne  ProjLoop
    rts

; ========== DIVISION 16/8 PAR 256 ==========
; Entrée : D (résultat du MUL), B = diviseur (z+offset)
; Sortie : A = (D/B)
div256:
    pshs x
    clra
    ldx  #0
div256_lp:
    cmpb #0
    beq  div256_end
    subd 1,x
    bcc  div256_ok
    addd 1,x
    bra  div256_next
div256_ok:
    inca
    subb #1
div256_next:
    cmpb #0
    bne  div256_lp
div256_end:
    puls x,pc

; ========== TRACÉ DES SEGMENTS ==========
; Utilise la table CubeEdges et ProjectedPoints
DrawCube:
    ldx #CubeEdges
EdgeLoop:
    lda ,x+
    cmpa #$FF
    beq  DrawEnd
    ldb ,x+
    ldy #ProjectedPoints
    ldu #ProjectedPoints
    ldd a,y
    std x0y0
    ldd b,u
    std x1y1
    jsr DrawLine     ; à écrire : routine Bresenham 2D entre x0y0 et x1y1
    bra EdgeLoop
DrawEnd:
    rts

; ========== VARIABLES TEMPORAIRES ==========
tmp_x:     rmb 1
tmp_y:     rmb 1
tmp_z:     rmb 1
tmp_t1:    rmb 1
tmp_t2:    rmb 1
tmp_t3:    rmb 1
tmp_t4:    rmb 1
tmp_t5:    rmb 1
tmp_t6:    rmb 1
tmp_t7:    rmb 1
tmp_t8:    rmb 1
tmp_t9:    rmb 1
tmp_t10:   rmb 1
tmp_t11:   rmb 1
tmp_t12:   rmb 1
tmp_yx:    rmb 1
tmp_zx:    rmb 1
tmp_xy:    rmb 1
tmp_zy:    rmb 1
tmp_zp:    rmb 1
x0y0:      rmb 2
x1y1:      rmb 2

; ========== ROUTINE DE TRAÇAGE DE SEGMENT ==========
; Entrée : x0y0, x1y1 (2 octets chacun, X et Y écran)
; À compléter selon ton affichage (Bresenham...)

DrawLine:
    ; ... à compléter selon ton architecture écran ...
    rts