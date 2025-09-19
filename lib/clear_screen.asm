;==============================================================================
; Effacement complet de l'écran graphique 320x200, 1bpp, VRAM $4000-$5F3F
; Utilise : X, A uniquement
;==============================================================================


ClearScreen:
    pshs  a,b,x,y,u,cc,dp
    clrd
    ldx   #0
    ldy   #0
    tfr   a,dp
    andcc #0
    ldu   #$5F40
    
CS_Loop:
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
    bne   CS_Loop
    puls  a,b,x,y,u,cc,dp,pc


;==============================================================================
; Effacement d'une zone centrée de 192x120 pixels (24 octets x 120 lignes)
; Centre horizontal = 8 octets (64px) depuis la gauche, vertical = 40 lignes
; Utilise : X, Y, B, A, TMP (RAM)
; Marge haut    $4000   $49E7
; Zone centrée  $4A08   $5EDF
; Marge bas     $5F00   $5FA7
;==============================================================================

ClearZone_Centered:
    pshs  a,b,x,y,u,cc,dp
    clrd
    ldx   #0
    ldy   #0
    tfr   a,dp
    andcc #0
    ldu   #$5EE0
    
CS_Loop_Centered:
    ; ligne 1
    pshu  a,b,x,y,cc,dp
    pshu  a,b,x,y,cc,dp
    pshu  a,b,x,y,cc,dp
    leau  -16,u

    ; ligne 2
    pshu  a,b,x,y,cc,dp
    pshu  a,b,x,y,cc,dp
    pshu  a,b,x,y,cc,dp
    leau  -16,u

    ; ligne 3
    pshu  a,b,x,y,cc,dp
    pshu  a,b,x,y,cc,dp
    pshu  a,b,x,y,cc,dp
    leau  -16,u

    ; ligne 4
    pshu  a,b,x,y,cc,dp
    pshu  a,b,x,y,cc,dp
    pshu  a,b,x,y,cc,dp
    leau  -16,u

    ; ligne 5
    pshu  a,b,x,y,cc,dp
    pshu  a,b,x,y,cc,dp
    pshu  a,b,x,y,cc,dp

    cmpu  #$4A08
    leau  -16,u
    bne   CS_Loop_Centered
    puls  a,b,x,y,u,cc,dp,pc
