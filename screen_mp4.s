.intel_syntax noprefix
.global entry

# Microsoft x64 ABI. The low 32 bytes of each call frame are shadow space.
.macro api name
    call qword ptr [rip+imp_\name]
.endm
.macro address reg, label
    lea \reg, [rip+\label]
.endm


.macro com object, slot
    mov rcx, [rip+\object]
    mov rax, [rcx]
    call qword ptr [rax+8*\slot]
.endm
.macro check failure
    test eax, eax
    js \failure
.endm

.text
entry:
    sub rsp, 56
    mov rcx, -4
    api SetProcessDpiAwarenessContext
    xor ecx, ecx
    mov edx, 2
    api CoInitializeEx
    check .entry_exit
    xor ecx, ecx
    api GetModuleHandleW
    mov rcx, rax
    address rdx, dialog
    xor r8d, r8d
    address r9, dialog_proc
    mov qword ptr [rsp+32], 0
    api DialogBoxIndirectParamW
    api CoUninitialize
.entry_exit:
    xor ecx, ecx
    api ExitProcess

# States: 0 idle, 1 countdown, 2 recording, 3 synchronous transition.
dialog_proc:
    sub rsp, 40
    cmp edx, 0x110
    je .init
    cmp edx, 0x111
    je .command
    cmp edx, 0x113
    je .timer
    cmp edx, 0x312
    je .hotkey
    cmp edx, 0x10
    je .close
    xor eax, eax
    jmp .return
.init:
    mov [rip+window], rcx
    jmp .handled
.command:
    cmp r8w, 2
    je .close
    cmp r8w, 100
    jne .handled
    mov eax, [rip+state]
    cmp eax, 1
    je .cancel
    cmp eax, 2
    je .stop
    test eax, eax
    jnz .handled
    call start_countdown
    jmp .handled
.hotkey:
    cmp r8, 10
    jne .handled
    cmp dword ptr [rip+state], 2
    je .stop
    jmp .handled
.timer:
    cmp r8, 1
    jne .handled
    cmp dword ptr [rip+state], 1
    je .countdown
    cmp dword ptr [rip+state], 2
    jne .handled
    call record_tick
    jmp .handled
.countdown:
    call countdown_tick
    jmp .handled
.cancel:
    call reset_ui
    jmp .handled
.stop:
    xor ecx, ecx
    call finish_recording
    jmp .handled
.close:
    cmp dword ptr [rip+state], 3
    je .handled
    cmp dword ptr [rip+state], 2
    jne .dismiss
    xor ecx, ecx
    call finish_recording
.dismiss:
    mov rcx, [rip+window]
    xor edx, edx
    api EndDialog
.handled:
    mov eax, 1
.return:
    add rsp, 40
    ret

start_countdown:
    sub rsp, 40
    mov dword ptr [rip+state], 3
    mov rax, [rip+window]
    mov [rip+save_owner], rax
    address rax, path
    mov [rip+save_path], rax
    address rax, filter
    mov [rip+save_filter], rax
    address rax, extension
    mov [rip+save_extension], rax
    address rcx, path
    address rdx, default_name
    api lstrcpyW
    mov dword ptr [rip+save_flags], 0x880e
    address rcx, save_dialog
    api GetSaveFileNameW
    test eax, eax
    jz .dialog_closed
    test dword ptr [rip+save_flags], 0x400 # OFN_EXTENSIONDIFFERENT
    jnz .wrong_extension
    mov rcx, [rip+window]
    mov edx, 1
    mov r8d, 40
    xor r9d, r9d
    api SetTimer
    test rax, rax
    jz .timer_failure
    api GetTickCount64
    add rax, 15000
    mov [rip+deadline], rax
    mov dword ptr [rip+seconds_shown], 0
    mov dword ptr [rip+state], 1
    address r8, cancel_label
    call set_button
    call countdown_tick
    jmp .countdown_return
.dialog_closed:
    api CommDlgExtendedError
    test eax, eax
    jz .reset_state
    jmp .timer_failure
.wrong_extension:
    address rdx, extension_error_label
    call error_message
    jmp .reset_state
.timer_failure:
    address rdx, start_error_label
    call error_message
.reset_state:
    mov dword ptr [rip+state], 0
.countdown_return:
    add rsp, 40
    ret

countdown_tick:
    sub rsp, 40
    api GetTickCount64
    mov rcx, [rip+deadline]
    sub rcx, rax
    jle .countdown_done
    lea rax, [rcx+999]
    xor edx, edx
    mov ecx, 1000
    div rcx
    cmp eax, [rip+seconds_shown]
    je .tick_return
    mov [rip+seconds_shown], eax
    xor edx, edx
    mov ecx, 10
    div ecx
    add eax, '0'
    add edx, '0'
    mov [rip+count_digits], ax
    mov [rip+count_digits+2], dx
    address r8, countdown_label
    call set_status
    jmp .tick_return
.countdown_done:
    mov dword ptr [rip+state], 3
    call stop_timer
    mov rcx, [rip+window]
    mov edx, 6                  # SW_MINIMIZE
    api ShowWindow
    call begin_recording
.tick_return:
    add rsp, 40
    ret

begin_recording:
    sub rsp, 72
    call prepare_capture
    test eax, eax
    jz .begin_failed
    call prepare_writer
    check .begin_failed
    mov dword ptr [rip+frames], 0
    mov qword ptr [rip+next_slot], 0
    mov rcx, [rip+window]
    mov edx, 10
    mov r8d, 0x4006            # MOD_NOREPEAT | CONTROL | SHIFT
    mov r9d, 0x79              # F10
    api RegisterHotKey
    mov [rip+hotkey_active], eax
    mov ecx, 1
    api timeBeginPeriod
    test eax, eax
    setz byte ptr [rip+timer_resolution]
    mov rcx, [rip+window]
    mov edx, 1
    mov r8d, 10
    xor r9d, r9d
    api SetTimer
    test rax, rax
    jz .begin_failed
    address r8, stop_label
    call set_button
    address r8, recording_label
    cmp dword ptr [rip+hotkey_active], 0
    jne .record_status
    address r8, no_hotkey_label
.record_status:
    call set_status
    api DwmFlush
    api GetTickCount64
    mov [rip+record_start], rax
    mov dword ptr [rip+state], 2
    call record_tick
    jmp .begin_return
.begin_failed:
    call cleanup_recording
    call discard_temp
    call reset_ui
    call restore_window
    address rdx, start_error_label
    call error_message
.begin_return:
    add rsp, 72
    ret

prepare_capture:
    sub rsp, 56
    xor ecx, ecx
    api GetSystemMetrics
    test eax, eax
    jle .capture_setup_failed
    cmp eax, 4096
    ja .capture_setup_failed
    mov [rip+width], eax
    add eax, 3
    and eax, -4
    mov [rip+encoded_width], eax
    mov [rip+bitmap_width], eax
    mov ecx, 1
    api GetSystemMetrics
    test eax, eax
    jle .capture_setup_failed
    cmp eax, 4096
    ja .capture_setup_failed
    mov [rip+height], eax
    add eax, 1
    and eax, -2
    mov [rip+encoded_height], eax
    neg eax
    mov [rip+bitmap_height], eax
    neg eax
    imul eax, [rip+encoded_width]
    mov [rip+luma_size], eax
    lea eax, [rax+rax*2]
    shr eax, 1
    mov [rip+nv12_size], eax
    xor ecx, ecx
    api GetDC
    test rax, rax
    jz .capture_setup_failed
    mov [rip+screen_dc], rax
    mov rcx, rax
    api CreateCompatibleDC
    test rax, rax
    jz .capture_setup_failed
    mov [rip+memory_dc], rax
    mov rcx, rax
    address rdx, bitmap_info
    xor r8d, r8d
    address r9, pixels
    mov qword ptr [rsp+32], 0
    mov qword ptr [rsp+40], 0
    api CreateDIBSection
    test rax, rax
    jz .capture_setup_failed
    mov [rip+bitmap], rax
    mov rcx, [rip+memory_dc]
    mov rdx, rax
    api SelectObject
    test rax, rax
    jz .capture_setup_failed
    mov [rip+old_bitmap], rax
    mov rcx, [rip+memory_dc]
    xor edx, edx
    xor r8d, r8d
    mov r9d, [rip+encoded_width]
    mov eax, [rip+encoded_height]
    mov [rsp+32], eax
    mov dword ptr [rsp+40], 0x42 # BLACKNESS, initialize padding
    api PatBlt
    jmp .capture_setup_return
.capture_setup_failed:
    xor eax, eax
.capture_setup_return:
    add rsp, 56
    ret

prepare_writer:
    sub rsp, 56
    mov ecx, 0x20070
    xor edx, edx
    api MFStartup
    check .writer_return
    mov byte ptr [rip+mf_started], 1

    # Use a temporary file beside the final destination to preserve an
    # existing MP4 until encoding and finalization both succeed.
    address rcx, directory
    address rdx, path
    api lstrcpyW
    address rdx, directory
    xor ecx, ecx
.scan_directory:
    mov ax, [rdx]
    test ax, ax
    jz .directory_end
    add rdx, 2
    cmp ax, 92
    cmove rcx, rdx
    jmp .scan_directory
.directory_end:
    test rcx, rcx
    jz .writer_error
    mov word ptr [rcx], 0
    address rcx, directory
    address rdx, temp_prefix
    xor r8d, r8d
    address r9, temp_path
    api GetTempFileNameW
    test eax, eax
    jz .writer_error
    mov byte ptr [rip+temp_exists], 1

    address rcx, attributes
    mov edx, 1
    api MFCreateAttributes
    check .writer_return
    address rdx, attr_container
    address r8, container_mp4
    com attributes, 24           # IMFAttributes::SetGUID
    check .writer_return
    mov ecx, 2                 # MF_ACCESSMODE_WRITE
    mov edx, 4                 # MF_OPENMODE_DELETE_IF_EXIST
    xor r8d, r8d
    address r9, temp_path
    address rax, byte_stream
    mov [rsp+32], rax
    api MFCreateFile
    check .writer_return
    xor ecx, ecx
    mov rdx, [rip+byte_stream]
    mov r8, [rip+attributes]
    address r9, writer
    api MFCreateSinkWriterFromURL
    check .writer_return

    address rcx, format
    api MFCreateMediaType
    check .writer_return
    address rcx, subtype_h264
    call set_video_type
    check .writer_return
    address rdx, attr_bitrate
    mov r8d, [rip+luma_size]
    shl r8d, 2
    com format, 21               # IMFAttributes::SetUINT32
    check .writer_return
    mov rdx, [rip+format]
    address r8, stream_index
    com writer, 3                # AddStream
    check .writer_return
    address rcx, format
    call release_com
    address rcx, format
    api MFCreateMediaType
    check .writer_return
    address rcx, subtype_nv12
    call set_video_type
    check .writer_return
    mov edx, [rip+stream_index]
    mov r8, [rip+format]
    xor r9d, r9d
    com writer, 4                # SetInputMediaType
    check .writer_return
    com writer, 5                # BeginWriting
    jmp .writer_return
.writer_error:
    mov eax, 0x80004005
.writer_return:
    add rsp, 56
    ret

set_video_type:
    sub rsp, 56
    mov [rsp+40], rcx
    address rdx, attr_major
    address r8, type_video
    com format, 24
    check .video_type_return
    address rdx, attr_subtype
    mov r8, [rsp+40]
    com format, 24
    check .video_type_return
    address rdx, attr_interlace
    mov r8d, 2
    com format, 21
    check .video_type_return
    address rdx, attr_size
    mov r8d, [rip+encoded_width]
    shl r8, 32
    mov eax, [rip+encoded_height]
    or r8, rax
    com format, 22               # IMFAttributes::SetUINT64
    check .video_type_return
    address rdx, attr_rate
    mov r8, 0x1e00000001
    com format, 22
    check .video_type_return
    address rdx, attr_aspect
    mov r8, 0x100000001
    com format, 22
.video_type_return:
    add rsp, 56
    ret

# Capture on a monotonic 30 Hz timeline. Reuse a captured frame for short
# scheduling gaps; skip larger gaps so a stalled encoder cannot pile up work.
record_tick:
    sub rsp, 88
    api GetTickCount64
    sub rax, [rip+record_start]
    imul rax, 30
    xor edx, edx
    mov ecx, 1000
    div rcx
    cmp rax, [rip+next_slot]
    jb .record_return
    mov [rsp+72], rax
    sub rax, [rip+next_slot]
    cmp rax, 4
    jbe .blit
    mov rax, [rsp+72]
    mov [rip+next_slot], rax
.blit:
    mov rcx, [rip+memory_dc]
    xor edx, edx
    xor r8d, r8d
    mov r9d, [rip+width]
    mov eax, [rip+height]
    mov [rsp+32], eax
    mov rax, [rip+screen_dc]
    mov [rsp+40], rax
    mov dword ptr [rsp+48], 0
    mov dword ptr [rsp+56], 0
    mov dword ptr [rsp+64], 0x40cc0020
    api BitBlt
    test eax, eax
    jz .record_error
    api GdiFlush
    test eax, eax
    jz .record_error
    call make_frame_buffer
    check .record_error
.submit:
    call write_sample
    check .record_error
    inc dword ptr [rip+frames]
    inc qword ptr [rip+next_slot]
    mov rax, [rip+next_slot]
    cmp rax, [rsp+72]
    jbe .submit
    address rcx, frame_buffer
    call release_com
    jmp .record_return
.record_error:
    mov ecx, 1
    call finish_recording
.record_return:
    add rsp, 88
    ret

make_frame_buffer:
    sub rsp, 56
    mov ecx, [rip+nv12_size]
    address rdx, frame_buffer
    api MFCreateMemoryBuffer
    check .buffer_return
    lea rdx, [rsp+40]
    xor r8d, r8d
    xor r9d, r9d
    com frame_buffer, 3         # Lock
    check .buffer_return
    mov rcx, [rip+pixels]
    mov rdx, [rsp+40]
    mov r8d, [rip+encoded_width]
    mov r9d, [rip+encoded_height]
    call convert_nv12
    com frame_buffer, 4         # Unlock
    check .buffer_return
    mov edx, [rip+nv12_size]
    com frame_buffer, 6         # SetCurrentLength
.buffer_return:
    add rsp, 56
    ret

write_sample:
    sub rsp, 56
    address rcx, sample
    api MFCreateSample
    check .sample_return
    mov rax, [rip+next_slot]
    imul rax, 10000000
    xor edx, edx
    mov ecx, 30
    div rcx
    mov [rsp+40], rax
    mov rdx, rax
    com sample, 36              # SetSampleTime
    check .sample_release
    mov rax, [rip+next_slot]
    inc rax
    imul rax, 10000000
    xor edx, edx
    mov ecx, 30
    div rcx
    sub rax, [rsp+40]
    mov rdx, rax
    com sample, 38              # SetSampleDuration
    check .sample_release
    mov rdx, [rip+frame_buffer]
    com sample, 42              # AddBuffer
    check .sample_release
    mov edx, [rip+stream_index]
    mov r8, [rip+sample]
    com writer, 6              # WriteSample
.sample_release:
    mov [rsp+40], eax
    address rcx, sample
    call release_com
    mov eax, [rsp+40]
.sample_return:
    add rsp, 56
    ret

# Convert a top-down BGRX DIB into NV12, processing four pixels in each
# of two rows. Chroma uses the average of each 2x2 block (BT.601 limited).
# RCX = source, RDX = destination, R8D = width, R9D = even height.
convert_nv12:
    push rbx
    push rsi
    push rdi
    mov esi, r8d
    mov ebx, r8d
    shl ebx, 2
    mov eax, r8d
    imul eax, r9d
    lea rdi, [rdx+rax]
.convert_rows:
    mov r10d, esi
    lea r11, [rcx+rbx]
.convert_pixels:
    movdqu xmm0, [rcx]
    movdqu xmm1, [r11]
    movdqa xmm2, xmm0
    movdqa xmm3, xmm1
    pmaddubsw xmm2, [rip+y_coeff]
    pmaddubsw xmm3, [rip+y_coeff]
    phaddw xmm2, xmm3
    paddw xmm2, [rip+y_round]
    psrlw xmm2, 7
    packuswb xmm2, xmm2
    movd [rdx], xmm2
    psrldq xmm2, 4
    movd [rdx+rsi], xmm2

    pavgb xmm0, xmm1
    pshufd xmm1, xmm0, 0xb1
    pavgb xmm0, xmm1
    pshufd xmm0, xmm0, 0xa0
    pmaddubsw xmm0, [rip+uv_coeff]
    phaddw xmm0, xmm0
    paddw xmm0, [rip+uv_round]
    psraw xmm0, 8
    paddw xmm0, [rip+uv_center]
    packuswb xmm0, xmm0
    movd [rdi], xmm0

    add rcx, 16
    add r11, 16
    add rdx, 4
    add rdi, 4
    sub r10d, 4
    jnz .convert_pixels
    add rcx, rbx
    add rdx, rsi
    sub r9d, 2
    jnz .convert_rows
    pop rdi
    pop rsi
    pop rbx
    ret

finish_recording:
    sub rsp, 56
    mov dword ptr [rip+state], 3
    mov [rsp+40], ecx
    call stop_timer
    cmp dword ptr [rip+frames], 0
    je .finalize_failed
    com writer, 11             # Finalize
    check .finalize_failed
    call cleanup_recording
    address rcx, temp_path
    address rdx, path
    mov r8d, 9                 # MOVEFILE_REPLACE_EXISTING | WRITE_THROUGH
    api MoveFileExW
    test eax, eax
    jz .move_failed
    mov byte ptr [rip+temp_exists], 0
    call reset_ui
    call restore_window
    address r8, saved_label
    cmp dword ptr [rsp+40], 0
    je .saved_status
    address r8, interrupted_label
.saved_status:
    call set_status
    jmp .finish_return
.move_failed:
    mov byte ptr [rip+temp_exists], 0
    call reset_ui
    call restore_window
    address r8, move_error_label
    call set_status
    address rdx, temp_path
    call error_message
    jmp .finish_return
.finalize_failed:
    call cleanup_recording
    call discard_temp
    call reset_ui
    call restore_window
    address rdx, save_error_label
    call error_message
.finish_return:
    add rsp, 56
    ret

cleanup_recording:
    sub rsp, 40
    call stop_timer
    cmp byte ptr [rip+timer_resolution], 0
    je .cleanup_hotkey
    mov ecx, 1
    api timeEndPeriod
    mov byte ptr [rip+timer_resolution], 0
.cleanup_hotkey:
    cmp dword ptr [rip+hotkey_active], 0
    je .cleanup_com
    mov rcx, [rip+window]
    mov edx, 10
    api UnregisterHotKey
    mov dword ptr [rip+hotkey_active], 0
.cleanup_com:
    address rcx, sample
    call release_com
    address rcx, frame_buffer
    call release_com
    address rcx, writer
    call release_com
    address rcx, byte_stream
    call release_com
    address rcx, format
    call release_com
    address rcx, attributes
    call release_com
    cmp byte ptr [rip+mf_started], 0
    je .cleanup_gdi
    api MFShutdown
    mov byte ptr [rip+mf_started], 0
.cleanup_gdi:
    call release_capture
    add rsp, 40
    ret

release_com:
    mov rax, [rcx]
    test rax, rax
    jz .release_com_return
    mov qword ptr [rcx], 0
    mov rcx, rax
    mov rax, [rcx]
    jmp qword ptr [rax+16]
.release_com_return:
    ret

discard_temp:
    cmp byte ptr [rip+temp_exists], 0
    je .discard_return
    mov byte ptr [rip+temp_exists], 0
    address rcx, temp_path
    jmp qword ptr [rip+imp_DeleteFileW]
.discard_return:
    ret

reset_ui:
    sub rsp, 40
    call stop_timer
    mov dword ptr [rip+state], 0
    address r8, start_label
    call set_button
    address r8, ready_label
    call set_status
    add rsp, 40
    ret

stop_timer:
    mov rcx, [rip+window]
    mov edx, 1
    jmp qword ptr [rip+imp_KillTimer]
restore_window:
    mov rcx, [rip+window]
    mov edx, 9                  # SW_RESTORE
    jmp qword ptr [rip+imp_ShowWindow]
set_button:
    mov edx, 100
    jmp set_control
set_status:
    mov edx, 101
set_control:
    mov rcx, [rip+window]
    jmp qword ptr [rip+imp_SetDlgItemTextW]

release_capture:
    sub rsp, 40
    mov rdx, [rip+old_bitmap]
    test rdx, rdx
    jz .release_memory_dc
    mov rcx, [rip+memory_dc]
    api SelectObject
    mov qword ptr [rip+old_bitmap], 0
.release_memory_dc:
    mov rcx, [rip+memory_dc]
    test rcx, rcx
    jz .release_bitmap
    api DeleteDC
    mov qword ptr [rip+memory_dc], 0
.release_bitmap:
    mov rcx, [rip+bitmap]
    test rcx, rcx
    jz .release_screen
    api DeleteObject
    mov qword ptr [rip+bitmap], 0
.release_screen:
    mov rdx, [rip+screen_dc]
    test rdx, rdx
    jz .released
    xor ecx, ecx
    api ReleaseDC
    mov qword ptr [rip+screen_dc], 0
.released:
    add rsp, 40
    ret

error_message:
    sub rsp, 40
    mov rcx, [rip+window]
    address r8, title
    mov r9d, 0x10
    api MessageBoxW
    add rsp, 40
    ret

.section .data
.balign 8
window: .quad 0
screen_dc: .quad 0
memory_dc: .quad 0
bitmap: .quad 0
old_bitmap: .quad 0
pixels: .quad 0
writer: .quad 0
byte_stream: .quad 0
attributes: .quad 0
format: .quad 0
frame_buffer: .quad 0
sample: .quad 0
deadline: .quad 0
record_start: .quad 0
next_slot: .quad 0
state: .long 0
frames: .long 0
stream_index: .long 0
seconds_shown: .long 0
hotkey_active: .long 0
width: .long 0
height: .long 0
encoded_width: .long 0
encoded_height: .long 0
luma_size: .long 0
nv12_size: .long 0
mf_started: .byte 0
temp_exists: .byte 0
timer_resolution: .byte 0

.balign 4
bitmap_info:
    .long 40
bitmap_width: .long 0
bitmap_height: .long 0
    .short 1, 32
    .long 0, 0, 0, 0, 0, 0

.balign 8
save_dialog:
    .long 152, 0
save_owner: .quad 0
    .quad 0
save_filter: .quad 0
    .quad 0
    .long 0, 1
save_path: .quad 0
    .long 260, 0
    .quad 0
    .long 0, 0
    .quad 0, 0
save_flags: .long 0x880e
    .short 0, 0
save_extension: .quad 0
    .quad 0, 0, 0, 0
    .long 0, 0
path: .zero 520
directory: .zero 520
temp_path: .zero 520
countdown_label:
    .short 82, 101, 99, 111, 114, 100, 105, 110, 103, 32, 115, 116, 97, 114, 116, 115, 32, 105, 110, 32
count_digits:
    .string16 "15 seconds"

.section .rdata,"a"
.macro utf16 value:vararg
    .string16 \value
.endm
.balign 16
y_coeff: .rept 4
    .byte 13, 64, 33, 0
    .endr
y_round: .rept 8
    .short 2112
    .endr
uv_coeff: .rept 2
    .byte 112, -74, -38, 0, -18, -94, 112, 0
    .endr
uv_round: .rept 8
    .short 128
    .endr
uv_center: .rept 8
    .short 128
    .endr

.macro guid name, a, b, c, d:vararg
\name:
    .long \a
    .short \b, \c
    .byte \d
.endm
guid attr_major, 0x48eba18e, 0xf8c9, 0x4687, 0xbf,0x11,0x0a,0x74,0xc9,0xf9,0x6a,0x8f
guid attr_subtype, 0xf7e34c9a, 0x42e8, 0x4714, 0xb7,0x4b,0xcb,0x29,0xd7,0x2c,0x35,0xe5
guid attr_size, 0x1652c33d, 0xd6b2, 0x4012, 0xb8,0x34,0x72,0x03,0x08,0x49,0xa3,0x7d
guid attr_rate, 0xc459a2e8, 0x3d2c, 0x4e44, 0xb1,0x32,0xfe,0xe5,0x15,0x6c,0x7b,0xb0
guid attr_aspect, 0xc6376a1e, 0x8d0a, 0x4027, 0xbe,0x45,0x6d,0x9a,0x0a,0xd3,0x9b,0xb6
guid attr_interlace, 0xe2724bb8, 0xe676, 0x4806, 0xb4,0xb2,0xa8,0xd6,0xef,0xb4,0x4c,0xcd
guid attr_bitrate, 0x20332624, 0xfb0d, 0x4d9e, 0xbd,0x0d,0xcb,0xf6,0x78,0x6c,0x10,0x2e
guid attr_container, 0x150ff23f, 0x4abc, 0x478b, 0xac,0x4f,0xe1,0x91,0x6f,0xba,0x1c,0xca
guid container_mp4, 0xdc6cd05d, 0xb9d0, 0x40ef, 0xbd,0x35,0xfa,0x62,0x2c,0x1a,0xb2,0x8a
guid type_video, 0x73646976, 0, 0x0010, 0x80,0,0,0xaa,0,0x38,0x9b,0x71
guid subtype_h264, 0x34363248, 0, 0x0010, 0x80,0,0,0xaa,0,0x38,0x9b,0x71
guid subtype_nv12, 0x3231564e, 0, 0x0010, 0x80,0,0,0xaa,0,0x38,0x9b,0x71

.balign 4
dialog:
    .long 0x90ca00c0, 0x00040000 # WS_MINIMIZEBOX | WS_EX_APPWINDOW
    .short 2, 0, 0, 218, 68
    .short 0, 0
title: utf16 "Screen Recorder"
    .short 9
    utf16 "Segoe UI"
    .balign 4
    .long 0x50000000, 0
    .short 10, 10, 198, 19, 101, 0xffff, 0x82
ready_label: utf16 "Full primary display - MP4 / 30 fps"
    .short 0
    .balign 4
    .long 0x50010000, 0
    .short 10, 35, 124, 22, 100, 0xffff, 0x80
start_label: utf16 "Start recording..."
    .short 0
stop_label: utf16 "Stop and save"
cancel_label: utf16 "Cancel countdown"
recording_label: utf16 "Recording - Ctrl+Shift+F10 to save"
no_hotkey_label: utf16 "Recording - click Stop and save"
saved_label: utf16 "MP4 saved."
interrupted_label: utf16 "Recording interrupted. Partial MP4 saved."
move_error_label: utf16 "Could not move MP4. Temporary path shown."
start_error_label: utf16 "Could not start. Check your save location, display size, and Windows Media Foundation."
extension_error_label: utf16 "Choose a filename ending in .mp4."
save_error_label: utf16 "Could not finalize the MP4. Check your available disk space."
filter: utf16 "MP4 video (*.mp4)", "*.mp4", ""
extension: utf16 "mp4"
default_name: utf16 "Recording.mp4"
temp_prefix: utf16 "REC"

.macro imports dll, names:vararg
    .section .idata$2,"a"
    .long lookup_\dll-0x400000, 0, 0, dll_\dll-0x400000, iat_\dll-0x400000
    .section .idata$4,"a"
    .balign 8
lookup_\dll:
    .irp name, \names
        .long hint_\name-0x400000, 0
    .endr
    .quad 0
    .section .idata$5,"aw"
    .balign 8
iat_\dll:
    .irp name, \names
imp_\name:
        .long hint_\name-0x400000, 0
    .endr
    .quad 0
    .section .idata$6,"a"
dll_\dll:
    .asciz "\dll\().dll"
    .irp name, \names
        .balign 2
hint_\name:
        .short 0
        .asciz "\name"
    .endr
.endm
imports KERNEL32, ExitProcess, GetModuleHandleW, GetTickCount64, GetTempFileNameW, lstrcpyW, MoveFileExW, DeleteFileW
imports USER32, SetProcessDpiAwarenessContext, DialogBoxIndirectParamW, EndDialog, GetSystemMetrics, GetDC, ReleaseDC, SetTimer, KillTimer, SetDlgItemTextW, MessageBoxW, ShowWindow, RegisterHotKey, UnregisterHotKey
imports GDI32, CreateCompatibleDC, CreateDIBSection, SelectObject, BitBlt, PatBlt, GdiFlush, DeleteObject, DeleteDC
imports COMDLG32, GetSaveFileNameW, CommDlgExtendedError
imports OLE32, CoInitializeEx, CoUninitialize
imports WINMM, timeBeginPeriod, timeEndPeriod
imports DWMAPI, DwmFlush
imports MFPLAT, MFStartup, MFShutdown, MFCreateAttributes, MFCreateMediaType, MFCreateMemoryBuffer, MFCreateSample, MFCreateFile
imports MFREADWRITE, MFCreateSinkWriterFromURL
