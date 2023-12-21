; EXAMPLE external command source code

%launcher none
%option no_sysinit
%zeropage basicsafe
%encoding iso
%address $4000

%import diskio

shell {
    romsub $06e0 = shell_print(str string @AY) clobbers(A,Y)
    romsub $06e3 = shell_print_uw(uword value @AY) clobbers(A,Y)
    romsub $06e6 = shell_print_uwhex(uword value @ AY, bool prefix @ Pc) clobbers(A,Y)
    romsub $06e9 = shell_print_uwbin(uword value @ AY, bool prefix @ Pc) clobbers(A,Y)
    romsub $06ec = shell_input_chars(uword buffer @ AY) clobbers(A) -> ubyte @Y
    romsub $06ef = shell_err_set(str message @AY) clobbers(Y) -> bool @A

    ; input registers set by shell upon calling your command:
    ;    cx16.r0 = command address
    ;    cx16.r1 = length of command (byte)
    ;    cx16.r2 = arguments address
    ;    cx16.r3 = length of arguments (byte)

    ; command should return error status in A. You can use err_set() to set a specific error message for the shell.
    ; command CAN use the FREE zero page locations.
    ; command CANNOT use memory below $4000 (the shell sits there)
    ; command CAN use Ram $0400-$06df.
}

main $4000 {
    %option force_output

    uword pp1_size = 0

    sub start()  {
        if not cx16.r3 {
            shell.shell_print("You need to provide file location for pp1 to load!")
            sys.exit(1)
        }
        shell.shell_print("Loading: ")
        shell.shell_print(cx16.r2)
        shell.shell_print(" from disk to addr: ")
        shell.shell_print_uwhex(pp1unpacker.address1,true)
        cbm.CHROUT('\r')
        bool is_file_opened = diskio.f_open(cx16.r2)
        if not is_file_opened {
            shell.shell_print("Cannot open file!")
            sys.exit(1)
        }
        pp1_size = diskio.load_raw(cx16.r2, pp1unpacker.PP1_LOAD_ADDR)
        shell.shell_print("Finished loading at addr: ")
        shell.shell_print_uwhex(pp1_size, true)
        pp1_size = pp1_size - pp1unpacker.address1
        shell.shell_print(" with size of ")
        shell.shell_print_uw(pp1_size)
        shell.shell_print(" bytes")
        cbm.CHROUT('\r')
        diskio.f_close()
        ; cleanup memory, easier to see what happened in emulator ;)
        uword addr = pp1unpacker.NES_CONVERTED_ADDR
        repeat {
            if addr == pp1unpacker.NES_CONVERTED_ADDR+$1000 {
                break
            }
            @(addr) = 0
            addr++
        }
        shell.shell_print("Starting unpacking process now!")
        cbm.CHROUT('\r')
        pp1unpacker.unpack()
        shell.shell_print("Finished unpacking process with following results:\rSize before: ")
        shell.shell_print_uw(pp1_size)
        shell.shell_print("\rSize after: ")
        shell.shell_print_uw(read_bytes_count)
        shell.shell_print("\rSaving to file: ")
        str fname = "                                 "
        ubyte i = 0
        repeat {
            fname[i] = @(cx16.r2 + i)
            if @(cx16.r2 + i) == 0 {
                break
            }
            i++
        }
        string.append(fname, ".CHR")
        shell.shell_print(fname)
        uword read_bytes_count = pp1unpacker.temp8 * 16
        void diskio.save_raw(fname,$7000,read_bytes_count)
        sys.exit(0)
    }
}

pp1unpacker {
    const uword PP1_LOAD_ADDR = $5000
    const uword NES_CONVERTED_ADDR = $7000
    uword[16] @requirezp @shared toplevvar1 = 0
    uword @requirezp @shared address1 = PP1_LOAD_ADDR
    uword[16] @requirezp @shared address2 = 0
    uword @requirezp @shared temp1 = 0
    uword @requirezp @shared temp2 = 0
    uword @requirezp @shared temp3 = 0
    uword @requirezp @shared temp4 = 0
    uword @requirezp @shared temp5 = 0
    uword @requirezp @shared temp6 = 0
    uword @requirezp @shared temp7 = 0
    uword @requirezp @shared temp8 = 0
    uword @requirezp @shared current_dump_addr = NES_CONVERTED_ADDR

    asmsub unpack() clobbers(A,X,Y) {
        ; This code was mostly taken from original Super Robin Hood source code published on github here:
        ; https://github.com/Wireframe-Magazine/Wireframe-34/tree/master
        ; Original code saves output into $2007 memory address which is NES PPU
        ; This code was modified to save output to NES_CONVERTED_ADDR.
        %asm {{
                adr1 = p8_address1
                adr1l = p8_address1
                adr1h = p8_address1+1

                pp1_zbuf = p8_toplevvar1
                pp1_types = p8_address2
                pp1_fol1 = pp1_types+4
                pp1_fol2 = pp1_types+8
                pp1_fol3 = pp1_types+12
            pp1_unpack:
                ldy #0
                lda (adr1), y
                sta p8_temp1
                sta p8_temp8
                iny
                
                lda #$80
                sta p8_temp2
            ; character loop start
            pp1_chrloop:
                ; is new header
                ; get bit into carry flag
                jsr pp1_getc
                bcs pp1_gotheader

                ; fetch header
                ldx #3

            _hl:
                jsr pp1_get2
                sta pp1_types,x
                beq _t0
                lsr a
                beq _t1
                bcc _t2
            ;type3
            _t3:
                jsr pp1_t3
                sta pp1_fol3, x
                jmp _t0
            ;type2
            _t2:
                jsr pp1_t3
                sta p8_temp3
                jsr pp1_getc
                bcc _t0
                lda p8_temp3
                sta pp1_fol2,x
                jmp _t0
            ;type1
            _t1:
                jsr pp1_t1
                sta pp1_fol1,x
            _t0:
                dex
                bpl _hl
            
            pp1_gotheader:
                ldx #7
            pp1_getline:
                stx p8_temp3
                ;line repetition?
                asl p8_temp2
                bcc _q10
                bne pp1_gotline
                jsr pp1_getq
                bcs pp1_gotline
            _q10:
                jsr pp1_get2
                tax

                sta p8_temp4
                lsr a
                ora #2
                sta p8_temp5

            _next:
                lda pp1_types,x
                beq _t0
                asl p8_temp2
                bcc _q11
                bne _t0
                jsr pp1_getq
                bcs _t0
            _q11:
                lda pp1_types,x
                lsr a
                beq _t1
                bcc _t2
            _t3:
                asl p8_temp2
                bcc _q12
                bne _t1
                jsr pp1_getq
                bcs _t1
            _q12:
                asl p8_temp2
                bcc _t2b
                bne _q13
                jsr pp1_getq
                bcc _t2b
            _q13:
                lda pp1_fol3,x
                tax
                jmp _p
            _t2:
                asl p8_temp2
                bcc _t1
                bne _q14
                jsr pp1_getq
                bcc _t1
            _q14:
            _t2b:
                lda pp1_fol2,x
                tax
                jmp _p
            _t1:
                lda pp1_fol1,x
                tax
                jmp _p
            _t0:
                txa
            _p:
                lsr a
                rol p8_temp4
                lsr a
                rol p8_temp5
                bcc _next
            
            pp1_gotline:
                ;store line
                lda p8_temp4
                sta (p8_current_dump_addr)
                lda #1
                clc
                adc p8_current_dump_addr
                sta p8_current_dump_addr
                bcc _continue1
                lda #0
                adc p8_current_dump_addr+1
                sta p8_current_dump_addr+1

            _continue1:
                ldx p8_temp3
                lda p8_temp5
                sta pp1_zbuf,x
                dex
                bpl pp1_getline

                ldx #7

            _bpl1:
                lda pp1_zbuf, x
                sta (p8_current_dump_addr)
                lda #1
                clc
                adc p8_current_dump_addr
                sta p8_current_dump_addr
                bcc _continue2
                lda #0
                adc p8_current_dump_addr+1
                sta p8_current_dump_addr+1
                lda pp1_zbuf, x
            _continue2:
                dex
                bpl _bpl1

                dec p8_temp1
                beq _done
                jmp pp1_chrloop
            _done:
                rts

            pp1_getc:
                asl p8_temp2
                beq _h0
                rts
            _h0:
            pp1_getq:
                lda (adr1),y
                iny
                bne _h2
                inc adr1h
            _h2:
                rol a
                sta p8_temp2
                rts

            pp1_get2:
                ;get b1
                asl p8_temp2
                bne _twenty

                lda (adr1),y
                iny
                bne _twentytwo
                inc adr1h
            _twentytwo:
                rol a
                sta p8_temp2
            _twenty:
                rol a
                and #1
                ; get b2
                asl p8_temp2
                beq _twentyone
                rol a
                rts
            _twentyone:
                pha
                lda (adr1),y
                iny
                bne _twentythree
                inc adr1h
            _twentythree:
                rol a
                sta p8_temp2
                pla
                rol a
                rts

            pp1_t1:
                jsr pp1_getc
                bcc _t1b
                lda pp1_fc1,x
                rts
            _t1b:
                jsr pp1_getc
                bcs _t1c
                lda pp1_fc2,x
                rts
            _t1c:
                lda pp1_fc3,x
                rts
            
            pp1_t3:
                jsr pp1_t1
                sta pp1_fol1,x
                beq _t30
                cmp #2
                bcc _t31
                beq _t32
            _t33:
                lda pp1_f3l,x
                sta pp1_fol2,x
                lda pp1_f3h,x
                rts
            _t32:
                lda pp1_f2l,x
                sta pp1_fol2,x
                lda pp1_f2h,x
                rts
            _t31:
                lda pp1_f1l,x
                sta pp1_fol2,x
                lda pp1_f1h,x
                rts
            _t30:
                lda pp1_f0l,x
                sta pp1_fol2,x
                lda pp1_f0h,x
                rts
            ; Tables used for unpacking data
            pp1_fc3: .byte $03, $03, $03
            pp1_fc2: .byte $02, $02, $01
            pp1_fc1: .byte $01, $00, $00, $00
            pp1_f0l: .byte $02, $02, $01
            pp1_f0h: .byte $03, $03, $03
            pp1_f1l: .byte $02, $FF, $00, $00
            pp1_f1h: .byte $03, $03, $03
            pp1_f2l: .byte $01, $00, $00, $00
            pp1_f2h: .byte $03, $03, $FF, $01
            pp1_f3l: .byte $01, $00, $00, $00
            pp1_f3h: .byte $02, $02, $01
        }}
    }
}
