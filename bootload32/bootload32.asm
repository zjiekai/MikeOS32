; ==================================================================
; The Mike Operating System bootloader
; Copyright (C) 2006 - 2013 MikeOS Developers -- see doc/LICENSE.TXT
;
; Based on a free boot loader by E Dehling. It scans the FAT12
; floppy for KERNEL.BIN (the MikeOS kernel), loads it and executes it.
; This must grow no larger than 512 bytes (one sector), with the final
; two bytes being the boot signature (AA55h). Note that in FAT12,
; a cluster is the same as a sector: 512 bytes.
; ==================================================================
  RESERVED_TRACK EQU 36
  USE32
  org 7C00h
  jmp short bootloader_start            ; Jump past disk description section
  nop                                   ; Pad out before disk description
; ------------------------------------------------------------------
; Disk description table, to make it a valid floppy
; Note: some of these values are hard-coded in the source!
; Values are those used by IBM for 1.44 MB, 3.5" diskette
OEMLabel db "MIKEBOOT"                  ; Disk label
BytesPerSector dw 512                   ; Bytes per sector
SectorsPerCluster db 1                  ; Sectors per cluster
ReservedForBoot dw 1                    ; Reserved sectors for boot record
NumberOfFats db 2                       ; Number of copies of the FAT
RootDirEntries dw 224                   ; Number of entries in root dir
                                        ; (224 * 32 = 7168 = 14 sectors to read)
LogicalSectors dw 2880                  ; Number of logical sectors
MediumByte db 0F0h                      ; Medium descriptor byte
SectorsPerFat dw 9                      ; Sectors per FAT
SectorsPerTrack dw 18                   ; Sectors per track (36/cylinder)
Sides dw 2                              ; Number of sides/heads
HiddenSectors dd 0                      ; Number of hidden sectors
LargeSectors dd 0                       ; Number of LBA sectors
DriveNo: dw 0                           ; Drive No: 0
Signature db 41                         ; Drive signature: 41 for floppy
VolumeID dd 00000000h                   ; Volume ID: any number
VolumeLabel db "MIKEOS     "            ; Volume Label: any 11 chars
FileSystem db "FAT12   "                ; File system type: don't change!
; ------------------------------------------------------------------
; Main bootloader code
bootloader_start:
  mov esp, 7C00h
  mov [DriveNo], dl                     ; Save boot device number
  mov ah, 8                             ; Get drive parameters
  int 13h
  jc no_change
  and ecx, 3Fh                          ; Maximum sector number
  mov [SectorsPerTrack], cx             ; Sector numbers start at 1
  movzx edx, dh                         ; Maximum head number
  add edx, 1                            ; Head numbers start at 0 - add 1 for total
  mov [Sides], dx
no_change:
  mov eax, 0                            ; Needed for some older BIOSes
; First, we need to load the root directory from the disk. Technical details:
; Start of root = ReservedForBoot + NumberOfFats * SectorsPerFat = logical 19
; Number of root = RootDirEntries * 32 bytes/entry / 512 bytes/sector = 14
; Start of user data = (start of root) + (number of root) = logical 33
floppy_ok:                              ; Ready to read first block of data
  mov eax, 19+RESERVED_TRACK            ; Root dir starts at logical sector 19
  call l2hts
  mov ebx, buffer                       ; Set ES:BX to point to our buffer (see end of code)
  mov ah, 2                             ; Params for int 13h: read floppy sectors
  mov al, 14                            ; And read 14 of them
  pusha                                 ; Prepare to enter loop
read_root_dir:
  popa                                  ; In case registers are altered by int 13h
  pusha
  stc                                   ; A few BIOSes do not set properly on error
  int 13h                               ; Read sectors using BIOS
  jnc search_dir                        ; If read went OK, skip ahead
  call reset_floppy                     ; Otherwise, reset floppy controller and try again
  jnc read_root_dir                     ; Floppy reset OK?
  jmp reboot                            ; If not, fatal double error
search_dir:
  popa
  mov edi, buffer                       ; Root dir is now in [buffer]
                                        ; Set DI to this info
  movzx ecx, WORD [RootDirEntries]      ; Search all (224) entries
  mov eax, 0                            ; Searching at offset 0
next_root_entry:
  xchg ecx, edx                         ; We use CX in the inner loop...
  mov esi, kern_filename                ; Start searching for kernel filename
  mov ecx, 11
  rep cmpsb
  je found_file_to_load                 ; Pointer DI will be at offset 11
  add eax, 32                           ; Bump searched entries by 1 (32 bytes per entry)
  mov edi, buffer                       ; Point to next entry
  add edi, eax
  xchg edx, ecx                         ; Get the original CX back
  loop next_root_entry
  mov esi, file_not_found               ; If kernel is not found, bail out
  call print_string
  jmp reboot
found_file_to_load:                     ; Fetch cluster and load FAT into RAM
  movzx eax, WORD [edi+0Fh]             ; Offset 11 + 15 = 26, contains 1st cluster
  mov DWORD [cluster], eax
  mov eax, 1+RESERVED_TRACK             ; Sector 1 = first sector of first FAT
  call l2hts
  mov ebx, buffer                       ; ES:BX points to our buffer
  mov ah, 2                             ; int 13h params: read (FAT) sectors
  mov al, 9                             ; All 9 sectors of 1st FAT
  pusha                                 ; Prepare to enter loop
read_fat:
  popa                                  ; In case registers are altered by int 13h
  pusha
  stc
  int 13h                               ; Read sectors using the BIOS
  jnc read_fat_ok                       ; If read went OK, skip ahead
  call reset_floppy                     ; Otherwise, reset floppy controller and try again
  jnc read_fat                          ; Floppy reset OK?
; ******************************************************************
fatal_disk_error:
; ******************************************************************
  mov esi, disk_error                   ; If not, print error message and reboot
  call print_string
  jmp reboot                            ; Fatal double error
read_fat_ok:
  popa
  mov ah, 2                             ; int 13h floppy read params
  mov al, 1
  push eax                              ; Save in case we (or int calls) lose it
; Now we must load the FAT from the disk. Here's how we find out where it starts:
; FAT cluster 0 = media descriptor = 0F0h
; FAT cluster 1 = filler cluster = 0FFh
; Cluster start = ((cluster number) - 2) * SectorsPerCluster + (start of user)
; = (cluster number) + 31
load_file_sector:
  mov eax, DWORD [cluster]              ; Convert sector to logical
  add eax, 31+RESERVED_TRACK
  call l2hts                            ; Make appropriate params for int 13h
  mov ebx, DWORD [pointer]
  pop eax                               ; Save in case we (or int calls) lose it
  push eax
  stc
  int 13h
  jnc calculate_next_cluster            ; If there's no error...
  call reset_floppy                     ; Otherwise, reset floppy and retry
  jmp load_file_sector
; In the FAT, cluster values are stored in 12 bits, so we have to
; do a bit of maths to work out whether we're dealing with a byte
; and 4 bits of the next byte -- or the last 4 bits of one byte
; and then the subsequent byte!
calculate_next_cluster:
  mov eax, [cluster]
  mov edx, 0
  mov ebx, 3
  mul ebx
  mov ebx, 2
  div ebx                               ; DX = [cluster] mod 2
  mov esi, buffer
  add esi, eax                          ; AX = word in FAT for the 12 bit entry
  movzx eax, WORD [esi]
  or edx, edx                           ; If DX = 0 [cluster] is even; if DX = 1 then it's odd
  jz even                               ; If [cluster] is even, drop last 4 bits of word
                                        ; with next cluster; if odd, drop first 4 bits
odd:
  shr eax, 4                            ; Shift out first 4 bits (they belong to another entry)
  jmp short next_cluster_cont
even:
  and eax, 0FFFh                        ; Mask out final 4 bits
next_cluster_cont:
  mov DWORD [cluster], eax              ; Store cluster
  cmp eax, 0FF8h                        ; FF8h = end of file marker in FAT12
  jae the_end
  add DWORD [pointer], 512              ; Increase buffer pointer 1 sector length
  jmp load_file_sector
the_end:                                ; We've got the file to load!
  pop eax                               ; Clean up the stack (AX was pushed earlier)
  mov dl, BYTE [DriveNo]                ; Provide kernel with boot device info
  jmp 100000h                           ; Jump to entry point of loaded kernel!
; ------------------------------------------------------------------
; BOOTLOADER SUBROUTINES
reboot:
  mov eax, 0
  int 16h                               ; Wait for keystroke
  mov eax, 0
  int 19h                               ; Reboot the system
print_string:                           ; Output string in SI to screen
  pusha
  mov ah, 0Eh                           ; int 10h teletype function
.repeat:
  lodsb                                 ; Get char from string
  cmp al, 0
  je .done                              ; If char is zero, end of string
  int 10h                               ; Otherwise, print it
  jmp short .repeat
.done:
  popa
  ret
reset_floppy:                           ; IN: [bootdev] = boot device; OUT: carry set on error
  push eax
  push edx
  mov eax, 0
  mov dl, BYTE [DriveNo]
  stc
  int 13h
  pop edx
  pop eax
  ret
l2hts:                                  ; Calculate head, track and sector settings for int 13h
  push ebx                              ; IN: logical sector in AX, OUT: correct registers for int 13h
  push eax
  mov edx, 0                            ; First the sector
  movzx ebx, WORD [SectorsPerTrack]
  div ebx
  add edx, 1                            ; Physical sectors start at 1
  mov ecx, edx                          ; Sectors belong in CL for int 13h
  mov edx, 0
  movzx ebx, WORD [Sides]
  div ebx
  mov dh, dl                            ; Head/side
  xchg al, ah
  shl al, 6
  or ecx, eax                           ; cylinder in ch
  pop eax
  pop ebx
  mov dl, BYTE [DriveNo]                ; Set correct device
  ret
; ------------------------------------------------------------------
; STRINGS AND VARIABLES
  kern_filename db "KERNEL32BIN"        ; MikeOS kernel filename
  disk_error db "Drive error! Press any key...", 0
  file_not_found db "KERNEL32.BIN not found!", 0
  cluster dd 0                          ; Cluster of the file we want to load
  pointer dd 100000h                    ; Pointer into Buffer, for loading kernel
; ------------------------------------------------------------------
buffer:                                 ; Disk buffer begins
; ==================================================================
