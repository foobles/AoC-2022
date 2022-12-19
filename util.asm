        XDEF    setup_env,close_env
        XDEF    open_file,close_file
        XDEF    next_file_char
        XDEF    printf,print_and_exit_error
        XDEF    stdout

        INCLUDE "exec/exec.i"
        INCLUDE "dos/dos.i"

        XREF    _AbsExecBase
        XREF    _LVOOpenLibrary,_LVOCloseLibrary
        XREF    _LVOOpen,_LVOClose,_LVORead,_LVOWrite,_LVOOutput,_LVOIoErr
        XREF    _LVORawDoFmt

;;;     Setup basic working environment (stdout, load DOS, save SP).
;;;     Must be called first before anything else in program.
;;;
;;;     Output:
;;;     D0.L:   0 if unsuccessful, non-0 otherwise
;;;     A5.L:   DOS library root
setup_env
        LEA.L   (4,SP),A1       ; get root SP of process
        MOVE.L  A1,(root_sp).L  ; save initial stack pointer for early returns

        ;;;     open DOS library
        MOVEA.L _AbsExecBase,A6
        MOVEQ.L #0,D0
        LEA     (dos_lib_name).L,A1
        JSR     (_LVOOpenLibrary,A6)
        ;;;     exit program if opening DOS failed
        TST.L   D0
        BEQ.W   .exit
        MOVEA.L D0,A5                   ; A5 stores DOS root for remainder of program

        ;;;     save output handle for printing
        MOVEA.L A5,A6                   ; load DOS root
        JSR     (_LVOOutput,A6)
        MOVE.L  D0,(stdout).L           ; store handle to output stream
.exit
        RTS


;;;     Opens an existing file for reading. Exits program on failure.
;;;
;;;     Arguments:
;;;     D1.L:   null terminated file path
;;;     A5.L:   DOS library handle
;;;
;;;     Output:
;;;     D4.L:   file handle
open_file
        MOVE.L  D2,-(SP)        ; save D2
        MOVE.L  D1,-(SP)        ; save file path (bottom of stack for error printing)
        ;;;     open input file
        MOVEA.L A5,A6
        ;;;     D1.L already contains file path
        MOVE.L  #MODE_OLDFILE,D2
        JSR     (_LVOOpen,A6)
        MOVE.L  D0,D4
        BEQ.S   .file_err
        ADDQ.L  #4,SP           ; pop file path
        MOVE.L  (SP)+,D2        ; restore D2
        RTS
.file_err
        ;;;     if could not open file, print error message and exit
        ;;;     file name ptr already pushed to bottom of stack as format arg
        LEA.L   (emsg_open_file).L,A0
        JMP     print_and_exit_error


;;;     Closes file.
;;;
;;;     Arguments:
;;;     D4.L:   file handle
close_file
        MOVEA.L A5,A6
        MOVE.L  D4,D1
        JMP     (_LVOClose,A6)  ; tail call


;;;     Read a single character in from file. Performs buffered IO.
;;;
;;;     Arguments:
;;;     D4.L    file handle
;;;     D5.W    length of remaining data in file buffer (start with 0)
;;;     A2.L    current pointer into file buffer (can start uninitialized)
;;;     A5.L    DOS library handle
;;;
;;;     Output:
;;;     D0.B    next character
;;;     D5.W    updated remaining data in buffer. If -1, stream is over.
;;;     A2.L    updated pointer into file buffer
;;;
next_file_char
        DBRA.W  D5,.get_character

        ;;;     refill buffer if no remaining data
        MOVEM.L D2-D3,-(SP)
        MOVE.L  A5,A6
        MOVE.L  D4,D1
        MOVE.L  #file_data_buf,D2
        MOVE.L  #FILE_DATA_BUF_LEN,D3
        JSR     (_LVORead,A6)
        MOVEM.L (SP)+,D2-D3

        ;;;     Though Read() returns length written as a long, since the buffer
        ;;;     size fits in a word, we can reinterpret it as a word.
        ;;;     If -1 is returned to signify an error, this still applies.
        TST.W   D0
        BPL.S   .read_ok
        ;;;     exit with error if read returned negative number
        ;;;     get error code
        MOVEA.L A5,A6
        JSR     (_LVOIoErr,A6)
        MOVE.L  D0,-(SP)
        JSR     close_file
        ;;;     print and exit
        LEA.L   (emsg_read_file).L,A0
        JMP     print_and_exit_error

.read_ok
        MOVE.W  D0,D5                   ; reset counter of remaining data
        SUBQ.W  #1,D5                   ; we read 1 byte later on, so decrement
        LEA.L   (file_data_buf).L,A2    ; reset pointer

.get_character
        MOVE.B  (A2)+,D0
        RTS


;;;     Arguments:
;;;     A0.L    message pointer format string (null terminated)
;;;     A5.L    DOS library handle
;;;     (SP)    format values
;;;
;;;     Do not JSR to this function. Jump directly instead since is always a tail call.
;;;     Using JSR will corrupt the list of format values.
print_and_exit_error
        JSR     printf
        JSR     close_env
        ;;;     exit program
        MOVEA.L (root_sp).L,SP
        MOVEQ   #10,D0
        RTS

;;;     arguments:
;;;     A5.L    DOS library handle
close_env
        ;;; close dos
        MOVEA.L _AbsExecBase,A6
        MOVEA.L A5,A1
        JMP     (_LVOCloseLibrary,A6)   ; tail call


;;;     Arguments:
;;;     A0.L    pointer to null terminated format string
;;;     A5.L    DOS library handle
;;;     (SP)    format values
;;;
;;;     Preserves D2-D7 and A2-A5
;;;     Overwrites scratch buffer.
;;;     Length of printed string (not including null byte) returned in (length).
printf
        MOVEM.L D2-D3/A2-A3,-(SP)       ; preserve registers
        MOVE.W  #-1,(string_len).L      ; keep track of string length (minus null byte)

        ;;;     format string into scratch buffer
        MOVEA.L (_AbsExecBase).W,A6
        ;;;     first argument already provided in A0
        LEA.L   (5*4,SP),A1              ; pointer to array of values on the stack (after return addr)
        LEA.L   (.push_char,PC),A2       ; function to emplace characters
        LEA.L   (string_format_buf).L,A3 ; output buffer
        JSR     (_LVORawDoFmt,A6)

        ;;;     print
        MOVEA.L A5,A6                   ; load DOS library
        MOVE.L  (stdout).L,D1           ; set output to stdout
        MOVE.L  #string_format_buf,D2   ; print from scratch buffer
        MOVE.W  (string_len).L,D3       ; get string length
        EXT.L   D3
        JSR     (_LVOWrite,A6)

        MOVEM.L (SP)+,D2-D3/A2-A3       ; restore registers
        RTS

        ;;;     local function for use with RawDoFmt
.push_char
        MOVE.B  D0,(A3)+                ; write character and increment address
        ADDQ.W  #1,(string_len).L       ; increment length
        RTS


        DATA
dos_lib_name            DOSNAME
emsg_open_file          DC.B    "Could not open file '%s'",10,0
emsg_read_file          DC.B    "Error reading from file: %ld",10,0


        BSS
stdout                  DS.L    1
root_sp                 DS.L    1

FILE_DATA_BUF_LEN       EQU     512
file_data_buf           DS.B    FILE_DATA_BUF_LEN

                        EVEN
STRING_FORMAT_BUF_LEN   EQU     140
string_len              DS.W    1
string_format_buf       DS.B    STRING_FORMAT_BUF_LEN
