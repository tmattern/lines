; 6809 - Tracé/Effacement de polygone depuis un tableau de points
; Compatible lwtools (lwasm)
; Ecran 320x200 1bpp, base $4000
; Entrée tableau: liste de X,Y,X,Y,..., dernier=premier pour polygone fermé
; mode = $FF (trace) ou $00 (efface)

; ==== SECTION RAM (page zéro) ====
            org $B000
x0          rmb 1        ; point de départ X
y0          rmb 1        ; point de départ Y
x1          rmb 1        ; point d'arrivée X
y1          rmb 1        ; point d'arrivée Y
mode        rmb 1        ; $FF (trace), $00 (efface)
count       rmb 1        ; compteur de segments

; --- Variables temporaires, non partagées ---
; Pour Line_HV_SetClear (horizontale)
lh_tmp      rmb 2        ; adresse ligne video
lh_byt0     rmb 1        ; octet video début
lh_byt1     rmb 1        ; octet video fin
lh_mask0    rmb 1        ; masque début
lh_mask1    rmb 1        ; masque fin
lh_filla    rmb 1        ; itérateur octet
lh_fillz    rmb 1        ; borne octet

; Pour Line_HV_SetClear (verticale)
lv_tmp      rmb 2        ; adresse colonne video
lv_mask     rmb 1        ; masque bit vertical
lv_xbyte    rmb 1        ; octet colonne
lv_yiter    rmb 1        ; itérateur Y

; Pour Bresenham (LineSelfModSetClear)
bg_tmp      rmb 2        ; adresse pixel video
bg_addr     rmb 2    ; adresse octet vidéo courant (nouveau, 16 bits)
bg_mask     rmb 1        ; masque bit
bg_dx       rmb 1
bg_dy       rmb 1
bg_sx       rmb 1
bg_sy       rmb 1
bg_err      rmb 1
bg_err2     rmb 1

; ==== SECTION DONNÉES Et CODE ====
            org $A000
            lbra start

; --- TABLEAU DE POINTS EXEMPLE ---
points      fcb 30,30
            fcb 100,100
            fcb 50,40
            fcb 10,40
            fcb 10,10

npts        equ 4          ; 5 points = 4 segments + fermeture

; --- Exemple d'appel ---
start       LDA #$B0
            TFR A,DP        ; DP = $FExx
            ldy  #points
            ldb  #npts
            stb  count
            lda  #$FF      ; $FF: trace, $00: efface
            sta  mode
            jsr  DrawPolyTable
            rts

; --- ROUTINE PRINCIPALE: Trace ou efface le polygone ---
; Entrées : Y = adresse du tableau, count = nombre de segments, mode = $FF/$00 en RAM
DrawPolyTable:
            lda ,y+        ; x0
            sta x0
            lda ,y+        ; y0
            sta y0
DrawPolyTable_Loop:
            lda ,y+        ; x1
            sta x1
            lda ,y+        ; y1
            sta y1
            jsr Line_HV_SetClear
            lda x1
            sta x0
            lda y1
            sta y0
            dec count
            lda count
            bne DrawPolyTable_Loop
            rts

; === ROUTINE LIGNE ULTRA-RAPIDE TRACE/EFFACE ===
Line_HV_SetClear:
            lda y0
            cmpa y1
            lbne .notHoriz
            ; ----- HORIZONTALE -----
            lda x0
            cmpa x1
            bls .lh_ok
            lda x0
            ldb x1
            sta x1
            stb x0
.lh_ok:
            lda y0
            ldb #40
            mul
            addd #$4000
            std lh_tmp

            lda x0
            lsra
            lsra
            lsra
            sta lh_byt0
            lda x1
            lsra
            lsra
            lsra
            sta lh_byt1

            ; Masques début et fin
            lda x0
            anda #7
            eora #7
            ldb #1
.lh_msk0:   cmpa #0
            beq .lh_msk0ok
            lslb
            deca
            bra .lh_msk0
.lh_msk0ok: stb lh_mask0
            lda x1
            anda #7
            eora #7
            ldb #1
.lh_msk1:   cmpa #0
            beq .lh_msk1ok
            lslb
            deca
            bra .lh_msk1
.lh_msk1ok: stb lh_mask1

            lda lh_byt0
            cmpa lh_byt1
            beq .lh_samebyte
            ; Plusieurs octets
            ldx lh_tmp
            lda mode
            cmpa #$FF
            beq .lh_set

            ; ---- effacement ----
            lda #$FF
            eora lh_mask0
            anda lh_byt0,x
            sta lh_byt0,x
            lda #$FF
            eora lh_mask1
            anda lh_byt1,x
            sta lh_byt1,x
            ; Octets pleins
            lda lh_byt0
            inca
            sta lh_filla
            lda lh_byt1
            deca
            sta lh_fillz
.lh_fillc:  lda lh_filla
            cmpa lh_fillz
            bgt .lh_out
            lda #$00
            sta a,x
            inc lh_filla
            bra .lh_fillc
.lh_out:    rts
.lh_set:
            lda lh_mask0
            ora lh_byt0,x
            sta lh_byt0,x
            lda lh_mask1
            ora lh_byt1,x
            sta lh_byt1,x
            ; Octets pleins
            lda lh_byt0
            inca
            sta lh_filla
            lda lh_byt1
            deca
            sta lh_fillz
.lh_fills:  lda lh_filla
            cmpa lh_fillz
            bgt .lh_out2
            lda #$FF
            sta a,x
            inc lh_filla
            bra .lh_fills
.lh_out2:   rts
.lh_samebyte:
            ldx lh_tmp
            lda mode
            cmpa #$FF
            beq .lh_sbset
            ; effacement
            lda #$FF
            eora lh_mask0
            eora lh_mask1
            anda lh_byt0,x
            sta lh_byt0,x
            rts
.lh_sbset:
            lda lh_mask0
            ora lh_mask1
            ora lh_byt0,x
            sta lh_byt0,x
            rts

; ----- VERTICALE -----
.notHoriz:
            lda x0
            cmpa x1
            lbne .notVert
            lda y0
            cmpa y1
            bls .lv_ok
            lda y0
            ldb y1
            sta y1
            stb y0
.lv_ok:
            lda x0
            lsra
            lsra
            lsra
            sta lv_xbyte
            lda x0
            anda #7
            eora #7
            ldb #1
.lv_mask:   cmpa #0
            beq .lv_maskok
            lslb
            deca
            bra .lv_mask
.lv_maskok: stb lv_mask
            lda y0
            sta lv_yiter
            lda mode
            cmpa #$FF
            beq .lv_set
            ; ---- effacement ----
.lv_ce:     lda lv_yiter
            cmpa y1
            bgt .lv_end
            lda lv_yiter
            ldb #40
            mul
            addd #$4000
            addb lv_xbyte
            std lv_tmp
            ldx lv_tmp
            lda #$FF
            eora lv_mask
            anda ,x
            sta ,x
            inc lv_yiter
            bra .lv_ce
.lv_set:    ; ---- traçage ----
.lv_cs:     lda lv_yiter
            cmpa y1
            bgt .lv_end
            lda lv_yiter
            ldb #40
            mul
            addd #$4000
            addb lv_xbyte
            std lv_tmp
            ldx lv_tmp
            lda ,x
            ora lv_mask
            sta ,x
            inc lv_yiter
            bra .lv_cs
.lv_end:    rts

; ----- Bresenham général (trace/efface) -----
.notVert:
            jsr LineSelfModSetClear
            rts

LineSelfModSetClear:
    lda x0
    cmpa x1
    bls .bg_dxpos
    lda x0
    suba x1

; === Routine Bresenham 6809 (ligne tous cas) ===
; Variables d'entrée : x0, y0, x1, y1, mode (FF=trace, sinon efface)
; Variables temporaires : bg_dx, bg_dy, bg_sx, bg_sy, bg_err, bg_err2, bg_addr, bg_mask
; Nécessite : bg_addr rmb 2, bg_mask rmb 1, bg_dx rmb 1, bg_dy rmb 1, bg_sx rmb 1, bg_sy rmb 1, bg_err rmb 1, bg_err2 rmb 1

LineBresenham6809:
    ; --- Calcul des directions et deltas ---
    lda x1
    suba x0
    bpl dx_pos
    nega
    sta bg_dx
    ldb #-1
    stb bg_sx
    bra dx_ok
dx_pos
    sta bg_dx
    ldb #1
    stb bg_sx
dx_ok
    lda y1
    suba y0
    bpl dy_pos
    nega
    sta bg_dy
    ldb #-1
    stb bg_sy
    bra dy_ok
dy_pos
    sta bg_dy
    ldb #1
    stb bg_sy
dy_ok

    lda bg_dx
    suba bg_dy
    sta bg_err

;--- Boucle principale ---
Bres_loop
    ; --- Calcul adresse vidéo (adresse octet) ---
    lda y0
    ldb #40
    mul                 ; D = y0 * 40
    addd #$4000         ; D = base VRAM + offset ligne
    std bg_addr         ; bg_addr = adresse début de ligne

    lda x0
    lsra
    lsra
    lsra                ; x0 // 8
    clrb
    addd bg_addr        ; D = adresse octet vidéo
    std bg_addr

    ; --- Calcul masque bit ---
    lda x0
    anda #7
    eora #7
    ldb #1
masq_loop
    cmpa #0
    beq masq_ok
    lslb
    deca
    bra masq_loop
masq_ok
    stb bg_mask

    ; --- Trace ou efface ---
    ldx bg_addr
    lda ,x
    ldb mode
    cmpb #$FF
    bne efface
    ora bg_mask
    bra store
efface
    coma        ; A = ~A
    ora bg_mask
    coma        ; A = ~A
store
    sta ,x

    ; --- Test de fin ---
    lda x0
    cmpa x1
    bne not_end
    lda y0
    cmpa y1
    beq Bres_end
not_end

    ; --- Bresenham erreur 2*err ---
    lda bg_err
    asla
    sta bg_err2

    ; Test incrément x (si 2*err > -dy)
    ldb bg_err2
    addb bg_dy    ; B = 2*err + dy
    bpl do_x      ; Si positif, fait x
    bra test_y

do_x
    lda bg_err
    suba bg_dy
    sta bg_err
    lda x0
    adda bg_sx
    sta x0

test_y
    ldb bg_err2
    subb bg_dx    ; B = 2*err - dx
    bmi Bres_loop ; Si négatif, saute y
    lda bg_err
    adda bg_dx
    sta bg_err
    lda y0
    adda bg_sy
    sta y0
    bra Bres_loop

Bres_end
    rts

