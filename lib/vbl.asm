; === Variables en page directe ===


InitScreen:
    ; Map video RAM to $0000
    LDA  #%01100000  ; D7=0, D6=1 (écriture), D5=1 (RAM active), D4-D0=00000 (page 0)
    STA  $E7E6       ; Mappe la page 0 en $0000

    ; Configuration Gate Array
    LDA  #%00000000  ; Couleur tour ecran
    STA  $E7DD       ; Registre systeme 2


; === Routine d'attente VBL + switch buffer ===

WaitVBLAndSwitchBuffer:
    ; -- Attendre que le bit 7 de $E7E5 passe à 1 (VBL active) --
WaitVBL_Loop:
    lda   $E7E5
    bpl   WaitVBL_Loop   ; Tant que bit 7=0, on boucle (attend VBL)

    ; -- Attendre la fin de VBL (évite plusieurs déclenchements) --
WaitVBL_End:
    lda   $E7E5
    bmi   WaitVBL_End    ; Tant que bit 7=1, on boucle (attend sortie VBL)

    ; -- Inverser la page --
    ldx   #current_page
    lda   ,x
    eora  #1             ; inverse 0<->1
    sta   ,x

    ; -- Mettre à jour le registre vidéo (page affichée) --
    lda   ,x
    asla                  ; bit 0 -> bit 1 (LSB to page select bit)
    sta   $E7C0           ; $E7C0 = registre d'affichage (bit 1 = page)

    rts