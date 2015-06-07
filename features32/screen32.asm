; ==================================================================
; MikeOS -- The Mike Operating System kernel
; Copyright (C) 2006 - 2013 MikeOS Developers -- see doc/LICENSE.TXT
;
; SCREEN HANDLING SYSTEM CALLS
; ==================================================================
; ------------------------------------------------------------------
; os_print_string -- Displays text
; IN: SI = message location (zero-terminated string)
; OUT: Nothing (registers preserved)
os_print_string:
  pusha
  mov ah, 0Eh                           ; int 10h teletype function
.repeat:
  lodsb                                 ; Get char from string
  cmp al, 0
  je .done                              ; If char is zero, end of string
  int 10h                               ; Otherwise, print it
  jmp .repeat                           ; And move on to next char
.done:
  popa
  ret
; ------------------------------------------------------------------
; os_clear_screen -- Clears the screen to background
; IN/OUT: Nothing (registers preserved)
os_clear_screen:
  pusha
  mov edx, 0                            ; Position cursor at top-left
  call os_move_cursor
  mov ah, 6                             ; Scroll full-screen
  mov al, 0                             ; Normal white on black
  mov bh, 7                             ;
  mov ecx, 0                            ; Top-left
  mov dh, 24                            ; Bottom-right
  mov dl, 79
  int 10h
  popa
  ret
; ------------------------------------------------------------------
; os_move_cursor -- Moves cursor in text mode
; IN: DH, DL = row, column; OUT: Nothing (registers preserved)
os_move_cursor:
  pusha
  mov bh, 0
  mov ah, 2
  int 10h                               ; BIOS interrupt to move cursor
  popa
  ret
; ------------------------------------------------------------------
; os_get_cursor_pos -- Return position of text cursor
; OUT: DH, DL = row, column
os_get_cursor_pos:
  pusha
  mov bh, 0
  mov ah, 3
  int 10h                               ; BIOS interrupt to get cursor position
  mov [.tmp], edx
  popa
  mov edx, [.tmp]
  ret
  .tmp dd 0
; ------------------------------------------------------------------
; os_print_horiz_line -- Draw a horizontal line on the screen
; IN: AX = line type (1 for double (-), otherwise single (=))
; OUT: Nothing (registers preserved)
os_print_horiz_line:
  pusha
  mov ecx, eax                          ; Store line type param
  mov al, 196                           ; Default is single-line code
  cmp ecx, 1                            ; Was double-line specified in AX?
  jne .ready
  mov al, 205                           ; If so, here's the code
.ready:
  mov ecx, 0                            ; Counter
  mov ah, 0Eh                           ; BIOS output char routine
.restart:
  int 10h
  inc ecx
  cmp ecx, 80                           ; Drawn 80 chars yet?
  je .done
  jmp .restart
.done:
  popa
  ret
; ------------------------------------------------------------------
; os_show_cursor -- Turns on cursor in text mode
; IN/OUT: Nothing
os_show_cursor:
  pusha
  mov ch, 6
  mov cl, 7
  mov ah, 1
  mov al, 3
  int 10h
  popa
  ret
; ------------------------------------------------------------------
; os_hide_cursor -- Turns off cursor in text mode
; IN/OUT: Nothing
os_hide_cursor:
  pusha
  mov ch, 32
  mov ah, 1
  mov al, 3                             ; Must be video mode for buggy BIOSes!
  int 10h
  popa
  ret
; ------------------------------------------------------------------
; os_draw_block -- Render block of specified colour
; IN: BL/DL/DH/SI/DI = colour/start X pos/start Y pos/width/finish Y pos
os_draw_block:
  pusha
.more:
  call os_move_cursor                   ; Move to block starting position
  mov ah, 09h                           ; Draw colour section
  mov bh, 0
  mov ecx, esi
  mov al, ' '
  int 10h
  inc dh                                ; Get ready for next line
  mov eax, 0
  mov al, dh                            ; Get current Y position into DL
  cmp eax, edi                          ; Reached finishing point (DI)?
  jne .more                             ; If not, keep drawing
  popa
  ret
; ------------------------------------------------------------------
; os_file_selector -- Show a file selection dialog
; IN: Nothing; OUT: AX = location of filename string (or carry set if Esc pressed)
os_file_selector:
  pusha
  mov DWORD [.filename], 0              ; Terminate string in case user leaves without choosing
  mov eax, .buffer                      ; Get comma-separated list of filenames
  call os_get_file_list
  mov eax, .buffer                      ; Show those filenames in a list dialog box
  mov ebx, .help_msg1
  mov ecx, .help_msg2
  call os_list_dialog
  jc .esc_pressed
  dec eax                               ; Result from os_list_box starts from 1, but
                                        ; for our file list offset we want to start from 0
  mov ecx, eax
  mov ebx, 0
  mov esi, .buffer                      ; Get our filename from the list
.loop1:
  cmp ebx, ecx
  je .got_our_filename
  lodsb
  cmp al, ','
  je .comma_found
  jmp .loop1
.comma_found:
  inc ebx
  jmp .loop1
.got_our_filename:                      ; Now copy the filename string
  mov edi, .filename
.loop2:
  lodsb
  cmp al, ','
  je .finished_copying
  cmp al, 0
  je .finished_copying
  stosb
  jmp .loop2
.finished_copying:
  mov BYTE [edi], 0                     ; Zero terminate the filename string
  popa
  mov eax, .filename
  clc
  ret
.esc_pressed:                           ; Set carry flag if Escape was pressed
  popa
  stc
  ret
  .buffer: times 1024 db 0
  .help_msg1 db 'Please select a file using the cursor', 0
  .help_msg2 db 'keys from the list below...', 0
  .filename: times 13 db 0
; ------------------------------------------------------------------
; os_list_dialog -- Show a dialog with a list of options
; IN: AX = comma-separated list of strings to show (zero-terminated),
; BX = first help string, CX = second help string
; OUT: AX = number (starts from 1) of entry selected; carry set if Esc pressed
os_list_dialog:
  pusha
  push eax                              ; Store string list for now
  push ecx                              ; And help strings
  push ebx
  call os_hide_cursor
  mov cl, 0                             ; Count the number of entries in the list
  mov esi, eax
.count_loop:
  lodsb
  cmp al, 0
  je .done_count
  cmp al, ','
  jne .count_loop
  inc cl
  jmp .count_loop
.done_count:
  inc cl
  mov BYTE [.num_of_entries], cl
  mov bl, 01001111b                     ; White on red
  mov dl, 20                            ; Start X position
  mov dh, 2                             ; Start Y position
  mov esi, 40                           ; Width
  mov edi, 23                           ; Finish Y position
  call os_draw_block                    ; Draw option selector window
  mov dl, 21                            ; Show first line of help text...
  mov dh, 3
  call os_move_cursor
  pop esi                               ; Get back first string
  call os_print_string
  inc dh                                ; ...and the second
  call os_move_cursor
  pop esi
  call os_print_string
  pop esi                               ; SI = location of option list string (pushed earlier)
  mov DWORD [.list_string], esi
                                        ; Now that we've drawn the list, highlight the currently selected
                                        ; entry and let the user move up and down using the cursor keys
  mov BYTE [.skip_num], 0               ; Not skipping any lines at first showing
  mov dl, 25                            ; Set up starting position for selector
  mov dh, 7
  call os_move_cursor
.more_select:
  pusha
  mov bl, 11110000b                     ; Black on white for option list box
  mov dl, 21
  mov dh, 6
  mov esi, 38
  mov edi, 22
  call os_draw_block
  popa
  call .draw_black_bar
  mov DWORD esi, [.list_string]
  call .draw_list
.another_key:
  call os_wait_for_key                  ; Move / select option
  cmp ah, 48h                           ; Up pressed?
  je .go_up
  cmp ah, 50h                           ; Down pressed?
  je .go_down
  cmp al, 13                            ; Enter pressed?
  je .option_selected
  cmp al, 27                            ; Esc pressed?
  je .esc_pressed
  jmp .more_select                      ; If not, wait for another key
.go_up:
  cmp dh, 7                             ; Already at top?
  jle .hit_top
  call .draw_white_bar
  mov dl, 25
  call os_move_cursor
  dec dh                                ; Row to select (increasing down)
  jmp .more_select
.go_down:                               ; Already at bottom of list?
  cmp dh, 20
  je .hit_bottom
  mov ecx, 0
  mov cl, dh
  sub cl, 7
  inc cl
  add cl, [.skip_num]
  mov al, [.num_of_entries]
  cmp cl, al
  je .another_key
  call .draw_white_bar
  mov dl, 25
  call os_move_cursor
  inc dh
  jmp .more_select
.hit_top:
  mov cl, [.skip_num]                   ; Any lines to scroll up?
  cmp cl, 0
  je .another_key                       ; If not, wait for another key
  dec BYTE [.skip_num]                  ; If so, decrement lines to skip
  jmp .more_select
.hit_bottom:                            ; See if there's more to scroll
  mov ecx, 0
  mov cl, dh
  sub cl, 7
  inc cl
  add cl, [.skip_num]
  mov al, [.num_of_entries]
  cmp cl, al
  je .another_key
  inc BYTE [.skip_num]                  ; If so, increment lines to skip
  jmp .more_select
.option_selected:
  call os_show_cursor
  sub dh, 7
  mov eax, 0
  mov al, dh
  inc al                                ; Options start from 1
  add al, [.skip_num]                   ; Add any lines skipped from scrolling
  mov DWORD [.tmp], eax                 ; Store option number before restoring all other regs
  popa
  mov eax, [.tmp]
  clc                                   ; Clear carry as Esc wasn't pressed
  ret
.esc_pressed:
  call os_show_cursor
  popa
  stc                                   ; Set carry for Esc
  ret
.draw_list:
  pusha
  mov dl, 23                            ; Get into position for option list text
  mov dh, 7
  call os_move_cursor
  mov ecx, 0                            ; Skip lines scrolled off the top of the dialog
  mov cl, [.skip_num]
.skip_loop:
  cmp ecx, 0
  je .skip_loop_finished
.more_lodsb:
  lodsb
  cmp al, ','
  jne .more_lodsb
  dec ecx
  jmp .skip_loop
.skip_loop_finished:
  mov ebx, 0                            ; Counter for total number of options
.more:
  lodsb                                 ; Get next character in file name, increment pointer
  cmp al, 0                             ; End of string?
  je .done_list
  cmp al, ','                           ; Next option? (String is comma-separated)
  je .newline
  mov ah, 0Eh
  int 10h
  jmp .more
.newline:
  mov dl, 23                            ; Go back to starting X position
  inc dh                                ; But jump down a line
  call os_move_cursor
  inc ebx                               ; Update the number-of-options counter
  cmp ebx, 14                           ; Limit to one screen of options
  jl .more
.done_list:
  popa
  call os_move_cursor
  ret
.draw_black_bar:
  pusha
  mov dl, 22
  call os_move_cursor
  mov ah, 09h                           ; Draw white bar at top
  mov bh, 0
  mov ecx, 36
  mov bl, 00001111b                     ; White text on black background
  mov al, ' '
  int 10h
  popa
  ret
.draw_white_bar:
  pusha
  mov dl, 22
  call os_move_cursor
  mov ah, 09h                           ; Draw white bar at top
  mov bh, 0
  mov ecx, 36
  mov bl, 11110000b                     ; Black text on white background
  mov al, ' '
  int 10h
  popa
  ret
  .tmp dd 0
  .num_of_entries db 0
  .skip_num db 0
  .list_string dd 0
; ------------------------------------------------------------------
; os_draw_background -- Clear screen with white top and bottom bars
; containing text, and a coloured middle section.
; IN: AX/BX = top/bottom string locations, CX = colour
os_draw_background:
  pusha
  push eax                              ; Store params to pop out later
  push ebx
  push ecx
  mov dl, 0
  mov dh, 0
  call os_move_cursor
  mov ah, 09h                           ; Draw white bar at top
  mov bh, 0
  mov ecx, 80
  mov bl, 01110000b
  mov al, ' '
  int 10h
  mov dh, 1
  mov dl, 0
  call os_move_cursor
  mov ah, 09h                           ; Draw colour section
  mov ecx, 1840
  pop ebx                               ; Get colour param (originally in CX)
  mov bh, 0
  mov al, ' '
  int 10h
  mov dh, 24
  mov dl, 0
  call os_move_cursor
  mov ah, 09h                           ; Draw white bar at bottom
  mov bh, 0
  mov ecx, 80
  mov bl, 01110000b
  mov al, ' '
  int 10h
  mov dh, 24
  mov dl, 1
  call os_move_cursor
  pop ebx                               ; Get bottom string param
  mov esi, ebx
  call os_print_string
  mov dh, 0
  mov dl, 1
  call os_move_cursor
  pop eax                               ; Get top string param
  mov esi, eax
  call os_print_string
  mov dh, 1                             ; Ready for app text
  mov dl, 0
  call os_move_cursor
  popa
  ret
; ------------------------------------------------------------------
; os_print_newline -- Reset cursor to start of next line
; IN/OUT: Nothing (registers preserved)
os_print_newline:
  pusha
  mov ah, 0Eh                           ; BIOS output char code
  mov al, 13
  int 10h
  mov al, 10
  int 10h
  popa
  ret
; ------------------------------------------------------------------
; os_dump_registers -- Displays register contents in hex on the screen
; IN/OUT: EAX/EBX/ECX/EDX/ESI/EDI = registers to show
os_dump_registers:
  pusha
  call os_print_newline
  push edi
  push esi
  push edx
  push ecx
  push ebx
  mov esi, .ax_string
  call os_print_string
  call os_print_8hex
  pop eax
  mov esi, .bx_string
  call os_print_string
  call os_print_8hex
  pop eax
  mov esi, .cx_string
  call os_print_string
  call os_print_8hex
  pop eax
  mov esi, .dx_string
  call os_print_string
  call os_print_8hex
  pop eax
  mov esi, .si_string
  call os_print_string
  call os_print_8hex
  pop eax
  mov esi, .di_string
  call os_print_string
  call os_print_8hex
  call os_print_newline
  popa
  ret
  .ax_string db 'EAX:', 0
  .bx_string db ' EBX:', 0
  .cx_string db ' ECX:', 0
  .dx_string db ' EDX:', 0
  .si_string db ' ESI:', 0
  .di_string db ' EDI:', 0
; ------------------------------------------------------------------
; os_input_dialog -- Get text string from user via a dialog box
; IN: AX = string location, BX = message to show; OUT: AX = string location
os_input_dialog:
  pusha
  push eax                              ; Save string location
  push ebx                              ; Save message to show
  mov dh, 10                            ; First, draw red background box
  mov dl, 12
.redbox:                                ; Loop to draw all lines of box
  call os_move_cursor
  pusha
  mov ah, 09h
  mov bh, 0
  mov ecx, 55
  mov bl, 01001111b                     ; White on red
  mov al, ' '
  int 10h
  popa
  inc dh
  cmp dh, 16
  je .boxdone
  jmp .redbox
.boxdone:
  mov dl, 14
  mov dh, 11
  call os_move_cursor
  pop ebx                               ; Get message back and display it
  mov esi, ebx
  call os_print_string
  mov dl, 14
  mov dh, 13
  call os_move_cursor
  pop eax                               ; Get input string back
  call os_input_string
  popa
  ret
; ------------------------------------------------------------------
; os_dialog_box -- Print dialog box in middle of screen, with button(s)
; IN: AX, BX, CX = string locations (set registers to 0 for no display)
; IN: DX = 0 for single 'OK' dialog, 1 for two-button 'OK' and 'Cancel'
; OUT: If two-button mode, AX = 0 for OK and 1 for cancel
; NOTE: Each string is limited to 40 characters
os_dialog_box:
  pusha
  mov [.tmp], edx
  call os_hide_cursor
  mov dh, 9                             ; First, draw red background box
  mov dl, 19
.redbox:                                ; Loop to draw all lines of box
  call os_move_cursor
  pusha
  mov ah, 09h
  mov bh, 0
  mov ecx, 42
  mov bl, 01001111b                     ; White on red
  mov al, ' '
  int 10h
  popa
  inc dh
  cmp dh, 16
  je .boxdone
  jmp .redbox
.boxdone:
  cmp eax, 0                            ; Skip string params if zero
  je .no_first_string
  mov dl, 20
  mov dh, 10
  call os_move_cursor
  mov esi, eax                          ; First string
  call os_print_string
.no_first_string:
  cmp ebx, 0
  je .no_second_string
  mov dl, 20
  mov dh, 11
  call os_move_cursor
  mov esi, ebx                          ; Second string
  call os_print_string
.no_second_string:
  cmp ecx, 0
  je .no_third_string
  mov dl, 20
  mov dh, 12
  call os_move_cursor
  mov esi, ecx                          ; Third string
  call os_print_string
.no_third_string:
  mov edx, [.tmp]
  cmp edx, 0
  je .one_button
  cmp edx, 1
  je .two_button
.one_button:
  mov bl, 11110000b                     ; Black on white
  mov dh, 14
  mov dl, 35
  mov esi, 8
  mov edi, 15
  call os_draw_block
  mov dl, 38                            ; OK button, centred at bottom of box
  mov dh, 14
  call os_move_cursor
  mov esi, .ok_button_string
  call os_print_string
  jmp .one_button_wait
.two_button:
  mov bl, 11110000b                     ; Black on white
  mov dh, 14
  mov dl, 27
  mov esi, 8
  mov edi, 15
  call os_draw_block
  mov dl, 30                            ; OK button
  mov dh, 14
  call os_move_cursor
  mov esi, .ok_button_string
  call os_print_string
  mov dl, 44                            ; Cancel button
  mov dh, 14
  call os_move_cursor
  mov esi, .cancel_button_string
  call os_print_string
  mov ecx, 0                            ; Default button = 0
  jmp .two_button_wait
.one_button_wait:
  call os_wait_for_key
  cmp al, 13                            ; Wait for enter key (13) to be pressed
  jne .one_button_wait
  call os_show_cursor
  popa
  ret
.two_button_wait:
  call os_wait_for_key
  cmp ah, 75                            ; Left cursor key pressed?
  jne .noleft
  mov bl, 11110000b                     ; Black on white
  mov dh, 14
  mov dl, 27
  mov esi, 8
  mov edi, 15
  call os_draw_block
  mov dl, 30                            ; OK button
  mov dh, 14
  call os_move_cursor
  mov esi, .ok_button_string
  call os_print_string
  mov bl, 01001111b                     ; White on red for cancel button
  mov dh, 14
  mov dl, 42
  mov esi, 9
  mov edi, 15
  call os_draw_block
  mov dl, 44                            ; Cancel button
  mov dh, 14
  call os_move_cursor
  mov esi, .cancel_button_string
  call os_print_string
  mov ecx, 0                            ; And update result we'll return
  jmp .two_button_wait
.noleft:
  cmp ah, 77                            ; Right cursor key pressed?
  jne .noright
  mov bl, 01001111b                     ; Black on white
  mov dh, 14
  mov dl, 27
  mov esi, 8
  mov edi, 15
  call os_draw_block
  mov dl, 30                            ; OK button
  mov dh, 14
  call os_move_cursor
  mov esi, .ok_button_string
  call os_print_string
  mov bl, 11110000b                     ; White on red for cancel button
  mov dh, 14
  mov dl, 43
  mov esi, 8
  mov edi, 15
  call os_draw_block
  mov dl, 44                            ; Cancel button
  mov dh, 14
  call os_move_cursor
  mov esi, .cancel_button_string
  call os_print_string
  mov ecx, 1                            ; And update result we'll return
  jmp .two_button_wait
.noright:
  cmp al, 13                            ; Wait for enter key (13) to be pressed
  jne .two_button_wait
  call os_show_cursor
  mov [.tmp], ecx                       ; Keep result after restoring all regs
  popa
  mov eax, [.tmp]
  ret
  .ok_button_string db 'OK', 0
  .cancel_button_string db 'Cancel', 0
  .ok_button_noselect db ' OK ', 0
  .cancel_button_noselect db ' Cancel ', 0
  .tmp dd 0
; ------------------------------------------------------------------
; os_print_space -- Print a space to the screen
; IN/OUT: Nothing
os_print_space:
  pusha
  mov ah, 0Eh                           ; BIOS teletype function
  mov al, 20h                           ; Space is character 20h
  int 10h
  popa
  ret
; ------------------------------------------------------------------
; os_dump_string -- Dump string as hex bytes and printable characters
; IN: SI = points to string to dump
os_dump_string:
  pusha
  mov ebx, esi                          ; Save for final print
.line:
  mov edi, esi                          ; Save current pointer
  mov ecx, 0                            ; Byte counter
.more_hex:
  lodsb
  cmp al, 0
  je .chr_print
  call os_print_2hex
  call os_print_space                   ; Single space most bytes
  inc ecx
  cmp ecx, 8
  jne .q_next_line
  call os_print_space                   ; Double space centre of line
  jmp .more_hex
.q_next_line:
  cmp ecx, 16
  jne .more_hex
.chr_print:
  call os_print_space
  mov ah, 0Eh                           ; BIOS teletype function
  mov al, '|'                           ; Break between hex and character
  int 10h
  call os_print_space
  mov esi, edi                          ; Go back to beginning of this line
  mov ecx, 0
.more_chr:
  lodsb
  cmp al, 0
  je .done
  cmp al, ' '
  jae .tst_high
  jmp short .not_printable
.tst_high:
  cmp al, '~'
  jbe .output
.not_printable:
  mov al, '.'
.output:
  mov ah, 0Eh
  int 10h
  inc ecx
  cmp ecx, 16
  jl .more_chr
  call os_print_newline                 ; Go to next line
  jmp .line
.done:
  call os_print_newline                 ; Go to next line
  popa
  ret
; ------------------------------------------------------------------
; os_print_digit -- Displays contents of AX as a single digit
; Works up to base 37, ie digits 0-Z
; IN: AX = "digit" to format and print
os_print_digit:
  pusha
  cmp eax, 9                            ; There is a break in ASCII table between 9 and A
  jle .digit_format
  add eax, 'A'-'9'-1                    ; Correct for the skipped punctuation
.digit_format:
  add eax, '0'                          ; 0 will display as '0', etc. 
  mov ah, 0Eh                           ; May modify other registers
  int 10h
  popa
  ret
; ------------------------------------------------------------------
; os_print_1hex -- Displays low nibble of AL in hex format
; IN: AL = number to format and print
os_print_1hex:
  pusha
  and eax, 0Fh                          ; Mask off data to display
  call os_print_digit
  popa
  ret
; ------------------------------------------------------------------
; os_print_2hex -- Displays AL in hex format
; IN: AL = number to format and print
os_print_2hex:
  pusha
  push eax                              ; Output high nibble
  shr eax, 4
  call os_print_1hex
  pop eax                               ; Output low nibble
  call os_print_1hex
  popa
  ret
; ------------------------------------------------------------------
; os_print_4hex -- Displays AX in hex format
; IN: AX = number to format and print
os_print_4hex:
  pusha
  push eax                              ; Output high byte
  mov al, ah
  call os_print_2hex
  pop eax                               ; Output low byte
  call os_print_2hex
  popa
  ret
; ------------------------------------------------------------------
; os_print_8hex -- Displays EAX in hex format
; IN: AX = number to format and print
os_print_8hex:
  pusha
  push eax                              ; Output high word
  shr eax, 16
  call os_print_4hex
  pop eax                               ; Output low word
  call os_print_4hex
  popa
  ret
; ------------------------------------------------------------------
; os_input_string -- Take string from keyboard entry
; IN/OUT: AX = location of string, other regs preserved
; (Location will contain up to 255 characters, zero-terminated)
os_input_string:
  pusha
  mov edi, eax                          ; DI is where we'll store input (buffer)
  mov ecx, 0                            ; Character received counter for backspace
.more:                                  ; Now onto string getting
  call os_wait_for_key
  cmp al, 13                            ; If Enter key pressed, finish
  je .done
  cmp al, 8                             ; Backspace pressed?
  je .backspace                         ; If not, skip following checks
  cmp al, ' '                           ; In ASCII range (32 - 126)?
  jb .more                              ; Ignore most non-printing characters
  cmp al, '~'
  ja .more
  jmp .nobackspace
.backspace:
  cmp ecx, 0                            ; Backspace at start of string?
  je .more                              ; Ignore it if so
  call os_get_cursor_pos                ; Backspace at start of screen line?
  cmp dl, 0
  je .backspace_linestart
  pusha
  mov ah, 0Eh                           ; If not, write space and move cursor back
  mov al, 8
  int 10h                               ; Backspace twice, to clear space
  mov al, 32
  int 10h
  mov al, 8
  int 10h
  popa
  dec edi                               ; Character position will be overwritten by new
                                        ; character or terminator at end
  dec ecx                               ; Step back counter
  jmp .more
.backspace_linestart:
  dec dh                                ; Jump back to end of previous line
  mov dl, 79
  call os_move_cursor
  mov al, ' '                           ; Print space there
  mov ah, 0Eh
  int 10h
  mov dl, 79                            ; And jump back before the space
  call os_move_cursor
  dec edi                               ; Step back position in string
  dec ecx                               ; Step back counter
  jmp .more
.nobackspace:
  pusha
  mov ah, 0Eh                           ; Output entered, printable character
  int 10h
  popa
  stosb                                 ; Store character in designated buffer
  inc ecx                               ; Characters processed += 1
  cmp ecx, 254                          ; Make sure we don't exhaust buffer
  jae .done
  jmp .more                             ; Still room for more
.done:
  mov eax, 0
  stosb
  popa
  ret
; ==================================================================
