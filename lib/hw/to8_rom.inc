; =================================================================
;  Thomson TO8 - Définitions des adresses ROM (vecteurs, routines)
;  (Pas de registres hardware dans ce fichier)
; =================================================================

; ------------------- ROM Système et entrées ---------------------
ROM_SYSTEM      equ $E000   ; Base ROM système TO8 (16 Ko)
ROM_BASIC       equ $E000   ; Entrée BASIC TO8
ROM_MONITOR     equ $E100   ; Entrée moniteur TO8

; ------------------- Vecteurs interruptions ---------------------
VEC_SWI3        equ $FFF2
VEC_SWI2        equ $FFF4
VEC_FIRQ        equ $FFF6
VEC_IRQ         equ $FFF8
VEC_SWI         equ $FFFA
VEC_NMI         equ $FFFC
VEC_RESET       equ $FFFE

; ------------------- Routines ROM courantes --------------------
ROM_CLS         equ $E403   ; Efface écran
ROM_PUTC        equ $E52C   ; Affiche caractère en A
ROM_PUTS        equ $E5A1   ; Affiche chaîne (X, $00 terminé)
ROM_READK       equ $E40F   ; Lire touche, résultat en A
ROM_GRAFLINE    equ $E7F4   ; Trace segment graphique (X0,Y0,X1,Y1 en mémoire)
ROM_GRAFFILL    equ $E7F1   ; Remplissage zone graphique

; ------------------- Emplacement cartouche ---------------------
CART_ROM        equ $B000   ; Emplacement ROM cartouche (lecture)

; ------------------- Divers ROM utilisés par l'OS --------------
VBL_FLAG        equ $A7E5   ; Flag VBL utilisé par l'OS TO8
SYSTIMER        equ $A7E7   ; Timer système (OS)

; =================================================================
;  Fin du fichier ROM TO8 - Aucune adresse hardware ici !
; =================================================================