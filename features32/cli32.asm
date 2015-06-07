; ==================================================================
; MikeOS -- The Mike Operating System kernel
; Copyright (C) 2006 - 2013 MikeOS Developers -- see doc/LICENSE.TXT
;
; COMMAND LINE INTERFACE
; ==================================================================
os_command_line:
  call os_clear_screen
  mov esi, version_msg
  call os_print_string
  mov esi, help_text
  call os_print_string
get_cmd:                                ; Main processing loop
  mov edi, input                        ; Clear input buffer each time
  mov al, 0
  mov ecx, 256
  rep stosb
  mov edi, command                      ; And single command buffer
  mov ecx, 32
  rep stosb
  mov esi, prompt                       ; Main loop; prompt for input
  call os_print_string
  mov eax, input                        ; Get command string from user
  call os_input_string
  call os_print_newline
  mov eax, input                        ; Remove trailing spaces
  call os_string_chomp
  mov esi, input                        ; If just enter pressed, prompt again
  cmp BYTE [esi], 0
  je get_cmd
  mov esi, input                        ; Separate out the individual command
  mov al, ' '
  call os_string_tokenize
  mov DWORD [param_list], edi           ; Store location of full parameters
  mov esi, input                        ; Store copy of command for later modifications
  mov edi, command
  call os_string_copy
                                        ; First, let's check to see if it's an internal command...
  mov eax, input
  call os_string_uppercase
  mov esi, input
  mov edi, exit_string                  ; 'EXIT' entered?
  call os_string_compare
  jc exit
  mov edi, help_string                  ; 'HELP' entered?
  call os_string_compare
  jc print_help
  mov edi, cls_string                   ; 'CLS' entered?
  call os_string_compare
  jc clear_screen
  mov edi, dir_string                   ; 'DIR' entered?
  call os_string_compare
  jc list_directory
  mov edi, ver_string                   ; 'VER' entered?
  call os_string_compare
  jc print_ver
  mov edi, time_string                  ; 'TIME' entered?
  call os_string_compare
  jc print_time
  mov edi, date_string                  ; 'DATE' entered?
  call os_string_compare
  jc print_date
  mov edi, cat_string                   ; 'CAT' entered?
  call os_string_compare
  jc cat_file
  mov edi, del_string                   ; 'DEL' entered?
  call os_string_compare
  jc del_file
  mov edi, copy_string                  ; 'COPY' entered?
  call os_string_compare
  jc copy_file
  mov edi, ren_string                   ; 'REN' entered?
  call os_string_compare
  jc ren_file
  mov edi, size_string                  ; 'SIZE' entered?
  call os_string_compare
  jc size_file
                                        ; If the user hasn't entered any of the above commands, then we
                                        ; need to check for an executable file -- .BIN or .BAS, and the
                                        ; user may not have provided the extension
  mov eax, command
  call os_string_uppercase
  call os_string_length
                                        ; If the user has entered, say, MEGACOOL.BIN, we want to find that .BIN
                                        ; bit, so we get the length of the command, go four characters back to
                                        ; the full stop, and start searching from there
  mov esi, command
  add esi, eax
  sub esi, 4
  mov edi, bin_extension                ; Is there a .BIN extension?
  call os_string_compare
  jc bin_file
  mov edi, bas_extension                ; Or is there a .BAS extension?
  call os_string_compare
  jc bas_file
  jmp no_extension
bin_file:
  mov eax, command
  mov ebx, 0
  mov ecx, LOAD_ADDRESS
  call os_load_file
  jc total_fail
execute_bin:
  mov esi, command
  mov edi, kern_file_string
  mov ecx, 6
  call os_string_strincmp
  jc no_kernel_allowed
  mov eax, 0                            ; Clear all registers
  mov ebx, 0
  mov ecx, 0
  mov edx, 0
  mov DWORD esi, [param_list]
  mov edi, 0
  call LOAD_ADDRESS                            ; Call the external program
  jmp get_cmd                           ; When program has finished, start again
bas_file:
  mov eax, command
  mov ebx, 0
  mov ecx, LOAD_ADDRESS
  call os_load_file
  jc total_fail
  mov eax, LOAD_ADDRESS
  mov DWORD esi, [param_list]
  call os_run_basic
  jmp get_cmd
no_extension:
  mov eax, command
  call os_string_length
  mov esi, command
  add esi, eax
  mov BYTE [esi], '.'
  mov BYTE [esi+1], 'B'
  mov BYTE [esi+2], 'I'
  mov BYTE [esi+3], 'N'
  mov BYTE [esi+4], 0
  mov eax, command
  mov ebx, 0
  mov ecx, LOAD_ADDRESS
  call os_load_file
  jc try_bas_ext
  jmp execute_bin
try_bas_ext:
  mov eax, command
  call os_string_length
  mov esi, command
  add esi, eax
  sub esi, 4
  mov BYTE [esi], '.'
  mov BYTE [esi+1], 'B'
  mov BYTE [esi+2], 'A'
  mov BYTE [esi+3], 'S'
  mov BYTE [esi+4], 0
  jmp bas_file
total_fail:
  mov esi, invalid_msg
  call os_print_string
  jmp get_cmd
no_kernel_allowed:
  mov esi, kern_warn_msg
  call os_print_string
  jmp get_cmd
; ------------------------------------------------------------------
print_help:
  mov esi, help_text
  call os_print_string
  jmp get_cmd
; ------------------------------------------------------------------
clear_screen:
  call os_clear_screen
  jmp get_cmd
; ------------------------------------------------------------------
print_time:
  mov ebx, tmp_string
  call os_get_time_string
  mov esi, ebx
  call os_print_string
  call os_print_newline
  jmp get_cmd
; ------------------------------------------------------------------
print_date:
  mov ebx, tmp_string
  call os_get_date_string
  mov esi, ebx
  call os_print_string
  call os_print_newline
  jmp get_cmd
; ------------------------------------------------------------------
print_ver:
  mov esi, version_msg
  call os_print_string
  jmp get_cmd
; ------------------------------------------------------------------
kern_warning:
  mov esi, kern_warn_msg
  call os_print_string
  jmp get_cmd
; ------------------------------------------------------------------
list_directory:
  mov ecx, 0                            ; Counter
  mov eax, dirlist                      ; Get list of files on disk
  call os_get_file_list
  mov esi, dirlist
  mov ah, 0Eh                           ; BIOS teletype function
.repeat:
  lodsb                                 ; Start printing filenames
  cmp al, 0                             ; Quit if end of string
  je .done
  cmp al, ','                           ; If comma in list string, don't print it
  jne .nonewline
  pusha
  call os_print_newline                 ; But print a newline instead
  popa
  jmp .repeat
.nonewline:
  int 10h
  jmp .repeat
.done:
  call os_print_newline
  jmp get_cmd
; ------------------------------------------------------------------
cat_file:
  mov DWORD esi, [param_list]
  call os_string_parse
  cmp eax, 0                            ; Was a filename provided?
  jne .filename_provided
  mov esi, nofilename_msg               ; If not, show error message
  call os_print_string
  jmp get_cmd
.filename_provided:
  call os_file_exists                   ; Check if file exists
  jc .not_found
  mov ecx, LOAD_ADDRESS                        ; Load file into second 32K
  call os_load_file
  mov DWORD [file_size], ebx
  cmp ebx, 0                            ; Nothing in the file?
  je get_cmd
  mov esi, LOAD_ADDRESS
  mov ah, 0Eh                           ; int 10h teletype function
.loop:
  lodsb                                 ; Get byte from loaded file
  cmp al, 0Ah                           ; Move to start of line if we get a newline char
  jne .not_newline
  call os_get_cursor_pos
  mov dl, 0
  call os_move_cursor
.not_newline:
  int 10h                               ; Display it
  dec ebx                               ; Count down file size
  cmp ebx, 0                            ; End of file?
  jne .loop
  jmp get_cmd
.not_found:
  mov esi, notfound_msg
  call os_print_string
  jmp get_cmd
; ------------------------------------------------------------------
del_file:
  mov DWORD esi, [param_list]
  call os_string_parse
  cmp eax, 0                            ; Was a filename provided?
  jne .filename_provided
  mov esi, nofilename_msg               ; If not, show error message
  call os_print_string
  jmp get_cmd
.filename_provided:
  call os_remove_file
  jc .failure
  mov esi, .success_msg
  call os_print_string
  mov esi, eax
  call os_print_string
  call os_print_newline
  jmp get_cmd
.failure:
  mov esi, .failure_msg
  call os_print_string
  jmp get_cmd
  .success_msg db 'Deleted file: ', 0
  .failure_msg db 'Could not delete file - does not exist or write protected', 13, 10, 0
; ------------------------------------------------------------------
size_file:
  mov DWORD esi, [param_list]
  call os_string_parse
  cmp eax, 0                            ; Was a filename provided?
  jne .filename_provided
  mov esi, nofilename_msg               ; If not, show error message
  call os_print_string
  jmp get_cmd
.filename_provided:
  call os_get_file_size
  jc .failure
  mov esi, .size_msg
  call os_print_string
  mov eax, ebx
  call os_int_to_string
  mov esi, eax
  call os_print_string
  call os_print_newline
  jmp get_cmd
.failure:
  mov esi, notfound_msg
  call os_print_string
  jmp get_cmd
  .size_msg db 'Size (in bytes) is: ', 0
; ------------------------------------------------------------------
copy_file:
  mov DWORD esi, [param_list]
  call os_string_parse
  mov DWORD [.tmp], ebx
  cmp ebx, 0                            ; Were two filenames provided?
  jne .filename_provided
  mov esi, nofilename_msg               ; If not, show error message
  call os_print_string
  jmp get_cmd
.filename_provided:
  mov edx, eax                          ; Store first filename temporarily
  mov eax, ebx
  call os_file_exists
  jnc .already_exists
  mov eax, edx
  mov ecx, LOAD_ADDRESS
  call os_load_file
  jc .load_fail
  mov ecx, ebx
  mov ebx, LOAD_ADDRESS
  mov eax, [.tmp]
  call os_write_file
  jc .write_fail
  mov esi, .success_msg
  call os_print_string
  jmp get_cmd
.load_fail:
  mov esi, notfound_msg
  call os_print_string
  jmp get_cmd
.write_fail:
  mov esi, writefail_msg
  call os_print_string
  jmp get_cmd
.already_exists:
  mov esi, exists_msg
  call os_print_string
  jmp get_cmd
  .tmp dd 0
  .success_msg db 'File copied successfully', 13, 10, 0
; ------------------------------------------------------------------
ren_file:
  mov DWORD esi, [param_list]
  call os_string_parse
  cmp ebx, 0                            ; Were two filenames provided?
  jne .filename_provided
  mov esi, nofilename_msg               ; If not, show error message
  call os_print_string
  jmp get_cmd
.filename_provided:
  mov ecx, eax                          ; Store first filename temporarily
  mov eax, ebx                          ; Get destination
  call os_file_exists                   ; Check to see if it exists
  jnc .already_exists
  mov eax, ecx                          ; Get first filename back
  call os_rename_file
  jc .failure
  mov esi, .success_msg
  call os_print_string
  jmp get_cmd
.already_exists:
  mov esi, exists_msg
  call os_print_string
  jmp get_cmd
.failure:
  mov esi, .failure_msg
  call os_print_string
  jmp get_cmd
  .success_msg db 'File renamed successfully', 13, 10, 0
  .failure_msg db 'Operation failed - file not found or invalid filename', 13, 10, 0
; ------------------------------------------------------------------
exit:
  ret
; ------------------------------------------------------------------
  input: times 256 db 0
  command: times 32 db 0
  dirlist: times 1024 db 0
  tmp_string: times 15 db 0
  file_size dd 0
  param_list dd 0
  bin_extension db '.BIN', 0
  bas_extension db '.BAS', 0
  prompt db '> ', 0
  help_text db 'Commands: DIR, COPY, REN, DEL, CAT, SIZE, CLS, HELP, TIME, DATE, VER, EXIT', 13, 10, 0
  invalid_msg db 'No such command or program', 13, 10, 0
  nofilename_msg db 'No filename or not enough filenames', 13, 10, 0
  notfound_msg db 'File not found', 13, 10, 0
  writefail_msg db 'Could not write file. Write protected or invalid filename?', 13, 10, 0
  exists_msg db 'Target file already exists!', 13, 10, 0
  version_msg db 'MikeOS32 ', MikeOS32_VER, 13, 10, 0
  exit_string db 'EXIT', 0
  help_string db 'HELP', 0
  cls_string db 'CLS', 0
  dir_string db 'DIR', 0
  time_string db 'TIME', 0
  date_string db 'DATE', 0
  ver_string db 'VER', 0
  cat_string db 'CAT', 0
  del_string db 'DEL', 0
  ren_string db 'REN', 0
  copy_string db 'COPY', 0
  size_string db 'SIZE', 0
  kern_file_string db 'KERNEL', 0
  kern_warn_msg db 'Cannot execute kernel file!', 13, 10, 0
; ==================================================================
