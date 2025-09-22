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

    ; Sauver couleur du tour (D3-D0 de GA_SYS2)
    lda   GA_SYS2
    anda  #$0F            ; Garde bits couleur tour
    sta   saved_border_color

    ; Changer couleur du tour pour debug (rouge = 2)
    lda   GA_SYS2
    anda  #$F0            ; Efface bits couleur tour
    ora   #2              ; Mets rouge (2)
    sta   GA_SYS2

    ; -- Attendre que le bit 7 de VIDEO_STATUS passe à 1 (VBL active) --
WaitVBL_Loop:
    lda   LIGHT_PEN_4
    bpl   WaitVBL_Loop

    ; -- Attendre la fin de VBL (évite plusieurs déclenchements) --
WaitVBL_End:
    lda   LIGHT_PEN_4
    bmi   WaitVBL_End

    ; -- Inverser la page --
    lda   current_page
    eora  #1
    sta   current_page
    bne   WaitVBL_AffichePage1_MappePage0Cartouche

WaitVBL_AffichePage0_MappePage1Cartouche:
    lda   GA_SYS2
    anda  #$3F
    sta   GA_SYS2

    lda   #%01100001
    sta   GA_CART_RAM

    bra   WaitVBL_RestoreBorder

WaitVBL_AffichePage1_MappePage0Cartouche:
    lda   GA_SYS2
    anda  #$3F
    ora   #$40
    sta   GA_SYS2

    lda   #%01100000
    sta   GA_CART_RAM

WaitVBL_RestoreBorder:
    ; Remettre la couleur du tour originale
    lda   GA_SYS2
    anda  #$F0            ; Efface bits couleur tour
    ora   saved_border_color
    sta   GA_SYS2

    puls  a,pc