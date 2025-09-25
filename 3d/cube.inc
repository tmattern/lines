; Structure générique d'un objet 3D

; --- En-tête de l'objet ---
; n_points: nombre de points (1 octet)
; n_edges:  nombre d'arêtes (1 octet)
; points_ptr: adresse des points (2 octets)
; edges_ptr:  adresse des arêtes (2 octets)

struct3d:
    fcb 0           ; n_points
    fcb 0           ; n_edges
    fdb 0           ; points_ptr
    fdb 0           ; edges_ptr

; --- Table des points (chaque point: X, Y, Z en fixed 8.8, 6 octets/point) ---
; Exemple de points pour un cube:
cube_3d_points:
    fcb -10,-10,-10  ; 0
    fcb  10,-10,-10  ; 1
    fcb  10,10,-10   ; 2
    fcb -10,10,-10   ; 3
    fcb -10,-10,10   ; 4
    fcb  10,-10,10   ; 5
    fcb  10,10,10    ; 6
    fcb -10,10,10    ; 7

cube_2d_points:
    rmb 2*2*8

; --- Table des arêtes (2 octets par arête: index1, index2) ---
cube_edges:
    fcb 0,1,1,2,2,3,3,0      ; base
    fcb 4,5,5,6,6,7,7,4      ; haut
    fcb 0,4,1,5,2,6,3,7      ; montants

; --- Initialisation de la structure pour le cube ---
cube3d:
    fcb 8                ; n_points
    fcb 12               ; n_edges
    fdb cube_3d_points   ; points_ptr
    fdb cube_edges       ; edges_ptr

cube2d:
    fcb 8                ; n_points
    fcb 12               ; n_edges
    fdb cube_2d_points   ; points_2d_ptr
    fdb cube_edges       ; edges_ptr
