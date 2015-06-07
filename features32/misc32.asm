; ==================================================================
; MikeOS -- The Mike Operating System kernel
; Copyright (C) 2006 - 2013 MikeOS Developers -- see doc/LICENSE.TXT
;
; MISCELLANEOUS ROUTINES
; ==================================================================
; ------------------------------------------------------------------
; os_get_api_version -- Return current version of MikeOS API
; IN: Nothing; OUT: AL = API version number
os_get_api_version:
  mov al, MikeOS32_API_VER
  ret
; ------------------------------------------------------------------
; os_pause -- Delay execution for specified 110ms chunks
; IN: AX = 100 millisecond chunks to wait (max delay is 32767,
; which multiplied by 55ms = 1802 seconds = 30 minutes)
os_pause:
  pusha
  cmp eax, 0
  je .time_up                           ; If delay = 0 then bail out
  mov ecx, 0
  mov [.counter_var], ecx               ; Zero the counter variable
  mov ebx, eax
  mov eax, 0
  mov al, 2                             ; 2 * 55ms = 110mS
  mul ebx                               ; Multiply by number of 110ms chunks required 
  mov [.orig_req_delay], eax            ; Save it
  mov ah, 0
  int 1Ah                               ; Get tick count 
  mov [.prev_tick_count], edx           ; Save it for later comparison
.checkloop:
  mov ah,0
  int 1Ah                               ; Get tick count again
  cmp [.prev_tick_count], edx           ; Compare with previous tick count
  jne .up_date                          ; If it's changed check it
  jmp .checkloop                        ; Otherwise wait some more
.time_up:
  popa
  ret
.up_date:
  mov eax, [.counter_var]               ; Inc counter_var
  inc eax
  mov [.counter_var], eax
  cmp eax, [.orig_req_delay]            ; Is counter_var = required delay?
  jge .time_up                          ; Yes, so bail out
  mov [.prev_tick_count], edx           ; No, so update .prev_tick_count 
  jmp .checkloop                        ; And go wait some more
  .orig_req_delay dd 0
  .counter_var dd 0
  .prev_tick_count dd 0
; ------------------------------------------------------------------
; os_fatal_error -- Display error message and halt execution
; IN: AX = error message string location
os_fatal_error:
  mov ebx, eax                          ; Store string location for now
  mov dh, 0
  mov dl, 0
  call os_move_cursor
  pusha
  mov ah, 09h                           ; Draw red bar at top
  mov bh, 0
  mov ecx, 240
  mov bl, 01001111b
  mov al, ' '
  int 10h
  popa
  mov dh, 0
  mov dl, 0
  call os_move_cursor
  mov esi, .msg_inform                  ; Inform of fatal error
  call os_print_string
  mov esi, ebx                          ; Program-supplied error message
  call os_print_string
  jmp $                                 ; Halt execution
  
  .msg_inform db '>>> FATAL OPERATING SYSTEM ERROR', 13, 10, 0
; ==================================================================
