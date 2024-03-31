    .text                                                  ┃     .text                                                 
    .file    "saxpy"                                      ⟪╋⟫    .file    "saxpy_simd"                                 
    .globl    saxpy                # -- Begin function sa…⟪╋⟫    .globl    saxpy_simd           # -- Begin function sa…
    .p2align    4, 0x90                                    ┃     .p2align    4, 0x90                                   
    .type    saxpy,@function                              ⟪╋⟫    .type    saxpy_simd,@function                         
saxpy:                       # @saxpy                     ⟪╋⟫saxpy_simd:                  # @saxpy_simd                
    .cfi_startproc                                         ┃     .cfi_startproc                                        
# %bb.0:                                # %top             ┃ # %bb.0:                                # %top            
    push    rbp                                            ┃     push    rbp                                           
    .cfi_def_cfa_offset 16                                 ┃     .cfi_def_cfa_offset 16                                
    .cfi_offset rbp, -16                                   ┃     .cfi_offset rbp, -16                                  
    mov    rbp, rsp                                        ┃     mov    rbp, rsp                                       
    .cfi_def_cfa_register rbp                              ┃     .cfi_def_cfa_register rbp                             
    push    r15                                           ⟪┫                                                           
    push    r14                                           ⟪┫                                                           
    push    r13                                           ⟪┫                                                           
    push    r12                                           ⟪┫                                                           
    push    rsi                                            ┃     push    rsi                                           
    push    rdi                                            ┃     push    rdi                                           
    push    rbx                                           ⟪┫                                                           
    sub    rsp, 72                                        ⟪╋⟫    sub    rsp, 32                                        
    vmovdqa    xmmword ptr [rbp - 80], xmm7    # 16-byte …⟪╋⟫    vmovdqa    xmmword ptr [rbp - 32], xmm7    # 16-byte …
    vmovdqa    xmmword ptr [rbp - 96], xmm6    # 16-byte …⟪╋⟫    vmovdqa    xmmword ptr [rbp - 48], xmm6    # 16-byte …
    .cfi_offset rbx, -72                                  ⟪╋⟫    .cfi_offset rdi, -32                                  
    .cfi_offset rdi, -64                                  ⟪╋⟫    .cfi_offset rsi, -24                                  
    .cfi_offset rsi, -56                                  ⟪╋⟫    .cfi_offset xmm6, -64                                 
    .cfi_offset r12, -48                                  ⟪╋⟫    .cfi_offset xmm7, -48                                 
    .cfi_offset r13, -40                                  ⟪┫                                                           
    .cfi_offset r14, -32                                  ⟪┫                                                           
    .cfi_offset r15, -24                                  ⟪┫                                                           
    .cfi_offset xmm6, -112                                ⟪┫                                                           
    .cfi_offset xmm7, -96                                 ⟪┫                                                           
    mov    r13, r8                                        ⟪┫                                                           
    mov    r8, qword ptr [rcx + 8]                        ⟪╋⟫    mov    r10, qword ptr [rcx + 8]                       
    test    r8, r8                                        ⟪╋⟫    test    r10, r10                                      
    je    .LBB0_15                                        ⟪╋⟫    je    .LBB0_11                                        
# %bb.1:                                # %L13.preheader  ⟪╋⟫# %bb.1:                                # %L12.lr.ph      
    mov    r15, qword ptr [r13]                           ⟪╋⟫    mov    r8, qword ptr [r8]                             
    mov    r11, qword ptr [r13 + 8]                       ⟪╋⟫    mov    r9, qword ptr [r9]                             
    mov    r10, qword ptr [r9]                            ⟪╋⟫    mov    r11, qword ptr [rcx]                           
    mov    r14, qword ptr [r9 + 8]                        ⟪┫                                                           
    mov    qword ptr [rbp - 120], rcx      # 8-byte Spill ⟪┫                                                           
    mov    rbx, qword ptr [rcx]                           ⟪┫                                                           
    cmp    r11, r8                                        ⟪╋⟫    cmp    r10, 16                                        
    mov    rax, r8                                        ⟪┫                                                           
    cmovb    rax, r11                                     ⟪┫                                                           
    mov    rsi, r14                                       ⟪┫                                                           
    sar    rsi, 63                                        ⟪┫                                                           
    and    rsi, r14                                       ⟪┫                                                           
    mov    rdi, r14                                       ⟪┫                                                           
    sub    rdi, rsi                                       ⟪┫                                                           
    test    rsi, rsi                                      ⟪┫                                                           
    mov    r12, -1                                        ⟪┫                                                           
    cmovns    r12, rsi                                    ⟪┫                                                           
    inc    r12                                            ⟪┫                                                           
    imul    r12, rdi                                      ⟪┫                                                           
    cmp    rax, r12                                       ⟪┫                                                           
    cmovb    r12, rax                                     ⟪┫                                                           
    cmp    r12, r8                                        ⟪┫                                                           
    cmovae    r12, r8                                     ⟪┫                                                           
    mov    edi, 1                                         ⟪┫                                                           
    test    r12, r12                                      ⟪┫                                                           
    je    .LBB0_2                                         ⟪╋⟫    jae    .LBB0_3                                        
# %bb.3:                                # %idxend21.prehe…⟪┫                                                           
    cmp    r12, 16                                        ⟪┫                                                           
    jae    .LBB0_4                                        ⟪┫                                                           
.LBB0_6:                                # %scalar.ph      ⟪┫                                                           
    dec    rdi                                            ⟪┫                                                           
    mov    rax, rdi                                       ⟪┫                                                           
    .p2align    4, 0x90                                   ⟪┫                                                           
.LBB0_7:                                # %idxend21       ⟪┫                                                           
                                        # =>This Inner Lo…⟪┫                                                           
    mov    rcx, qword ptr [r15 + 8*rax]                   ⟪┫                                                           
    imul    rcx, rdx                                      ⟪┫                                                           
    add    rcx, qword ptr [r10 + 8*rax]                   ⟪┫                                                           
    mov    qword ptr [rbx + 8*rax], rcx                   ⟪┫                                                           
    inc    rax                                            ⟪┫                                                           
    cmp    rax, r12                                       ⟪┫                                                           
    jb    .LBB0_7                                         ⟪┫                                                           
# %bb.8:                                # %main.exit.sele…⟪┫                                                           
    lea    rdi, [rax + 1]                                 ⟪┫                                                           
.LBB0_9:                                # %main.exit.sele…⟪┫                                                           
    cmp    rax, r8                                        ⟪┫                                                           
    mov    rcx, qword ptr [rbp - 120]      # 8-byte Reloa…⟪┫                                                           
    jae    .LBB0_15                                       ⟪┫                                                           
                                                           ┣⟫# %bb.2:                                                  
                                                           ┣⟫    xor    eax, eax                                       
    jmp    .LBB0_10                                        ┃     jmp    .LBB0_10                                       
.LBB0_2:                                                  ⟪┫                                                           
    mov    rcx, qword ptr [rbp - 120]      # 8-byte Reloa…⟪┫                                                           
.LBB0_10:                               # %main.pseudo.ex…⟪╋⟫.LBB0_3:                                # %vector.ph      
    lea    rax, [r8 + 1]                                  ⟪┫                                                           
    .p2align    4, 0x90                                   ⟪┫                                                           
.LBB0_11:                               # %L13.postloop   ⟪┫                                                           
                                        # =>This Inner Lo…⟪┫                                                           
    lea    rsi, [rdi - 1]                                 ⟪┫                                                           
    cmp    rsi, r11                                       ⟪┫                                                           
    jae    .LBB0_25                                       ⟪┫                                                           
# %bb.12:                               # %idxend.postloo…⟪┫                                                           
                                        #   in Loop: Head…⟪┫                                                           
    cmp    rsi, r14                                       ⟪┫                                                           
    jae    .LBB0_26                                       ⟪┫                                                           
# %bb.13:                               # %idxend12.postl…⟪┫                                                           
                                        #   in Loop: Head…⟪┫                                                           
    cmp    rsi, r8                                        ⟪┫                                                           
    jae    .LBB0_27                                       ⟪┫                                                           
# %bb.14:                               # %idxend21.postl…⟪┫                                                           
                                        #   in Loop: Head…⟪┫                                                           
    mov    rsi, qword ptr [r15 + 8*rdi - 8]               ⟪┫                                                           
    imul    rsi, rdx                                      ⟪┫                                                           
    add    rsi, qword ptr [r10 + 8*rdi - 8]               ⟪┫                                                           
    mov    qword ptr [rbx + 8*rdi - 8], rsi               ⟪┫                                                           
    inc    rdi                                            ⟪┫                                                           
    cmp    rax, rdi                                       ⟪┫                                                           
    jne    .LBB0_11                                       ⟪┫                                                           
.LBB0_15:                               # %L31            ⟪┫                                                           
    vmovaps    xmm6, xmmword ptr [rbp - 96]    # 16-byte …⟪┫                                                           
    vmovaps    xmm7, xmmword ptr [rbp - 80]    # 16-byte …⟪┫                                                           
    lea    rsp, [rbp - 56]                                ⟪┫                                                           
    pop    rbx                                            ⟪┫                                                           
    pop    rdi                                            ⟪┫                                                           
    pop    rsi                                            ⟪┫                                                           
    pop    r12                                            ⟪┫                                                           
    pop    r13                                            ⟪┫                                                           
    pop    r14                                            ⟪┫                                                           
    pop    r15                                            ⟪┫                                                           
    pop    rbp                                            ⟪┫                                                           
    vzeroupper                                            ⟪┫                                                           
    ret                                                   ⟪┫                                                           
.LBB0_4:                                # %vector.memchec…⟪┫                                                           
    mov    qword ptr [rbp - 104], r13      # 8-byte Spill ⟪┫                                                           
    mov    qword ptr [rbp - 112], r9       # 8-byte Spill ⟪┫                                                           
    lea    rsi, [rbx + 8*r12]                             ⟪┫                                                           
    lea    rax, [r15 + 8*r12]                             ⟪┫                                                           
    lea    r13, [r10 + 8*r12]                             ⟪┫                                                           
    cmp    rbx, rax                                       ⟪┫                                                           
    setb    r9b                                           ⟪┫                                                           
    cmp    r15, rsi                                       ⟪┫                                                           
    setb    cl                                            ⟪┫                                                           
    cmp    rbx, r13                                       ⟪┫                                                           
    setb    al                                            ⟪┫                                                           
    cmp    r10, rsi                                       ⟪┫                                                           
    setb    sil                                           ⟪┫                                                           
    test    r9b, cl                                       ⟪┫                                                           
    jne    .LBB0_5                                        ⟪┫                                                           
# %bb.16:                               # %vector.memchec…⟪┫                                                           
    and    al, sil                                        ⟪┫                                                           
    mov    r9, qword ptr [rbp - 112]       # 8-byte Reloa…⟪┫                                                           
    mov    r13, qword ptr [rbp - 104]      # 8-byte Reloa…⟪┫                                                           
    jne    .LBB0_6                                        ⟪┫                                                           
# %bb.17:                               # %vector.ph      ⟪┫                                                           
    movabs    rsi, 9223372036854775792                    ⟪┫                                                           
    and    rsi, r12                                       ⟪┫                                                           
                                                           ┣⟫    mov    rax, r10                                       
                                                           ┣⟫    and    rax, -16                                       
    vmovq    xmm0, rdx                                     ┃     vmovq    xmm0, rdx                                    
    vpbroadcastq    ymm0, xmm0                             ┃     vpbroadcastq    ymm0, xmm0                            
    lea    rcx, [rsi - 16]                                ⟪╋⟫    lea    rcx, [rax - 16]                                
    mov    rax, rcx                                       ⟪╋⟫    mov    rsi, rcx                                       
    shr    rax, 4                                         ⟪╋⟫    shr    rsi, 4                                         
    inc    rax                                            ⟪╋⟫    inc    rsi                                            
    vpsrlq    ymm1, ymm0, 32                               ┃     vpsrlq    ymm1, ymm0, 32                              
    test    rcx, rcx                                       ┃     test    rcx, rcx                                      
    je    .LBB0_18                                        ⟪╋⟫    je    .LBB0_4                                         
# %bb.19:                               # %vector.ph.new  ⟪╋⟫# %bb.5:                                # %vector.ph.new  
    mov    r13, rax                                       ⟪┫                                                           
    and    r13, -2                                        ⟪╋⟫    and    rdi, -2                                        
    xor    edi, edi                                       ⟪┫                                                           
                                                           ┣⟫    mov    rdi, rsi                                       
                                                           ┣⟫    xor    ecx, ecx                                       
    .p2align    4, 0x90                                    ┃     .p2align    4, 0x90                                   
.LBB0_20:                               # %vector.body    ⟪╋⟫.LBB0_6:                                # %vector.body    
                                        # =>This Inner Lo… ┃                                         # =>This Inner Lo…
    vmovdqu    ymm2, ymmword ptr [r15 + 8*rdi]            ⟪╋⟫    vmovdqu    ymm2, ymmword ptr [r8 + 8*rcx]             
    vmovdqu    ymm3, ymmword ptr [r15 + 8*rdi + 32]       ⟪╋⟫    vmovdqu    ymm3, ymmword ptr [r8 + 8*rcx + 32]        
    vmovdqu    ymm4, ymmword ptr [r15 + 8*rdi + 64]       ⟪╋⟫    vmovdqu    ymm4, ymmword ptr [r8 + 8*rcx + 64]        
    vmovdqu    ymm5, ymmword ptr [r15 + 8*rdi + 96]       ⟪╋⟫    vmovdqu    ymm5, ymmword ptr [r8 + 8*rcx + 96]        
    vpmuludq    ymm6, ymm2, ymm1                           ┃     vpmuludq    ymm6, ymm2, ymm1                          
    vpsrlq    ymm7, ymm2, 32                               ┃     vpsrlq    ymm7, ymm2, 32                              
    vpmuludq    ymm7, ymm7, ymm0                           ┃     vpmuludq    ymm7, ymm7, ymm0                          
    vpaddq    ymm6, ymm6, ymm7                             ┃     vpaddq    ymm6, ymm6, ymm7                            
    vpsllq    ymm6, ymm6, 32                               ┃     vpsllq    ymm6, ymm6, 32                              
    vpmuludq    ymm2, ymm2, ymm0                           ┃     vpmuludq    ymm2, ymm2, ymm0                          
    vpaddq    ymm2, ymm2, ymm6                             ┃     vpaddq    ymm2, ymm2, ymm6                            
    vpmuludq    ymm6, ymm3, ymm1                           ┃     vpmuludq    ymm6, ymm3, ymm1                          
    vpsrlq    ymm7, ymm3, 32                               ┃     vpsrlq    ymm7, ymm3, 32                              
    vpmuludq    ymm7, ymm7, ymm0                           ┃     vpmuludq    ymm7, ymm7, ymm0                          
    vpaddq    ymm6, ymm6, ymm7                             ┃     vpaddq    ymm6, ymm6, ymm7                            
    vpsllq    ymm6, ymm6, 32                               ┃     vpsllq    ymm6, ymm6, 32                              
    vpmuludq    ymm3, ymm3, ymm0                           ┃     vpmuludq    ymm3, ymm3, ymm0                          
    vpaddq    ymm3, ymm3, ymm6                             ┃     vpaddq    ymm3, ymm3, ymm6                            
    vpmuludq    ymm6, ymm4, ymm1                           ┃     vpmuludq    ymm6, ymm4, ymm1                          
    vpsrlq    ymm7, ymm4, 32                               ┃     vpsrlq    ymm7, ymm4, 32                              
    vpmuludq    ymm7, ymm7, ymm0                           ┃     vpmuludq    ymm7, ymm7, ymm0                          
    vpaddq    ymm6, ymm6, ymm7                             ┃     vpaddq    ymm6, ymm6, ymm7                            
    vpsllq    ymm6, ymm6, 32                               ┃     vpsllq    ymm6, ymm6, 32                              
    vpmuludq    ymm4, ymm4, ymm0                           ┃     vpmuludq    ymm4, ymm4, ymm0                          
    vpaddq    ymm4, ymm4, ymm6                             ┃     vpaddq    ymm4, ymm4, ymm6                            
    vpmuludq    ymm6, ymm5, ymm1                           ┃     vpmuludq    ymm6, ymm5, ymm1                          
    vpsrlq    ymm7, ymm5, 32                               ┃     vpsrlq    ymm7, ymm5, 32                              
    vpmuludq    ymm7, ymm7, ymm0                           ┃     vpmuludq    ymm7, ymm7, ymm0                          
    vpaddq    ymm6, ymm6, ymm7                             ┃     vpaddq    ymm6, ymm6, ymm7                            
    vpsllq    ymm6, ymm6, 32                               ┃     vpsllq    ymm6, ymm6, 32                              
    vpmuludq    ymm5, ymm5, ymm0                           ┃     vpmuludq    ymm5, ymm5, ymm0                          
    vpaddq    ymm5, ymm5, ymm6                             ┃     vpaddq    ymm5, ymm5, ymm6                            
    vpaddq    ymm2, ymm2, ymmword ptr [r10 + 8*rdi]       ⟪╋⟫    vpaddq    ymm2, ymm2, ymmword ptr [r9 + 8*rcx]        
    vpaddq    ymm3, ymm3, ymmword ptr [r10 + 8*rdi + 32]  ⟪╋⟫    vpaddq    ymm3, ymm3, ymmword ptr [r9 + 8*rcx + 32]   
    vpaddq    ymm4, ymm4, ymmword ptr [r10 + 8*rdi + 64]  ⟪╋⟫    vpaddq    ymm4, ymm4, ymmword ptr [r9 + 8*rcx + 64]   
    vpaddq    ymm5, ymm5, ymmword ptr [r10 + 8*rdi + 96]  ⟪╋⟫    vpaddq    ymm5, ymm5, ymmword ptr [r9 + 8*rcx + 96]   
    vmovdqu    ymmword ptr [rbx + 8*rdi], ymm2            ⟪╋⟫    vmovdqu    ymmword ptr [r11 + 8*rcx], ymm2            
    vmovdqu    ymmword ptr [rbx + 8*rdi + 32], ymm3       ⟪╋⟫    vmovdqu    ymmword ptr [r11 + 8*rcx + 32], ymm3       
    vmovdqu    ymmword ptr [rbx + 8*rdi + 64], ymm4       ⟪╋⟫    vmovdqu    ymmword ptr [r11 + 8*rcx + 64], ymm4       
    vmovdqu    ymmword ptr [rbx + 8*rdi + 96], ymm5       ⟪╋⟫    vmovdqu    ymmword ptr [r11 + 8*rcx + 96], ymm5       
    vmovdqu    ymm2, ymmword ptr [r15 + 8*rdi + 128]      ⟪╋⟫    vmovdqu    ymm2, ymmword ptr [r8 + 8*rcx + 128]       
    vmovdqu    ymm3, ymmword ptr [r15 + 8*rdi + 160]      ⟪╋⟫    vmovdqu    ymm3, ymmword ptr [r8 + 8*rcx + 160]       
    vmovdqu    ymm4, ymmword ptr [r15 + 8*rdi + 192]      ⟪╋⟫    vmovdqu    ymm4, ymmword ptr [r8 + 8*rcx + 192]       
    vmovdqu    ymm5, ymmword ptr [r15 + 8*rdi + 224]      ⟪╋⟫    vmovdqu    ymm5, ymmword ptr [r8 + 8*rcx + 224]       
    vpmuludq    ymm6, ymm2, ymm1                           ┃     vpmuludq    ymm6, ymm2, ymm1                          
    vpsrlq    ymm7, ymm2, 32                               ┃     vpsrlq    ymm7, ymm2, 32                              
    vpmuludq    ymm7, ymm7, ymm0                           ┃     vpmuludq    ymm7, ymm7, ymm0                          
    vpaddq    ymm6, ymm6, ymm7                             ┃     vpaddq    ymm6, ymm6, ymm7                            
    vpsllq    ymm6, ymm6, 32                               ┃     vpsllq    ymm6, ymm6, 32                              
    vpmuludq    ymm2, ymm2, ymm0                           ┃     vpmuludq    ymm2, ymm2, ymm0                          
    vpaddq    ymm2, ymm2, ymm6                             ┃     vpaddq    ymm2, ymm2, ymm6                            
    vpmuludq    ymm6, ymm3, ymm1                           ┃     vpmuludq    ymm6, ymm3, ymm1                          
    vpsrlq    ymm7, ymm3, 32                               ┃     vpsrlq    ymm7, ymm3, 32                              
    vpmuludq    ymm7, ymm7, ymm0                           ┃     vpmuludq    ymm7, ymm7, ymm0                          
    vpaddq    ymm6, ymm6, ymm7                             ┃     vpaddq    ymm6, ymm6, ymm7                            
    vpsllq    ymm6, ymm6, 32                               ┃     vpsllq    ymm6, ymm6, 32                              
    vpmuludq    ymm3, ymm3, ymm0                           ┃     vpmuludq    ymm3, ymm3, ymm0                          
    vpaddq    ymm3, ymm3, ymm6                             ┃     vpaddq    ymm3, ymm3, ymm6                            
    vpmuludq    ymm6, ymm4, ymm1                           ┃     vpmuludq    ymm6, ymm4, ymm1                          
    vpsrlq    ymm7, ymm4, 32                               ┃     vpsrlq    ymm7, ymm4, 32                              
    vpmuludq    ymm7, ymm7, ymm0                           ┃     vpmuludq    ymm7, ymm7, ymm0                          
    vpaddq    ymm6, ymm6, ymm7                             ┃     vpaddq    ymm6, ymm6, ymm7                            
    vpsllq    ymm6, ymm6, 32                               ┃     vpsllq    ymm6, ymm6, 32                              
    vpmuludq    ymm4, ymm4, ymm0                           ┃     vpmuludq    ymm4, ymm4, ymm0                          
    vpaddq    ymm4, ymm4, ymm6                             ┃     vpaddq    ymm4, ymm4, ymm6                            
    vpmuludq    ymm6, ymm5, ymm1                           ┃     vpmuludq    ymm6, ymm5, ymm1                          
    vpsrlq    ymm7, ymm5, 32                               ┃     vpsrlq    ymm7, ymm5, 32                              
    vpmuludq    ymm7, ymm7, ymm0                           ┃     vpmuludq    ymm7, ymm7, ymm0                          
    vpaddq    ymm6, ymm6, ymm7                             ┃     vpaddq    ymm6, ymm6, ymm7                            
    vpsllq    ymm6, ymm6, 32                               ┃     vpsllq    ymm6, ymm6, 32                              
    vpmuludq    ymm5, ymm5, ymm0                           ┃     vpmuludq    ymm5, ymm5, ymm0                          
    vpaddq    ymm5, ymm5, ymm6                             ┃     vpaddq    ymm5, ymm5, ymm6                            
    vpaddq    ymm2, ymm2, ymmword ptr [r10 + 8*rdi + 128] ⟪╋⟫    vpaddq    ymm2, ymm2, ymmword ptr [r9 + 8*rcx + 128]  
    vpaddq    ymm3, ymm3, ymmword ptr [r10 + 8*rdi + 160] ⟪╋⟫    vpaddq    ymm3, ymm3, ymmword ptr [r9 + 8*rcx + 160]  
    vpaddq    ymm4, ymm4, ymmword ptr [r10 + 8*rdi + 192] ⟪╋⟫    vpaddq    ymm4, ymm4, ymmword ptr [r9 + 8*rcx + 192]  
    vpaddq    ymm5, ymm5, ymmword ptr [r10 + 8*rdi + 224] ⟪╋⟫    vpaddq    ymm5, ymm5, ymmword ptr [r9 + 8*rcx + 224]  
    vmovdqu    ymmword ptr [rbx + 8*rdi + 128], ymm2      ⟪╋⟫    vmovdqu    ymmword ptr [r11 + 8*rcx + 128], ymm2      
    vmovdqu    ymmword ptr [rbx + 8*rdi + 160], ymm3      ⟪╋⟫    vmovdqu    ymmword ptr [r11 + 8*rcx + 160], ymm3      
    vmovdqu    ymmword ptr [rbx + 8*rdi + 192], ymm4      ⟪╋⟫    vmovdqu    ymmword ptr [r11 + 8*rcx + 192], ymm4      
    vmovdqu    ymmword ptr [rbx + 8*rdi + 224], ymm5      ⟪╋⟫    vmovdqu    ymmword ptr [r11 + 8*rcx + 224], ymm5      
    add    rdi, 32                                        ⟪╋⟫    add    rcx, 32                                        
    add    r13, -2                                        ⟪╋⟫    add    rdi, -2                                        
    jne    .LBB0_20                                       ⟪╋⟫    jne    .LBB0_6                                        
    jmp    .LBB0_21                                       ⟪┫                                                           
.LBB0_5:                                                  ⟪┫                                                           
    mov    r9, qword ptr [rbp - 112]       # 8-byte Reloa…⟪┫                                                           
    mov    r13, qword ptr [rbp - 104]      # 8-byte Reloa…⟪┫                                                           
    jmp    .LBB0_6                                        ⟪┫                                                           
.LBB0_18:                                                 ⟪┫                                                           
    xor    edi, edi                                       ⟪┫                                                           
.LBB0_21:                               # %middle.block.u…⟪╋⟫# %bb.7:                                # %middle.block.u…
    test    al, 1                                         ⟪╋⟫    test    sil, 1                                        
    mov    r13, qword ptr [rbp - 104]      # 8-byte Reloa…⟪┫                                                           
    je    .LBB0_23                                        ⟪╋⟫    je    .LBB0_9                                         
# %bb.22:                               # %vector.body.ep…⟪╋⟫.LBB0_8:                                # %vector.body.ep…
    vmovdqu    ymm2, ymmword ptr [r15 + 8*rdi]            ⟪╋⟫    vmovdqu    ymm2, ymmword ptr [r8 + 8*rcx]             
    vmovdqu    ymm3, ymmword ptr [r15 + 8*rdi + 32]       ⟪╋⟫    vmovdqu    ymm3, ymmword ptr [r8 + 8*rcx + 32]        
    vmovdqu    ymm4, ymmword ptr [r15 + 8*rdi + 64]       ⟪╋⟫    vmovdqu    ymm4, ymmword ptr [r8 + 8*rcx + 64]        
    vmovdqu    ymm5, ymmword ptr [r15 + 8*rdi + 96]       ⟪╋⟫    vmovdqu    ymm5, ymmword ptr [r8 + 8*rcx + 96]        
    vpmuludq    ymm6, ymm2, ymm1                           ┃     vpmuludq    ymm6, ymm2, ymm1                          
    vpsrlq    ymm7, ymm2, 32                               ┃     vpsrlq    ymm7, ymm2, 32                              
    vpmuludq    ymm7, ymm7, ymm0                           ┃     vpmuludq    ymm7, ymm7, ymm0                          
    vpaddq    ymm6, ymm6, ymm7                             ┃     vpaddq    ymm6, ymm6, ymm7                            
    vpsllq    ymm6, ymm6, 32                               ┃     vpsllq    ymm6, ymm6, 32                              
    vpmuludq    ymm2, ymm2, ymm0                           ┃     vpmuludq    ymm2, ymm2, ymm0                          
    vpaddq    ymm2, ymm2, ymm6                             ┃     vpaddq    ymm2, ymm2, ymm6                            
    vpmuludq    ymm6, ymm3, ymm1                           ┃     vpmuludq    ymm6, ymm3, ymm1                          
    vpsrlq    ymm7, ymm3, 32                               ┃     vpsrlq    ymm7, ymm3, 32                              
    vpmuludq    ymm7, ymm7, ymm0                           ┃     vpmuludq    ymm7, ymm7, ymm0                          
    vpaddq    ymm6, ymm6, ymm7                             ┃     vpaddq    ymm6, ymm6, ymm7                            
    vpsllq    ymm6, ymm6, 32                               ┃     vpsllq    ymm6, ymm6, 32                              
    vpmuludq    ymm3, ymm3, ymm0                           ┃     vpmuludq    ymm3, ymm3, ymm0                          
    vpaddq    ymm3, ymm3, ymm6                             ┃     vpaddq    ymm3, ymm3, ymm6                            
    vpmuludq    ymm6, ymm4, ymm1                           ┃     vpmuludq    ymm6, ymm4, ymm1                          
    vpsrlq    ymm7, ymm4, 32                               ┃     vpsrlq    ymm7, ymm4, 32                              
    vpmuludq    ymm7, ymm7, ymm0                           ┃     vpmuludq    ymm7, ymm7, ymm0                          
    vpaddq    ymm6, ymm6, ymm7                             ┃     vpaddq    ymm6, ymm6, ymm7                            
    vpsllq    ymm6, ymm6, 32                               ┃     vpsllq    ymm6, ymm6, 32                              
    vpmuludq    ymm4, ymm4, ymm0                           ┃     vpmuludq    ymm4, ymm4, ymm0                          
    vpaddq    ymm4, ymm4, ymm6                             ┃     vpaddq    ymm4, ymm4, ymm6                            
    vpmuludq    ymm1, ymm5, ymm1                           ┃     vpmuludq    ymm1, ymm5, ymm1                          
    vpsrlq    ymm6, ymm5, 32                               ┃     vpsrlq    ymm6, ymm5, 32                              
    vpmuludq    ymm6, ymm6, ymm0                           ┃     vpmuludq    ymm6, ymm6, ymm0                          
    vpaddq    ymm1, ymm1, ymm6                             ┃     vpaddq    ymm1, ymm1, ymm6                            
    vpsllq    ymm1, ymm1, 32                               ┃     vpsllq    ymm1, ymm1, 32                              
    vpmuludq    ymm0, ymm5, ymm0                           ┃     vpmuludq    ymm0, ymm5, ymm0                          
    vpaddq    ymm0, ymm0, ymm1                             ┃     vpaddq    ymm0, ymm0, ymm1                            
    vpaddq    ymm1, ymm2, ymmword ptr [r10 + 8*rdi]       ⟪╋⟫    vpaddq    ymm1, ymm2, ymmword ptr [r9 + 8*rcx]        
    vpaddq    ymm2, ymm3, ymmword ptr [r10 + 8*rdi + 32]  ⟪╋⟫    vpaddq    ymm2, ymm3, ymmword ptr [r9 + 8*rcx + 32]   
    vpaddq    ymm3, ymm4, ymmword ptr [r10 + 8*rdi + 64]  ⟪╋⟫    vpaddq    ymm3, ymm4, ymmword ptr [r9 + 8*rcx + 64]   
    vpaddq    ymm0, ymm0, ymmword ptr [r10 + 8*rdi + 96]  ⟪╋⟫    vpaddq    ymm0, ymm0, ymmword ptr [r9 + 8*rcx + 96]   
    vmovdqu    ymmword ptr [rbx + 8*rdi], ymm1            ⟪╋⟫    vmovdqu    ymmword ptr [r11 + 8*rcx], ymm1            
    vmovdqu    ymmword ptr [rbx + 8*rdi + 32], ymm2       ⟪╋⟫    vmovdqu    ymmword ptr [r11 + 8*rcx + 32], ymm2       
    vmovdqu    ymmword ptr [rbx + 8*rdi + 64], ymm3       ⟪╋⟫    vmovdqu    ymmword ptr [r11 + 8*rcx + 64], ymm3       
    vmovdqu    ymmword ptr [rbx + 8*rdi + 96], ymm0       ⟪╋⟫    vmovdqu    ymmword ptr [r11 + 8*rcx + 96], ymm0       
.LBB0_23:                               # %middle.block   ⟪╋⟫.LBB0_9:                                # %middle.block   
    lea    rdi, [rsi + 1]                                 ⟪┫                                                           
    cmp    r12, rsi                                       ⟪╋⟫    cmp    r10, rax                                       
    jne    .LBB0_6                                        ⟪╋⟫    je    .LBB0_11                                        
# %bb.24:                                                 ⟪┫                                                           
    mov    rax, r12                                       ⟪┫                                                           
    jmp    .LBB0_9                                        ⟪┫                                                           
.LBB0_25:                               # %oob            ⟪╋⟫.LBB0_10:                               # %L12            
    mov    eax, 16                                        ⟪┫                                                           
    movabs    r11, offset ___chkstk_ms                    ⟪┫                                                           
    call    r11                                           ⟪┫                                                           
    sub    rsp, rax                                       ⟪┫                                                           
    mov    rdx, rsp                                       ⟪┫                                                           
    mov    qword ptr [rdx], rdi                           ⟪┫                                                           
    sub    rsp, 32                                        ⟪┫                                                           
    movabs    rax, offset ijl_bounds_error_ints           ⟪┫                                                           
    mov    r8d, 1                                         ⟪┫                                                           
    mov    rcx, r13                                       ⟪┫                                                           
    vzeroupper                                            ⟪┫                                                           
    call    rax                                           ⟪┫                                                           
.LBB0_26:                               # %oob10          ⟪╋⟫.LBB0_11:                               # %L32            
    mov    eax, 16                                        ⟪┫                                                           
    movabs    r11, offset ___chkstk_ms                    ⟪┫                                                           
    call    r11                                           ⟪┫                                                           
    sub    rsp, rax                                       ⟪┫                                                           
    mov    rdx, rsp                                       ⟪┫                                                           
    mov    qword ptr [rdx], rdi                           ⟪┫                                                           
    sub    rsp, 32                                        ⟪╋⟫    add    rsp, 32                                        
    movabs    rax, offset ijl_bounds_error_ints           ⟪┫                                                           
    mov    r8d, 1                                         ⟪┫                                                           
    mov    rcx, r9                                        ⟪┫                                                           
    vzeroupper                                            ⟪┫                                                           
    call    rax                                           ⟪┫                                                           
.LBB0_27:                               # %oob19          ⟪┫                                                           
    mov    eax, 16                                        ⟪┫                                                           
    movabs    r11, offset ___chkstk_ms                    ⟪┫                                                           
    call    r11                                           ⟪┫                                                           
    sub    rsp, rax                                       ⟪┫                                                           
    mov    rdx, rsp                                       ⟪┫                                                           
    mov    qword ptr [rdx], rdi                           ⟪┫                                                           
    sub    rsp, 32                                        ⟪┫                                                           
    movabs    rax, offset ijl_bounds_error_ints           ⟪┫                                                           
    mov    r8d, 1                                         ⟪┫                                                           
                                                           ┣⟫    .p2align    4, 0x90                                   
                                                           ┣⟫                                        # =>This Inner Lo…
                                                           ┣⟫    mov    rcx, qword ptr [r8 + 8*rax]                    
                                                           ┣⟫    imul    rcx, rdx                                      
                                                           ┣⟫    add    rcx, qword ptr [r9 + 8*rax]                    
                                                           ┣⟫    mov    qword ptr [r11 + 8*rax], rcx                   
                                                           ┣⟫    inc    rax                                            
                                                           ┣⟫    cmp    r10, rax                                       
                                                           ┣⟫    jne    .LBB0_10                                       
                                                           ┣⟫    vmovaps    xmm6, xmmword ptr [rbp - 48]    # 16-byte …
                                                           ┣⟫    vmovaps    xmm7, xmmword ptr [rbp - 32]    # 16-byte …
                                                           ┣⟫    pop    rdi                                            
                                                           ┣⟫    pop    rsi                                            
                                                           ┣⟫    pop    rbp                                            
    vzeroupper                                             ┃     vzeroupper                                            
    call    rax                                           ⟪┫                                                           
                                                           ┣⟫    ret                                                   
                                                           ┣⟫.LBB0_4:                                                  
                                                           ┣⟫    xor    ecx, ecx                                       
                                                           ┣⟫    test    sil, 1                                        
                                                           ┣⟫    je    .LBB0_9                                         
                                                           ┣⟫    jmp    .LBB0_8                                        
.Lfunc_end0:                                               ┃ .Lfunc_end0:                                              
    .size    saxpy, .Lfunc_end0-saxpy                     ⟪╋⟫    .size    saxpy_simd, .Lfunc_end0-saxpy_simd           
    .cfi_endproc                                           ┃     .cfi_endproc                                          
                                        # -- End function  ┃                                         # -- End function 
    .section    ".note.GNU-stack","",@progbits             ┃     .section    ".note.GNU-stack","",@progbits            
                                                           ┃                                                           