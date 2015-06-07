; ==================================================================
; MikeOS -- The Mike Operating System kernel
; Copyright (C) 2006 - 2013 MikeOS Developers -- see doc/LICENSE.TXT
;
; MATH ROUTINES
; ==================================================================
; ------------------------------------------------------------------
; os_seed_random -- Seed the random number generator based on clock
; IN: Nothing; OUT: Nothing (registers preserved)
os_seed_random:
  push ebx
  push eax
  mov ebx, 0
  mov al, 0x02                          ; Minute
  out 0x70, al
  in al, 0x71
  mov bl, al
  shl ebx, 8
  mov al, 0                             ; Second
  out 0x70, al
  in al, 0x71
  mov bl, al
  mov DWORD [os_random_seed], ebx       ; Seed will be something like 0x4435 (if it
                                        ; were 44 minutes and 35 seconds after the hour)
  pop eax
  pop ebx
  ret
  os_random_seed dd 0
; ------------------------------------------------------------------
; os_get_random -- Return a random integer between low and high (inclusive)
; IN: AX = low integer, BX = high integer
; OUT: CX = random integer
os_get_random:
  push edx
  push ebx
  push eax
  sub ebx, eax                          ; We want a number between 0 and (high-low)
  call .generate_random
  mov edx, ebx
  add edx, 1
  mul edx
  mov ecx, edx
  pop eax
  pop ebx
  pop edx
  add ecx, eax                          ; Add the low offset back
  ret
.generate_random:
  push edx
  push ebx
  mov eax, [os_random_seed]
  mov edx, 0x7383                       ; The magic number (random.org)
  mul edx                               ; DX:AX = AX * DX
  mov [os_random_seed], eax
  pop ebx
  pop edx
  ret
; ------------------------------------------------------------------
; os_bcd_to_int -- Converts binary coded decimal number to an integer
; IN: AL = BCD number; OUT: AX = integer value
os_bcd_to_int:
  pusha
  mov bl, al                            ; Store entire number for now
  and eax, 0Fh                          ; Zero-out high bits
  mov ecx, eax                          ; CH/CL = lower BCD number, zero extended
  shr bl, 4                             ; Move higher BCD number into lower bits, zero fill msb
  mov al, 10
  mul bl                                ; AX = 10 * BL
  add eax, ecx                          ; Add lower BCD to 10*higher
  mov [.tmp], eax
  popa
  mov eax, [.tmp]                       ; And return it in AX!
  ret
  .tmp dd 0
; ------------------------------------------------------------------
; os_long_int_negate -- Multiply value in DX:AX by -1
; IN: DX:AX = long integer; OUT: DX:AX = -(initial DX:AX)
os_long_int_negate:
  neg eax
  adc edx, 0
  neg edx
  ret
; ==================================================================
