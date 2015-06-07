; ==================================================================
; MikeOS -- The Mike Operating System kernel
; Copyright (C) 2006 - 2013 MikeOS Developers -- see doc/LICENSE.TXT
;
; STRING MANIPULATION ROUTINES
; ==================================================================
; ------------------------------------------------------------------
; os_string_length -- Return length of a string
; IN: AX = string location
; OUT AX = length (other regs preserved)
os_string_length:
  pusha
  mov ebx, eax                          ; Move location of string to BX
  mov ecx, 0                            ; Counter
.more:
  cmp BYTE [ebx], 0                     ; Zero (end of string) yet?
  je .done
  inc ebx                               ; If not, keep adding
  inc ecx
  jmp .more
.done:
  mov DWORD [.tmp_counter], ecx         ; Store count before restoring other registers
  popa
  mov eax, [.tmp_counter]               ; Put count back into AX before returning
  ret
  .tmp_counter dd 0
; ------------------------------------------------------------------
; os_string_reverse -- Reverse the characters in a string
; IN: SI = string location
os_string_reverse:
  pusha
  cmp BYTE [esi], 0                     ; Don't attempt to reverse empty string
  je .end
  mov eax, esi
  call os_string_length
  mov edi, esi
  add edi, eax
  dec edi                               ; DI now points to last char in string
.loop:
  mov al, [esi]                         ; Swap bytes
  mov bl, [edi]
  mov BYTE [esi], bl
  mov BYTE [edi], al
  inc esi                               ; Move towards string centre
  dec edi
  cmp edi, esi                          ; Both reached the centre?
  ja .loop
.end:
  popa
  ret
; ------------------------------------------------------------------
; os_find_char_in_string -- Find location of character in a string
; IN: SI = string location, AL = character to find
; OUT: AX = location in string, or 0 if char not present
os_find_char_in_string:
  pusha
  mov ecx, 1                            ; Counter -- start at first char (we count
                                        ; from 1 in chars here, so that we can
                                        ; return 0 if the source char isn't found)
.more:
  cmp BYTE [esi], al
  je .done
  cmp BYTE [esi], 0
  je .notfound
  inc esi
  inc ecx
  jmp .more
.done:
  mov [.tmp], ecx
  popa
  mov eax, [.tmp]
  ret
.notfound:
  popa
  mov eax, 0
  ret
  .tmp dd 0
; ------------------------------------------------------------------
; os_string_charchange -- Change instances of character in a string
; IN: SI = string, AL = char to find, BL = char to replace with
os_string_charchange:
  pusha
  mov cl, al
.loop:
  mov al, [esi]
  cmp al, 0
  je .finish
  cmp al, cl
  jne .nochange
  mov BYTE [esi], bl
.nochange:
  inc esi
  jmp .loop
.finish:
  popa
  ret
; ------------------------------------------------------------------
; os_string_uppercase -- Convert zero-terminated string to upper case
; IN/OUT: AX = string location
os_string_uppercase:
  pusha
  mov esi, eax                          ; Use SI to access string
.more:
  cmp BYTE [esi], 0                     ; Zero-termination of string?
  je .done                              ; If so, quit
  cmp BYTE [esi], 'a'                   ; In the lower case A to Z range?
  jb .noatoz
  cmp BYTE [esi], 'z'
  ja .noatoz
  sub BYTE [esi], 20h                   ; If so, convert input char to upper case
  inc esi
  jmp .more
.noatoz:
  inc esi
  jmp .more
.done:
  popa
  ret
; ------------------------------------------------------------------
; os_string_lowercase -- Convert zero-terminated string to lower case
; IN/OUT: AX = string location
os_string_lowercase:
  pusha
  mov esi, eax                          ; Use SI to access string
.more:
  cmp BYTE [esi], 0                     ; Zero-termination of string?
  je .done                              ; If so, quit
  cmp BYTE [esi], 'A'                   ; In the upper case A to Z range?
  jb .noatoz
  cmp BYTE [esi], 'Z'
  ja .noatoz
  add BYTE [esi], 20h                   ; If so, convert input char to lower case
  inc esi
  jmp .more
.noatoz:
  inc esi
  jmp .more
.done:
  popa
  ret
; ------------------------------------------------------------------
; os_string_copy -- Copy one string into another
; IN/OUT: SI = source, DI = destination (programmer ensure sufficient room)
os_string_copy:
  pusha
.more:
  mov al, [esi]                         ; Transfer contents (at least one byte terminator)
  mov [edi], al
  inc esi
  inc edi
  cmp al, 0                             ; If source string is empty, quit out
  jne .more
.done:
  popa
  ret
; ------------------------------------------------------------------
; os_string_truncate -- Chop string down to specified number of characters
; IN: SI = string location, AX = number of characters
; OUT: String modified, registers preserved
os_string_truncate:
  pusha
  add esi, eax
  mov BYTE [esi], 0
  popa
  ret
; ------------------------------------------------------------------
; os_string_join -- Join two strings into a third string
; IN/OUT: AX = string one, BX = string two, CX = destination string
os_string_join:
  pusha
  mov esi, eax                          ; Put first string into CX
  mov edi, ecx
  call os_string_copy
  call os_string_length                 ; Get length of first string
  add ecx, eax                          ; Position at end of first string
  mov esi, ebx                          ; Add second string onto it
  mov edi, ecx
  call os_string_copy
  popa
  ret
; ------------------------------------------------------------------
; os_string_chomp -- Strip leading and trailing spaces from a string
; IN: AX = string location
os_string_chomp:
  pusha
  mov edx, eax                          ; Save string location
  mov edi, eax                          ; Put location into DI
  mov ecx, 0                            ; Space counter
.keepcounting:                          ; Get number of leading spaces into BX
  cmp BYTE [edi], ' '
  jne .counted
  inc ecx
  inc edi
  jmp .keepcounting
.counted:
  cmp ecx, 0                            ; No leading spaces?
  je .finished_copy
  mov esi, edi                          ; Address of first non-space character
  mov edi, edx                          ; DI = original string start
.keep_copying:
  mov al, [esi]                         ; Copy SI into DI
  mov [edi], al                         ; Including terminator
  cmp al, 0
  je .finished_copy
  inc esi
  inc edi
  jmp .keep_copying
.finished_copy:
  mov eax, edx                          ; AX = original string start
  call os_string_length
  cmp eax, 0                            ; If empty or all blank, done, return 'null'
  je .done
  mov esi, edx
  add esi, eax                          ; Move to end of string
.more:
  dec esi
  cmp BYTE [esi], ' '
  jne .done
  mov BYTE [esi], 0                     ; Fill end spaces with 0s
  jmp .more                             ; (First 0 will be the string terminator)
.done:
  popa
  ret
; ------------------------------------------------------------------
; os_string_strip -- Removes specified character from a string (max 255 chars)
; IN: SI = string location, AL = character to remove
os_string_strip:
  pusha
  mov edi, esi
  mov bl, al                            ; Copy the char into BL since LODSB and STOSB use AL
.nextchar:
  lodsb
  stosb
  cmp al, 0                             ; Check if we reached the end of the string
  je .finish                            ; If so, bail out
  cmp al, bl                            ; Check to see if the character we read is the interesting char
  jne .nextchar                         ; If not, skip to the next character
.skip:                                  ; If so, the fall through to here
  dec edi                               ; Decrement DI so we overwrite on the next pass
  jmp .nextchar
.finish:
  popa
  ret
; ------------------------------------------------------------------
; os_string_compare -- See if two strings match
; IN: SI = string one, DI = string two
; OUT: carry set if same, clear if different
os_string_compare:
  pusha
.more:
  mov al, [esi]                         ; Retrieve string contents
  mov bl, [edi]
  cmp al, bl                            ; Compare characters at current location
  jne .not_same
  cmp al, 0                             ; End of first string? Must also be end of second
  je .terminated
  inc esi
  inc edi
  jmp .more
.not_same:                              ; If unequal lengths with same beginning, the byte
  popa                                  ; comparison fails at shortest string terminator
  clc                                   ; Clear carry flag
  ret
.terminated:                            ; Both strings terminated at the same position
  popa
  stc                                   ; Set carry flag
  ret
; ------------------------------------------------------------------
; os_string_strincmp -- See if two strings match up to set number of chars
; IN: SI = string one, DI = string two, CL = chars to check
; OUT: carry set if same, clear if different
os_string_strincmp:
  pusha
.more:
  mov al, [esi]                         ; Retrieve string contents
  mov bl, [edi]
  cmp al, bl                            ; Compare characters at current location
  jne .not_same
  cmp al, 0                             ; End of first string? Must also be end of second
  je .terminated
  inc esi
  inc edi
  dec cl                                ; If we've lasted through our char count
  cmp cl, 0                             ; Then the bits of the string match!
  je .terminated
  jmp .more
.not_same:                              ; If unequal lengths with same beginning, the byte
  popa                                  ; comparison fails at shortest string terminator
  clc                                   ; Clear carry flag
  ret
.terminated:                            ; Both strings terminated at the same position
  popa
  stc                                   ; Set carry flag
  ret
; ------------------------------------------------------------------
; os_string_parse -- Take string (eg "run foo bar baz") and return
; pointers to zero-terminated strings (eg AX = "run", BX = "foo" etc.)
; IN: SI = string; OUT: AX, BX, CX, DX = individual strings
os_string_parse:
  push esi
  mov eax, esi                          ; AX = start of first string
  mov ebx, 0                            ; By default, other strings start empty
  mov ecx, 0
  mov edx, 0
  push eax                              ; Save to retrieve at end
.loop1:
  lodsb                                 ; Get a byte
  cmp al, 0                             ; End of string?
  je .finish
  cmp al, ' '                           ; A space?
  jne .loop1
  dec esi
  mov BYTE [esi], 0                     ; If so, zero-terminate this bit of the string
  inc esi                               ; Store start of next string in BX
  mov ebx, esi
.loop2:                                 ; Repeat the above for CX and DX...
  lodsb
  cmp al, 0
  je .finish
  cmp al, ' '
  jne .loop2
  dec esi
  mov BYTE [esi], 0
  inc esi
  mov ecx, esi
.loop3:
  lodsb
  cmp al, 0
  je .finish
  cmp al, ' '
  jne .loop3
  dec esi
  mov BYTE [esi], 0
  inc esi
  mov edx, esi
.finish:
  pop eax
  pop esi
  ret
; ------------------------------------------------------------------
; os_string_to_int -- Convert decimal string to integer value
; IN: SI = string location (max 5 chars, up to '65536')
; OUT: AX = number
os_string_to_int:
  pusha
  mov eax, esi                          ; First, get length of string
  call os_string_length
  add esi, eax                          ; Work from rightmost char in string
  dec esi
  mov ecx, eax                          ; Use string length as counter
  mov ebx, 0                            ; BX will be the final number
  mov eax, 0
                                        ; As we move left in the string, each char is a bigger multiple. The
                                        ; right-most character is a multiple of 1, then next (a char to the
                                        ; left) a multiple of 10, then 100, then 1,000, and the final (and
                                        ; leftmost char) in a five-char number would be a multiple of 10,000
  mov DWORD [.multiplier], 1            ; Start with multiples of 1
.loop:
  mov eax, 0
  mov al, [esi]                         ; Get character
  sub al, 48                            ; Convert from ASCII to real number
  mul DWORD [.multiplier]               ; Multiply by our multiplier
  add ebx, eax                          ; Add it to BX
  push eax                              ; Multiply our multiplier by 10 for next char
  mov eax, [.multiplier]
  mov edx, 10
  mul edx
  mov DWORD [.multiplier], eax
  pop eax
  dec ecx                               ; Any more chars?
  cmp ecx, 0
  je .finish
  dec esi                               ; Move back a char in the string
  jmp .loop
.finish:
  mov DWORD [.tmp], ebx
  popa
  mov eax, [.tmp]
  ret
  .multiplier dd 0
  .tmp dd 0
; ------------------------------------------------------------------
; os_int_to_string -- Convert unsigned integer to string
; IN: AX = signed int
; OUT: AX = string location
os_int_to_string:
  pusha
  mov ecx, 0
  mov ebx, 10                           ; Set BX 10, for division and mod
  mov edi, .t                           ; Get our pointer ready
.push:
  mov edx, 0
  div ebx                               ; Remainder in DX, quotient in AX
  inc ecx                               ; Increase pop loop counter
  push edx                              ; Push remainder, so as to reverse order when popping
  test eax, eax                         ; Is quotient zero?
  jnz .push                             ; If not, loop again
.pop:
  pop edx                               ; Pop off values in reverse order, and add 48 to make them digits
  add dl, '0'                           ; And save them in the string, increasing the pointer each time
  mov [edi], dl
  inc edi
  dec ecx
  jnz .pop
  mov BYTE [edi], 0                     ; Zero-terminate string
  popa
  mov eax, .t                           ; Return location of string
  ret
  .t: times 7 db 0
; ------------------------------------------------------------------
; os_sint_to_string -- Convert signed integer to string
; IN: AX = signed int
; OUT: AX = string location
os_sint_to_string:
  pusha
  mov ecx, 0
  mov ebx, 10                           ; Set BX 10, for division and mod
  mov edi, .t                           ; Get our pointer ready
  test eax, eax                         ; Find out if X > 0 or not, force a sign
  js .neg                               ; If negative...
  jmp .push                             ; ...or if positive
.neg:
  neg eax                               ; Make AX positive
  mov BYTE [.t], '-'                    ; Add a minus sign to our string
  inc edi                               ; Update the index
.push:
  mov edx, 0
  div ebx                               ; Remainder in DX, quotient in AX
  inc ecx                               ; Increase pop loop counter
  push edx                              ; Push remainder, so as to reverse order when popping
  test eax, eax                         ; Is quotient zero?
  jnz .push                             ; If not, loop again
.pop:
  pop edx                               ; Pop off values in reverse order, and add 48 to make them digits
  add dl, '0'                           ; And save them in the string, increasing the pointer each time
  mov [edi], dl
  inc edi
  dec ecx
  jnz .pop
  mov BYTE [edi], 0                     ; Zero-terminate string
  popa
  mov eax, .t                           ; Return location of string
  ret
  .t: times 7 db 0
; ------------------------------------------------------------------
; os_long_int_to_string -- Convert value in DX:AX to string
; IN: DX:AX = long unsigned integer, BX = number base, DI = string location
; OUT: DI = location of converted string
os_long_int_to_string:
  pusha
  mov esi, edi                          ; Prepare for later data movement
  mov DWORD [edi], 0                    ; Terminate string, creates 'null'
  cmp ebx, 37                           ; Base > 37 or < 0 not supported, return null
  ja .done
  cmp ebx, 0                            ; Base = 0 produces overflow, return null
  je .done
.conversion_loop:
  mov ecx, 0                            ; Zero extend unsigned integer, number = CX:DX:AX
                                        ; If number = 0, goes through loop once and stores '0'
  xchg eax, ecx                         ; Number order DX:AX:CX for high order division
  xchg eax, edx
  div ebx                               ; AX = high quotient, DX = high remainder
  xchg eax, ecx                         ; Number order for low order division
  div ebx                               ; CX = high quotient, AX = low quotient, DX = remainder
  xchg ecx, edx                         ; CX = digit to send
.save_digit:
  cmp ecx, 9                            ; Eliminate punctuation between '9' and 'A'
  jle .convert_digit
  add ecx, 'A'-'9'-1
.convert_digit:
  add ecx, '0'                          ; Convert to ASCII
  push eax                              ; Load this ASCII digit into the beginning of the string
  push ebx
  mov eax, esi
  call os_string_length                 ; AX = length of string, less terminator
  mov edi, esi
  add edi, eax                          ; DI = end of string
  inc eax                               ; AX = nunber of characters to move, including terminator
.move_string_up:
  mov bl, [edi]                         ; Put digits in correct order
  mov [edi+1], bl
  dec edi
  dec eax
  jnz .move_string_up
  pop ebx
  pop eax
  mov [esi], cl                         ; Last digit (LSD) will print first (on left)
.test_end:
  mov ecx, edx                          ; DX = high word, again
  or ecx, eax                           ; Nothing left?
  jnz .conversion_loop
.done:
  popa
  ret
; ------------------------------------------------------------------
; os_set_time_fmt -- Set time reporting format (eg '10:25 AM' or '2300 hours')
; IN: AL = format flag, 0 = 12-hr format
os_set_time_fmt:
  pusha
  cmp al, 0
  je .store
  mov al, 0FFh
.store:
  mov [fmt_12_24], al
  popa
  ret
; ------------------------------------------------------------------
; os_get_time_string -- Get current time in a string (eg '10:25')
; IN/OUT: BX = string location
os_get_time_string:
  pusha
  mov edi, ebx                          ; Location to place time string
  clc                                   ; For buggy BIOSes
  mov ah, 2                             ; Get time data from BIOS in BCD format
  int 1Ah
  jnc .read
  clc
  mov ah, 2                             ; BIOS was updating (~1 in 500 chance), so try again
  int 1Ah
.read:
  mov al, ch                            ; Convert hours to integer for AM/PM test
  call os_bcd_to_int
  mov edx, eax                          ; Save
  mov al, ch                            ; Hour
  shr al, 4                             ; Tens digit - move higher BCD number into lower bits
  and ch, 0Fh                           ; Ones digit
  test BYTE [fmt_12_24], 0FFh
  jz .twelve_hr
  call .add_digit                       ; BCD already in 24-hour format
  mov al, ch
  call .add_digit
  jmp short .minutes
.twelve_hr:
  cmp edx, 0                            ; If 00mm, make 12 AM
  je .midnight
  cmp edx, 10                           ; Before 1000, OK to store 1 digit
  jl .twelve_st1
  cmp edx, 12                           ; Between 1000 and 1300, OK to store 2 digits
  jle .twelve_st2
  mov eax, edx                          ; Change from 24 to 12-hour format
  sub eax, 12
  mov bl, 10
  div bl
  mov ch, ah
  cmp al, 0                             ; 1-9 PM
  je .twelve_st1
  jmp short .twelve_st2                 ; 10-11 PM
.midnight:
  mov al, 1
  mov ch, 2
.twelve_st2:
  call .add_digit                       ; Modified BCD, 2-digit hour
.twelve_st1:
  mov al, ch
  call .add_digit
  mov al, ':'                           ; Time separator (12-hr format)
  stosb
.minutes:
  mov al, cl                            ; Minute
  shr al, 4                             ; Tens digit - move higher BCD number into lower bits
  and cl, 0Fh                           ; Ones digit
  call .add_digit
  mov al, cl
  call .add_digit
  mov al, ' '                           ; Separate time designation
  stosb
  mov esi, .hours_string                ; Assume 24-hr format
  test BYTE [fmt_12_24], 0FFh
  jnz .copy
  mov esi, .pm_string                   ; Assume PM
  cmp edx, 12                           ; Test for AM/PM
  jg .copy
  mov esi, .am_string                   ; Was actually AM
.copy:
  lodsb                                 ; Copy designation, including terminator
  stosb
  cmp al, 0
  jne .copy
  popa
  ret
.add_digit:
  add al, '0'                           ; Convert to ASCII
  stosb                                 ; Put into string buffer
  ret
  .hours_string db 'hours', 0
  .am_string db 'AM', 0
  .pm_string db 'PM', 0
; ------------------------------------------------------------------
; os_set_date_fmt -- Set date reporting format (M/D/Y, D/M/Y or Y/M/D - 0, 1, 2)
; IN: AX = format flag, 0-2
; If AX bit 7 = 1 = use name for months
; If AX bit 7 = 0, high byte = separator character
os_set_date_fmt:
  pusha
  test al, 80h                          ; ASCII months (bit 7)?
  jnz .fmt_clear
  and eax, 7F03h                        ; 7-bit ASCII separator and format number
  jmp short .fmt_test
.fmt_clear:
  and eax, 0003                         ; Ensure separator is clear
.fmt_test:
  cmp al, 3                             ; Only allow 0, 1 and 2
  jae .leave
  mov [fmt_date], eax
.leave:
  popa
  ret
; ------------------------------------------------------------------
; os_get_date_string -- Get current date in a string (eg '12/31/2007')
; IN/OUT: BX = string location
os_get_date_string:
  pusha
  mov edi, ebx                          ; Store string location for now
  mov ebx, [fmt_date]                   ; BL = format code
  and ebx, 7F03h                        ; BH = separator, 0 = use month names
  clc                                   ; For buggy BIOSes
  mov ah, 4                             ; Get date data from BIOS in BCD format
  int 1Ah
  jnc .read
  clc
  mov ah, 4                             ; BIOS was updating (~1 in 500 chance), so try again
  int 1Ah
.read:
  cmp bl, 2                             ; YYYY/MM/DD format, suitable for sorting
  jne .try_fmt1
  mov ah, ch                            ; Always provide 4-digit year
  call .add_2digits
  mov ah, cl
  call .add_2digits                     ; And '/' as separator
  mov al, '/'
  stosb
  mov ah, dh                            ; Always 2-digit month
  call .add_2digits
  mov al, '/'                           ; And '/' as separator
  stosb
  mov ah, dl                            ; Always 2-digit day
  call .add_2digits
  jmp .done
.try_fmt1:
  cmp bl, 1                             ; D/M/Y format (military and Europe)
  jne .do_fmt0
  mov ah, dl                            ; Day
  call .add_1or2digits
  mov al, bh
  cmp bh, 0
  jne .fmt1_day
  mov al, ' '                           ; If ASCII months, use space as separator
.fmt1_day:
  stosb                                 ; Day-month separator
  mov ah, dh                            ; Month
  cmp bh, 0                             ; ASCII?
  jne .fmt1_month
  call .add_month                       ; Yes, add to string
  mov eax, ', '
  stosw
  jmp short .fmt1_century
.fmt1_month:
  call .add_1or2digits                  ; No, use digits and separator
  mov al, bh
  stosb
.fmt1_century:
  mov ah, ch                            ; Century present?
  cmp ah, 0
  je .fmt1_year
  call .add_1or2digits                  ; Yes, add it to string (most likely 2 digits)
.fmt1_year:
  mov ah, cl                            ; Year
  call .add_2digits                     ; At least 2 digits for year, always
  jmp short .done
.do_fmt0:                               ; Default format, M/D/Y (US and others)
  mov ah, dh                            ; Month
  cmp bh, 0                             ; ASCII?
  jne .fmt0_month
  call .add_month                       ; Yes, add to string and space
  mov al, ' '
  stosb
  jmp short .fmt0_day
.fmt0_month:
  call .add_1or2digits                  ; No, use digits and separator
  mov al, bh
  stosb
.fmt0_day:
  mov ah, dl                            ; Day
  call .add_1or2digits
  mov al, bh
  cmp bh, 0                             ; ASCII?
  jne .fmt0_day2
  mov al, ','                           ; Yes, separator = comma space
  stosb
  mov al, ' '
.fmt0_day2:
  stosb
.fmt0_century:
  mov ah, ch                            ; Century present?
  cmp ah, 0
  je .fmt0_year
  call .add_1or2digits                  ; Yes, add it to string (most likely 2 digits)
.fmt0_year:
  mov ah, cl                            ; Year
  call .add_2digits                     ; At least 2 digits for year, always
.done:
  mov eax, 0                            ; Terminate date string
  stosw
  popa
  ret
.add_1or2digits:
  test ah, 0F0h
  jz .only_one
  call .add_2digits
  jmp short .two_done
.only_one:
  mov al, ah
  and al, 0Fh
  call .add_digit
.two_done:
  ret
.add_2digits:
  mov al, ah                            ; Convert AH to 2 ASCII digits
  shr al, 4
  call .add_digit
  mov al, ah
  and al, 0Fh
  call .add_digit
  ret
.add_digit:
  add al, '0'                           ; Convert AL to ASCII
  stosb                                 ; Put into string buffer
  ret
.add_month:
  push ebx
  push ecx
  mov al, ah                            ; Convert month to integer to index print table
  call os_bcd_to_int
  dec al                                ; January = 0
  mov bl, 4                             ; Multiply month by 4 characters/month
  mul bl
  mov esi, .months
  add esi, eax
  mov ecx, 4
  rep movsb
  cmp BYTE [edi-1], ' '                 ; May?
  jne .done_month                       ; Yes, eliminate extra space
  dec edi
.done_month:
  pop ecx
  pop ebx
  ret
  .months db 'Jan.Feb.Mar.Apr.May JuneJulyAug.SeptOct.Nov.Dec.'
; ------------------------------------------------------------------
; os_string_tokenize -- Reads tokens separated by specified char from
; a string. Returns pointer to next token, or 0 if none left
; IN: AL = separator char, SI = beginning; OUT: DI = next token or 0 if none
os_string_tokenize:
  push esi
.next_char:
  cmp BYTE [esi], al
  je .return_token
  cmp BYTE [esi], 0
  jz .no_more
  inc esi
  jmp .next_char
.return_token:
  mov BYTE [esi], 0
  inc esi
  mov edi, esi
  pop esi
  ret
.no_more:
  mov edi, 0
  pop esi
  ret
; ==================================================================
