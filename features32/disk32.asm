; ==================================================================
; MikeOS -- The Mike Operating System kernel
; Copyright (C) 2006 - 2013 MikeOS Developers -- see doc/LICENSE.TXT
;
; FAT12 FLOPPY DISK ROUTINES
; ==================================================================
; ------------------------------------------------------------------
; os_get_file_list -- Generate comma-separated string of files on floppy
; IN/OUT: AX = location to store zero-terminated filename string
os_get_file_list:
  pusha
  mov DWORD [.file_list_tmp], eax
  mov eax, 0                            ; Needed for some older BIOSes
  call disk_reset_floppy                ; Just in case disk was changed
  mov eax, 19 + RESERVED_TRACK          ; Root dir starts at logical sector 19
  call disk_convert_l2hts
  mov ebx, DISK_BUFFER                  ; ES:BX should point to our buffer
  mov ah, 2                             ; Params for int 13h: read floppy sectors
  mov al, 14                            ; And read 14 of them
  pusha                                 ; Prepare to enter loop
.read_root_dir:
  popa
  pusha
  stc
  int 13h                               ; Read sectors
  call disk_reset_floppy                ; Check we've read them OK
  jnc .show_dir_init                    ; No errors, continue
  call disk_reset_floppy                ; Error = reset controller and try again
  jnc .read_root_dir
  jmp .done                             ; Double error, exit 'dir' routine
.show_dir_init:
  popa
  mov eax, 0
  mov esi, DISK_BUFFER                  ; Data reader from start of filenames
  mov DWORD edi, [.file_list_tmp]       ; Name destination buffer
.start_entry:
  mov al, [esi+11]                      ; File attributes for entry
  cmp al, 0Fh                           ; Windows marker, skip it
  je .skip
  test al, 18h                          ; Is this a directory entry or volume label?
  jnz .skip                             ; Yes, ignore it
  mov al, [esi]
  cmp al, 229                           ; If we read 229 = deleted filename
  je .skip
  cmp al, 0                             ; 1st byte = entry never used
  je .done
  mov ecx, 1                            ; Set char counter
  mov edx, esi                          ; Beginning of possible entry
.testdirentry:
  inc esi
  mov al, [esi]                         ; Test for most unusable characters
  cmp al, ' '                           ; Windows sometimes puts 0 (UTF-8) or 0FFh
  jl .nxtdirentry
  cmp al, '~'
  ja .nxtdirentry
  inc ecx
  cmp ecx, 11                           ; Done 11 char filename?
  je .gotfilename
  jmp .testdirentry
.gotfilename:                           ; Got a filename that passes testing
  mov esi, edx                          ; DX = where getting string
  mov ecx, 0
.loopy:
  mov al, [esi]
  cmp al, ' '
  je .ignore_space
  mov BYTE [edi], al
  inc esi
  inc edi
  inc ecx
  cmp ecx, 8
  je .add_dot
  cmp ecx, 11
  je .done_copy
  jmp .loopy
.ignore_space:
  inc esi
  inc ecx
  cmp ecx, 8
  je .add_dot
  jmp .loopy
.add_dot:
  mov BYTE [edi], '.'
  inc edi
  jmp .loopy
.done_copy:
  mov BYTE [edi], ','                   ; Use comma to separate filenames
  inc edi
.nxtdirentry:
  mov esi, edx                          ; Start of entry, pretend to skip to next
.skip:
  add esi, 32                           ; Shift to next 32 bytes (next filename)
  jmp .start_entry
.done:
  dec edi
  mov BYTE [edi], 0                     ; Zero-terminate string (gets rid of final comma)
  popa
  ret
  .file_list_tmp dd 0
; ------------------------------------------------------------------
; os_load_file -- Load file into RAM
; IN: AX = location of filename, CX = location in RAM to load file
; OUT: BX = file size (in bytes), carry set if file not found
os_load_file:
  call os_string_uppercase
  call int_filename_convert
  mov [.filename_loc], eax              ; Store filename location
  mov [.load_position], ecx             ; And where to load the file!
  mov eax, 0                            ; Needed for some older BIOSes
  call disk_reset_floppy                ; In case floppy has been changed
  jnc .floppy_ok                        ; Did the floppy reset OK?
  mov eax, .err_msg_floppy_reset        ; If not, bail out
  jmp os_fatal_error
.floppy_ok:                             ; Ready to read first block of data
  mov eax, 19 + RESERVED_TRACK          ; Root dir starts at logical sector 19
  call disk_convert_l2hts
  mov ebx, DISK_BUFFER                  ; ES:BX should point to our buffer
  mov ah, 2                             ; Params for int 13h: read floppy sectors
  mov al, 14                            ; 14 root directory sectors
  pusha                                 ; Prepare to enter loop
.read_root_dir:
  popa
  pusha
  stc                                   ; A few BIOSes clear, but don't set properly
  int 13h                               ; Read sectors
  jnc .search_root_dir                  ; No errors = continue
  call disk_reset_floppy                ; Problem = reset controller and try again
  jnc .read_root_dir
  popa
  jmp .root_problem                     ; Double error = exit
.search_root_dir:
  popa
  mov ecx, DWORD 224                    ; Search all entries in root dir
  mov ebx, -32                          ; Begin searching at offset 0 in root dir
.next_root_entry:
  add ebx, 32                           ; Bump searched entries by 1 (offset + 32 bytes)
  mov edi, DISK_BUFFER                  ; Point root dir at next entry
  add edi, ebx
  mov al, [edi]                         ; First character of name
  cmp al, 0                             ; Last file name already checked?
  je .root_problem
  cmp al, 229                           ; Was this file deleted?
  je .next_root_entry                   ; If yes, skip it
  mov al, [edi+11]                      ; Get the attribute byte
  cmp al, 0Fh                           ; Is this a special Windows entry?
  je .next_root_entry
  test al, 18h                          ; Is this a directory entry or volume label?
  jnz .next_root_entry
  mov BYTE [edi+11], 0                  ; Add a terminator to directory name entry
  mov eax, edi                          ; Convert root buffer name to upper case
  call os_string_uppercase
  mov esi, [.filename_loc]              ; DS:SI = location of filename to load
  call os_string_compare                ; Current entry same as requested?
  jc .found_file_to_load
  loop .next_root_entry
.root_problem:
  mov ebx, 0                            ; If file not found or major disk error,
  stc                                   ; return with size = 0 and carry set
  ret
.found_file_to_load:                    ; Now fetch cluster and load FAT into RAM
  mov eax, [edi+28]                     ; Store file size to return to calling routine
  mov DWORD [.file_size], eax
  cmp eax, 0                            ; If the file size is zero, don't bother trying
  je .end                               ; to read more clusters
  movzx eax, WORD [edi+26]              ; Now fetch cluster and load FAT into RAM
  mov DWORD [.cluster], eax
  mov eax, 1 + RESERVED_TRACK           ; Sector 1 = first sector of first FAT
  call disk_convert_l2hts
  mov ebx, DISK_BUFFER                  ; ES:BX points to our buffer
  mov ah, 2                             ; int 13h params: read sectors
  mov al, 9                             ; And read 9 of them
  pusha
.read_fat:
  popa                                  ; In case registers altered by int 13h
  pusha
  stc
  int 13h
  jnc .read_fat_ok
  call disk_reset_floppy
  jnc .read_fat
  popa
  jmp .root_problem
.read_fat_ok:
  popa
.load_file_sector:
  mov eax, DWORD [.cluster]             ; Convert sector to logical
  add eax, 31 + RESERVED_TRACK
  call disk_convert_l2hts               ; Make appropriate params for int 13h
  mov ebx, [.load_position]
  mov ah, 02                            ; AH = read sectors, AL = just read 1
  mov al, 01
  stc
  int 13h
  jnc .calculate_next_cluster           ; If there's no error...
  call disk_reset_floppy                ; Otherwise, reset floppy and retry
  jnc .load_file_sector
  mov eax, .err_msg_floppy_reset        ; Reset failed, bail out
  jmp os_fatal_error
.calculate_next_cluster:
  mov eax, [.cluster]
  mov ebx, 3
  mul ebx
  mov ebx, 2
  div ebx                               ; DX = [CLUSTER] mod 2
  mov esi, DISK_BUFFER                  ; AX = word in FAT for the 12 bits
  add esi, eax
  movzx eax, WORD [esi]
  or edx, edx                           ; If DX = 0 [CLUSTER] = even, if DX = 1 then odd
  jz .even                              ; If [CLUSTER] = even, drop last 4 bits of word
                                        ; with next cluster; if odd, drop first 4 bits
.odd:
  shr eax, 4                            ; Shift out first 4 bits (belong to another entry)
  jmp .calculate_cluster_cont           ; Onto next sector!
.even:
  and eax, 0FFFh                        ; Mask out top (last) 4 bits
.calculate_cluster_cont:
  mov DWORD [.cluster], eax             ; Store cluster
  cmp eax, 0FF8h
  jae .end
  add DWORD [.load_position], 512
  jmp .load_file_sector                 ; Onto next sector!
.end:
  mov ebx, [.file_size]                 ; Get file size to pass back in BX
  clc                                   ; Carry clear = good load
  ret
  .bootd db 0                           ; Boot device number
  .cluster dd 0                         ; Cluster of the file we want to load
  .pointer dd 0                         ; Pointer into disk_buffer, for loading 'file2load'
  .filename_loc dd 0                    ; Temporary store of filename location
  .load_position dd 0                   ; Where we'll load the file
  .file_size dd 0                       ; Size of the file
  .string_buff: times 12 db 0           ; For size (integer) printing
  .err_msg_floppy_reset db 'os_load_file: Floppy failed to reset', 0
; --------------------------------------------------------------------------
; os_write_file -- Save (max 64K) file to disk
; IN: AX = filename, BX = data location, CX = bytes to write
; OUT: Carry clear if OK, set if failure
os_write_file:
  pusha
  mov esi, eax
  call os_string_length
  cmp eax, 0
  je .failure
  mov eax, esi
  call os_string_uppercase
  call int_filename_convert             ; Make filename FAT12-style
  jc .failure
  mov DWORD [.filesize], ecx
  mov DWORD [.location], ebx
  mov DWORD [.filename], eax
  call os_file_exists                   ; Don't overwrite a file if it exists!
  jnc .failure
                                        ; First, zero out the .free_clusters list from any previous execution
  pusha
  mov edi, .free_clusters
  mov ecx, 128
.clean_free_loop:
  mov DWORD [edi], 0
  lea edi, [edi+4]
  loop .clean_free_loop
  popa
                                        ; Next, we need to calculate now many 512 byte clusters are required
  mov eax, ecx
  mov edx, 0
  mov ebx, 512                          ; Divide file size by 512 to get clusters needed
  div ebx
  cmp edx, 0
  jg .add_a_bit                         ; If there's a remainder, we need another cluster
  jmp .carry_on
.add_a_bit:
  add eax, 1
.carry_on:
  mov DWORD [.clusters_needed], eax
  mov eax, [.filename]                  ; Get filename back
  call os_create_file                   ; Create empty root dir entry for this file
  jc .failure                           ; If we can't write to the media, jump out
  mov ebx, [.filesize]
  cmp ebx, 0
  je .finished
  call disk_read_fat                    ; Get FAT copy into RAM
  mov esi, DISK_BUFFER + 3              ; And point SI at it (skipping first two clusters)
  mov ebx, 2                            ; Current cluster counter
  mov ecx, [.clusters_needed]
  mov edx, 0                            ; Offset in .free_clusters list
.find_free_cluster:
  movzx eax, WORD [esi]                 ; Get a word
  lea esi, [esi+2]
  and eax, 0FFFh                        ; Mask out for even
  jz .found_free_even                   ; Free entry?
.more_odd:
  inc ebx                               ; If not, bump our counter
  dec esi                               ; 'lodsw' moved on two chars; we only want to move on one
  movzx eax, WORD [esi]                 ; Get a word
  lea esi, [esi+2]
  shr eax, 4                            ; Shift for odd
  or eax, eax                           ; Free entry?
  jz .found_free_odd
.more_even:
  inc ebx                               ; If not, keep going
  jmp .find_free_cluster
.found_free_even:
  push esi
  mov esi, .free_clusters               ; Store cluster
  add esi, edx
  mov DWORD [esi], ebx
  pop esi
  dec ecx                               ; Got all the clusters we need?
  cmp ecx, 0
  je .finished_list
  lea edx, [edx+4]                      ; Next word in our list
  jmp .more_odd
.found_free_odd:
  push esi
  mov esi, .free_clusters               ; Store cluster
  add esi, edx
  mov DWORD [esi], ebx
  pop esi
  dec ecx
  cmp ecx, 0
  je .finished_list
  lea edx, [edx+4]                      ; Next word in our list
  jmp .more_even
.finished_list:
                                        ; Now the .free_clusters table contains a series of numbers (words)
                                        ; that correspond to free clusters on the disk; the next job is to
                                        ; create a cluster chain in the FAT for our file
  mov ecx, 0                            ; .free_clusters offset counter
  mov DWORD [.count], 1                 ; General cluster counter
.chain_loop:
  mov eax, [.count]                     ; Is this the last cluster?
  cmp eax, [.clusters_needed]
  je .last_cluster
  mov edi, .free_clusters
  add edi, ecx
  mov ebx, [edi]                        ; Get cluster
  mov eax, ebx                          ; Find out if it's an odd or even cluster
  mov edx, 0
  mov ebx, 3
  mul ebx
  mov ebx, 2
  div ebx                               ; DX = [.cluster] mod 2
  mov esi, DISK_BUFFER
  add esi, eax                          ; AX = word in FAT for the 12 bit entry
  movzx eax, WORD [esi]
  or edx, edx                           ; If DX = 0, [.cluster] = even; if DX = 1 then odd
  jz .even
.odd:
  and eax, 000Fh                        ; Zero out bits we want to use
  mov edi, .free_clusters
  add edi, ecx                          ; Get offset in .free_clusters
  mov ebx, [edi+4]                      ; Get number of NEXT cluster
  shl ebx, 4                            ; And convert it into right format for FAT
  add eax, ebx
  mov WORD [esi], ax                    ; Store cluster data back in FAT copy in RAM
  inc DWORD [.count]
  lea ecx, [ecx+4]                      ; Move on a word in .free_clusters
  jmp .chain_loop
.even:
  and eax, 0F000h                       ; Zero out bits we want to use
  mov edi, .free_clusters
  add edi, ecx                          ; Get offset in .free_clusters
  mov ebx, [edi+4]                      ; Get number of NEXT free cluster
  add eax, ebx
  mov WORD [esi], ax                    ; Store cluster data back in FAT copy in RAM
  inc DWORD [.count]
  lea ecx, [ecx+4]                      ; Move on a word in .free_clusters
  jmp .chain_loop
.last_cluster:
  mov edi, .free_clusters
  add edi, ecx
  mov ebx, [edi]                        ; Get cluster
  mov eax, ebx
  mov edx, 0
  mov ebx, 3
  mul ebx
  mov ebx, 2
  div ebx                               ; DX = [.cluster] mod 2
  mov esi, DISK_BUFFER
  add esi, eax                          ; AX = word in FAT for the 12 bit entry
  movzx eax, WORD [esi]
  or edx, edx                           ; If DX = 0, [.cluster] = even; if DX = 1 then odd
  jz .even_last
.odd_last:
  and eax, 000Fh                        ; Set relevant parts to FF8h (last cluster in file)
  add eax, 0FF80h
  jmp .finito
.even_last:
  and eax, 0F000h                       ; Same as above, but for an even cluster
  add eax, 0FF8h
.finito:
  mov WORD [esi], ax
  call disk_write_fat                   ; Save our FAT back to disk
                                        ; Now it's time to save the sectors to disk!
  mov ecx, 0
.save_loop:
  mov edi, .free_clusters
  add edi, ecx
  mov eax, [edi]
  cmp eax, 0
  je .write_root_entry
  pusha
  add eax, 31 + RESERVED_TRACK
  call disk_convert_l2hts
  mov ebx, [.location]
  mov ah, 3
  mov al, 1
  stc
  int 13h
  popa
  add DWORD [.location], 512
  lea ecx, [ecx+4]
  jmp .save_loop
.write_root_entry:
                                        ; Now it's time to head back to the root directory, find our
                                        ; entry and update it with the cluster in use and file size
  call disk_read_root_dir
  mov eax, [.filename]
  call disk_get_root_entry
  mov eax, [.free_clusters]             ; Get first free cluster
  mov WORD [edi+26], ax                 ; Save cluster location into root dir entry
  mov ecx, [.filesize]
  mov DWORD [edi+28], ecx               ; File size
  call disk_write_root_dir
.finished:
  popa
  clc
  ret
.failure:
  popa
  stc                                   ; Couldn't write!
  ret
  .filesize dd 0
  .cluster dd 0
  .count dd 0
  .location dd 0
  .clusters_needed dd 0
  .filename dd 0
  .free_clusters: times 128 dd 0
; --------------------------------------------------------------------------
; os_file_exists -- Check for presence of file on the floppy
; IN: AX = filename location; OUT: carry clear if found, set if not
os_file_exists:
  call os_string_uppercase
  call int_filename_convert             ; Make FAT12-style filename
  push eax
  call os_string_length
  cmp eax, 0
  je .failure
  pop eax
  push eax
  call disk_read_root_dir
  pop eax                               ; Restore filename
  mov edi, DISK_BUFFER
  call disk_get_root_entry              ; Set or clear carry flag
  ret
.failure:
  pop eax
  stc
  ret
; --------------------------------------------------------------------------
; os_create_file -- Creates a new 0-byte file on the floppy disk
; IN: AX = location of filename; OUT: Nothing
os_create_file:
  clc
  call os_string_uppercase
  call int_filename_convert             ; Make FAT12-style filename
  pusha
  push eax                              ; Save filename for now
  call os_file_exists                   ; Does the file already exist?
  jnc .exists_error
                                        ; Root dir already read into disk_buffer by os_file_exists
  mov edi, DISK_BUFFER                  ; So point DI at it!
  mov ecx, 224                          ; Cycle through root dir entries
.next_entry:
  mov al, [edi]
  cmp al, 0                             ; Is this a free entry?
  je .found_free_entry
  cmp al, 0E5h                          ; Is this a free entry?
  je .found_free_entry
  add edi, 32                           ; If not, go onto next entry
  loop .next_entry
.exists_error:                          ; We also get here if above loop finds nothing
  pop eax                               ; Get filename back
  popa
  stc                                   ; Set carry for failure
  ret
.found_free_entry:
  pop esi                               ; Get filename back
  mov ecx, 11
  rep movsb                             ; And copy it into RAM copy of root dir (in DI)
  sub edi, 11                           ; Back to start of root dir entry, for clarity
  mov BYTE [edi+11], 0                  ; Attributes
  mov BYTE [edi+12], 0                  ; Reserved
  mov BYTE [edi+13], 0                  ; Reserved
  mov BYTE [edi+14], 0C6h               ; Creation time
  mov BYTE [edi+15], 07Eh               ; Creation time
  mov BYTE [edi+16], 0                  ; Creation date
  mov BYTE [edi+17], 0                  ; Creation date
  mov BYTE [edi+18], 0                  ; Last access date
  mov BYTE [edi+19], 0                  ; Last access date
  mov BYTE [edi+20], 0                  ; Ignore in FAT12
  mov BYTE [edi+21], 0                  ; Ignore in FAT12
  mov BYTE [edi+22], 0C6h               ; Last write time
  mov BYTE [edi+23], 07Eh               ; Last write time
  mov BYTE [edi+24], 0                  ; Last write date
  mov BYTE [edi+25], 0                  ; Last write date
  mov BYTE [edi+26], 0                  ; First logical cluster
  mov BYTE [edi+27], 0                  ; First logical cluster
  mov BYTE [edi+28], 0                  ; File size
  mov BYTE [edi+29], 0                  ; File size
  mov BYTE [edi+30], 0                  ; File size
  mov BYTE [edi+31], 0                  ; File size
  call disk_write_root_dir
  jc .failure
  popa
  clc                                   ; Clear carry for success
  ret
.failure:
  popa
  stc
  ret
; --------------------------------------------------------------------------
; os_remove_file -- Deletes the specified file from the filesystem
; IN: AX = location of filename to remove
os_remove_file:
  pusha
  call os_string_uppercase
  call int_filename_convert             ; Make filename FAT12-style
  push eax                              ; Save filename
  clc
  call disk_read_root_dir               ; Get root dir into disk_buffer
  mov edi, DISK_BUFFER                  ; Point DI to root dir
  pop eax                               ; Get chosen filename back
  call disk_get_root_entry              ; Entry will be returned in DI
  jc .failure                           ; If entry can't be found
  movzx eax, WORD [edi+26]              ; Get first cluster number from the dir entry
  mov DWORD [.cluster], eax             ; And save it
  mov BYTE [edi], 0E5h                  ; Mark directory entry (first byte of filename) as empty
  inc edi
  mov ecx, 0                            ; Set rest of data in root dir entry to zeros
.clean_loop:
  mov BYTE [edi], 0
  inc edi
  inc ecx
  cmp ecx, 31                           ; 32-byte entries, minus E5h byte we marked before
  jl .clean_loop
  call disk_write_root_dir              ; Save back the root directory from RAM
  call disk_read_fat                    ; Now FAT is in disk_buffer
  mov edi, DISK_BUFFER                  ; And DI points to it
.more_clusters:
  mov eax, [.cluster]                   ; Get cluster contents
  cmp eax, 0                            ; If it's zero, this was an empty file
  je .nothing_to_do
  mov ebx, 3                            ; Determine if cluster is odd or even number
  mul ebx
  mov ebx, 2
  div ebx                               ; DX = [first_cluster] mod 2
  mov esi, DISK_BUFFER                  ; AX = word in FAT for the 12 bits
  add esi, eax
  movzx eax, WORD [esi]
  or edx, edx                           ; If DX = 0 [.cluster] = even, if DX = 1 then odd
  jz .even                              ; If [.cluster] = even, drop last 4 bits of word
                                        ; with next cluster; if odd, drop first 4 bits
.odd:
  push eax
  and eax, 000Fh                        ; Set cluster data to zero in FAT in RAM
  mov WORD [esi], ax
  pop eax
  shr eax, 4                            ; Shift out first 4 bits (they belong to another entry)
  jmp .calculate_cluster_cont           ; Onto next sector!
.even:
  push eax
  and eax, 0F000h                       ; Set cluster data to zero in FAT in RAM
  mov WORD [esi], ax
  pop eax
  and eax, 0FFFh                        ; Mask out top (last) 4 bits (they belong to another entry)
.calculate_cluster_cont:
  mov DWORD [.cluster], eax             ; Store cluster
  cmp eax, 0FF8h                        ; Final cluster marker?
  jae .end
  jmp .more_clusters                    ; If not, grab more
.end:
  call disk_write_fat
  jc .failure
.nothing_to_do:
  popa
  clc
  ret
.failure:
  popa
  stc
  ret
  .cluster dd 0
; --------------------------------------------------------------------------
; os_rename_file -- Change the name of a file on the disk
; IN: AX = filename to change, BX = new filename (zero-terminated strings)
; OUT: carry set on error
os_rename_file:
  push ebx
  push eax
  clc
  call disk_read_root_dir               ; Get root dir into disk_buffer
  mov edi, DISK_BUFFER                  ; Point DI to root dir
  pop eax                               ; Get chosen filename back
  call os_string_uppercase
  call int_filename_convert
  call disk_get_root_entry              ; Entry will be returned in DI
  jc .fail_read                         ; Quit out if file not found
  pop ebx                               ; Get new filename string (originally passed in BX)
  mov eax, ebx
  call os_string_uppercase
  call int_filename_convert
  mov esi, eax
  mov ecx, 11                           ; Copy new filename string into root dir entry in disk_buffer
  rep movsb
  call disk_write_root_dir              ; Save root dir to disk
  jc .fail_write
  clc
  ret
.fail_read:
  pop eax
  stc
  ret
.fail_write:
  stc
  ret
; --------------------------------------------------------------------------
; os_get_file_size -- Get file size information for specified file
; IN: AX = filename; OUT: BX = file size in bytes (up to 64K)
; or carry set if file not found
os_get_file_size:
  pusha
  call os_string_uppercase
  call int_filename_convert
  clc
  push eax
  call disk_read_root_dir
  jc .failure
  pop eax
  mov edi, DISK_BUFFER
  call disk_get_root_entry
  jc .failure
  mov ebx, [edi+28]
  mov DWORD [.tmp], ebx
  popa
  mov ebx, [.tmp]
  ret
.failure:
  popa
  stc
  ret
  .tmp dd 0
; ==================================================================
; INTERNAL OS ROUTINES -- Not accessible to user programs
; ------------------------------------------------------------------
; int_filename_convert -- Change 'TEST.BIN' into 'TEST BIN' as per FAT12
; IN: AX = filename string
; OUT: AX = location of converted string (carry set if invalid)
int_filename_convert:
  pusha
  mov esi, eax
  call os_string_length
  cmp eax, 12 ;14                       ; Filename too long?
  jg .failure                           ; Fail if so
  cmp eax, 0
  je .failure                           ; Similarly, fail if zero-char string
  mov edx, eax                          ; Store string length for now
  mov edi, .dest_string
  mov ecx, 0
.copy_loop:
  lodsb
  cmp al, '.'
  je .extension_found
  stosb
  inc ecx
  cmp ecx, edx
  jg .failure                           ; No extension found = wrong
  jmp .copy_loop
.extension_found:
  cmp ecx, 0
  je .failure                           ; Fail if extension dot is first char
  cmp ecx, 8
  je .do_extension                      ; Skip spaces if first bit is 8 chars
                                        ; Now it's time to pad out the rest of the first part of the filename
                                        ; with spaces, if necessary
.add_spaces:
  mov BYTE [edi], ' '
  inc edi
  inc ecx
  cmp ecx, 8
  jl .add_spaces
                                        ; Finally, copy over the extension
.do_extension:
  lodsb                                 ; 3 characters
  cmp al, 0
  je .failure
  stosb
  lodsb
  cmp al, 0
  je .failure
  stosb
  lodsb
  cmp al, 0
  je .failure
  stosb
  mov BYTE [edi], 0                     ; Zero-terminate filename
  popa
  mov eax, .dest_string
  clc                                   ; Clear carry for success
  ret
.failure:
  popa
  stc                                   ; Set carry for failure
  ret
  .dest_string: times 13 db 0
; --------------------------------------------------------------------------
; disk_get_root_entry -- Search RAM copy of root dir for file entry
; IN: AX = filename; OUT: DI = location in disk_buffer of root dir entry,
; or carry set if file not found
disk_get_root_entry:
  pusha
  mov DWORD [.filename], eax
  mov ecx, 224                          ; Search all (224) entries
  mov eax, 0                            ; Searching at offset 0
.to_next_root_entry:
  xchg ecx, edx                         ; We use CX in the inner loop...
  mov DWORD esi, [.filename]            ; Start searching for filename
  mov ecx, 11
  rep cmpsb
  je .found_file                        ; Pointer DI will be at offset 11, if file found
  add eax, 32                           ; Bump searched entries by 1 (32 bytes/entry)
  mov edi, DISK_BUFFER                  ; Point to next root dir entry
  add edi, eax
  xchg edx, ecx                         ; Get the original CX back
  loop .to_next_root_entry
  popa
  stc                                   ; Set carry if entry not found
  ret
.found_file:
  sub edi, 11                           ; Move back to start of this root dir entry
  mov DWORD [.tmp], edi                 ; Restore all registers except for DI
  popa
  mov DWORD edi, [.tmp]
  clc
  ret
  .filename dd 0
  .tmp dd 0
; --------------------------------------------------------------------------
; disk_read_fat -- Read FAT entry from floppy into disk_buffer
; IN: Nothing; OUT: carry set if failure
disk_read_fat:
  pusha
  mov eax, 1 + RESERVED_TRACK           ; FAT starts at logical sector 1 (after boot sector)
  call disk_convert_l2hts
  mov ebx, DISK_BUFFER                  ; Set ES:BX to point to 8K OS buffer
  mov ah, 2                             ; Params for int 13h: read floppy sectors
  mov al, 9                             ; And read 9 of them for first FAT
  pusha                                 ; Prepare to enter loop
.read_fat_loop:
  popa
  pusha
  stc                                   ; A few BIOSes do not set properly on error
  int 13h                               ; Read sectors
  jnc .fat_done
  call disk_reset_floppy                ; Reset controller and try again
  jnc .read_fat_loop                    ; Floppy reset OK?
  popa
  jmp .read_failure                     ; Fatal double error
.fat_done:
  popa                                  ; Restore registers from main loop
  popa                                  ; And restore registers from start of system call
  clc
  ret
.read_failure:
  popa
  stc                                   ; Set carry flag (for failure)
  ret
; --------------------------------------------------------------------------
; disk_write_fat -- Save FAT contents from disk_buffer in RAM to disk
; IN: FAT in disk_buffer; OUT: carry set if failure
disk_write_fat:
  pusha
  mov eax, 1 + RESERVED_TRACK           ; FAT starts at logical sector 1 (after boot sector)
  call disk_convert_l2hts
  mov ebx, DISK_BUFFER                  ; Set ES:BX to point to 8K OS buffer
  mov ah, 3                             ; Params for int 13h: write floppy sectors
  mov al, 9                             ; And write 9 of them for first FAT
  stc                                   ; A few BIOSes do not set properly on error
  int 13h                               ; Write sectors
  jc .write_failure                     ; Fatal double error
  popa                                  ; And restore from start of system call
  clc
  ret
.write_failure:
  popa
  stc                                   ; Set carry flag (for failure)
  ret
; --------------------------------------------------------------------------
; disk_read_root_dir -- Get the root directory contents
; IN: Nothing; OUT: root directory contents in disk_buffer, carry set if error
disk_read_root_dir:
  pusha
  mov eax, 19 + RESERVED_TRACK          ; Root dir starts at logical sector 19
  call disk_convert_l2hts
  mov ebx, DISK_BUFFER                  ; Set ES:BX to point to OS buffer
  mov ah, 2                             ; Params for int 13h: read floppy sectors
  mov al, 14                            ; And read 14 of them (from 19 onwards)
  pusha                                 ; Prepare to enter loop
.read_root_dir_loop:
  popa
  pusha
  stc                                   ; A few BIOSes do not set properly on error
  int 13h                               ; Read sectors
  jnc .root_dir_finished
  call disk_reset_floppy                ; Reset controller and try again
  jnc .read_root_dir_loop               ; Floppy reset OK?
  popa
  jmp .read_failure                     ; Fatal double error
.root_dir_finished:
  popa                                  ; Restore registers from main loop
  popa                                  ; And restore from start of this system call
  clc                                   ; Clear carry (for success)
  ret
.read_failure:
  popa
  stc                                   ; Set carry flag (for failure)
  ret
; --------------------------------------------------------------------------
; disk_write_root_dir -- Write root directory contents from disk_buffer to disk
; IN: root dir copy in disk_buffer; OUT: carry set if error
disk_write_root_dir:
  pusha
  mov eax, 19 + RESERVED_TRACK          ; Root dir starts at logical sector 19
  call disk_convert_l2hts
  mov ebx, DISK_BUFFER                  ; Set ES:BX to point to OS buffer
  mov ah, 3                             ; Params for int 13h: write floppy sectors
  mov al, 14                            ; And write 14 of them (from 19 onwards)
  stc                                   ; A few BIOSes do not set properly on error
  int 13h                               ; Write sectors
  jc .write_failure
  popa                                  ; And restore from start of this system call
  clc
  ret
.write_failure:
  popa
  stc                                   ; Set carry flag (for failure)
  ret
; --------------------------------------------------------------------------
; Reset floppy disk
disk_reset_floppy:
  push eax
  push edx
  mov eax, 0
; ******************************************************************
  mov dl, [bootdev]
; ******************************************************************
  stc
  int 13h
  pop edx
  pop eax
  ret
; --------------------------------------------------------------------------
; disk_convert_l2hts -- Calculate head, track and sector for int 13h
; IN: logical sector in AX; OUT: correct registers for int 13h
disk_convert_l2hts:
  push ebx
  push eax
  mov ebx, eax                          ; Save logical sector
  mov edx, 0                            ; First the sector
  div DWORD [SecsPerTrack]              ; Sectors per track
  add edx, 1                            ; Physical sectors start at 1
  mov ecx, edx                          ; Sectors belong in CL for int 13h
;  mov eax, ebx
;  mov edx, 0                            ; Now calculate the head
;  div DWORD [SecsPerTrack]              ; Sectors per track
  mov edx, 0
  div DWORD [Sides]                     ; Floppy sides
  mov dh, dl                            ; Head/side
  xchg al, ah
  shl al, 6
  or ecx, eax                           ; cylinder in ch
;  mov ch, al                           ; Track
  pop eax
  pop ebx
; ******************************************************************
  mov dl, [bootdev]                     ; Set correct device
; ******************************************************************
  ret
  Sides dd 2
  SecsPerTrack dd 18
; ******************************************************************
  bootdev db 0                          ; Boot device number
; ******************************************************************
; ==================================================================
