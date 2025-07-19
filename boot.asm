[org 0x7c00]
[bits 16]

start:
    ; Set up segments and stack
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00
    
    ; Print boot message
    mov si, boot_msg
    call print_string
    
    ; Load kernel from disk
    mov bx, 0x8000      ; Load kernel here
    mov ah, 0x02        ; Read disk function
    mov al, 10          ; Read 10 sectors (more space)
    mov ch, 0           ; Cylinder 0
    mov dh, 0           ; Head 0
    mov cl, 2           ; Start from sector 2
    mov dl, 0x00        ; Floppy disk (not 0x80)
    int 0x13
    jc disk_error
    
    ; Switch to protected mode
    cli
    lgdt [gdt_descriptor]
    mov eax, cr0
    or eax, 1
    mov cr0, eax
    jmp 0x08:protected_mode

[bits 32]
protected_mode:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, 0x90000
    
    ; Jump to kernel
    jmp 0x8000

[bits 16]
print_string:
    pusha
    mov ah, 0x0e
.loop:
    lodsb
    cmp al, 0
    je .done
    int 0x10
    jmp .loop
.done:
    popa
    ret

disk_error:
    mov si, error_msg
    call print_string
    cli
    hlt

boot_msg db "Royce's Bootloader Loading...", 0x0D, 0x0A, 0
error_msg db "Disk Error!", 0

; GDT
gdt_start:
    dd 0x0, 0x0                     ; Null descriptor
    dd 0x0000FFFF, 0x00CF9A00       ; Code segment
    dd 0x0000FFFF, 0x00CF9200       ; Data segment
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start

times 510-($-$$) db 0
dw 0xaa55