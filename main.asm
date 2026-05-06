BITS 64
GLOBAL main
EXTERN printf, scanf, fopen, fclose, fprintf, cos, log, fabs

SECTION .data
    fmt_in      db "%lf %lf %lf", 0
    fmt_out     db `LHS = %.15lf\nRHS = %.15lf\n`, 0
    fmt_term    db `%d %.15e\n`, 0
    
    fmt_err_args db "Usage: %s <output_file>\n", 0
    fmt_err_open db "Error: cannot open output file.\n", 0
    fmt_err_read db "Error: failed to read input.\n", 0
    fmt_err_dom  db "Error: domain error (|x| > 1 or ln argument <= 0).\n", 0
    
    mode_w      db `w`, 0
    
    one         dq 1.0
    zero        dq 0.0
    neg_two     dq -2.0
    max_iter    dq 2000000.0

SECTION .bss
    x           resq 1
    alpha       resq 1
    eps         resq 1
    
    out_file    resq 1
    
    lhs         resq 1
    rhs         resq 1
    
    n           resd 1
    term_val    resq 1
    sum         resq 1
    x_pow       resq 1

SECTION .text
main:
    push rbp
    mov rbp, rsp
    sub rsp, 32                  ; Выравнивание стека по SysV ABI

    ; 1. Проверка аргументов
    cmp rdi, 2
    jl .err_args
    mov rax, [rsi + 8]

    ; 2. Открытие файла
    mov rdi, rax
    lea rsi, [rel mode_w]
    call fopen
    test rax, rax
    jz .err_open
    mov [rel out_file], rax

    ; 3. Чтение входных данных
    lea rdi, [rel fmt_in]
    lea rsi, [rel x]
    lea rdx, [rel alpha]
    lea rcx, [rel eps]
    xor eax, eax
    call scanf
    cmp eax, 3
    jne .err_read

    ; 4. Проверка |x| <= 1
    movsd xmm0, qword [rel x]
    call fabs
    ucomisd xmm0, qword [rel one]
    ja .err_dom

    ; 5. Вычисление LHS
    movsd xmm0, qword [rel alpha]
    call cos
    
    movsd xmm1, qword [rel x]
    mulsd xmm1, xmm0
    addsd xmm1, xmm1
    
    movsd xmm2, qword [rel x]
    mulsd xmm2, qword [rel x]
    
    movsd xmm3, qword [rel one]
    subsd xmm3, xmm1
    addsd xmm3, xmm2
    
    ucomisd xmm3, qword [rel zero]
    jbe .err_dom
    
    movsd xmm0, xmm3
    call log
    movsd qword [rel lhs], xmm0

    ; 6. Вычисление RHS
    xorpd xmm0, xmm0
    movsd qword [rel sum], xmm0
    movsd xmm0, qword [rel x]
    movsd qword [rel x_pow], xmm0
    mov dword [rel n], 1

.loop:
    ; cos(n*alpha)
    mov eax, [rel n]
    cvtsi2sd xmm0, eax
    mulsd xmm0, qword [rel alpha]
    call cos

    ; term = x_pow * cos / n
    mov edx, [rel n]
    cvtsi2sd xmm2, edx
    mulsd xmm0, qword [rel x_pow]
    divsd xmm0, xmm2
    movsd qword [rel term_val], xmm0

    ; sum += term
    movsd xmm1, qword [rel sum]
    addsd xmm1, xmm0
    movsd qword [rel sum], xmm1

    ; Запись в файл
    mov rdi, [rel out_file]
    lea rsi, [rel fmt_term]
    mov edx, [rel n]
    movsd xmm0, qword [rel term_val]
    mov eax, 1
    call fprintf

    ; !!! Проверка точности: строго |term| < eps !!!
    movsd xmm0, qword [rel term_val]
    call fabs
    ucomisd xmm0, qword [rel eps]
    jb .loop_end

    ; x_pow *= x
    movsd xmm0, qword [rel x_pow]
    mulsd xmm0, qword [rel x]
    movsd qword [rel x_pow], xmm0

    ; n++
    inc dword [rel n]
    cvtsi2sd xmm1, dword [rel n]
    ucomisd xmm1, qword [rel max_iter]
    ja .loop_end
    jmp .loop

.loop_end:
    movsd xmm0, qword [rel sum]
    mulsd xmm0, qword [rel neg_two]
    movsd qword [rel rhs], xmm0

    lea rdi, [rel fmt_out]
    movsd xmm0, qword [rel lhs]
    movsd xmm1, qword [rel rhs]
    mov eax, 2
    call printf

    mov rdi, [rel out_file]
    call fclose

    xor eax, eax
    leave
    ret

.err_args:
    lea rdi, [rel fmt_err_args]
    mov rsi, [rsi]
    xor eax, eax
    call printf
    mov eax, 1
    leave
    ret

.err_open:
    lea rdi, [rel fmt_err_open]
    xor eax, eax
    call printf
    mov eax, 1
    leave
    ret

.err_read:
    lea rdi, [rel fmt_err_read]
    xor eax, eax
    call printf
    mov eax, 1
    leave
    ret

.err_dom:
    lea rdi, [rel fmt_err_dom]
    xor eax, eax
    call printf
    mov eax, 1
    leave
    ret
