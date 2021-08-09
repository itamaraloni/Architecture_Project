%macro check_last 0
    cmp dword [eax+1], 0
    jne %%not_zero

    cmp edx, 0
    je .return

    %%not_zero:
%endmacro

%define MAX_LINE 80

%define MAX_STACK_SZ 63

%define DEFAULT_STACK_SZ 5

%macro print_debug_messages 2      ; prints to stderr only if in debug mode
    cmp dword [debug], 0           ; check if in debug mode
    je %%notDebugMode
    FPRINTF(stderr,%1,%2)
    %%notDebugMode:
%endmacro


%macro printMe 3  ; calls fprintf with 3 arguments
    pushad
    push %3
    push %2
    push dword [%1]
    call fprintf
    add esp,12
    popad
%endmacro

%macro my_fgets 3  ; calls fgets with 3 arguments
  push dword [%3]
  push %2
  push %1
  call fgets
  add esp,12
%endmacro

%macro freeLink 0 ; frees the link in the [linkToFree]
    pushad
    pushfd
    push dword [linkToFree]
    call free
    add esp, 4
    popfd
    popad
%endmacro

%define FPRINTF(stream, format, args) printMe stream, format, args

%define FGETS(buf, sz, stream) my_fgets buf, sz, stream

%define DEBUG_PRINT(format,args) print_debug_messages format, args

section .rodata
    decimal_format: db "%d", 10, 0
    hexa_decimal_format: db "%x", 10, 0
    hexa_decimal_format_: db "%X", 0
    newline_string: db 10, 0
    string_format: db "%s", 0
    string_format_newline: db "%s", 10, 0
    calc_str: db "calc: ", 0
    stackSize_str: db "Stack size is: ", 0
    operandStackAddress_str: db "Address of operands stack is: ", 0
    currLinkAddress_str: db "Address of new link is: ", 0
    poppedLinkAddress_str: db "Popped link Address is: ", 0
    octal_format: db "%o", 10, 0
    overflowError: db 'Error:Operand Stack Overflow',0
    insufficientNumberError: db 'Error: Insufficient Number of Arguments on Stack',0

section .bss
    stack_ebp: resd 1
    stack_esp: resd 1
    buffer: resb MAX_LINE
    curr_link: resd 1
    nextLink: resb 5
    nextOfFirstOperand: resd 1
    valueOfFirstOperand: resb 1
    nextOfSecondOperand: resd 1
    valueOfSecondOperand: resb 1
    linkToFree: resd 1
    nextLinkToFree: resd 1

section .data
    stack_sz: dd DEFAULT_STACK_SZ
    stack_counter: dd 0
    debug: dd 0
    numOfOperations: dd 0
    nextLinkNeeded: dd 1



section .text
  align 16
  global main
  extern printf
  extern fprintf 
  extern fflush
  extern malloc 
  extern calloc 
  extern free 
  ;extern gets 
  extern getchar 
  extern fgets 
  extern stdout
  extern stdin
  extern stderr

main:
    push ebp
    mov ebp, esp


    mov edx, 1                  ; counter
    mov eax, dword [stack_sz]   ; eax now holds default stack_sz = 5

    loopOnArgs:
    mov ebx, dword [ebp+8]      ; ebx = int argc
    cmp edx, ebx                ; check if finished reading arguments
    je finished_args

    mov ecx, dword [ebp+12]     ; ecx = char** argv
    mov ecx, dword [ecx + 4*edx]; ecx = argv[edx]  
    cmp byte [ecx], '-'         ; check if user inserted debug mode
    jne newStackSize            ; argument is a number to be the new stack_size
    mov byte [debug],1          ; activate debug mode
    inc edx                     ; advance to next argument
    jmp loopOnArgs              

    newStackSize:
    push ecx
    call oatoi                  ; change the string into a octal number
    add esp, 4                   
    mov dword [stack_sz], eax   ; update stack size to user's input
    inc edx                     ; advance to next argument
    jmp loopOnArgs

    finished_args:
    mov eax, dword [stack_sz]
    shl eax, 2                  ; stack will hold pointers which are each the size of 4 bytes

    push eax
    call malloc                 ; allocate memory for the stack
    add esp, 4

    mov dword [stack_ebp], eax  ; both points to the begining of the stack
    mov dword [stack_esp], eax

    DEBUG_PRINT(string_format, stackSize_str)
    DEBUG_PRINT(octal_format,dword [stack_sz]) 
    DEBUG_PRINT(string_format,operandStackAddress_str)
    DEBUG_PRINT(hexa_decimal_format,dword [stack_esp])

    call myCalc

    FPRINTF(stdout,octal_format,eax)    ; print the number of operations

    push dword [stack_ebp]
    call free
    add esp, 4

    pop ebp
    ret

myCalc:
    push ebp
    mov ebp, esp

    myCalc_loop:
    FPRINTF(stdout,string_format,calc_str)  ; print 'calc:'
    FGETS(buffer, MAX_LINE, stdin)          ; wait for the user input

    cmp byte [buffer], 'q'
    je quit

    cmp byte [buffer], '+'
    je plus

    cmp byte [buffer], 'p'
    je pop_and_print

    cmp byte [buffer], 'd'
    je duplicate

    cmp byte [buffer], '&'
    je bitwise_and

    cmp byte [buffer], 'n'
    je numof_bytes

    mov eax, dword [stack_counter]  ; holds the number of operands in stack
    cmp eax, dword [stack_sz]       ; check if stack is full
    je overflowError_handle   

    call create_linked_list

    jmp myCalc_loop

    quit:

    mov eax, dword [stack_esp]
    mov ebx, dword [stack_ebp]
    cmp eax, ebx                    ;check if stack is empty
    je finish_free_loop

    ;free Loop frees all of the linked lists in stack
    freeLoop: 

    call pop_operand
    mov dword [nextLinkToFree], eax        

    ; innerLoop frees a linked list
    innerLoop:
    mov eax, dword [eax+1]
    mov dword [nextLink], eax
    mov eax, dword [nextLinkToFree]
    mov dword [linkToFree], eax
    freeLink
    cmp dword [nextLink], 0             ; check if there is a next link to free
    jne beforeNextLink

    ;no more link in current operand, proceed to next one
    mov eax, dword [stack_esp]          
    mov ebx, dword [stack_ebp]
    cmp eax, ebx                    ; check if stack is empty 
    jne freeLoop                    ; if not, free next operand
    jmp finish_free_loop

    beforeNextLink:
    mov eax, dword [nextLink]
    mov dword [nextLinkToFree], eax
    jmp innerLoop

    finish_free_loop:
    mov eax, dword [numOfOperations]

    pop ebp
    ret

create_linked_list:
    push ebp
    mov ebp, esp

    mov ebx, buffer       ; ebx points to the begining of input
    
    .find_end:
    cmp byte [ebx], 10    ; check if reached end of input string
    je .found_end

    inc ebx
    jmp .find_end

    .found_end:
    dec ebx
    mov dword [curr_link], 0

    caseA:
    movzx ecx, byte [ebx]           ; ecx hold a digit (in ascii) from input string padded with zero
    sub ecx, '0'                    ; ecx = first number in binary ,ecx = 00..000111
    dec ebx                         ; point to next digit
    cmp ebx, buffer-1               ; check if finished number
    je finished_digits_A            ; no more links are required

    movzx edx, byte [ebx]           ; edx hold a digit (in ascii) from input string padded with zero
    sub edx, '0'                    ; edx = second number in binary, edx = 00..00101
    shl edx, 3                      ; edx = 00..000101000  
    or ecx, edx                     ; ecx = updated number in binary , ecx = 00...00101111
    dec ebx                         ; point to next digit
    cmp ebx, buffer-1               ; check if finished number
    je finished_digits_A            ; no more links are required

    movzx edx, byte [ebx]           ; edx hold a digit (in ascii) from input string padded with zero
    sub edx, '0'                    ; edx = third number in binary , edx = 00..00010
    and edx, 3                      ; only 2 of 3 bits are relevant edx = 00...00010
    shl edx, 6                      ; 
    or ecx, edx                     ; ecx hold the number in the first link

    mov edi, ebx
    dec edi
    cmp edi, buffer-1               ; check if finished number
    jne finishA                     ; if not an extra link is needed
    
    ;check if the last bit of the third digit is zero - if not an extra link is needed
    movzx edx, byte [ebx]           ; edx hold a digit (in ascii) from input string padded with zero
    sub edx, '0'                    ; edx = third number in binary
    and edx, 4                      ; only msb of 3 bits is relevant
    cmp edx,0                       ; if msb of last digit is zero and there is no extra digit - no additional link is needed
    jne finishA

    finished_digits_A:
    mov dword [nextLinkNeeded], 0   ; we reached here if no extra link is required

    finishA:
    cmp dword [curr_link], 0        ; check if this is first link (only happens in case A)
    jne .not_first

    push ecx
    call create_link                ; creates a link that points to null
    add esp, 4
    mov dword [curr_link], eax      ; curr_link now holds the address of the newly created link

    push eax
    call push_operand               ; insert the new created link to our operand stack
    add esp, 4

    cmp dword [nextLinkNeeded], 1    ; check if an extra link is required
    je caseB
    jmp finishedNumber

    .not_first:

    push ecx
    call create_link                ; creates a link that points to null
    add esp, 4

    mov ecx, dword [curr_link]    ; ecx now points to the address of the father
    mov dword [ecx+1], eax        ; update father 'next pointer' to point on new link
    mov dword [curr_link], eax      ; curr_link now holds the address of the newly created link

    cmp dword [nextLinkNeeded], 1    ; check if an extra link is required
    je caseB
    jmp finishedNumber

    caseB:
    mov dword [nextLinkNeeded], 1   ; default is that a next link is needed
    movzx ecx, byte [ebx]           
    sub ecx, '0'                    ; ecx now holds last digit from case A, ecx = 0000.00010
    and ecx, 4                      ; get only the msb of the digit
    shr ecx, 2                      ; make the relevent bit be most right in ecx
    dec ebx
    cmp ebx, buffer-1               ; check if finished number
    je finished_digits_B

    movzx edx, byte [ebx]           ;
    sub edx, '0'                    ; edx = second number in binary, edx = 00..00001
    shl edx, 1                      ; edx = 00..0000010  
    or ecx, edx                     ; ecx = updated number in binary , ecx = 00...000010
    dec ebx
    cmp ebx, buffer-1
    je finished_digits_B

    movzx edx, byte [ebx]
    sub edx, '0'                    ;edx = second number in binary
    shl edx, 4                      
    or ecx, edx                     
    dec ebx
    cmp ebx, buffer-1
    je finished_digits_B

    movzx edx, byte [ebx]
    sub edx, '0'
    and edx, 1                      ; we only need the lsb
    shl edx, 7                      ; put the bit in the relevant position
    or ecx, edx                     ; ecx = complete 8 bit number (in cl)

    mov edi, ebx
    dec edi
    cmp edi, buffer-1               ; check if finished number
    jne finishB                     ; if not an extra link is needed
    
    ;check if the last 2 bits of the last digit is zero - if not an extra link is needed
    movzx edx, byte [ebx]           ; edx hold a digit (in ascii) from input string padded with zero
    sub edx, '0'                    ; edx = third number in binary
    and edx, 6                      ; only msb of 3 bits is relevant
    cmp edx,0                       ; if msb of last digit is zero and there is no extra digit - no additional link is needed
    jne finishB

    finished_digits_B:
    mov dword [nextLinkNeeded], 0   ; we reached here if no extra link is required

    finishB:
    push ecx
    call create_link                ; creates a link that points to null
    add esp, 4

    mov ecx, dword [curr_link]      ; ecx now points to the address of the father
    mov dword [ecx+1], eax          ; update father 'next pointer' to point on new link
    mov dword [curr_link], eax      ; curr_link now holds the address of the newly created link

    cmp dword [nextLinkNeeded], 1    ; check if an extra link is required
    je caseC
    jmp finishedNumber

    caseC:
    mov dword [nextLinkNeeded], 1   ; default is that a next link is needed 

    movzx ecx, byte [ebx]           ; 
    sub ecx, '0'                    ; ecx now holds last digit from case A, ecx = 0000.00010
    and ecx, 6                      ; get only the 2 left bits of the digit
    shr ecx, 1                      ; make the relevent bits be most right in ecx
    dec ebx                         ; 
    cmp ebx, buffer-1               ; check if finished number
    je finishC

    movzx edx, byte [ebx]           
    sub edx, '0'                    ; edx = second number in binary
    shl edx, 2                        
    or ecx, edx                     ; ecx = updated number in binary 
    dec ebx                         
    cmp ebx, buffer-1
    je finishC

    movzx edx, byte [ebx]           
    sub edx, '0'                    ; edx = second number in binary
    shl edx, 5                        
    or ecx, edx                     ; ecx = updated number in binary 
    dec ebx                         

    finishC:

    push ecx
    call create_link                ; creates a link that points to null
    add esp, 4

    mov ecx, dword [curr_link]      ; ecx now points to the address of the father
    mov dword [ecx+1], eax          ; update father 'next pointer' to point on new link
    mov dword [curr_link], eax      ; curr_link now holds the address of the newly created link

    cmp ebx, buffer-1               ; check if finished number
    je finishedNumber
    jmp caseA
    
finishedNumber:
    mov dword [nextLinkNeeded], 1   ; default is that a next link is needed
    pop ebp
    ret


create_link:
    push ebp
    mov ebp, esp

    movzx edx, byte [ebp+8]     ; the data (number in binary)

    push edx                    ; edx is changed in malloc so we need to save edx's value

    push 5
    call malloc                 ; allocate memory for the link of size 5 - eax points to it
    add esp, 4 

    pop edx                 

    DEBUG_PRINT(string_format,currLinkAddress_str)
    DEBUG_PRINT(hexa_decimal_format,eax)

    mov byte [eax], dl          ; put the data in the first byte of the link
    mov dword [eax+1], 0        ; next 4 bytes of the link points to null as default

    .return:
    pop ebp
    ret

push_operand:
    push ebp
    mov ebp, esp      

    mov edx, dword [stack_esp]      ; edx = next empty place on stack
    mov eax, dword [ebp+8]          ; eax = link* operand
    mov dword [edx], eax            ; put the link in the next empty place on stack

    inc dword [stack_counter]       ; new link added to the stack so stack_counter++ 
    add dword [stack_esp], 4        ; make stack_esp point to the next empty space in the stack

    DEBUG_PRINT(string_format,operandStackAddress_str)
    DEBUG_PRINT(hexa_decimal_format, dword [stack_esp])

    .return:
    pop ebp
    ret

pop_operand: 

    push ebp
    mov ebp, esp

    mov edx, dword [stack_esp] ;
    sub edx, 4                        ; edx now points to the last occupied address in the stack 
    mov eax, dword [edx]              ; eax now points to the first link

    DEBUG_PRINT(string_format,poppedLinkAddress_str)
    DEBUG_PRINT(hexa_decimal_format, eax)

    dec dword [stack_counter]   ;link was poped out of the stack so stack_counter-- 
    sub dword [stack_esp], 4    ;make stack_esp point to the newly empty space in the stack

    DEBUG_PRINT(string_format,operandStackAddress_str)
    DEBUG_PRINT(hexa_decimal_format, dword [stack_esp])

    .return:
    pop ebp
    ret


oatoi:
    push ebp
    mov ebp, esp

    mov ebx, dword [ebp+8]      ; ebx = char* s

    mov eax, 0
    .loop:
    cmp byte [ebx], 0
    je .return

    movzx ecx, byte [ebx]
    sub ecx, '0'
    shl eax, 3
    add eax, ecx
    inc ebx
    jmp .loop

    .return:
    pop ebp
    ret

plus:
    inc dword [numOfOperations]

    mov eax, dword [stack_counter]
    cmp eax, 2                          ; + operation needs at least 2 numbers in stack 
    jl insufficientNumberError_handle

    call pop_operand                    ; eax now holds a pointer to the first link
    mov dword [linkToFree], eax         ; this link should be freed when we finish using it
    movzx edx, byte [eax]               ; edx now holds the number held in the first link
    mov byte [valueOfFirstOperand],dl
    mov ebx, dword [eax+1]              ; ebx points to next link of first operand
    mov dword [nextOfFirstOperand], ebx
    freeLink

    call pop_operand                    ; eax now holds a pointer to the second link
    mov dword [linkToFree], eax         ; this link should be freed when we finish using it
    movzx edx, byte [eax]               ; edx now holds the number held in the second link
    mov byte [valueOfSecondOperand],dl
    mov ebx, dword [eax+1]              ; ebx points to next link of second operand
    mov dword [nextOfSecondOperand], ebx   
    freeLink

    clc
    pushfd
    mov eax, 0
    mov edx, 0
    mov al, byte [valueOfFirstOperand]
    mov dl, byte [valueOfSecondOperand]
    popfd
    adc al,dl
    pushfd

    push eax
    call create_link                ; creates a link that points to null
    add esp, 4
    mov dword [curr_link], eax      ; curr_link now holds the address of the newly created link

    push eax
    call push_operand               ; insert the new created link to our operand stack
    add esp, 4

    plus_loop:
    cmp dword [nextOfFirstOperand], 0   ; if one of the links has a next link, the loop continue
    jne plus_cont
    cmp dword [nextOfSecondOperand], 0
    jne plus_cont
    jmp finalCarry

    plus_cont:

    checkFirst:
    cmp dword [nextOfFirstOperand], 0   ; check if first opernad has an additional link to add
    jne updateLinkFirstOp               ; if it does, update the link
    mov byte [valueOfFirstOperand],0    ; if it doesnt, the value to be added should be zero
    
    checkSecond:
    cmp dword [nextOfSecondOperand], 0   ; check if second opernad has an additional link to add
    jne updateLinkSecondOp               ; if it does, update the link
    mov byte [valueOfSecondOperand],0    ; if it doesnt, the value to be added should be zero
    jmp doAdd

    updateLinkFirstOp:
    mov eax, dword [nextOfFirstOperand] ; eax holds the address of the next link of first operand
    mov dword [linkToFree], eax         ; this link should be freed when we finish using it
    movzx edx, byte [eax]               ; edx now holds the number held in the first link
    mov byte [valueOfFirstOperand],dl
    mov ebx, dword [eax+1]              ; ebx points to next link of first operand
    mov dword [nextOfFirstOperand], ebx
    freeLink
    jmp checkSecond

    updateLinkSecondOp:
    mov eax, dword [nextOfSecondOperand] ; eax holds the address of the next link of second 
    mov dword [linkToFree], eax         ; this link should be freed when we finish using it
    movzx edx, byte [eax]               ; edx now holds the number held in the second link
    mov byte [valueOfSecondOperand],dl
    mov ebx, dword [eax+1]              ; ebx points to next link of second operand
    mov dword [nextOfSecondOperand], ebx    
    freeLink

    doAdd:
    mov eax, 0
    mov edx, 0
    mov al, byte [valueOfFirstOperand]
    mov dl, byte [valueOfSecondOperand]
    popfd
    adc al,dl
    pushfd

    push eax
    call create_link                ; creates a link that points to null
    add esp, 4

    mov ecx, dword [curr_link]    ; ecx now points to the address of the father
    mov dword [ecx+1], eax        ; update father 'next pointer' to point on new link
    mov dword [curr_link], eax    ; curr_link now holds the address of the newly created link

    jmp plus_loop

    finalCarry:
    mov eax, 0
    mov edx, 0
    popfd
    adc al, dl                    ; if there is a carry, eax value will be 1
    cmp eax, 0                    ; check if there is a carry
    je finishPlus                 ; if there isn't a carry, no extra link is needed
    
    push eax
    call create_link                ; creates a link that points to null
    add esp, 4    

    mov ecx, dword [curr_link]    ; ecx now points to the address of the father
    mov dword [ecx+1], eax        ; update father 'next pointer' to point on new link

    finishPlus:

    jmp myCalc_loop

pop_and_print:

    inc dword [numOfOperations]
    mov eax, dword [stack_counter]
    cmp eax, 1                          ; 'p' operation needs at least 1 number in stack
    jl insufficientNumberError_handle

    call pop_operand                    ; eax now holds a pointer to the first link
    push eax
    call printLinkedList
    add esp,4

    freeLink
    FPRINTF(stdout, string_format_newline, ecx)
    jmp myCalc_loop

duplicate:

    inc dword [numOfOperations]
    mov eax, dword [stack_counter]
    cmp eax, 1                          ; 'd' operation needs at least 1 number in stack
    jl insufficientNumberError_handle

    mov eax, dword [stack_counter]  ; holds the number of operands in stack
    cmp eax, dword [stack_sz]       ; check if stack is full
    je overflowError_handle  

    mov dword [curr_link], 0

    sub dword [stack_esp], 4 
    mov eax, dword[stack_esp]         ; eax now points to the last address in the stack
    add dword [stack_esp], 4 
    mov eax, dword [eax]                ; eax now points to the link needed to be duplicated
    mov edx, dword [eax+1]              ; edx holds the pointer to the 'next pointer' of the current link
    mov dword [nextLink], edx           ; next link will hold the next link to be added
    movzx edx, byte [eax]               ; edx now holds the number we want to create link with

    push edx
    call create_link                    ; create a link with the copied data
    add esp, 4
    mov dword [curr_link], eax      ; curr_link now holds the address of the newly created link

    push eax
    call push_operand                   ; push the new link to the operand stack
    add esp, 4

    cmp dword [nextLink], 0             ; check if next pointer of the current link in null
    je finish_duplicate
    
    duplicat_loop:
    mov eax, dword [nextLink]           ; eax holds the address of the next link
    mov edx, dword [eax+1]              ; edx holds the pointer to the 'next pointer' of the current link
    mov dword [nextLink], edx           ; next link will hold the next link to be added
    movzx edx, byte [eax]               ; edx now holds the number we want to create link with

    push edx
    call create_link                    ; create a link with the copied data
    add esp, 4

    mov ecx, dword [curr_link]    ; ecx now points to the address of the father
    mov dword [ecx+1], eax        ; update father 'next pointer' to point on new link
    mov dword [curr_link], eax    ; curr_link now holds the address of the newly created link

    cmp dword [nextLink], 0             ; check if next pointer of the current link in null
    jne duplicat_loop

    finish_duplicate:
    jmp myCalc_loop

bitwise_and:
    inc dword [numOfOperations]

    mov eax, dword [stack_counter]
    cmp eax, 2                          ; '&' operation needs at least 2 numbers in stack
    jl insufficientNumberError_handle

    call pop_operand                    ; eax now holds a pointer to the first link
    mov dword [linkToFree], eax         ; this link should be freed when we finish using it
    movzx edx, byte [eax]               ; edx now holds the number held in the first link
    mov byte [valueOfFirstOperand],dl
    mov ebx, dword [eax+1]              ; ebx points to next link of first operand
    mov dword [nextOfFirstOperand], ebx
    freeLink


    call pop_operand                    ; eax now holds a pointer to the second link
    mov dword [linkToFree], eax         ; this link should be freed when we finish using it
    movzx edx, byte [eax]               ; edx now holds the number held in the second link
    mov byte [valueOfSecondOperand],dl
    mov ebx, dword [eax+1]              ; ebx points to next link of second operand
    mov dword [nextOfSecondOperand], ebx    
    freeLink

    movzx ecx, byte [valueOfFirstOperand]
    movzx edx, byte [valueOfSecondOperand]
    and ecx, edx                        ; and between the values in the first link of both operands

    push ecx
    call create_link                ; creates a link that points to null
    add esp, 4
    mov dword [curr_link], eax      ; curr_link now holds the address of the newly created link

    push eax
    call push_operand               ; insert the new created link to our operand stack
    add esp, 4

    and_loop:
    cmp dword [nextOfFirstOperand], 0
    je finish_and_loop
    cmp dword [nextOfSecondOperand], 0
    je finish_and_loop

    mov eax, dword [nextOfFirstOperand] ; eax holds the address of the next link of first operand
    mov dword [linkToFree], eax         ; this link should be freed when we finish using it
    movzx edx, byte [eax]               ; edx now holds the number held in the first link
    mov byte [valueOfFirstOperand],dl
    mov ebx, dword [eax+1]              ; ebx points to next link of first operand
    mov dword [nextOfFirstOperand], ebx
    freeLink

    mov eax, dword [nextOfSecondOperand] ; eax holds the address of the next link of second operand
    mov dword [linkToFree], eax         ; this link should be freed when we finish using it
    movzx edx, byte [eax]               ; edx now holds the number held in the second link
    mov byte [valueOfSecondOperand],dl
    mov ebx, dword [eax+1]              ; ebx points to next link of second operand
    mov dword [nextOfSecondOperand], ebx    
    freeLink

    movzx ecx, byte [valueOfFirstOperand]
    movzx edx, byte [valueOfSecondOperand]
    and ecx, edx                        ; and between the values in the first link of both operands
    cmp ecx, 0                          ; check if and result is 0
    je check_if_last                    ; if the value is zero and this is the last link, no need to add the link

    addLink:
    push ecx
    call create_link                ; creates a link that points to null
    add esp, 4

    mov ecx, dword [curr_link]    ; ecx now points to the address of the father
    mov dword [ecx+1], eax        ; update father 'next pointer' to point on new link
    mov dword [curr_link], eax     ; curr_link now holds the address of the newly created link

    jmp and_loop

    finish_and_loop:

    jmp myCalc_loop

    check_if_last:
    cmp dword [nextOfFirstOperand], 0
    je finish_and_loop
    cmp dword [nextOfSecondOperand], 0
    je finish_and_loop
    jmp addLink

numof_bytes:
    inc dword [numOfOperations]

    mov eax, dword [stack_counter]
    cmp eax, 1                          ; 'n' operation needs at least 2 numbers in stack
    jl insufficientNumberError_handle

    call pop_operand                    ; eax now holds a pointer to the first link

    mov ecx, 0                          ; ecx will be the counter of bytes

    numOfBytes_loop:
    mov dword [linkToFree], eax         ; this link should be freed when we finish using it
    inc ecx
    mov ebx, dword [eax+1]              ; ebx holds the pointer to the 'next pointer' of the current link
    mov dword [nextLink], ebx           ; next link will hold the next link to be counted
    freeLink
    cmp dword [nextLink], 0             ; check if there is a next link
    je finishNumOf                    ;
    mov eax, dword [nextLink]           ; eax holds a pointer to the next link
    jmp numOfBytes_loop

    finishNumOf:

    push ecx
    call create_link                ; creates a link that points to null
    add esp, 4

    push eax
    call push_operand               ; insert the new created link to our operand stack
    add esp, 4

    jmp myCalc_loop


printLinkedList:
    push ebp
    mov ebp, esp

    mov eax, dword [ebp+8]
    mov ecx, buffer+MAX_LINE-1
    mov byte [ecx], 0

    .loop:
    ; A: first 3
    mov dword [linkToFree], eax         ; this link should be freed when we finish using it
    dec ecx
    movzx edx, byte [eax]               ; edx now holds the number held in the first link
        
    mov ebx, edx
    and ebx, 7
    add ebx, '0'
    mov byte [ecx], bl

    shr edx, 3

    check_last

    dec ecx

    ; A: second 3
    mov ebx, edx
    and ebx, 7
    add ebx, '0'
    mov byte [ecx], bl

    shr edx, 3

    check_last

    dec ecx

    ; A: 2
    mov ebx, edx
    and ebx, 3

    cmp dword [eax+1], 0
    jne .cont1

    add ebx, '0'
    mov byte [ecx], bl
    jmp .return

    .cont1:
    ; B: first 1
    mov eax, dword [eax+1]
    freeLink
    mov dword [linkToFree], eax             ; this link should be freed when we finish using it
    movzx edx, byte [eax]

    mov edi, edx
    and edi, 1
    shl edi, 2
    or ebx, edi
    add ebx, '0'
    mov byte [ecx], bl

    shr edx, 1

    check_last

    dec ecx

    ; B: first 3
    mov ebx, edx
    and ebx, 7
    add ebx, '0'
    mov byte [ecx], bl

    shr edx, 3

    check_last

    dec ecx

    ; B: second 3
    mov ebx, edx
    and ebx, 7
    add ebx, '0'
    mov byte [ecx], bl

    shr edx, 3

    check_last

    dec ecx

    ; B: last 1
    mov ebx, edx
    and ebx, 1

    cmp dword [eax+1], 0
    jne .cont2

    add ebx, '0'
    mov byte [ecx], bl
    jmp .return

    .cont2:
    ;C: 2
    mov eax, dword [eax+1]
    freeLink
    mov dword [linkToFree], eax             ; this link should be freed when we finish using it
    movzx edx, byte [eax]

    mov edi, edx
    and edi, 3
    shl edi, 1
    or ebx, edi
    add ebx, '0'
    mov byte [ecx], bl

    shr edx, 2

    check_last

    dec ecx

    ; C: first 3
    mov ebx, edx
    and ebx, 7
    add ebx, '0'
    mov byte [ecx], bl

    shr edx, 3

    check_last

    dec ecx

    ; C: second 3
    mov ebx, edx
    and ebx, 7
    add ebx, '0'
    mov byte [ecx], bl

    mov eax, dword [eax+1]          ; eax holds the address of the next link
    cmp eax, 0                      ; check if there is a next link, if not we finished
    je .return

    freeLink
    jmp .loop

    .return:
    pop ebp
    ret


insufficientNumberError_handle:
    FPRINTF(stderr,string_format_newline,insufficientNumberError)
    jmp myCalc_loop

overflowError_handle:
    FPRINTF(stderr,string_format_newline,overflowError)
    jmp myCalc_loop


