; ==================================================================
; MikeOS -- The Mike Operating System kernel
; Copyright (C) 2006 - 2013 MikeOS Developers -- see doc/LICENSE.TXT
;
; BASIC CODE INTERPRETER (4.4)
; ==================================================================
; ------------------------------------------------------------------
; Token types
DEFINE VARIABLE 1
DEFINE STRING_VAR 2
DEFINE NUMBER 3
DEFINE STRING 4
DEFINE QUOTE 5
DEFINE CHAR 6
DEFINE UNKNOWN 7
DEFINE LABEL 8
; ------------------------------------------------------------------
; The BASIC interpreter execution starts here -- a parameter string
; is passed in SI and copied into the first string, unless SI = 0
os_run_basic:
  mov DWORD [orig_stack], esp           ; Save stack pointer -- we might jump to the
                                        ; error printing code and quit in the middle
                                        ; some nested loops, and we want to preserve
                                        ; the stack
  mov DWORD [load_point], eax           ; AX was passed as starting location of code
  mov DWORD [prog], eax                 ; prog = pointer to current execution point in code
  add ebx, eax                          ; We were passed the .BAS byte size in BX
  dec ebx
  dec ebx
  mov DWORD [prog_end], ebx             ; Make note of program end point
  call clear_ram                        ; Clear variables etc. from previous run
                                        ; of a BASIC program
  cmp esi, 0                            ; Passed a parameter string?
  je mainloop
  mov edi, string_vars                  ; If so, copy it into $1
  call os_string_copy
mainloop:
  call get_token                        ; Get a token from the start of the line
  cmp eax, STRING                       ; Is the type a string of characters?
  je .keyword                           ; If so, let's see if it's a keyword to process
  cmp eax, VARIABLE                     ; If it's a variable at the start of the line,
  je assign                             ; this is an assign (eg "X = Y + 5")
  cmp eax, STRING_VAR                   ; Same for a string variable (eg $1)
  je assign
  cmp eax, LABEL                        ; Don't need to do anything here - skip
  je mainloop
  mov esi, err_syntax                   ; Otherwise show an error and quit
  jmp error
.keyword:
  mov esi, token                        ; Start trying to match commands
  mov edi, alert_cmd
  call os_string_compare
  jc do_alert
  mov edi, askfile_cmd
  call os_string_compare
  jc do_askfile
  mov edi, break_cmd
  call os_string_compare
  jc do_break
  mov edi, case_cmd
  call os_string_compare
  jc do_case
  mov edi, call_cmd
  call os_string_compare
  jc do_call
  mov edi, cls_cmd
  call os_string_compare
  jc do_cls
  mov edi, cursor_cmd
  call os_string_compare
  jc do_cursor
  mov edi, curschar_cmd
  call os_string_compare
  jc do_curschar
  mov edi, curscol_cmd
  call os_string_compare
  jc do_curscol
  mov edi, curspos_cmd
  call os_string_compare
  jc do_curspos
  
  mov edi, delete_cmd
  call os_string_compare
  jc do_delete
  
  mov edi, do_cmd
  call os_string_compare
  jc do_do
  mov edi, end_cmd
  call os_string_compare
  jc do_end
  mov edi, else_cmd
  call os_string_compare
  jc do_else
  mov edi, files_cmd
  call os_string_compare
  jc do_files
  mov edi, for_cmd
  call os_string_compare
  jc do_for
  mov edi, getkey_cmd
  call os_string_compare
  jc do_getkey
  mov edi, gosub_cmd
  call os_string_compare
  jc do_gosub
  mov edi, goto_cmd
  call os_string_compare
  jc do_goto
  mov edi, if_cmd
  call os_string_compare
  jc do_if
  mov edi, include_cmd
  call os_string_compare
  jc do_include
  mov edi, ink_cmd
  call os_string_compare
  jc do_ink
  mov edi, input_cmd
  call os_string_compare
  jc do_input
  
  mov edi, len_cmd
  call os_string_compare
  jc do_len
  mov edi, listbox_cmd
  call os_string_compare
  jc do_listbox
  mov edi, load_cmd
  call os_string_compare
  jc do_load
  mov edi, loop_cmd
  call os_string_compare
  jc do_loop
  mov edi, move_cmd
  call os_string_compare
  jc do_move
  mov edi, next_cmd
  call os_string_compare
  jc do_next
  mov edi, number_cmd
  call os_string_compare
  jc do_number
  mov edi, page_cmd
  call os_string_compare
  jc do_page
  mov edi, pause_cmd
  call os_string_compare
  jc do_pause
  mov edi, peek_cmd
  call os_string_compare
  jc do_peek
  mov edi, peekint_cmd
  call os_string_compare
  jc do_peekint
  
  mov edi, poke_cmd
  call os_string_compare
  jc do_poke
  
  mov edi, pokeint_cmd
  call os_string_compare
  jc do_pokeint
  mov edi, port_cmd
  call os_string_compare
  jc do_port
  mov edi, print_cmd
  call os_string_compare
  jc do_print
  mov edi, rand_cmd
  call os_string_compare
  jc do_rand
  mov edi, read_cmd
  call os_string_compare
  jc do_read
  mov edi, rem_cmd
  call os_string_compare
  jc do_rem
  mov edi, rename_cmd
  call os_string_compare
  jc do_rename
  mov edi, return_cmd
  call os_string_compare
  jc do_return
  mov edi, save_cmd
  call os_string_compare
  jc do_save
  mov edi, serial_cmd
  call os_string_compare
  jc do_serial
  mov edi, size_cmd
  call os_string_compare
  jc do_size
  mov edi, sound_cmd
  call os_string_compare
  jc do_sound
  
  mov edi, string_cmd
  call os_string_compare
  jc do_string
  mov edi, waitkey_cmd
  call os_string_compare
  jc do_waitkey
  mov esi, err_cmd_unknown              ; Command not found?
  jmp error
; ------------------------------------------------------------------
; CLEAR RAM
clear_ram:
  pusha
  mov eax, 0
  mov edi, variables
  mov ecx, 26
  rep stosd
  mov edi, for_variables
  mov ecx, 26
  rep stosd
  mov edi, for_code_points
  mov ecx, 26
  rep stosd
  
  mov edi, do_loop_store
  mov ecx, 10
  rep stosd
  mov BYTE [gosub_depth], 0
  mov BYTE [loop_in], 0
  mov edi, gosub_points
  mov ecx, 10
  rep stosd
  mov edi, string_vars
  mov ecx, 1024
  rep stosb
  mov BYTE [ink_colour], 7              ; White ink
  popa
  ret
; ------------------------------------------------------------------
; ASSIGNMENT
assign:
  cmp eax, VARIABLE                     ; Are we starting with a number var?
  je .do_num_var
  mov edi, string_vars                  ; Otherwise it's a string var
  mov eax, 128
  mul ebx                               ; (BX = string number, passed back from get_token)
  add edi, eax
  push edi
  call get_token
  mov al, [token]
  cmp al, '='
  jne .error
  call get_token                        ; See if second is quote
  cmp eax, QUOTE
  je .second_is_quote
  cmp eax, STRING_VAR
  jne .error
  mov esi, string_vars                  ; Otherwise it's a string var
  mov eax, 128
  mul ebx                               ; (BX = string number, passed back from get_token)
  add esi, eax
  pop edi
  call os_string_copy
  jmp .string_check_for_more
.second_is_quote:
  mov esi, token
  pop edi
  call os_string_copy
.string_check_for_more:
  push edi
  mov eax, [prog]                       ; Save code location in case there's no delimiter
  mov DWORD [.tmp_loc], eax
  call get_token                        ; Any more to deal with in this assignment?
  mov al, [token]
  cmp al, '+'
  je .string_theres_more
  mov eax, [.tmp_loc]                   ; Not a delimiter, so step back before the token
  mov DWORD [prog], eax                 ; that we just grabbed
  pop edi
  jmp mainloop                          ; And go back to the code interpreter!
.string_theres_more:
  call get_token
  cmp eax, STRING_VAR
  je .another_string_var
  cmp eax, QUOTE
  je .another_quote
  cmp eax, VARIABLE
  je .add_number_var
  jmp .error
.another_string_var:
  pop edi
  mov esi, string_vars
  mov eax, 128
  mul ebx                               ; (BX = string number, passed back from get_token)
  add esi, eax
  mov eax, edi
  mov ecx, edi
  mov ebx, esi
  call os_string_join
  jmp .string_check_for_more
.another_quote:
  pop edi
  mov eax, edi
  mov ecx, edi
  mov ebx, token
  call os_string_join
  jmp .string_check_for_more
.add_number_var:
  mov eax, 0
  mov al, [token]
  call get_var
  call os_int_to_string
  mov ebx, eax
  pop edi
  mov eax, edi
  mov ecx, edi
  call os_string_join
  jmp .string_check_for_more
  
.do_num_var:
  mov eax, 0
  mov al, [token]
  mov BYTE [.tmp], al
  call get_token
  mov al, [token]
  cmp al, '='
  jne .error
  call get_token
  cmp eax, NUMBER
  je .second_is_num
  cmp eax, VARIABLE
  je .second_is_variable
  cmp eax, STRING
  je .second_is_string
  cmp eax, UNKNOWN
  jne .error
  mov al, [token]                       ; Address of string var?
  cmp al, '&'
  jne .error
  call get_token                        ; Let's see if there's a string var
  cmp eax, STRING_VAR
  jne .error
  mov edi, string_vars
  mov eax, 128
  mul ebx
  add edi, eax
  mov ebx, edi
  mov al, [.tmp]
  call set_var
  jmp mainloop
.second_is_variable:
  mov eax, 0
  mov al, [token]
  call get_var
  mov ebx, eax
  mov al, [.tmp]
  call set_var
  jmp .check_for_more
.second_is_num:
  mov esi, token
  call os_string_to_int
  mov ebx, eax                          ; Number to insert in variable table
  mov eax, 0
  mov al, [.tmp]
  call set_var
                                        ; The assignment could be simply "X = 5" etc. Or it could be
                                        ; "X = Y + 5" -- ie more complicated. So here we check to see if
                                        ; there's a delimiter...
.check_for_more:
  mov eax, [prog]                       ; Save code location in case there's no delimiter
  mov DWORD [.tmp_loc], eax
  call get_token                        ; Any more to deal with in this assignment?
  mov al, [token]
  cmp al, '+'
  je .theres_more
  cmp al, '-'
  je .theres_more
  cmp al, '*'
  je .theres_more
  cmp al, '/'
  je .theres_more
  cmp al, '%'
  je .theres_more
  mov eax, [.tmp_loc]                   ; Not a delimiter, so step back before the token
  mov DWORD [prog], eax                 ; that we just grabbed
  jmp mainloop                          ; And go back to the code interpreter!
.theres_more:
  mov BYTE [.delim], al
  call get_token
  cmp eax, VARIABLE
  je .handle_variable
  mov esi, token
  call os_string_to_int
  mov ebx, eax
  mov eax, 0
  mov al, [.tmp]
  call get_var                          ; This also points SI at right place in variable table
  cmp BYTE [.delim], '+'
  jne .not_plus
  add eax, ebx
  jmp .finish
.not_plus:
  cmp BYTE [.delim], '-'
  jne .not_minus
  sub eax, ebx
  jmp .finish
.not_minus:
  cmp BYTE [.delim], '*'
  jne .not_times
  mul ebx
  jmp .finish
.not_times:
  cmp BYTE [.delim], '/'
  jne .not_divide
  cmp ebx, 0
  je .divide_zero
  
  mov edx, 0
  div ebx
  jmp .finish
.not_divide:
  mov edx, 0
  div ebx
  mov eax, edx                          ; Get remainder
.finish:
  mov ebx, eax
  mov al, [.tmp]
  call set_var
  jmp .check_for_more
.divide_zero:
  mov esi, err_divide_by_zero
  jmp error
  
.handle_variable:
  mov eax, 0
  mov al, [token]
  call get_var
  mov ebx, eax
  mov eax, 0
  mov al, [.tmp]
  call get_var
  cmp BYTE [.delim], '+'
  jne .vnot_plus
  add eax, ebx
  jmp .vfinish
.vnot_plus:
  cmp BYTE [.delim], '-'
  jne .vnot_minus
  sub eax, ebx
  jmp .vfinish
.vnot_minus:
  cmp BYTE [.delim], '*'
  jne .vnot_times
  mul ebx
  jmp .vfinish
.vnot_times:
  cmp BYTE [.delim], '/'
  jne .vnot_divide
  mov edx, 0
  div ebx
  jmp .finish
.vnot_divide:
  mov edx, 0
  div ebx
  mov eax, edx                          ; Get remainder
.vfinish:
  mov ebx, eax
  mov al, [.tmp]
  call set_var
  jmp .check_for_more
.second_is_string:                      ; These are "X = word" functions
  mov edi, token
  
  mov esi, ink_keyword
  call os_string_compare
  je .is_ink
  
  mov esi, progstart_keyword
  call os_string_compare
  je .is_progstart
  mov esi, ramstart_keyword
  call os_string_compare
  je .is_ramstart
  mov esi, timer_keyword
  call os_string_compare
  je .is_timer
  
  mov esi, variables_keyword
  call os_string_compare
  je .is_variables
  
  mov esi, version_keyword
  call os_string_compare
  je .is_version
  jmp .error
.is_ink:
  mov eax, 0
  mov al, [.tmp]
  
  mov ebx, 0
  mov bl, [ink_colour]
  call set_var
  
  jmp mainloop
.is_progstart:
  mov eax, 0
  mov al, [.tmp]
  mov ebx, [load_point]
  call set_var
  jmp mainloop
.is_ramstart:
  mov eax, 0
  mov al, [.tmp]
  mov ebx, [prog_end]
  inc ebx
  inc ebx
  inc ebx
  call set_var
  jmp mainloop
.is_timer:
  mov ah, 0
  int 1Ah
  mov ebx, edx
  mov eax, 0
  mov al, [.tmp]
  call set_var
  jmp mainloop
.is_variables:
  mov ebx, vars_loc
  mov eax, 0
  mov al, [.tmp]
  call set_var
  jmp mainloop
.is_version:
  call os_get_api_version
  
  mov ebx, 0
  mov bl, al
  mov al, [.tmp]
  call set_var
  
  jmp mainloop 
.error:
  mov esi, err_syntax
  jmp error
  .tmp db 0
  .tmp_loc dd 0
  .delim db 0
; ==================================================================
; SPECIFIC COMMAND CODE STARTS HERE
; ------------------------------------------------------------------
; ALERT
do_alert:
  mov bh, [work_page]                   ; Store the cursor position
  mov ah, 03h
  int 10h
  call get_token
  cmp eax, QUOTE
  je .is_quote
  
  cmp eax, STRING_VAR
  je .is_string
  mov esi, err_syntax
  jmp error
.is_string:
  mov esi, string_vars
  mov eax, 128
  mul ebx
  add eax, esi
  jmp .display_message
  
.is_quote:
  mov eax, token                        ; First string for alert box
  
.display_message:
  mov ebx, 0                            ; Others are blank
  mov ecx, 0
  mov edx, 0                            ; One-choice box
  call os_dialog_box
  
  mov bh, [work_page]                   ; Move the cursor back
  mov ah, 02h
  int 10h
  
  jmp mainloop
;-------------------------------------------------------------------
; ASKFILE
do_askfile:
  mov bh, [work_page]                   ; Store the cursor position
  mov ah, 03h
  int 10h
  
  call get_token
  
  cmp eax, STRING_VAR
  jne .error
  
  mov esi, string_vars                  ; Get the string location
  mov eax, 128
  mul ebx
  add eax, esi
  mov DWORD [.tmp], eax
  
  call os_file_selector                 ; Present the selector
  
  mov DWORD edi, [.tmp]                 ; Copy the string
  mov esi, eax
  call os_string_copy
  mov bh, [work_page]                   ; Move the cursor back
  mov ah, 02h
  int 10h
  
  jmp mainloop
  
.error:
  mov esi, err_syntax
  jmp error
.data:
  .tmp dd 0
; ------------------------------------------------------------------
; BREAK
do_break:
  mov esi, err_break
  jmp error
; ------------------------------------------------------------------
; CALL
do_call:
  call get_token
  cmp eax, NUMBER
  je .is_number
  mov eax, 0
  mov al, [token]
  call get_var
  jmp .execute_call
.is_number:
  mov esi, token
  call os_string_to_int
.execute_call:
  mov ebx, 0
  mov ecx, 0
  mov edx, 0
  mov edi, 0
  mov esi, 0
  call eax
  jmp mainloop
; ------------------------------------------------------------------
; CASE
do_case:
  call get_token
  cmp eax, STRING
  jne .error
  
  mov esi, token
  mov edi, upper_keyword
  call os_string_compare
  jc .uppercase
  
  mov edi, lower_keyword
  call os_string_compare
  jc .lowercase
  
  jmp .error
  
.uppercase:
  call get_token
  cmp eax, STRING_VAR
  jne .error
  
  mov esi, string_vars
  mov eax, 128
  mul ebx
  add eax, esi
  
  call os_string_uppercase
  
  jmp mainloop
  
.lowercase:
  call get_token
  cmp eax, STRING_VAR
  jne .error
  
  mov esi, string_vars
  mov eax, 128
  mul ebx
  add eax, esi
  
  call os_string_lowercase
  
  jmp mainloop
  
.error:
  mov esi, err_syntax
  jmp error
; ------------------------------------------------------------------
; CLS
do_cls:
  mov ah, 5
  mov al, [work_page]
  int 10h
  call os_clear_screen
  mov ah, 5
  mov al, [disp_page]
  int 10h
  jmp mainloop
; ------------------------------------------------------------------
; CURSOR
do_cursor:
  call get_token
  mov esi, token
  mov edi, .on_str
  call os_string_compare
  jc .turn_on
  mov esi, token
  mov edi, .off_str
  call os_string_compare
  jc .turn_off
  mov esi, err_syntax
  jmp error
.turn_on:
  call os_show_cursor
  jmp mainloop
.turn_off:
  call os_hide_cursor
  jmp mainloop
  .on_str db "ON", 0
  .off_str db "OFF", 0
; ------------------------------------------------------------------
; CURSCHAR
do_curschar:
  call get_token
  cmp eax, VARIABLE
  je .is_variable
  mov esi, err_syntax
  jmp error
.is_variable:
  mov eax, 0
  mov al, [token]
  push eax                              ; Store variable we're going to use
  mov ah, 08h
  mov ebx, 0
  mov bh, [work_page]
  int 10h                               ; Get char at current cursor location
  mov ebx, 0                            ; We only want the lower byte (the char, not attribute)
  mov bl, al
  pop eax                               ; Get the variable back
  call set_var                          ; And store the value
  jmp mainloop
; ------------------------------------------------------------------
; CURSCOL
do_curscol:
  call get_token
  cmp eax, VARIABLE
  jne .error
  mov eax, 0
  mov al, [token]
  push eax
  mov ah, 8
  mov ebx, 0
  mov bh, [work_page]
  int 10h
  mov ebx, 0
  mov bl, ah                            ; Get colour for higher byte; ignore lower byte (char)
  pop eax
  call set_var
  jmp mainloop
.error:
  mov esi, err_syntax
  jmp error
; ------------------------------------------------------------------
; CURSPOS
do_curspos:
  mov bh, [work_page]
  mov ah, 3
  int 10h
  call get_token
  cmp eax, VARIABLE
  jne .error
  mov eax, 0                                         ; Get the column in the first variable
  mov al, [token]
  mov ebx, 0
  mov bl, dl
  call set_var
  call get_token
  cmp eax, VARIABLE
  jne .error
  mov eax, 0                                         ; Get the row to the second
  mov al, [token]
  mov ebx, 0
  mov bl, dh
  call set_var
  jmp mainloop
.error:
  mov esi, err_syntax
  jmp error
; ------------------------------------------------------------------
; DELETE
do_delete:
  call get_token
  cmp eax, QUOTE
  je .is_quote
  cmp eax, STRING_VAR
  jne .error
  mov esi, string_vars
  mov eax, 128
  mul ebx
  add esi, eax
  jmp .get_filename
.is_quote:
  mov esi, token
.get_filename:
  mov eax, esi
  call os_file_exists
  jc .no_file
  call os_remove_file
  jc .del_fail
  jmp .returngood
.no_file:
  mov eax, 0
  mov al, 'R'
  mov ebx, 2
  call set_var
  jmp mainloop
.returngood:
  mov eax, 0
  mov al, 'R'
  mov ebx, 0
  call set_var
  jmp mainloop
.del_fail:
  mov eax, 0
  mov al, 'R'
  mov ebx, 1
  call set_var
  jmp mainloop
.error:
  mov esi, err_syntax
  jmp error
  
; ------------------------------------------------------------------
; DO
do_do:
  cmp BYTE [loop_in], 40
  je .loop_max
  mov DWORD edi, do_loop_store
  mov al, [loop_in]
  and eax, 0FFh
  add edi, eax
  mov eax, [prog]
  sub eax, 3
  stosd
  add BYTE [loop_in], 4
  jmp mainloop
.loop_max:
  mov esi, err_doloop_maximum
  jmp error
  
;-------------------------------------------------------------------
; ELSE
do_else:
  cmp BYTE [last_if_true], 1
  je .last_true
  
  inc DWORD [prog]
  jmp mainloop
  
.last_true:
  mov DWORD esi, [prog]
  
.next_line:
  lodsb
  cmp al, 10
  jne .next_line
  
  dec esi
  mov DWORD [prog], esi
  
  jmp mainloop
; ------------------------------------------------------------------
; END
do_end:
  mov ah, 5                             ; Restore active page
  mov al, 0
  int 10h
  mov BYTE [work_page], 0
  mov BYTE [disp_page], 0
  mov DWORD esp, [orig_stack]
  ret
; ------------------------------------------------------------------
; FILES
do_files:
  mov eax, .filelist                    ; get a copy of the filelist
  call os_get_file_list
  
  mov esi, eax
  call os_get_cursor_pos                ; move cursor to start of line
  mov dl, 0
  call os_move_cursor
  
  mov ah, 9                             ; print character function
  mov bh, [work_page]                   ; define parameters (page, colour, times)
  mov bl, [ink_colour]
  mov ecx, 1
.file_list_loop:
  lodsb                                 ; get a byte from the list
  cmp al, ','                           ; a comma means the next file, so create a new line for it
  je .nextfile
  
  cmp al, 0                             ; the list is null terminated
  je .end_of_list
  
  int 10h                               ; okay, it's not a comma or a null so print it
  call os_get_cursor_pos                ; find the location of the cursor
  inc dl                                ; move the cursor forward
  call os_move_cursor
  jmp .file_list_loop                   ; keep going until the list is finished
  
.nextfile:
  call os_get_cursor_pos                ; if the column is over 60 we need a new line
  cmp dl, 60
  jge .newline
.next_column:                           ; print spaces until the next column
  mov al, ' '
  int 10h
  
  inc dl
  call os_move_cursor
  
  cmp dl, 15
  je .file_list_loop
  
  cmp dl, 30
  je .file_list_loop
  
  cmp dl, 45
  je .file_list_loop
  
  cmp dl, 60
  je .file_list_loop
  
  jmp .next_column
  
.newline:
  call os_print_newline                 ; create a new line
  jmp .file_list_loop
  
.end_of_list:
  call os_print_newline
  jmp mainloop                          ; preform next command
  
.data:
  .filelist: times 256 db 0
  
; ------------------------------------------------------------------
; FOR
do_for:
  call get_token                        ; Get the variable we're using in this loop
  cmp eax, VARIABLE
  jne .error
  mov eax, 0
  mov al, [token]
  mov BYTE [.tmp_var], al               ; Store it in a temporary location for now
  call get_token
  mov eax, 0                            ; Check it's followed up with '='
  mov al, [token]
  cmp al, '='
  jne .error
  call get_token                        ; Next we want a number
  cmp eax, VARIABLE
  je .first_is_var
  cmp eax, NUMBER
  jne .error
  mov esi, token                        ; Convert it
  call os_string_to_int
  jmp .continue
.first_is_var:
  mov eax, 0                            ; It's a variable, so get it's value
  mov al, [token]
  call get_var
  
                                        ; At this stage, we've read something like "FOR X = 1"
                                        ; so let's store that 1 in the variable table
.continue:
  mov ebx, eax
  mov eax, 0
  mov al, [.tmp_var]
  call set_var
  call get_token                        ; Next we're looking for "TO"
  cmp eax, STRING
  jne .error
  mov eax, token
  call os_string_uppercase
  mov esi, token
  mov edi, .to_string
  call os_string_compare
  jnc .error
                                        ; So now we're at "FOR X = 1 TO"
  call get_token
  cmp eax, VARIABLE
  je .second_is_var
  cmp eax, NUMBER
  jne .error
.second_is_number:
  mov esi, token                        ; Get target number
  call os_string_to_int
  jmp .continue2
.second_is_var:
  mov eax, 0                            ; It's a variable, so get it's value
  mov al, [token]
  call get_var
.continue2:
  mov ebx, eax
  mov eax, 0
  mov al, [.tmp_var]
  sub al, 65                            ; Store target number in table
  mov edi, for_variables
  lea edi, [edi+eax*4]
  mov eax, ebx
  stosd
                                        ; So we've got the variable, assigned it the starting number, and put into
                                        ; our table the limit it should reach. But we also need to store the point in
                                        ; code after the FOR line we should return to if NEXT X doesn't complete the loop...
  mov eax, 0
  mov al, [.tmp_var]
  sub al, 65                            ; Store code position to return to in table
  mov edi, for_code_points
  lea edi, [edi+eax*4]
  mov eax, [prog]
  stosd
  jmp mainloop
.error:
  mov esi, err_syntax
  jmp error
  .tmp_var db 0
  .to_string db 'TO', 0
; ------------------------------------------------------------------
; GETKEY
do_getkey:
  call get_token
  cmp eax, VARIABLE
  je .is_variable
  mov esi, err_syntax
  jmp error
.is_variable:
  mov eax, 0
  mov al, [token]
  push eax
  call os_check_for_key
  cmp eax, 48E0h
  je .up_pressed
  cmp eax, 50E0h
  je .down_pressed
  cmp eax, 4BE0h
  je .left_pressed
  cmp eax, 4DE0h
  je .right_pressed
.store: 
  mov ebx, 0
  mov bl, al
  
  pop eax
  call set_var
  jmp mainloop
.up_pressed:
  mov eax, 1
  jmp .store
.down_pressed:
  mov eax, 2
  jmp .store
.left_pressed:
  mov eax, 3
  jmp .store
.right_pressed:
  mov eax, 4
  jmp .store
; ------------------------------------------------------------------
; GOSUB
do_gosub:
  call get_token                        ; Get the number (label)
  cmp eax, STRING
  je .is_ok
  mov esi, err_goto_notlabel
  jmp error
.is_ok:
  mov esi, token                        ; Back up this label
  mov edi, .tmp_token
  call os_string_copy
  mov eax, .tmp_token
  call os_string_length
  mov edi, .tmp_token                   ; Add ':' char to end for searching
  add edi, eax
  mov al, ':'
  stosb
  mov al, 0
  stosb 
  inc BYTE [gosub_depth]
  mov eax, 0
  mov al, [gosub_depth]                 ; Get current GOSUB nest level
  cmp al, 9
  jle .within_limit
  mov esi, err_nest_limit
  jmp error
.within_limit:
  mov edi, gosub_points                 ; Move into our table of pointers
  lea edi, [edi+eax*4]                  ; Table is words (not bytes)
  mov eax, [prog]
  stosd                                 ; Store current location before jump
  mov eax, [load_point]
  mov DWORD [prog], eax                 ; Return to start of program to find label
.loop:
  call get_token
  cmp eax, LABEL
  jne .line_loop
  mov esi, token
  mov edi, .tmp_token
  call os_string_compare
  jc mainloop
.line_loop:                             ; Go to end of line
  mov DWORD esi, [prog]
  mov al, [esi]
  inc DWORD [prog]
  cmp al, 10
  jne .line_loop
  mov eax, [prog]
  mov ebx, [prog_end]
  cmp eax, ebx
  jg .past_end
  jmp .loop
.past_end:
  mov esi, err_label_notfound
  jmp error
  .tmp_token: times 30 db 0
; ------------------------------------------------------------------
; GOTO
do_goto:
  call get_token                        ; Get the next token
  cmp eax, STRING
  je .is_ok
  mov esi, err_goto_notlabel
  jmp error
.is_ok:
  mov esi, token                        ; Back up this label
  mov edi, .tmp_token
  call os_string_copy
  mov eax, .tmp_token
  call os_string_length
  mov edi, .tmp_token                   ; Add ':' char to end for searching
  add edi, eax
  mov al, ':'
  stosb
  mov al, 0
  stosb 
  mov eax, [load_point]
  mov DWORD [prog], eax                 ; Return to start of program to find label
.loop:
  call get_token
  cmp eax, LABEL
  jne .line_loop
  mov esi, token
  mov edi, .tmp_token
  call os_string_compare
  jc mainloop
.line_loop:                             ; Go to end of line
  mov DWORD esi, [prog]
  mov al, [esi]
  inc DWORD [prog]
  cmp al, 10
  jne .line_loop
  mov eax, [prog]
  mov ebx, [prog_end]
  cmp eax, ebx
  jg .past_end
  jmp .loop
.past_end:
  mov esi, err_label_notfound
  jmp error
  .tmp_token: times 30 db 0
; ------------------------------------------------------------------
; IF
do_if:
  call get_token
  cmp eax, VARIABLE                     ; If can only be followed by a variable
  je .num_var
  cmp eax, STRING_VAR
  je .string_var
  mov esi, err_syntax
  jmp error
.num_var:
  mov eax, 0
  mov al, [token]
  call get_var
  mov edx, eax                          ; Store value of first part of comparison
  call get_token                        ; Get the delimiter
  mov al, [token]
  cmp al, '='
  je .equals
  cmp al, '>'
  je .greater
  cmp al, '<'
  je .less
  mov esi, err_syntax                   ; If not one of the above, error out
  jmp error
.equals:
  call get_token                        ; Is this 'X = Y' (equals another variable?)
  cmp eax, CHAR
  je .equals_char
  mov al, [token]
  call is_letter
  jc .equals_var
  mov esi, token                        ; Otherwise it's, eg 'X = 1' (a number)
  call os_string_to_int
  cmp eax, edx                          ; On to the THEN bit if 'X = num' matches
  je .on_to_then
  jmp .finish_line                      ; Otherwise skip the rest of the line
.equals_char:
  mov eax, 0
  mov al, [token]
  cmp eax, edx
  je .on_to_then
  jmp .finish_line
.equals_var:
  mov eax, 0
  mov al, [token]
  call get_var
  cmp eax, edx                          ; Do the variables match?
  je .on_to_then                        ; On to the THEN bit if so
  jmp .finish_line                      ; Otherwise skip the rest of the line
.greater:
  call get_token                        ; Greater than a variable or number?
  mov al, [token]
  call is_letter
  jc .greater_var
  mov esi, token                        ; Must be a number here...
  call os_string_to_int
  cmp eax, edx
  jl .on_to_then
  jmp .finish_line
.greater_var:                           ; Variable in this case
  mov eax, 0
  mov al, [token]
  call get_var
  cmp eax, edx                          ; Make the comparison!
  jl .on_to_then
  jmp .finish_line
.less:
  call get_token
  mov al, [token]
  call is_letter
  jc .less_var
  mov esi, token
  call os_string_to_int
  cmp eax, edx
  jg .on_to_then
  jmp .finish_line
.less_var:
  mov eax, 0
  mov al, [token]
  call get_var
  cmp eax, edx
  jg .on_to_then
  jmp .finish_line
.string_var:
  mov BYTE [.tmp_string_var], bl
  call get_token
  mov al, [token]
  cmp al, '='
  jne .error
  call get_token
  cmp eax, STRING_VAR
  je .second_is_string_var
  cmp eax, QUOTE
  jne .error
  mov esi, string_vars
  mov eax, 128
  mul ebx
  add esi, eax
  mov edi, token
  call os_string_compare
  je .on_to_then
  jmp .finish_line
.second_is_string_var:
  mov esi, string_vars
  mov eax, 128
  mul ebx
  add esi, eax
  mov edi, string_vars
  mov ebx, 0
  mov bl, [.tmp_string_var]
  mov eax, 128
  mul ebx
  add edi, eax
  call os_string_compare
  jc .on_to_then
  jmp .finish_line
.on_to_then:
  call get_token
  mov esi, token                        ; Look for AND for more comparison
  mov edi, and_keyword
  call os_string_compare
  jc do_if
  mov esi, token                        ; Look for THEN to perform more operations
  mov edi, then_keyword
  call os_string_compare
  jc .then_present
  mov esi, err_syntax
  jmp error
.then_present:                          ; Continue rest of line like any other command!
  mov BYTE [last_if_true], 1
  jmp mainloop
.finish_line:                           ; IF wasn't fulfilled, so skip rest of line
  mov DWORD esi, [prog]
  mov al, [esi]
  inc DWORD [prog]
  cmp al, 10
  jne .finish_line
  mov BYTE [last_if_true], 0
  jmp mainloop
.error:
  mov esi, err_syntax
  jmp error
  .tmp_string_var db 0
; ------------------------------------------------------------------
; INCLUDE
do_include:
  call get_token
  cmp eax, QUOTE
  je .is_ok
  mov esi, err_syntax
  jmp error
.is_ok:
  mov eax, token
  mov ecx, [prog_end]
  inc ecx                               ; Add a bit of space after original code
  inc ecx
  inc ecx
  push ecx
  call os_load_file
  jc .load_fail
  pop ecx
  add ecx, ebx
  mov DWORD [prog_end], ecx
  jmp mainloop
.load_fail:
  pop ecx
  mov esi, err_file_notfound
  jmp error
; ------------------------------------------------------------------
; INK
do_ink:
  call get_token                        ; Get column
  cmp eax, VARIABLE
  je .first_is_var
  mov esi, token
  call os_string_to_int
  mov BYTE [ink_colour], al
  jmp mainloop
.first_is_var:
  mov eax, 0
  mov al, [token]
  call get_var
  mov BYTE [ink_colour], al
  jmp mainloop
; ------------------------------------------------------------------
; INPUT
do_input:
  mov al, 0                             ; Clear string from previous usage
  mov edi, .tmpstring
  mov ecx, 128
  rep stosb
  call get_token
  cmp eax, VARIABLE                     ; We can only INPUT to variables!
  je .number_var
  cmp eax, STRING_VAR
  je .string_var
  mov esi, err_syntax
  jmp error
.number_var:
  mov eax, .tmpstring                   ; Get input from the user
  call os_input_string
  mov eax, .tmpstring
  call os_string_length
  cmp eax, 0
  jne .char_entered
  mov BYTE [.tmpstring], '0'            ; If enter hit, fill variable with zero
  mov BYTE [.tmpstring + 1], 0
.char_entered:
  mov esi, .tmpstring                   ; Convert to integer format
  call os_string_to_int
  mov ebx, eax
  mov eax, 0
  mov al, [token]                       ; Get the variable where we're storing it...
  call set_var                          ; ...and store it!
  call os_print_newline
  jmp mainloop
.string_var:
  push ebx
  mov eax, .tmpstring
  call os_input_string
  mov esi, .tmpstring
  mov edi, string_vars
  pop ebx
  mov eax, 128
  mul ebx
  add edi, eax
  call os_string_copy
  call os_print_newline
  jmp mainloop
  .tmpstring: times 128 db 0
; -----------------------------------------------------------
; LEN
do_len:
  call get_token
  cmp eax, STRING_VAR
  jne .error
  
  mov esi, string_vars
  mov eax, 128
  mul ebx
  add esi, eax
  mov eax, esi
  call os_string_length
  mov DWORD [.num1], eax
  call get_token
  cmp eax, VARIABLE
  je .is_ok
  
  mov esi, err_syntax
  jmp error
.is_ok:
  mov eax, 0
  mov al, [token]
  mov bl, al
  jmp .finish
.finish: 
  mov ebx, [.num1]
  mov al, [token]
  call set_var
  mov eax, 0
  jmp mainloop
  
.error:
  mov esi, err_syntax
  jmp error
  .num1 dd 0
; ------------------------------------------------------------------
; LISTBOX
do_listbox:
  mov bh, [work_page]                   ; Store the cursor position
  mov ah, 03h
  int 10h
  
  call get_token
  cmp eax, STRING_VAR
  jne .error
  mov esi, string_vars
  mov eax, 128
  mul ebx
  add esi, eax
  mov DWORD [.s1], esi
  call get_token
  cmp eax, STRING_VAR
  jne .error
  mov esi, string_vars
  mov eax, 128
  mul ebx
  add esi, eax
  mov DWORD [.s2], esi
  call get_token
  cmp eax, STRING_VAR
  jne .error
  mov esi, string_vars
  mov eax, 128
  mul ebx
  add esi, eax
  mov DWORD [.s3], esi
  call get_token
  cmp eax, VARIABLE
  jne .error
  mov al, [token]
  mov BYTE [.var], al
  mov eax, [.s1]
  mov ebx, [.s2]
  mov ecx, [.s3]
  call os_list_dialog
  jc .esc_pressed
  pusha
  mov bh, [work_page]                   ; Move the cursor back
  mov ah, 02h
  int 10h
  popa
  mov ebx, eax
  mov eax, 0
  mov al, [.var]
  call set_var
  jmp mainloop
.esc_pressed:
  mov eax, 0
  mov al, [.var]
  mov ebx, 0
  call set_var
  jmp mainloop
.error:
  mov esi, err_syntax
  jmp error
  .s1 dd 0
  .s2 dd 0
  .s3 dd 0
  .var db 0
; ------------------------------------------------------------------
; LOAD
do_load:
  call get_token
  cmp eax, QUOTE
  je .is_quote
  cmp eax, STRING_VAR
  jne .error
  mov esi, string_vars
  mov eax, 128
  mul ebx
  add esi, eax
  jmp .get_position
.is_quote:
  mov esi, token
.get_position:
  mov eax, esi
  call os_file_exists
  jc .file_not_exists
  mov edx, eax                          ; Store for now
  call get_token
  cmp eax, VARIABLE
  je .second_is_var
  cmp eax, NUMBER
  jne .error
  mov esi, token
  call os_string_to_int
.load_part:
  mov ecx, eax
  mov eax, edx
  call os_load_file
  mov eax, 0
  mov al, 'S'
  call set_var
  mov eax, 0
  mov al, 'R'
  mov ebx, 0
  call set_var
  jmp mainloop
.second_is_var:
  mov eax, 0
  mov al, [token]
  call get_var
  jmp .load_part
.file_not_exists:
  mov eax, 0
  mov al, 'R'
  mov ebx, 1
  call set_var
  call get_token                        ; Skip past the loading point -- unnecessary now
  jmp mainloop
.error:
  mov esi, err_syntax
  jmp error
; ------------------------------------------------------------------
; LOOP
do_loop:
  cmp BYTE [loop_in], 0
  je .no_do
  sub BYTE [loop_in], 4
;  dec BYTE [loop_in]
;  dec BYTE [loop_in]
  mov edx, 0
  call get_token
  mov edi, token
  
  mov esi, .endless_word
  call os_string_compare
  jc .loop_back
  
  mov esi, .while_word
  call os_string_compare
  jc .while_set
  
  mov esi, .until_word
  call os_string_compare
  jnc .error
  
.get_first_var:
  call get_token
  cmp eax, VARIABLE
  jne .error
  
  mov al, [token]
  call get_var
  mov ecx, eax
  
.check_equals:
  call get_token
  cmp eax, UNKNOWN
  jne .error
  mov eax, [token]
  cmp al, '='
  je .sign_ok
  cmp al, '>'
  je .sign_ok
  cmp al, '<'
  je .sign_ok
  jmp .error
  .sign_ok:
  mov BYTE [.sign], al
  
.get_second_var:
  call get_token
  cmp eax, NUMBER
  je .second_is_num
  cmp eax, VARIABLE
  je .second_is_var
  cmp eax, CHAR
  jne .error
.second_is_char:
  and eax, 0FFh
  mov al, [token]
  jmp .check_true
  
.second_is_var:
  mov al, [token]
  call get_var
  jmp .check_true
  
.second_is_num:
  mov esi, token
  call os_string_to_int
  
.check_true:
  mov bl, [.sign]
  cmp bl, '='
  je .sign_equals
  
  cmp bl, '>'
  je .sign_greater
  
  jmp .sign_lesser
  
.sign_equals:
  cmp eax, ecx
  jne .false
  jmp .true
  
.sign_greater:
  cmp eax, ecx
  jge .false
  jmp .true
  
.sign_lesser:
  cmp eax, ecx
  jle .false
  jmp .true
.true:
  cmp edx, 1
  je .loop_back
  jmp mainloop
.false:
  cmp edx, 1
  je mainloop
  
.loop_back: 
  mov DWORD esi, do_loop_store
  mov al, [loop_in]
  and eax, 0FFh
  add esi, eax
  lodsd
  mov DWORD [prog], eax
  jmp mainloop
  
.while_set:
  mov edx, 1
  jmp .get_first_var
  
.no_do:
  mov esi, err_loop
  jmp error
.error:
  mov esi, err_syntax
  jmp error
  
.data:
  .while_word db "WHILE", 0
  .until_word db "UNTIL", 0
  .endless_word db "ENDLESS", 0
  .sign db 0
  
  
; ------------------------------------------------------------------
; MOVE
do_move:
  call get_token
  cmp eax, VARIABLE
  je .first_is_var
  mov esi, token
  call os_string_to_int
  mov dl, al
  jmp .onto_second
.first_is_var:
  mov eax, 0
  mov al, [token]
  call get_var
  mov dl, al
.onto_second:
  call get_token
  cmp eax, VARIABLE
  je .second_is_var
  mov esi, token
  call os_string_to_int
  mov dh, al
  jmp .finish
.second_is_var:
  mov eax, 0
  mov al, [token]
  call get_var
  mov dh, al
.finish:
  mov bh, [work_page]
  mov ah, 2
  int 10h
  jmp mainloop
; ------------------------------------------------------------------
; NEXT
do_next:
  call get_token
  cmp eax, VARIABLE                     ; NEXT must be followed by a variable
  jne .error
  mov eax, 0
  mov al, [token]
  call get_var
  inc eax                               ; NEXT increments the variable, of course!
  mov ebx, eax
  mov eax, 0
  mov al, [token]
  sub al, 65
  mov esi, for_variables
  lea esi, [esi+eax*4]
  lodsd                                 ; Get the target number from the table
  inc eax                               ; (Make the loop inclusive of target number)
  cmp eax, ebx                          ; Do the variable and target match?
  je .loop_finished
  mov eax, 0                            ; If not, store the updated variable
  mov al, [token]
  call set_var
  mov eax, 0                            ; Find the code point and go back
  mov al, [token]
  sub al, 65
  mov esi, for_code_points
  lea esi, [esi+eax*4]
  lodsd
  mov DWORD [prog], eax
  jmp mainloop
.loop_finished:
  jmp mainloop
.error:
  mov esi, err_syntax
  jmp error
;-------------------------------------------------------------------
; NUMBER
do_number:
  call get_token                        ; Check if it's string to number, or number to string
  cmp eax, STRING_VAR
  je .is_string
  cmp eax, VARIABLE
  je .is_variable
  jmp .error
.is_string:
  mov esi, string_vars
  mov eax, 128
  mul ebx
  add esi, eax
  mov [.tmp], esi
  call get_token
  mov esi, [.tmp]
  cmp eax, VARIABLE
  jne .error
  call os_string_to_int
  mov ebx, eax
  mov eax, 0
  mov al, [token]
  call set_var
  jmp mainloop
.is_variable:
  mov eax, 0                            ; Get the value of the number
  mov al, [token]
  call get_var
  call os_int_to_string                 ; Convert to a string
  mov [.tmp], eax
  call get_token                        ; Get the second parameter
  mov esi, [.tmp]
  cmp eax, STRING_VAR                   ; Make sure it's a string variable
  jne .error
  mov edi, string_vars                  ; Locate string variable
  mov eax, 128
  mul ebx
  add edi, eax
  call os_string_copy                   ; Save converted string
  jmp mainloop
.error:
  mov esi, err_syntax
  jmp error
  .tmp dd 0
;-------------------------------------------------------------------
; PAGE
do_page:
  call get_token
  cmp eax, NUMBER
  jne .error
  mov esi, token
  call os_string_to_int
  mov BYTE [work_page], al              ; Set work page variable
  call get_token
  cmp eax, NUMBER
  jne .error
  mov esi, token
  call os_string_to_int
  mov BYTE [disp_page], al              ; Set display page variable
                                        ; Change display page -- AL should already be present from the os_string_to_int
  mov ah, 5
  int 10h
  jmp mainloop
.error:
  mov esi, err_syntax
  jmp error
; ------------------------------------------------------------------
; PAUSE
do_pause:
  call get_token
  cmp eax, VARIABLE
  je .is_var
  mov esi, token
  call os_string_to_int
  jmp .finish
.is_var:
  mov eax, 0
  mov al, [token]
  call get_var
.finish:
  call os_pause
  jmp mainloop
; ------------------------------------------------------------------
; PEEK
do_peek:
  call get_token
  cmp eax, VARIABLE
  jne .error
  mov eax, 0
  mov al, [token]
  mov BYTE [.tmp_var], al
  call get_token
  cmp eax, VARIABLE
  je .dereference
  cmp eax, NUMBER
  jne .error
  mov esi, token
  call os_string_to_int
.store:
  mov esi, eax
  mov ebx, 0
  mov bl, [esi]
  mov eax, 0
  mov al, [.tmp_var]
  call set_var
  jmp mainloop
.dereference:
  mov al, [token]
  call get_var
  jmp .store
.error:
  mov esi, err_syntax
  jmp error
  .tmp_var db 0
  
  
  
; ------------------------------------------------------------------
; PEEKINT
do_peekint:
  call get_token
  
  cmp eax, VARIABLE
  jne .error
.get_second:
  mov al, [token]
  mov ecx, eax
  
  call get_token
  
  cmp eax, VARIABLE
  je .address_is_var
  
  cmp eax, NUMBER
  jne .error
  
.address_is_number:
  mov esi, token
  call os_string_to_int
  jmp .load_data
  
.address_is_var:
  mov al, [token]
  call get_var
  
.load_data:
  mov esi, eax
  mov ebx, [esi]
  mov eax, ecx
  call set_var
  
  jmp mainloop
  
.error:
  mov esi, err_syntax
  jmp error
; ------------------------------------------------------------------
; POKE
do_poke:
  call get_token
  cmp eax, VARIABLE
  je .first_is_var
  cmp eax, NUMBER
  jne .error
  mov esi, token
  call os_string_to_int
  cmp eax, 255
  jg .error
  mov BYTE [.first_value], al
  jmp .onto_second
.first_is_var:
  mov eax, 0
  mov al, [token]
  call get_var
  mov BYTE [.first_value], al
.onto_second:
  call get_token
  cmp eax, VARIABLE
  je .second_is_var
  cmp eax, NUMBER
  jne .error
  mov esi, token
  call os_string_to_int
.got_value:
  mov edi, eax
  mov eax, 0
  mov al, [.first_value]
  mov BYTE [edi], al
  jmp mainloop
.second_is_var:
  mov eax, 0
  mov al, [token]
  call get_var
  jmp .got_value
.error:
  mov esi, err_syntax
  jmp error
  .first_value db 0
; ------------------------------------------------------------------
; POKEINT
do_pokeint:
  call get_token
  
  cmp eax, VARIABLE
  je .data_is_var
  
  cmp eax, NUMBER
  jne .error
.data_is_num:
  mov esi, token
  call os_string_to_int
  jmp .get_second
  
.data_is_var:
  mov al, [token]
  call get_var
  
.get_second:
  mov ecx, eax
  
  call get_token
  
  cmp eax, VARIABLE
  je .address_is_var
  
  cmp eax, NUMBER
  jne .error
  
.address_is_num:
  mov esi, token
  call os_string_to_int
  jmp .save_data
  
.address_is_var:
  mov al, [token]
  call get_var
  
.save_data:
  mov esi, eax
  mov [esi], ecx
  
  jmp mainloop
  
.error:
  mov esi, err_syntax
  jmp error
; ------------------------------------------------------------------
; PORT
do_port:
  call get_token
  mov esi, token
  mov edi, .out_cmd
  call os_string_compare
  jc .do_out_cmd
  mov edi, .in_cmd
  call os_string_compare
  jc .do_in_cmd
  jmp .error
.do_out_cmd:
  call get_token
  cmp eax, NUMBER
  jne .error
  mov esi, token
  call os_string_to_int                 ; Now AX = port number
  mov edx, eax
  call get_token
  cmp eax, NUMBER
  je .out_is_num
  cmp eax, VARIABLE
  je .out_is_var
  jmp .error
.out_is_num:
  mov esi, token
  call os_string_to_int
  call os_port_byte_out
  jmp mainloop
.out_is_var:
  mov eax, 0
  mov al, [token]
  call get_var
  call os_port_byte_out
  jmp mainloop
.do_in_cmd:
  call get_token
  cmp eax, NUMBER
  jne .error
  mov esi, token
  call os_string_to_int
  mov edx, eax
  call get_token
  cmp eax, VARIABLE
  jne .error
  mov cl, [token]
  call os_port_byte_in
  mov ebx, 0
  mov bl, al
  mov al, cl
  call set_var
  jmp mainloop
.error:
  mov esi, err_syntax
  jmp error
  .out_cmd db "OUT", 0
  .in_cmd db "IN", 0
; ------------------------------------------------------------------
; PRINT
do_print:
  call get_token                        ; Get part after PRINT
  cmp eax, QUOTE                        ; What type is it?
  je .print_quote
  cmp eax, VARIABLE                     ; Numerical variable (eg X)
  je .print_var
  cmp eax, STRING_VAR                   ; String variable (eg $1)
  je .print_string_var
  cmp eax, STRING                       ; Special keyword (eg CHR or HEX)
  je .print_keyword
  mov esi, err_print_type               ; We only print quoted strings and vars!
  jmp error
.print_var:
  mov eax, 0
  mov al, [token]
  call get_var                          ; Get its value
  call os_int_to_string                 ; Convert to string
  mov esi, eax
  call os_print_string
  jmp .newline_or_not
.print_quote:                           ; If it's quoted text, print it
  mov esi, token
.print_quote_loop:
  lodsb
  cmp al, 0
  je .newline_or_not
  mov ah, 09h
  mov bl, [ink_colour]
  mov bh, [work_page]
  mov ecx, 1
  int 10h
  mov ah, 3
  int 10h
  cmp dl, 79
  jge .quote_newline
  inc dl
.move_cur_quote:
  mov bh, [work_page]
  mov ah, 02h
  int 10h
  jmp .print_quote_loop
.quote_newline:
  cmp dh, 24
  je .move_cur_quote
  mov dl, 0
  inc dh
  jmp .move_cur_quote
.print_string_var:
  mov esi, string_vars
  mov eax, 128
  mul ebx
  add esi, eax
  jmp .print_quote_loop
.print_keyword:
  mov esi, token
  mov edi, chr_keyword
  call os_string_compare
  jc .is_chr
  mov edi, hex_keyword
  call os_string_compare
  jc .is_hex
  mov esi, err_syntax
  jmp error
.is_chr:
  call get_token
  cmp eax, VARIABLE
  je .is_chr_variable
  
  cmp eax, NUMBER
  je .is_chr_number
.is_chr_variable:
  mov eax, 0
  mov al, [token]
  call get_var
  jmp .print_chr
  
.is_chr_number:
  mov esi, token
  call os_string_to_int
.print_chr:
  mov ah, 09h
  mov bl, [ink_colour]
  mov bh, [work_page]
  mov ecx, 1
  int 10h
  mov ah, 3                             ; Move the cursor forward
  int 10h
  inc dl
  cmp dl, 79
  jg .end_line                          ; If it's over the end of the line
.move_cur:
  mov ah, 2
  int 10h
  jmp .newline_or_not
.is_hex:
  call get_token
  cmp eax, VARIABLE
  jne .error
  mov eax, 0
  mov al, [token]
  call get_var
  call os_print_2hex
  jmp .newline_or_not
.end_line:
  mov dl, 0
  inc dh
  cmp dh, 25
  jl .move_cur
  mov dh, 24
  mov dl, 79
  jmp .move_cur
.error:
  mov esi, err_syntax
  jmp error
  
.newline_or_not:
                                        ; We want to see if the command ends with ';' -- which means that
                                        ; we shouldn't print a newline after it finishes. So we store the
                                        ; current program location to pop ahead and see if there's the ';'
                                        ; character -- otherwise we put the program location back and resume
                                        ; the main loop
  mov eax, [prog]
  mov DWORD [.tmp_loc], eax
  call get_token
  cmp eax, UNKNOWN
  jne .ignore
  mov eax, 0
  mov al, [token]
  cmp al, ';'
  jne .ignore
  jmp mainloop                          ; And go back to interpreting the code!
.ignore:
  mov ah, 5
  mov al, [work_page]
  int 10h
  mov bh, [work_page]
  call os_print_newline
  mov ah, 5
  mov al, [disp_page]
  mov eax, [.tmp_loc]
  mov DWORD [prog], eax
  jmp mainloop
  .tmp_loc dd 0
; ------------------------------------------------------------------
; RAND
do_rand:
  call get_token
  cmp eax, VARIABLE
  jne .error
  mov al, [token]
  mov BYTE [.tmp], al
  call get_token
  cmp eax, NUMBER
  jne .error
  mov esi, token
  call os_string_to_int
  mov DWORD [.num1], eax
  call get_token
  cmp eax, NUMBER
  jne .error
  mov esi, token
  call os_string_to_int
  mov DWORD [.num2], eax
  mov eax, [.num1]
  mov ebx, [.num2]
  call os_get_random
  mov ebx, ecx
  mov eax, 0
  mov al, [.tmp]
  call set_var
  jmp mainloop
  .tmp db 0
  .num1 dd 0
  .num2 dd 0
.error:
  mov esi, err_syntax
  jmp error
; ------------------------------------------------------------------
; READ
do_read:
  call get_token                        ; Get the next token
  cmp eax, STRING                       ; Check for a label
  je .is_ok
  mov esi, err_goto_notlabel
  jmp error
.is_ok:
  mov esi, token                        ; Back up this label
  mov edi, .tmp_token
  call os_string_copy
  mov eax, .tmp_token
  call os_string_length
  mov edi, .tmp_token                   ; Add ':' char to end for searching
  add edi, eax
  mov al, ':'
  stosb
  mov al, 0
  stosb
  call get_token                        ; Now get the offset variable
  cmp eax, VARIABLE
  je .second_part_is_var
  mov esi, err_syntax
  jmp error
.second_part_is_var:
  mov eax, 0
  mov al, [token]
  call get_var
  cmp eax, 0                            ; Want to be searching for at least the first byte!
  jg .var_bigger_than_zero
  mov esi, err_syntax
  jmp error
.var_bigger_than_zero:
  mov DWORD [.to_skip], eax
  call get_token                        ; And now the var to store result into
  cmp eax, VARIABLE
  je .third_part_is_var
  mov esi, err_syntax
  jmp error
.third_part_is_var:                     ; Keep it for later
  mov eax, 0
  mov al, [token]
  mov BYTE [.var_to_use], al
                                        ; OK, so now we have all the stuff we need. Let's search for the label
  mov eax, [prog]                       ; Store current location
  mov DWORD [.curr_location], eax
  mov eax, [load_point]
  mov DWORD [prog], eax                 ; Return to start of program to find label
.loop:
  call get_token
  cmp eax, LABEL
  jne .line_loop
  mov esi, token
  mov edi, .tmp_token
  call os_string_compare
  jc .found_label
.line_loop:                             ; Go to end of line
  mov DWORD esi, [prog]
  mov al, [esi]
  inc DWORD [prog]
  cmp al, 10
  jne .line_loop
  mov eax, [prog]
  mov ebx, [prog_end]
  cmp eax, ebx
  jg .past_end
  jmp .loop
.past_end:
  mov esi, err_label_notfound
  jmp error
.found_label:
  mov ecx, [.to_skip]                   ; Skip requested number of data entries
.data_skip_loop:
  push ecx
  call get_token
  pop ecx
  loop .data_skip_loop
  cmp eax, NUMBER
  je .data_is_num
  mov esi, err_syntax
  jmp error
.data_is_num:
  mov esi, token
  call os_string_to_int
  mov ebx, eax
  mov eax, 0
  mov al, [.var_to_use]
  call set_var
  mov eax, [.curr_location]
  mov DWORD [prog], eax
  jmp mainloop
  .curr_location dd 0
  .to_skip dd 0
  .var_to_use db 0
  .tmp_token: times 30 db 0
; ------------------------------------------------------------------
; REM
do_rem:
  mov DWORD esi, [prog]
  mov al, [esi]
  inc DWORD [prog]
  cmp al, 10                            ; Find end of line after REM
  jne do_rem
  jmp mainloop
; ------------------------------------------------------------------
; RENAME
do_rename:
  call get_token
  cmp eax, STRING_VAR                   ; Is it a string or a quote?
  je .first_is_string
  cmp eax, QUOTE
  je .first_is_quote
  jmp .error
.first_is_string:
  mov esi, string_vars                  ; Locate string
  mov eax, 128
  mul ebx
  add esi, eax
  jmp .save_file1
.first_is_quote:
  mov esi, token                        ; The location of quotes is provided
.save_file1:
  mov DWORD edi, .file1                 ; The filename is saved to temporary strings because
  call os_string_copy                   ; getting a second quote will overwrite the previous
  
.get_second:
  call get_token
  cmp eax, STRING_VAR
  je .second_is_string
  cmp eax, QUOTE
  je .second_is_quote
  jmp .error
.second_is_string:
  mov esi, string_vars                  ; Locate second string
  mov eax, 128
  mul ebx
  add esi, eax
  jmp .save_file2
.second_is_quote:
  mov esi, token
.save_file2:
  mov DWORD edi, .file2
  call os_string_copy
  
.check_exists:
  mov eax, .file1                       ; Check if the source file exists
  call os_file_exists
  jc .file_not_found                    ; If it doesn't exists set "R = 1"
  clc
  mov eax, .file2                       ; The second file is the destination and should not exist
  call os_file_exists
  jnc .file_exists                      ; If it exists set "R = 3"
  
.rename:
  mov eax, .file1                       ; Seem to be okay, lets rename
  mov ebx, .file2
  call os_rename_file
  jc .rename_failed                     ; If it failed set "R = 2", usually caused by a read-only disk
  mov eax, 0                            ; It worked sucessfully, so set "R = 0" to indicate no error
  mov al, 'R'
  mov ebx, 0
  call set_var
  jmp mainloop
.error:
  mov esi, err_syntax
  jmp error
.file_not_found:
  mov eax, 0                            ; Set R variable to 1
  mov al, 'R'
  mov ebx, 1
  call set_var
  jmp mainloop
.rename_failed:
  mov eax, 0                            ; Set R variable to 2
  mov al, 'R'
  mov ebx, 2
  call set_var
  jmp mainloop
.file_exists:
  mov eax, 0
  mov al, 'R'                           ; Set R variable to 3
  mov ebx, 3
  call set_var
  jmp mainloop
.data:
  .file1: times 12 db 0
  .file2: times 12 db 0
; ------------------------------------------------------------------
; RETURN
do_return:
  mov eax, 0
  mov al, [gosub_depth]
  cmp al, 0
  jne .is_ok
  mov esi, err_return
  jmp error
.is_ok:
  mov esi, gosub_points
  lea esi, [esi+eax*4]                  ; Table is words (not bytes)
  lodsd
  mov DWORD [prog], eax
  dec BYTE [gosub_depth]
  jmp mainloop 
; ------------------------------------------------------------------
; SAVE
do_save:
  call get_token
  cmp eax, QUOTE
  je .is_quote
  cmp eax, STRING_VAR
  jne .error
  mov esi, string_vars
  mov eax, 128
  mul ebx
  add esi, eax
  jmp .get_position
.is_quote:
  mov esi, token
.get_position:
  mov edi, .tmp_filename
  call os_string_copy
  call get_token
  cmp eax, VARIABLE
  je .second_is_var
  cmp eax, NUMBER
  jne .error
  mov esi, token
  call os_string_to_int
.set_data_loc:
  mov DWORD [.data_loc], eax
  call get_token
  cmp eax, VARIABLE
  je .third_is_var
  cmp eax, NUMBER
  jne .error
  mov esi, token
  call os_string_to_int
.check_exists:
  mov DWORD [.data_size], eax
  mov eax, .tmp_filename
  call os_file_exists
  jc .write_file
  jmp .file_exists_fail
  
.write_file:
  mov eax, .tmp_filename
  mov ebx, [.data_loc]
  mov ecx, [.data_size]
  
  call os_write_file
  jc .save_failure
  mov eax, 0
  mov al, 'R'
  mov ebx, 0
  call set_var
  jmp mainloop
.second_is_var:
  mov eax, 0
  mov al, [token]
  call get_var
  jmp .set_data_loc
.third_is_var:
  mov eax, 0
  mov al, [token]
  call get_var
  jmp .check_exists
.file_exists_fail:
  mov eax, 0
  mov al, 'R'
  mov ebx, 2
  call set_var
  jmp mainloop
  
.save_failure:
  mov eax, 0
  mov al, 'R'
  mov ebx, 1
  call set_var
  jmp mainloop
.error:
  mov esi, err_syntax
  jmp error
  .filename_loc dd 0
  .data_loc dd 0
  .data_size dd 0
  .tmp_filename: times 15 db 0
; ------------------------------------------------------------------
; SERIAL
do_serial:
  call get_token
  mov esi, token
  mov edi, .on_cmd
  call os_string_compare
  jc .do_on_cmd
  mov edi, .send_cmd
  call os_string_compare
  jc .do_send_cmd
  mov edi, .rec_cmd
  call os_string_compare
  jc .do_rec_cmd
  jmp .error
.do_on_cmd:
  call get_token
  cmp eax, NUMBER
  je .do_on_cmd_ok
  jmp .error
.do_on_cmd_ok:
  mov esi, token
  call os_string_to_int
  cmp eax, 1200
  je .on_cmd_slow_mode
  cmp eax, 9600
  je .on_cmd_fast_mode
  jmp .error
.on_cmd_fast_mode:
  mov eax, 0
  call os_serial_port_enable
  jmp mainloop
.on_cmd_slow_mode:
  mov eax, 1
  call os_serial_port_enable
  jmp mainloop
.do_send_cmd:
  call get_token
  cmp eax, NUMBER
  je .send_number
  cmp eax, VARIABLE
  je .send_variable
  jmp .error
.send_number:
  mov esi, token
  call os_string_to_int
  call os_send_via_serial
  jmp mainloop
.send_variable:
  mov eax, 0
  mov al, [token]
  call get_var
  call os_send_via_serial
  jmp mainloop
.do_rec_cmd:
  call get_token
  cmp eax, VARIABLE
  jne .error
  mov al, [token]
  mov ecx, 0
  mov cl, al
  call os_get_via_serial
  mov ebx, 0
  mov bl, al
  mov al, cl
  call set_var
  jmp mainloop
.error:
  mov esi, err_syntax
  jmp error
  .on_cmd db "ON", 0
  .send_cmd db "SEND", 0
  .rec_cmd db "REC", 0
; ------------------------------------------------------------------
; SIZE
do_size:
  call get_token
  cmp eax, STRING_VAR
  je .is_string
  cmp eax, QUOTE
  je .is_quote
  jmp .error
.is_string:
  mov esi, string_vars
  mov eax, 128
  mul ebx
  add esi, eax
  mov eax, esi
  jmp .get_size
.is_quote:
  mov eax, token
.get_size:
  call os_get_file_size
  jc .file_not_found
  mov eax, 0
  mov al, 'S'
  call set_var
  mov eax, 0
  mov al, 'R'
  mov ebx, 0
  call set_var
  jmp mainloop
.error:
  mov esi, err_syntax
  jmp error
.file_not_found:
  mov eax, 0
  mov al, [token]
  mov ebx, 0
  call set_var
  mov eax, 0
  mov al, 'R'
  mov ebx, 1
  call set_var
  
  jmp mainloop
; ------------------------------------------------------------------
; SOUND
do_sound:
  call get_token
  cmp eax, VARIABLE
  je .first_is_var
  mov esi, token
  call os_string_to_int
  jmp .done_first
.first_is_var:
  mov eax, 0
  mov al, [token]
  call get_var
.done_first:
  call os_speaker_tone
  call get_token
  cmp eax, VARIABLE
  je .second_is_var
  mov esi, token
  call os_string_to_int
  jmp .finish
.second_is_var:
  mov eax, 0
  mov al, [token]
  call get_var
.finish:
  call os_pause
  call os_speaker_off
  jmp mainloop
;-------------------------------------------------------------------
; STRING
do_string:
  call get_token                        ; The first parameter is the word 'GET' or 'SET'
  mov esi, token
  
  mov edi, .get_cmd
  call os_string_compare
  jc .set_str
  
  mov edi, .set_cmd
  call os_string_compare
  jc .get_str
  
  jmp .error
  
  .set_str:
  mov ecx, 1
  jmp .check_second
  .get_str:
  mov ecx, 2
.check_second:
  call get_token                        ; The next should be a string variable, locate it
  
  cmp eax, STRING_VAR
  jne .error
  
  mov esi, string_vars
  mov eax, 128
  mul ebx
  add esi, eax
  mov DWORD [.string_loc], esi
  
.check_third:
  call get_token                        ; Now there should be a number
  
  cmp eax, NUMBER
  je .third_is_number
  
  cmp eax, VARIABLE
  je .third_is_variable
  
  jmp .error
  
.third_is_number: 
  mov esi, token
  call os_string_to_int
  jmp .got_number 
.third_is_variable:
  and eax, 0FFh ;mov ah, 0
  mov al, [token]
  call get_var
  jmp .got_number
.got_number:
  cmp eax, 128
  jg .outrange
  cmp eax, 0
  je .outrange
  sub eax, 1
  mov edx, eax
  
.check_forth:
  call get_token                        ; Next a numerical variable
  
  cmp eax, VARIABLE
  jne .error
  
  mov al, [token]
  mov BYTE [.tmp], al
  
  cmp ecx, 2
  je .set_var
  
.get_var:
  mov DWORD esi, [.string_loc]          ; Move to string location
  add esi, edx                          ; Add offset
  lodsb                                 ; Load data
  and eax, 0FFh ;mov ah, 0
  mov ebx, eax                          ; Set data in numerical variable
  mov al, [.tmp]
  call set_var
  jmp mainloop
  
.set_var:
  mov al, [.tmp]                        ; Retrieve the variable
  call get_var                          ; Get it's value
  mov edi, [.string_loc]                ; Locate the string
  add edi, edx                          ; Add the offset
  stosb                                 ; Store data
  jmp mainloop
  
.error:
  mov esi, err_syntax
  jmp error
  
.outrange:
  mov esi, err_string_range
  jmp error
.data:
  .get_cmd db "GET", 0
  .set_cmd db "SET", 0
  .string_loc dd 0
  .tmp db 0
; ------------------------------------------------------------------
; WAITKEY
do_waitkey:
  call get_token
  cmp eax, VARIABLE
  je .is_variable
  mov esi, err_syntax
  jmp error
.is_variable:
  mov eax, 0
  mov al, [token]
  push eax
  call os_wait_for_key
  cmp eax, 48E0h
  je .up_pressed
  cmp eax, 50E0h
  je .down_pressed
  cmp eax, 4BE0h
  je .left_pressed
  cmp eax, 4DE0h
  je .right_pressed
.store:
  mov ebx, 0
  mov bl, al
  pop eax
  call set_var
  jmp mainloop
.up_pressed:
  mov eax, 1
  jmp .store
.down_pressed:
  mov eax, 2
  jmp .store
.left_pressed:
  mov eax, 3
  jmp .store
.right_pressed:
  mov eax, 4
  jmp .store
; ==================================================================
; INTERNAL ROUTINES FOR INTERPRETER
; ------------------------------------------------------------------
; Get value of variable character specified in AL (eg 'A')
get_var:
  and eax, 0FFh ;mov ah, 0
  sub al, 65
  mov esi, variables
  lea esi, [esi+eax*4]
  lodsd
  ret
; ------------------------------------------------------------------
; Set value of variable character specified in AL (eg 'A')
; with number specified in BX
set_var:
  and eax, 0FFh ;mov ah, 0
  sub al, 65                            ; Remove ASCII codes before 'A'
  mov edi, variables                    ; Find position in table (of words)
  lea edi, [edi+eax*4]
  mov eax, ebx
  stosd
  ret
; ------------------------------------------------------------------
; Get token from current position in prog
get_token:
  mov DWORD esi, [prog]
  lodsb
  cmp al, 10
  je .newline
  cmp al, ' '
  je .newline
  call is_number
  jc get_number_token
  cmp al, '"'
  je get_quote_token
  cmp al, 39                            ; Quote mark (')
  je get_char_token
  cmp al, '$'
  je get_string_var_token
  jmp get_string_token
.newline:
  inc DWORD [prog]
  jmp get_token
get_number_token:
  mov DWORD esi, [prog]
  mov edi, token
.loop:
  lodsb
  cmp al, 10
  je .done
  cmp al, ' '
  je .done
  call is_number
  jc .fine
  mov esi, err_char_in_num
  jmp error
.fine:
  stosb
  inc DWORD [prog]
  jmp .loop
.done:
  mov al, 0                             ; Zero-terminate the token
  stosb
  mov eax, NUMBER                       ; Pass back the token type
  ret
get_char_token:
  inc DWORD [prog]                      ; Move past first quote (')
  mov DWORD esi, [prog]
  lodsb
  mov BYTE [token], al
  lodsb
  cmp al, 39                            ; Needs to finish with another quote
  je .is_ok
  mov esi, err_quote_term
  jmp error
.is_ok:
  inc DWORD [prog]
  inc DWORD [prog]
  mov eax, CHAR
  ret
get_quote_token:
  inc DWORD [prog]                      ; Move past first quote (") char
  mov DWORD esi, [prog]
  mov edi, token
.loop:
  lodsb
  cmp al, '"'
  je .done
  cmp al, 10
  je .error
  stosb
  inc DWORD [prog]
  jmp .loop
.done:
  mov al, 0                             ; Zero-terminate the token
  stosb
  inc DWORD [prog]                      ; Move past final quote
  mov eax, QUOTE                        ; Pass back token type
  ret
.error:
  mov esi, err_quote_term
  jmp error
get_string_var_token:
  lodsb
  mov ebx, 0                            ; If it's a string var, pass number of string in BX
  mov bl, al
  sub bl, 49
  inc DWORD [prog]
  inc DWORD [prog]
  mov eax, STRING_VAR
  ret
  
get_string_token:
  mov DWORD esi, [prog]
  mov edi, token
.loop:
  lodsb
  cmp al, 10
  je .done
  cmp al, ' '
  je .done
  stosb
  inc DWORD [prog]
  jmp .loop
.done:
  mov al, 0                             ; Zero-terminate the token
  stosb
  mov eax, token
  call os_string_uppercase
  mov eax, token
  call os_string_length                 ; How long was the token?
  cmp eax, 1                            ; If 1 char, it's a variable or delimiter
  je .is_not_string
  mov esi, token                        ; If the token ends with ':', it's a label
  add esi, eax
  dec esi
  lodsb
  cmp al, ':'
  je .is_label
  mov eax, STRING                       ; Otherwise it's a general string of characters
  ret
.is_label:
  mov eax, LABEL
  ret
.is_not_string:
  mov al, [token]
  call is_letter
  jc .is_var
  mov eax, UNKNOWN
  ret
.is_var:
  mov eax, VARIABLE                     ; Otherwise probably a variable
  ret
; ------------------------------------------------------------------
; Set carry flag if AL contains ASCII number
is_number:
  cmp al, 48
  jl .not_number
  cmp al, 57
  jg .not_number
  stc
  ret
.not_number:
  clc
  ret
; ------------------------------------------------------------------
; Set carry flag if AL contains ASCII letter
is_letter:
  cmp al, 65
  jl .not_letter
  cmp al, 90
  jg .not_letter
  stc
  ret
.not_letter:
  clc
  ret
; ------------------------------------------------------------------
; Print error message and quit out
error:
  mov ah, 5                             ; Revert display page
  mov al, 0
  int 10h
  mov BYTE [work_page], 0
  mov BYTE [disp_page], 0
  call os_print_newline
  call os_print_string                  ; Print error message
  mov esi, line_num_starter
  call os_print_string
                                        ; And now print the line number where the error occurred. We do this
                                        ; by working from the start of the program to the current point,
                                        ; counting the number of newline characters along the way
  mov DWORD esi, [load_point]
  mov ebx, [prog]
  mov ecx, 1
.loop:
  lodsb
  cmp al, 10
  jne .not_newline
  inc ecx
.not_newline:
  cmp esi, ebx
  je .finish
  jmp .loop
.finish:
  mov eax, ecx
  call os_int_to_string
  mov esi, eax
  call os_print_string
  call os_print_newline
  mov DWORD esp, [orig_stack]           ; Restore the stack to as it was when BASIC started
  ret                                   ; And finish
                                        ; Error messages text...
  err_char_in_num db "Error: unexpected char in number", 0
  err_cmd_unknown db "Error: unknown command", 0
  err_divide_by_zero db "Error: attempt to divide by zero", 0
  err_doloop_maximum db "Error: DO/LOOP nesting limit exceeded", 0
  err_file_notfound db "Error: file not found", 0
  err_goto_notlabel db "Error: GOTO or GOSUB not followed by label", 0
  err_label_notfound db "Error: label not found", 0
  err_nest_limit db "Error: FOR or GOSUB nest limit exceeded", 0
  err_next db "Error: NEXT without FOR", 0
  err_loop db "Error: LOOP without DO", 0
  err_print_type db "Error: PRINT not followed by quoted text or variable", 0
  err_quote_term db "Error: quoted string or char not terminated correctly", 0
  err_return db "Error: RETURN without GOSUB", 0
  err_string_range db "Error: string location out of range", 0
  err_syntax db "Error: syntax error", 0
  err_break db "BREAK CALLED", 0
  line_num_starter db " - line ", 0
; ==================================================================
; DATA SECTION
  orig_stack dd 0                       ; Original stack location when BASIC started
  prog dd 0                             ; Pointer to current location in BASIC code
  prog_end dd 0                         ; Pointer to final byte of BASIC code
  load_point dd 0
  token_type db 0                       ; Type of last token read (eg NUMBER, VARIABLE)
  token: times 255 db 0                 ; Storage space for the token
vars_loc:
  variables: times 26 dd 0              ; Storage space for variables A to Z
  for_variables: times 26 dd 0          ; Storage for FOR loops
  for_code_points: times 26 dd 0        ; Storage for code positions where FOR loops start
  
  do_loop_store: times 10 dd 0          ; Storage for DO loops
  loop_in db 0                          ; Loop level
  last_if_true db 1                     ; Checking for 'ELSE'
  ink_colour db 0                       ; Text printing colour
  work_page db 0                        ; Page to print to
  disp_page db 0                        ; Page to display
  alert_cmd db "ALERT", 0
  askfile_cmd db "ASKFILE", 0
  break_cmd db "BREAK", 0
  call_cmd db "CALL", 0
  case_cmd db "CASE", 0
  cls_cmd db "CLS", 0
  cursor_cmd db "CURSOR", 0
  curschar_cmd db "CURSCHAR", 0
  curscol_cmd db "CURSCOL", 0
  curspos_cmd db "CURSPOS", 0
  delete_cmd db "DELETE", 0
  do_cmd db "DO", 0
  else_cmd db "ELSE", 0
  end_cmd db "END", 0
  files_cmd db "FILES", 0
  for_cmd db "FOR", 0
  gosub_cmd db "GOSUB", 0
  goto_cmd db "GOTO", 0
  getkey_cmd db "GETKEY", 0
  if_cmd db "IF", 0
  include_cmd db "INCLUDE", 0
  ink_cmd db "INK", 0
  input_cmd db "INPUT", 0
  len_cmd db "LEN", 0
  listbox_cmd db "LISTBOX", 0
  load_cmd db "LOAD", 0
  loop_cmd db "LOOP", 0
  move_cmd db "MOVE", 0
  next_cmd db "NEXT", 0
  number_cmd db "NUMBER", 0
  page_cmd db "PAGE", 0
  pause_cmd db "PAUSE", 0
  peek_cmd db "PEEK", 0
  peekint_cmd db "PEEKINT", 0
  poke_cmd db "POKE", 0
  pokeint_cmd db "POKEINT", 0
  port_cmd db "PORT", 0
  print_cmd db "PRINT", 0
  rand_cmd db "RAND", 0
  read_cmd db "READ", 0
  rem_cmd db "REM", 0
  rename_cmd db "RENAME", 0
  return_cmd db "RETURN", 0
  save_cmd db "SAVE", 0
  serial_cmd db "SERIAL", 0
  size_cmd db "SIZE", 0
  sound_cmd db "SOUND", 0
  string_cmd db "STRING", 0
  waitkey_cmd db "WAITKEY", 0
  and_keyword db "AND", 0
  then_keyword db "THEN", 0
  chr_keyword db "CHR", 0
  hex_keyword db "HEX", 0
  
  lower_keyword db "LOWER", 0
  upper_keyword db "UPPER", 0
  ink_keyword db "INK", 0
  progstart_keyword db "PROGSTART", 0
  ramstart_keyword db "RAMSTART", 0
  timer_keyword db "TIMER", 0
  variables_keyword db "VARIABLES", 0
  version_keyword db "VERSION", 0
  gosub_depth db 0
  gosub_points: times 10 dd 0           ; Points in code to RETURN to
  string_vars: times 1024 db 0          ; 8 * 128 byte strings
; ------------------------------------------------------------------
