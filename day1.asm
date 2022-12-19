        XDEF    setup_env,close_env
        XDEF    open_file,close_file
        XDEF    next_file_char
        XDEF    printf

        TEXT
start
        JSR     setup_env               ; A5 contains DOS library root
        TST.L   D0
        BEQ.W   .exit

        MOVE.L  #input_file_name,D1
        JSR     open_file               ; D4 contains file handle

        MOVEQ.L #0,D5                   ; length of currently loaded data

        ;;;     set top 3 calories to 0 initially
        LEA.L   (top_3_calories).L,A3
        CLR.L   (A3)+
        CLR.L   (A3)+
        CLR.L   (A3)
.find_largest_loop
        MOVEQ.L #0,D2           ; reset accumulator
.count_calories_loop
        JSR     next_number
        TST.L   D0
        BMI.S   .no_num
        ADD.L   D0,D2
        BRA.S   .count_calories_loop

.no_num
        MOVEQ.L #2,D0
        LEA.L   (top_3_calories).L,A3
.insert_calorie_loop
        MOVE.L  (A3),D3
        CMP.L   D2,D3
        BHS.S   .prev_higher_same
        EXG.L   D2,D3
.prev_higher_same
        MOVE.L  D3,(A3)+
        DBRA.W  D0,.insert_calorie_loop

.check_iterate
        TST.W   D5
        BPL.S   .find_largest_loop

        ;;     print results
        MOVE.L  (top_3_calories).L,D2
        MOVE.L  D2,-(SP)
        LEA.L   (msg_highest).L,A0
        JSR     printf
        ADD.L   (top_3_calories+4).L,D2
        ADD.L   (top_3_calories+8).L,D2
        MOVE.L  D2,(SP)
        LEA.L   (msg_sum_top_3).L,A0
        JSR     printf

        ADDQ.L  #4,SP   ; pop

        JSR     close_file
        JSR     close_env
.exit
        MOVEQ   #0,D0
        RTS

;;;     Read number until end of line or EOF.
;;;     Returns -1 if line is empty.
;;;
;;;     arguments:
;;;     D4.L    file handle
;;;     D5.W    length of remaining data in file buffer
;;;     A2.L    current pointer into file buffer
;;;     A5.L    DOS library handle
;;;
;;;     output:
;;;     D0.L:   Numerical value of positive integer on current line of file.
;;;             If line is empty or file is at EOF, -1.
next_number
        MOVEM.L D2-D3,-(SP)     ; preserve registers

        ;;;     Get first character in the line. If line-feed or EOF,
        ;;;     then line is empty. Return early.
        JSR     next_file_char
        TST.W   D5
        BMI.S   .ret_none
        CMPI.B  #10,D0
        BEQ.S   .ret_none

        MOVEQ.L #0,D2           ; set initial accumulator to 0
.loop
        ;;;     Add most recently read digit onto accumulator
        SUBI.B  #48,D0  ; get value from ASCII code
        ANDI.L  #$000000FF,D0
        ADD.L   D0,D2

        ;;;     Get next character. If line-feed or EOF, return.
        JSR     next_file_char
        TST.W   D5
        BMI.S   .ret
        CMPI.B  #10,D0
        BEQ.S   .ret

        ;;;     Multiply accumulator by 10
        LSL.L   #1,D2
        MOVE.L  D2,D3
        LSL.L   #2,D2
        ADD.L   D3,D2

        BRA.S   .loop

.ret_none
        MOVEQ.L #-1,D2          ; if line is empty, return -1
.ret
        MOVE.L  D2,D0
        MOVEM.L (SP)+,D2-D3     ; restore registers
        RTS


        DATA
input_file_name         DC.B    "input/day1.txt",0

msg_highest             DC.B    "Highest calorie is: %ld",10,0
msg_sum_top_3           DC.B    "Sum of top 3 calories is: %ld",10,0

        BSS
top_3_calories          DS.L    3