;------------------------------------------------------------------------------
; INITIALISATION ET VARIABLES EN PAGE DIRECTE
;------------------------------------------------------------------------------
        setdp   $61      ; Configuration page directe à $61xx
        org     $6100    ; Adresse de début des variables

STACK   rmb     2

; Variables d'entrée (coordonnées des points)
X0:     rmb     2        ; Coordonnée X du point de départ (16 bits big-endian)
Y0:     rmb     2        ; Coordonnée Y du point de départ (16 bits big-endian)  
X1:     rmb     2        ; Coordonnée X du point d'arrivée (16 bits big-endian)
Y1:     rmb     2        ; Coordonnée Y du point d'arrivée (16 bits big-endian)

; Variables de calcul Bresenham
DX:     rmb     2        ; Différence absolue |X1-X0| (16 bits)
DY:     rmb     2        ; Différence absolue |Y1-Y0| (16 bits)
SX:     rmb     1        ; Sens d'incrémentation X : +1 ou -1 (8 bits signé)
SY:     rmb     1        ; Sens d'incrémentation Y : +1 ou -1 (8 bits signé)
ERR:    rmb     2        ; Variable d'erreur Bresenham (16 bits)

; Variables de gestion pixel et adressage VRAM
MASK:   rmb     1        ; Masque de bit pour le pixel courant (8 bits : 128,64,32,16,8,4,2,1)
ADDR:   rmb     2        ; Adresse VRAM de l'octet contenant le pixel courant (16 bits)
TMP:    rmb     2        ; Variable temporaire pour calculs d'adresse (16 bits)
PIX_CPT:rmb     1        ; Compteur de pixels à tracer (8 bits)

saved_border_color   rmb 1
current_page         rmb 1
CLEAR_SCREEN_START rmb 2
