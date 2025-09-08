; 6809 - Tracé/Effacement de polygone depuis un tableau de points
; Compatible lwtools (lwasm)
; Ecran 320x200 1bpp, base $4000
; Entrée tableau: liste de X,Y,X,Y,..., dernier=premier pour polygone fermé
; mode = $FF (trace) ou $00 (efface)

; ==== SECTION RAM (page zéro) ====
            org $A000
            lbra start
x0          rmb 1
y0          rmb 1
x1          rmb 1
y1          rmb 1
mode        rmb 1
tmp         rmb 2          ; pour STD/LDX tmp
tmp2        rmb 2          ; pour une 2ème adresse, au besoin
scratch     rmb 32         ; $10 à $2F pour variables temporaires

; ==== SECTION DONNÉES Et CODE ====

; --- TABLEAU DE POINTS EXEMPLE ---
points      fcb 10,10
            fcb 50,10
            fcb 50,40
            fcb 10,40
            fcb 10,10

npts        equ 5          ; 5 points = 4 segments + fermeture


; --- Exemple d'appel dans ton programme principal ---
start       ldy  #points
            ldb  #4        ; 5 points = 4 segments (fermeture)
            lda  #$FF      ; $FF: trace, $00: efface
            sta  mode
            jsr  DrawPolyTable
            rts


; --- ROUTINE PRINCIPALE: Trace ou efface le polygone ---
; Entrées : Y = adresse du tableau, B = nombre de segments, mode = $FF/$00 en RAM
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
            decb
            bne DrawPolyTable_Loop
            rts

; === ROUTINE LIGNE ULTRA-RAPIDE TRACE/EFFACE ===
; Entrée: x0,y0,x1,y1, mode
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
            std tmp

            lda x0
            lsra
            lsra
            lsra
            sta $12
            lda x1
            lsra
            lsra
            lsra
            sta $13

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
.lh_msk0ok: stb $14
            lda x1
            anda #7
            eora #7
            ldb #1
.lh_msk1:   cmpa #0
            beq .lh_msk1ok
            lslb
            deca
            bra .lh_msk1
.lh_msk1ok: stb $15

            lda $12
            cmpa $13
            beq .lh_samebyte
            ; Plusieurs octets
            ldx tmp
            lda mode
            cmpa #$FF
            beq .lh_set
            ; ---- effacement ----
            lda #$FF
            eora $14
            anda $12,x
            sta $12,x
            lda #$FF
            eora $15
            anda $13,x
            sta $13,x
            ; Octets pleins
            lda $12
            inca
            sta $16
            lda $13
            deca
            sta $17
.lh_fillc:  lda $16
            cmpa $17
            bgt .lh_out
            lda #$00
            sta a,x
            inc $16
            bra .lh_fillc
.lh_out:    rts
.lh_set:
            lda $14
            ora $12,x
            sta $12,x
            lda $15
            ora $13,x
            sta $13,x
            ; Octets pleins
            lda $12
            inca
            sta $16
            lda $13
            deca
            sta $17
.lh_fills:  lda $16
            cmpa $17
            bgt .lh_out2
            lda #$FF
            sta a,x
            inc $16
            bra .lh_fills
.lh_out2:   rts
.lh_samebyte:
            ldx tmp
            lda mode
            cmpa #$FF
            beq .lh_sbset
            ; effacement
            lda #$FF
            eora $14
            eora $15
            anda $12,x
            sta $12,x
            rts
.lh_sbset:
            lda $14
            ora $15
            ora $12,x
            sta $12,x
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
            sta $18
            lda x0
            anda #7
            eora #7
            ldb #1
.lv_mask:   cmpa #0
            beq .lv_maskok
            lslb
            deca
            bra .lv_mask
.lv_maskok: stb $19
            lda y0
            sta $1A
            lda mode
            cmpa #$FF
            beq .lv_set
            ; ---- effacement ----
.lv_ce:     lda $1A
            cmpa y1
            bgt .lv_end
            lda $1A
            ldb #40
            mul
            addd #$4000
            addb $18
            std tmp
            ldx tmp
            lda #$FF
            eora $19
            anda ,x
            sta ,x
            inc $1A
            bra .lv_ce

.lv_set:    ; ---- traçage ----
.lv_cs:     lda $1A
            cmpa y1
            bgt .lv_end
            lda $1A
            ldb #40
            mul
            addd #$4000
            addb $18
            std tmp
            ldx tmp
            lda ,x
            ora $19
            sta ,x
            inc $1A
            bra .lv_cs
.lv_end:    rts

; ----- Bresenham général (trace/efface) -----
.notVert:
            jsr LineSelfModSetClear
            rts

; === ROUTINE BRESENHAM GENERAL TRACE/EFFAC (mode) ===
LineSelfModSetClear:
            lda x0
            cmpa x1
            bls .bg_dxpos
            lda x0
            suba x1
            sta $04
            ldb #-1
            stb $06
            bra .bg_dxok
.bg_dxpos:
            lda x1
            suba x0
            sta $04
            ldb #1
            stb $06
.bg_dxok:
            lda y0
            cmpa y1
            bls .bg_dypos
            lda y0
            suba y1
            sta $05
            ldb #-1
            stb $07
            bra .bg_dyok
.bg_dypos:
            lda y1
            suba y0
            sta $05
            ldb #1
            stb $07
.bg_dyok:
            lda $04
            suba $05
            sta $08
.bg_loop:
            lda y0
            ldb #40
            mul
            addd #$4000
            std tmp
            lda x0
            lsra
            lsra
            lsra
            adda tmp
            sta $12
            lda x0
            anda #7
            eora #7
            ldb #1
.bg_msk:    cmpa #0
            beq .bg_mskok
            lslb
            deca
            bra .bg_msk
.bg_mskok:  stb $13
            lda mode
            cmpa #$FF
            beq .bg_set
            ldx $12
            lda #$FF
            eora $13
            anda ,x
            sta ,x
            bra .bg_next
.bg_set:    ldx $12
            lda ,x
            ora $13
            sta ,x
.bg_next:   lda x0
            cmpa x1
            bne .bg_notend
            lda y0
            cmpa y1
            beq .bg_end
.bg_notend: lda $08
            asla
            sta $09
            lda $09
            cmpa #0
            bpl .bg_skipx
            lda $08
            suba $05
            sta $08
            lda x0
            adda $06
            sta x0
.bg_skipx:  lda $09
            cmpa $04
            bmi .bg_skipy
            lda $08
            adda $04
            sta $08
            lda y0
            adda $07
            sta y0
.bg_skipy:  lbra .bg_loop
.bg_end:    rts

