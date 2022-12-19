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
        CLR.L   (part1_score).L ; also clears part2_score since they are adjacent words
.count_score_loop
        JSR     get_rps_moves
        TST.W   D5
        BMI.S   .end_count_score_loop   ; if file has no more data, we are done
        ;;;     add points based on move (part 1)
        ADDQ.W  #1,(part1_score).L
        EXT.W   D1
        ADD.W   D1,(part1_score).L
        ;;;     add points based on game result (part 2)
        TST.B   D1
        BEQ.S   .add_part1_result_points        ; 0 points for loss
        ADDQ.W  #3,(part2_score).L              ; 3 points for tie
        CMPI.B  #1,D1
        BEQ.S   .add_part1_result_points
        ADDQ.W  #3,(part2_score).L              ; 6 points (total) for win
.add_part1_result_points
        ;;;     add score based on game result (part 1)
        ;;;     calculate (opponent's guess - your guess) % 3 into D2
        ;;;     0: tie
        ;;;     1: opponent won
        ;;;     2: you won
        MOVE.B  D0,D2
        SUB.B   D1,D2
        BPL.S   .diff_ok
        ADDQ.B  #3,D2
.diff_ok
        CMPI.B  #1,D2
        BEQ.S   .add_part2_move_points  ; 0 points for loss
        ADDQ.W  #3,(part1_score).L
        TST.B   D2
        BEQ.S   .add_part2_move_points  ; 3 points for tie
        ADDQ.W  #3,(part1_score).L
.add_part2_move_points
        ;;;     add score based on move you must make (part 2)
        ;;;     Formula (simplified in code):
        ;;;     (opponent's guess + result code - 1) % 3 + 1
        MOVE.B  D0,D2
        ADD.B   D1,D2
        BNE.S   .p2_move_points_no_underflow
        MOVEQ.L #3,D2
        BRA.S   .p2_move_points_no_overflow
.p2_move_points_no_underflow
        CMPI.B  #3,D2
        BLS.S   .p2_move_points_no_overflow
        SUBQ.B  #3,D2
.p2_move_points_no_overflow
        EXT.W   D2
        ADD.W   D2,(part2_score).L
        BRA.S   .count_score_loop
.end_count_score_loop

        MOVE.W  (part1_score).L,-(SP)
        LEA.L   (msg_rps_score_part1).L,A0
        JSR     printf

        MOVE.W  (part2_score).L,(SP)
        LEA.L   (msg_rps_score_part2).L,A0
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
msg_rps_score_part1     DC.B    "Total score (part 1): %d",10,0
msg_rps_score_part2     DC.B    "Total score (part 2): %d",10,0
emsg_invalid_line       DC.B    "Invalid RPS (line %d)",10,0

        BSS
                        EVEN
;;;                     these must remain adjacent in memory
part1_score             DS.W    1
part2_score             DS.W    1