; === Variables en page directe ===


InitScreen:
    pshs  a
    ; Map video RAM to $0000
    LDA  #%01100000  ; D7=0, D6=1 (écriture), D5=1 (RAM active), D4-D0=00000 (page 0)
    STA  $E7E6       ; Mappe la page 0 en $0000

    ; Configuration Gate Array
    LDA  #%00000000  ; Couleur tour ecran
    STA  $E7DD       ; Registre systeme 2

    puls a,pc


; === Routine d'attente VBL + switch buffer ===

WaitVBLAndSwitchBuffer:
    pshs  a
    ; -- Attendre que le bit 7 de $E7E5 passe à 1 (VBL active) --
WaitVBL_Loop:
    lda   $E7E5
    bpl   WaitVBL_Loop   ; Tant que bit 7=0, on boucle (attend VBL)

    ; -- Attendre la fin de VBL (évite plusieurs déclenchements) --
WaitVBL_End:
    lda   $E7E5
    bmi   WaitVBL_End    ; Tant que bit 7=1, on boucle (attend sortie VBL)

    ; -- Inverser la page --
    lda   current_page
    eora  #1             ; inverse 0<->1
    sta   current_page
    bne   WaitVBL_AffichePage1_MappePage0Cartouche

WaitVBL_AffichePage0_MappePage1Cartouche:
    lda   $E7E4        ; Lire configuration actuelle (bordure/couleur)
    anda  #$3F         ; Effacer D7-D6 (page affichée)
    sta   $E7E4        ; Affiche page 0, bordure inchangée

    lda   #$61         ; %0110 0001 : D6=1 écriture autorisée, D5=1 RAM, D4-D0=1 (page 1)
    sta   $E7E6        ; Mappe RAM page 1 dans espace cartouche

    bra  WaitVBL_Exit

WaitVBL_AffichePage1_MappePage0Cartouche:
    lda   $E7E4        ; Lire configuration actuelle (bordure/couleur)
    anda  #$3F         ; Effacer D7-D6 (page affichée)
    ora   #$40         ; Mettre D7-D6 = 01 (page 1)
    sta   $E7E4        ; Affiche page 1, bordure inchangée

    lda   #$60         ; %0110 0000 : D6=1 écriture autorisée, D5=1 RAM, D4-D0=0 (page 0)
    sta   $E7E6        ; Mappe RAM page 0 dans espace cartouche

WaitVBL_Exit:
    puls  a,pc
