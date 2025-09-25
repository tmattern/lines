;-------------------------------------------
; Routine : project3d_to_2d
;  - Entrée :
;       X = adresse objet 3D source
;       Y = adresse objet 2D cible (assez grand)
;  - Sortie :
;       Objet 2D prêt à être affiché (coords 16 bits centrées écran)
;  - Utilise :
;       d3_scaling_table (32 valeurs 8.8)
;       D3_CAMERA_OFFSET = 20
;       D3_SCREEN_CX = 160
;       D3_SCREEN_CY = 100
;-------------------------------------------

D3_CAMERA_OFFSET  equ 20
D3_SCREEN_CX      equ 160
D3_SCREEN_CY      equ 100


project3d_to_2d:
    PSHS  X,Y,U

    ; -- Recopie n_points et n_edges (1 octet chacun) --
    LDA   0,X       ; nb points
    STA   d3_pt_count
    LDA   1,X       ; nb arêtes
    STA   d3_n_edges

    ; -- Boucle points 3D -> 2D --
    LDB   d3_pt_count
    BEQ   d3d_done_pts

    LDU   2,X       ; pointeur sur le tableau de point 3d
    LDY   2,Y       ; pointeur sur le tableau de point 2d
d3d_pt_loop:
    LDA   0,U       ; point 3d: X
    STA   d3_x3d
    LDA   1,U       ; point 3d: Y
    STA   d3_y3d
    LDA   2,U       ; point 3d: Z
    STA   d3_z3d

    ; -- Calcul index scaling : Z + D3_CAMERA_OFFSET --
    ADDA  d3_camera_offset

    ; Clamp à [0,127]
    BMI   d3d_zero
d3d_ok:
    LDX   #d3_scaling_table
    LDB   A,X      ; B = scaling (8.8)
    STB   d3_scaling

    ; -- Projection X : X2D = (X3D * scaling)>>8 + D3_SCREEN_CX --
    LDA   d3_x3d
    BPL   d3_xpos
    NEGA
    MUL                       ; D = X3D * scaling en 8.8
    LSLB
    ROLA
    LSLB
    ROLA
    LSLB
    ROLA
    NEGA
    BRA   d3_xresult
d3_xpos:
    MUL                       ; D = X3D * scaling en 8.8
    LSLB
    ROLA
    LSLB
    ROLA
    LSLB
    ROLA
d3_xresult:
    TFR   A,B
    SEX
    ADDD  #D3_SCREEN_CX       ; Ajoute centre écran
    STD   0,Y                 ; point 2d: stocke X

    ; -- Projection Y : Y2D = (Y3D * scaling)>>8 + D3_SCREEN_CY --
    LDB   d3_scaling
    LDA   d3_y3d
    BPL   d3_ypos
    NEGA
    MUL                       ; D = Y3D * scaling en 8.8
    LSLB
    ROLA
    LSLB
    ROLA
    LSLB
    ROLA
    NEGA
    BRA   d3_yresult
d3_ypos:
    MUL                       ; D = Y3D * scaling en 8.8
    LSLB
    ROLA
    LSLB
    ROLA
    LSLB
    ROLA
d3_yresult:
    TFR   A,B
    SEX
    ADDD  #D3_SCREEN_CY
    STD   2,Y                 ; point 2d: stocke Y

d3d_pt_next:
    LEAU  3,U                 ; point 3D suivant
    LEAY  4,Y                 ; point 2D suivant
    DEC   d3_pt_count
    BNE   d3d_pt_loop
    BRA   d3d_done_pts

d3d_zero:
    ; Point hors champ : stocke 0,0 (ou valeur spéciale)
    LDD   #D3_SCREEN_CX
    STD   0,Y                 ; point 2d: stocke X
    LDD   #D3_SCREEN_CY
    STD   2,Y                 ; point 2d: stocke Y
    BRA   d3d_pt_next

d3d_done_pts:
d3d_done:
    PULS  X,Y,U,PC

;-------------------------------------------
d3_scaling_table:
    fcb 255,218,191,170,153,139,128,118,109,102,95,90,84,80,76,72
    fcb 69,65,62,60,57,55,52,50,48,46,44,43,41,40,38,37
    fcb 36,34,33,32,31,30,29,28,27,26,25,24,23,22,22,21
    fcb 20,19,19,18,18,17,17,16,16,15,15,14,14,13,13,13
    fcb 12,12,12,11,11,11,10,10,10,10,9,9,9,9,8,8
    fcb 8,8,8,7,7,7,7,7,7,7,6,6,6,6,6,6
    fcb 6,6,6,6,5,5,5,5,5,5,5,5,5,5,4,4
    fcb 4,4,4,4,4,4,4,4,4,4,4,4,4,4,3,3