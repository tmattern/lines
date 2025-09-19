;==============================================================================
; Effacement complet de l'écran graphique 320x200, 1bpp, VRAM $4000-$5F3F
; Utilise : X, A uniquement
;==============================================================================

ClearScreen_v1:
    pshs  a,x,u
    ldx   #$4000         ; Début VRAM
    ldu   #0             ; U = 0 (valeur à écrire)
    lda   #200           ; A = 200 lignes
CS_Loop:
    stu   0,x
    stu   2,x
    stu   4,x
    stu   6,x
    stu   8,x
    stu   10,x
    stu   12,x
    stu   14,x
    stu   16,x
    stu   18,x
    stu   20,x
    stu   22,x
    stu   24,x
    stu   26,x
    stu   28,x
    stu   30,x
    stu   32,x
    stu   34,x
    stu   36,x
    stu   38,x
    deca
    bne   CS_Loop
    puls  a,x,u,pc

ClearScreen_v2:
    pshs  a,b,x,y,u,cc,dp
    clrd
    ldx   #0
    ldy   #0
    tfr   a,dp
    andcc #0
    ldu   #$5F40
    
CS_Loop_v2:
    ; ligne 1
    pshu  a,b,x,y,cc,dp
    pshu  a,b,x,y,cc,dp
    pshu  a,b,x,y,cc,dp
    pshu  a,b,x,y,cc,dp
    pshu  a,b,x,y,cc,dp

    ; ligne 2
    pshu  a,b,x,y,cc,dp
    pshu  a,b,x,y,cc,dp
    pshu  a,b,x,y,cc,dp
    pshu  a,b,x,y,cc,dp
    pshu  a,b,x,y,cc,dp

    ; ligne 3
    pshu  a,b,x,y,cc,dp
    pshu  a,b,x,y,cc,dp
    pshu  a,b,x,y,cc,dp
    pshu  a,b,x,y,cc,dp
    pshu  a,b,x,y,cc,dp

    ; ligne 4
    pshu  a,b,x,y,cc,dp
    pshu  a,b,x,y,cc,dp
    pshu  a,b,x,y,cc,dp
    pshu  a,b,x,y,cc,dp
    pshu  a,b,x,y,cc,dp

    ; ligne 5
    pshu  a,b,x,y,cc,dp
    pshu  a,b,x,y,cc,dp
    pshu  a,b,x,y,cc,dp
    pshu  a,b,x,y,cc,dp
    pshu  a,b,x,y,cc,dp

    cmpu  #$4000
    bne   CS_Loop_v2
    puls  a,b,x,y,u,cc,dp,pc


;==============================================================================
; Effacement d'une zone centrée de 192x120 pixels (24 octets x 120 lignes)
; Centre horizontal = 8 octets (64px) depuis la gauche, vertical = 40 lignes
; Utilise : X, Y, B, A, TMP (RAM)
;==============================================================================

ClearZone_Centered:
    ldy   #120           ; 120 lignes à effacer
CZ_Ligne:
    ldb   #40            ; 40 octets/ligne
    sty   TMP            ; Sauvegarde Y (compteur lignes)
    ldy   TMP            ; Y = ligne courante (0..119)
    mul                  ; D = Y * 40
    addd  #$4008         ; +8 pour centrer (8 octets = 64px)
    tfr   d,x            ; X = début de la zone à effacer

    ldb   #24            ; 24 octets = 192px
    clra                 ; A = 0 à écrire
CZ_Zone:
    sta   ,x+
    decb
    bne   CZ_Zone

    ldy   TMP            ; Restaure Y
    leay  -1,y
    cmpy  #0
    bne   CZ_Ligne
    rts

TMP   rmb 2              ; Variable temporaire pour la ligne (2 octets)