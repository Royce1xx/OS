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
    
    ; Set up interrupts
    call setup_idt
    call setup_pic
    sti                    ; Enable interrupts
    
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

setup_pic:
    ; Remap PIC interrupts to avoid conflicts with CPU exceptions
    ; Master PIC: IRQ 0-7 become interrupts 32-39
    ; Slave PIC: IRQ 8-15 become interrupts 40-47
    
    ; Start initialization sequence
    mov al, 0x11
    out 0x20, al        ; Master PIC command
    out 0xA0, al        ; Slave PIC command
    
    ; Set interrupt vector offsets
    mov al, 0x20        ; Master PIC starts at interrupt 32
    out 0x21, al
    mov al, 0x28        ; Slave PIC starts at interrupt 40  
    out 0xA1, al
    
    ; Tell PICs about each other
    mov al, 0x04        ; Master: slave PIC at IRQ 2
    out 0x21, al
    mov al, 0x02        ; Slave: cascade identity
    out 0xA1, al
    
    ; Set 8086 mode
    mov al, 0x01
    out 0x21, al
    out 0xA1, al
    
    ; Enable keyboard interrupt (IRQ 1) only, disable others
    mov al, 0xFD        ; Binary: 11111101 (bit 1 = 0 enables IRQ 1)
    out 0x21, al        ; Mask for master PIC
    mov al, 0xFF        ; Disable all slave PIC interrupts
    out 0xA1, al
    
    ret

setup_idt:
    ; Set up keyboard interrupt (IRQ 1 = interrupt 33)
    mov edi, idt + (33 * 8)     ; Point to entry 33
    mov eax, keyboard_handler   ; Handler address
    mov [edi], ax               ; Low 16 bits
    shr eax, 16
    mov [edi + 6], ax           ; High 16 bits
    mov word [edi + 2], 0x08    ; Code segment
    mov byte [edi + 4], 0       ; Reserved
    mov byte [edi + 5], 0x8E    ; Present, Ring 0, Interrupt Gate
    
    ; Load the IDT
    lidt [idt_descriptor]
    ret

; Keyboard handler - runs when key is pressed
keyboard_handler:
    pushad              ; Save all registers
    
    ; Read scan code from keyboard
    in al, 0x60         ; Read from keyboard data port
    
    ; Check if it's a key release (high bit set)
    test al, 0x80
    jnz .key_release
    
    ; Handle special keys (key press)
    cmp al, 0x0E        ; Backspace scan code
    je .backspace
    cmp al, 0x1C        ; Enter scan code
    je .enter
    cmp al, 0x2A        ; Left Shift press
    je .shift_press
    cmp al, 0x36        ; Right Shift press
    je .shift_press
    cmp al, 0x3A        ; Caps Lock press
    je .caps_lock_toggle
    
    ; Convert scan code to ASCII for regular keys
    movzx ebx, al       ; Zero-extend scan code to ebx
    cmp bl, 58          ; Check if scan code is in our table
    jge .done           ; Skip if outside range
    
    mov al, [scancode_table + ebx]  ; Get ASCII character
    cmp al, 0           ; Check if valid character
    je .done            ; Skip if no character
    
    ; Check if we need uppercase
    call should_uppercase
    cmp bl, 1
    jne .display_char
    
    ; Convert to uppercase if it's a letter
    cmp al, 'a'
    jb .check_numbers
    cmp al, 'z'
    ja .check_numbers
    sub al, 32          ; Convert to uppercase
    jmp .display_char
    
.check_numbers:
    ; Handle shift + number keys for symbols
    mov bl, [shift_pressed]
    cmp bl, 1
    jne .display_char
    
    ; Convert numbers to symbols when shift is pressed
    cmp al, '1'
    jne .check_2
    mov al, '!'
    jmp .display_char
.check_2:
    cmp al, '2'
    jne .check_3
    mov al, '@'
    jmp .display_char
.check_3:
    cmp al, '3'
    jne .check_4
    mov al, '#'
    jmp .display_char
.check_4:
    cmp al, '4'
    jne .check_5
    mov al, '$'
    jmp .display_char
.check_5:
    cmp al, '5'
    jne .display_char
    mov al, '%'
    
.display_char:
    ; Display the character
    mov edi, [cursor_pos]
    mov ah, 0x0F        ; White on black
    stosw               ; Store character + attribute
    
    ; Update cursor position
    add dword [cursor_pos], 2
    jmp .done

.key_release:
    ; Handle key releases
    and al, 0x7F        ; Remove release bit
    cmp al, 0x2A        ; Left Shift release
    je .shift_release
    cmp al, 0x36        ; Right Shift release
    je .shift_release
    jmp .done

.shift_press:
    mov byte [shift_pressed], 1
    jmp .done

.shift_release:
    mov byte [shift_pressed], 0
    jmp .done

.caps_lock_toggle:
    xor byte [caps_lock_on], 1    ; Toggle caps lock
    jmp .done
    
.backspace:
    ; Move cursor back and clear character
    mov edi, [cursor_pos]
    cmp edi, 0xB8000 + (80*6*2)  ; Don't go before start of line
    jle .done
    sub edi, 2                    ; Move back one character
    mov [cursor_pos], edi
    mov ax, 0x0F20               ; Space with white attribute
    stosw                        ; Clear the character
    sub dword [cursor_pos], 2    ; Adjust cursor back again
    jmp .done
    
.enter:
    ; Move to next line
    mov edi, [cursor_pos]
    ; Calculate current row
    sub edi, 0xB8000
    shr edi, 1          ; Divide by 2 (each char is 2 bytes)
    mov eax, edi
    mov ebx, 80
    xor edx, edx
    div ebx             ; eax = row, edx = column
    inc eax             ; Next row
    mov ebx, 80
    mul ebx             ; eax = row * 80
    shl eax, 1          ; Multiply by 2 (each char is 2 bytes)
    add eax, 0xB8000    ; Add video memory base
    mov [cursor_pos], eax
    jmp .done

.done:
    ; Send End of Interrupt to PIC
    mov al, 0x20
    out 0x20, al        ; Tell PIC we handled the interrupt
    
    popad               ; Restore all registers
    iret                ; Return from interrupt

; Function to determine if character should be uppercase
; Returns: bl = 1 if uppercase, bl = 0 if lowercase
should_uppercase:
    mov bl, [shift_pressed]
    xor bl, [caps_lock_on]    ; XOR: uppercase if shift XOR caps (one but not both)
    ret

; Messages
msg1 db "*** ROYCE'S KERNEL IS WORKING! ***", 0
msg2 db "Built with pure NASM assembly!", 0
msg3 db "Bootloader -> Kernel SUCCESS!", 0
msg4 db "I cant belive this is working", 0

; Cursor position for typing
cursor_pos dd 0xB8000 + (80*6*2)  ; Start at row 6

; Keyboard state flags
shift_pressed db 0      ; 1 if shift is currently held
caps_lock_on db 0       ; 1 if caps lock is active

; Scan code to ASCII conversion table
scancode_table:
    db 0,0,'1','2','3','4','5','6','7','8','9','0','-','=',0,0    ; 0x00-0x0F
    db 'q','w','e','r','t','y','u','i','o','p','[',']',0,0,'a','s' ; 0x10-0x1F
    db 'd','f','g','h','j','k','l',';',"'","`",0,'\','z','x','c','v' ; 0x20-0x2F
    db 'b','n','m',',','.','/',0,'*',0,' ',0,0,0,0,0,0             ; 0x30-0x3F

; IDT with 256 entries
idt:
    times 256 * 8 db 0      ; 256 entries, 8 bytes each

idt_descriptor:
    dw 256 * 8 - 1          ; IDT size
    dd idt                  ; IDT address