[bits 32]
[org 0x8000]

start:
    ; Clear screen
    mov edi, 0xB8000
    mov ecx, 80*25
    mov eax, 0x07200720    ; Space with gray background
    rep stosd
    
    ; Print first message
    mov edi, 0xB8000
    mov esi, msg1
    mov ah, 0x0F           ; White on black
    call print_string
    
    ; Print second message (second row)
    mov edi, 0xB8000 + (80*2*2)
    mov esi, msg2
    mov ah, 0x0A           ; Green on black
    call print_string
    
    ; Print third message (fourth row)
    mov edi, 0xB8000 + (80*4*2)
    mov esi, msg3
    mov ah, 0x0E           ; Yellow on black
    call print_string
    
    ; Infinite loop
    jmp $

print_string:
    lodsb                  ; Load character
    cmp al, 0             ; Check for null
    je .done
    stosw                 ; Store char + attribute
    jmp print_string
.done:
    ret

msg1 db "*** ROYCE'S KERNEL IS WORKING! ***", 0
msg2 db "Built with pure NASM assembly!", 0
msg3 db "Bootloader -> Kernel SUCCESS!", 0