        XREF    setup_env,close_env
        XREF    open_file,close_file
        XREF    next_file_char
        XREF    printf

        TEXT
start
        JSR     setup_env
        TST.L   D0
        BEQ.W   .exit

        MOVE.L  #input_file_name,D1
        JSR     open_file       ; load file into D4

        MOVEQ.L #0,D5           ; initial remaining data for reading from file
        MOVEQ.L #0,D2           ; score accumulator
.count_score_loop
        JSR     get_rps_moves
        TST.W   D5
        BMI.S   .end_count_score_loop   ; if file has no more data, we are done
        ;;;     add score based on move
        ADDQ.W  #1,D2
        EXT.W   D1
        ADD.W   D1,D2
        ;;;     add score based on if game was won
        ;;;     calculate (opponent's guess - your guess) % 3
        ;;;     0: tie
        ;;;     1: opponent won
        ;;;     2: you won
        SUB.B   D1,D0
        BPL.S   .diff_ok
        ADDQ.B  #3,D0
.diff_ok
        CMPI.B  #1,D0
        BEQ.S   .count_score_loop       ; add no score if opponent won
        ADDQ.W  #3,D2
        TST.B   D0
        BEQ.S   .count_score_loop       ; add 3 if tie
        ADDQ.W  #3,D2
        BRA.S   .count_score_loop       ; add 6 total if win
.end_count_score_loop

        MOVE.W  D2,-(SP)
        LEA.L   (msg_rps_score).L,A0
        JSR     printf
        ADDQ.L  #2,SP


        JSR     close_file
.exit
        JSR     close_env
        MOVEQ.L #0,D0
        RTS

;;;     Returns rock, paper, or scissors moves from file input as numbers
;;;     0, 1, or 2 respectively.
;;;
;;;     Arguments:
;;;     D4.L:   file handle
;;;     D5.L:   remaining data in file (start at 0)
;;;     A2.L:   index into file data buffer (do not modify between calls)
;;;     A5.L:   DOS library handle
;;;
;;;     Output:
;;;     D0.B:   opponent move
;;;     D1.B:   your move
get_rps_moves
        MOVEM.L D2-D3,-(SP)     ; save registers
        JSR     next_file_char  ; get opponent's move
        TST.W   D5
        BMI.S   .line_empty     ; return early if there is no line left to parse
        SUBI.B  #65,D0          ; subtract ASCII code 'A' to get number
        MOVE.B  D0,D2
        JSR     next_file_char  ; skip next character (space)
        JSR     next_file_char  ; get your move
        SUBI.B  #88,D0          ; subtract ASCII code 'Z' to get number
        MOVE.B  D0,D3
        JSR     next_file_char  ; skip next character (line feed)
        MOVE.B  D2,D0
        MOVE.B  D3,D1
.line_empty
        MOVEM.L (SP)+,D2-D3     ; restore registers
        RTS

        DATA
input_file_name         DC.B    "input/day2.txt",0
msg_rps_score           DC.B    "Score: %d",10,0
emsg_invalid_line       DC.B    "Invalid RPS (line %d)",10,0