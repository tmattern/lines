; =================================================================
;  Thomson TO8 - Définitions des adresses hardware (I/O, VRAM, etc)
;  (Pas d'adresses ni routines ROM ici)
; =================================================================

; ----------------- VIA 1 (contrôle vidéo) -----------------
VIA1_PORTA      equ $E7C0
VIA1_PORTB      equ $E7C1
VIA1_DDRA       equ $E7C2
VIA1_DDRB       equ $E7C3
VIA1_T1CL       equ $E7C4
VIA1_T1CH       equ $E7C5
VIA1_T1LL       equ $E7C6
VIA1_T1LH       equ $E7C7
VIA1_T2CL       equ $E7C8
VIA1_T2CH       equ $E7C9
VIA1_SR         equ $E7CA
VIA1_ACR        equ $E7CB
VIA1_PCR        equ $E7CC
VIA1_IFR        equ $E7CD
VIA1_IER        equ $E7CE
VIA1_PORTA_NH   equ $E7CF

; --------- VIA 2 (ports extension, imprimante, K7) ---------
VIA2_PORTA      equ $E7D0
VIA2_PORTB      equ $E7D1
VIA2_DDRA       equ $E7D2
VIA2_DDRB       equ $E7D3
VIA2_T1CL       equ $E7D4
VIA2_T1CH       equ $E7D5
VIA2_T1LL       equ $E7D6
VIA2_T1LH       equ $E7D7
VIA2_T2CL       equ $E7D8
VIA2_T2CH       equ $E7D9
VIA2_SR         equ $E7DA
VIA2_ACR        equ $E7DB
VIA2_PCR        equ $E7DC
VIA2_IFR        equ $E7DD
VIA2_IER        equ $E7DE
VIA2_PORTA_NH   equ $E7DF

; ------------------- PPI (Clavier, etc) -------------------
PPI_PORTA       equ $E7E0   ; Lecture clavier, souris, joystick
PPI_PORTB       equ $E7E1   ; Ecriture clavier, joystick
PPI_PORTC       equ $E7E2   ; Souris (position, boutons)
PPI_CTRL        equ $E7E3   ; Contrôle du PPI

; -------------- Contrôle vidéo spécifique TO8 -------------
VIDEO_MODE      equ $E7C0   ; Mode vidéo + page affichée (écriture)
VIDEO_BORDER    equ $E7C1   ; Couleur de bordure
VIDEO_PALETTE   equ $E7C2   ; Palette (écriture)
VIDEO_PALETTE_RD equ $E7C3  ; Palette (lecture)
VIDEO_SCROLL    equ $E7C4   ; Scroll vertical (320x200)

; --------------- Statut vidéo / VBL -----------------------
VIDEO_STATUS    equ $E7E5   ; Bit 7=VBL, autres bits statut vidéo

; --------------- Audio / DAC / buzzer ---------------------
SOUND_DAC       equ $E7E7   ; DAC 6 bits (sortie audio)
SOUND_BELL      equ $E7E6   ; Commande buzzer

; ------------- Contrôleur disquette / FDC -----------------
FDC_COMMAND     equ $E7E8
FDC_TRACK       equ $E7E9
FDC_SECTOR      equ $E7EA
FDC_DATA        equ $E7EB
FDC_STATUS      equ $E7EC

; --------------- Ports extension / cartouche --------------
CART_ROM        equ $B000   ; ROM cartouche externe (lecture)
CART_IO         equ $E7F0   ; Registre I/O cartouche

; ------------------- RAM vidéo (VRAM) ---------------------
VRAM_PAGE0      equ $C000   ; Page vidéo 0 (16 Ko)
VRAM_PAGE1      equ $8000   ; Page vidéo 1 (16 Ko)

; --------------------- RAM centrale -----------------------
RAM_START       equ $0000   ; Base RAM (jusqu'à 64 Ko selon config)

; -------------------- Ports divers ------------------------
PRINTER_PORT    equ $E7E4   ; Port imprimante Centronics
CASSETTE_PORT   equ $E7EE   ; Port cassette

; ---------------------- Divers ----------------------------
RESET_IO        equ $E7FF   ; Reset général I/O (attention !)

; =================================================================
;  Fin du fichier hardware TO8 - Aucune adresse ROM ici !
; =================================================================