; 6809 - Tracé/Effacement de polygone depuis un tableau de points
; Ecran 320x200 1bpp, base $4000
; Entrée tableau: liste de X,Y,X,Y,..., dernier=premier pour polygone fermé
; $20 = $FF (trace) ou $00 (efface)

BASE    EQU $4000
BPL     EQU 40         ; 320/8

; -- Variables page zéro --
X0      EQU $00
Y0      EQU $01
X1      EQU $02
Y1      EQU $03
MODE    EQU $20        ; $FF: trace, $00: efface

; --- TABLEAU DE POINTS EXEMPLE ---
; Un rectangle  (fermé)
POINTS
    .FCB  20,30    ; X0,Y0
    .FCB 150,30    ; X1,Y1
    .FCB 150,100   ; ...
    .FCB  20,100
    .FCB  20,30    ; Retour au point de départ

NPTS    EQU 5      ; 5 points = 4 segments + fermeture

; --- ROUTINE PRINCIPALE: Trace ou efface le polygone ---
; Entrées : Y = adresse tableau, B = nombre de segments, MODE = $FF/$00
DrawPolyTable:
    LDA ,Y+        ; X0
    STA X0
    LDA ,Y+        ; Y0
    STA Y0
DrawPolyTable_Loop:
    LDA ,Y+        ; X1
    STA X1
    LDA ,Y+        ; Y1
    STA Y1
    JSR Line_HV_SetClear
    ; Préparer prochain segment
    LDA X1
    STA X0
    LDA Y1
    STA Y0
    DECB
    BNE DrawPolyTable_Loop
    RTS

; === ROUTINE LIGNE ULTRA-RAPIDE TRACE/EFFACE ===
; Entrée: X0,Y0,X1,Y1, MODE
Line_HV_SetClear:
    LDA Y0
    CMPA Y1
    BNE .notHoriz
    ; ----- HORIZONTALE -----
    LDA X0
    CMPA X1
    BLS .lh_ok
    LDA X0
    LDB X1
    STA X1
    STB X0
.lh_ok:
    LDA Y0
    LDB #BPL
    MUL
    ADDD #BASE
    STD $10        ; $10 = base ligne

    LDA X0
    LSRA
    LSRA
    LSRA
    STA $12        ; byte0
    LDA X1
    LSRA
    LSRA
    LSRA
    STA $13        ; byte1

    ; Masques début et fin
    LDA X0
    ANDA #7
    EORA #7
    LDB #1
.lh_msk0:
    CMPA #0
    BEQ .lh_msk0ok
    LSLB
    DECA
    BRA .lh_msk0
.lh_msk0ok:
    STB $14
    LDA X1
    ANDA #7
    EORA #7
    LDB #1
.lh_msk1:
    CMPA #0
    BEQ .lh_msk1ok
    LSLB
    DECA
    BRA .lh_msk1
.lh_msk1ok:
    STB $15

    LDA $12
    CMPA $13
    BEQ .lh_samebyte
    ; Plusieurs octets
    LDX $10
    LDA MODE
    CMPA #$FF
    BEQ .lh_set
    ; ---- effacement ----
    LDA #$FF
    EORA $14
    ANDA $12,X
    STA $12,X
    LDA #$FF
    EORA $15
    ANDA $13,X
    STA $13,X
    ; Octets pleins
    LDA $12
    INCA
    STA $16
    LDA $13
    DECA
    STA $17
.lh_fillc:
    LDA $16
    CMPA $17
    BGT .lh_out
    LDA #$00   ; efface
    STA A,X
    INC $16
    BRA .lh_fillc
.lh_out:
    RTS
.lh_set:
    ; ---- traçage ----
    LDA $14
    ORA $12,X
    STA $12,X
    LDA $15
    ORA $13,X
    STA $13,X
    ; Octets pleins
    LDA $12
    INCA
    STA $16
    LDA $13
    DECA
    STA $17
.lh_fills:
    LDA $16
    CMPA $17
    BGT .lh_out2
    LDA #$FF
    STA A,X
    INC $16
    BRA .lh_fills
.lh_out2:
    RTS
.lh_samebyte:
    LDX $10
    LDA MODE
    CMPA #$FF
    BEQ .lh_sbset
    ; effacement
    LDA #$FF
    EORA $14
    EORA $15
    ANDA $12,X
    STA $12,X
    RTS
.lh_sbset:
    LDA $14
    ORA $15
    ORA $12,X
    STA $12,X
    RTS

; ----- VERTICALE -----
.notHoriz:
    LDA X0
    CMPA X1
    BNE .notVert
    LDA Y0
    CMPA Y1
    BLS .lv_ok
    LDA Y0
    LDB Y1
    STA Y1
    STB Y0
.lv_ok:
    LDA X0
    LSRA
    LSRA
    LSRA
    STA $18        ; offset_col
    LDA X0
    ANDA #7
    EORA #7
    LDB #1
.lv_mask:
    CMPA #0
    BEQ .lv_maskok
    LSLB
    DECA
    BRA .lv_mask
.lv_maskok:
    STB $19
    LDA Y0
    STA $1A
    LDA MODE
    CMPA #$FF
    BEQ .lv_set
    ; ---- effacement ----
.lv_ce:
    LDA $1A
    CMPA Y1
    BGT .lv_end
    LDA $1A
    LDB #BPL
    MUL
    ADDD #BASE
    ADDB $18
    LDX D
    LDA #$FF
    EORA $19
    ANDA ,X
    STA ,X
    INC $1A
    BRA .lv_ce
.lv_set:
    ; ---- traçage ----
.lv_cs:
    LDA $1A
    CMPA Y1
    BGT .lv_end
    LDA $1A
    LDB #BPL
    MUL
    ADDD #BASE
    ADDB $18
    LDX D
    LDA ,X
    ORA $19
    STA ,X
    INC $1A
    BRA .lv_cs
.lv_end:
    RTS

; ----- Bresenham général (trace/efface) -----
.notVert:
    JSR LineSelfModSetClear   ; Routine Bresenham général (voir ci-dessous)
    RTS

; === ROUTINE BRESENHAM GENERAL TRACE/EFFACE ($20) ===
; Entrée: X0,Y0,X1,Y1, MODE
LineSelfModSetClear:
    ; dx, sx
    LDA X0
    CMPA X1
    BLS .bg_dxpos
    LDA X0
    SUBA X1
    STA $04
    LDB #-1
    STB $06
    BRA .bg_dxok
.bg_dxpos:
    LDA X1
    SUBA X0
    STA $04
    LDB #1
    STB $06
.bg_dxok:
    ; dy, sy
    LDA Y0
    CMPA Y1
    BLS .bg_dypos
    LDA Y0
    SUBA Y1
    STA $05
    LDB #-1
    STB $07
    BRA .bg_dyok
.bg_dypos:
    LDA Y1
    SUBA Y0
    STA $05
    LDB #1
    STB $07
.bg_dyok:
    ; err = dx - dy
    LDA $04
    SUBA $05
    STA $08
.bg_loop:
    ; calcul adresse et masque
    LDA Y0
    LDB #BPL
    MUL
    ADDD #BASE
    STD $10
    LDA X0
    LSRA
    LSRA
    LSRA
    ADDA $10
    STA $12
    LDA X0
    ANDA #7
    EORA #7
    LDB #1
.bg_msk:
    CMPA #0
    BEQ .bg_mskok
    LSLB
    DECA
    BRA .bg_msk
.bg_mskok:
    STB $13
    ; traçage ou effacement
    LDA MODE
    CMPA #$FF
    BEQ .bg_set
    ; effacement
    LDX $12
    LDA #$FF
    EORA $13
    ANDA ,X
    STA ,X
    BRA .bg_next
.bg_set:
    LDX $12
    LDA ,X
    ORA $13
    STA ,X
.bg_next:
    ; fin ?
    LDA X0
    CMPA X1
    BNE .bg_notend
    LDA Y0
    CMPA Y1
    BEQ .bg_end
.bg_notend:
    LDA $08
    ASLA
    STA $09   ; e2
    LDA $09
    CMPA #0
    BPL .bg_skipx
    LDA $08
    SUBA $05
    STA $08
    LDA X0
    ADDA $06
    STA X0
.bg_skipx:
    LDA $09
    CMPA $04
    BMI .bg_skipy
    LDA $08
    ADDA $04
    STA $08
    LDA Y0
    ADDA $07
    STA Y0
.bg_skipy:
    BRA .bg_loop
.bg_end:
    RTS

; =========================

; --- Exemple d'appel ---
;   LDY  #POINTS
;   LDB  #4        ; 5 points = 4 segments (fermeture)
;   LDA  #$FF      ; $FF: trace, $00: efface
;   STA  MODE
;   JSR  DrawPolyTable

; =========================

; Fin du fichier
