    .text                                                  ┃     .text                                                 
    .file    "f"                                           ┃     .file    "f"                                          
    .globl    f                    # -- Begin function f   ┃     .globl    f                    # -- Begin function f  
    .p2align    4, 0x90                                    ┃     .p2align    4, 0x90                                   
    .type    f,@function                                   ┃     .type    f,@function                                  
f:                           # @f                          ┃ f:                           # @f                         
    .cfi_startproc                                         ┃     .cfi_startproc                                        
# %bb.0:                                # %top             ┃ # %bb.0:                                # %top            
    push    rbp                                            ┃     push    rbp                                           
    .cfi_def_cfa_offset 16                                 ┃     .cfi_def_cfa_offset 16                                
    .cfi_offset rbp, -16                                   ┃     .cfi_offset rbp, -16                                  
    mov    rbp, rsp                                        ┃     mov    rbp, rsp                                       
    .cfi_def_cfa_register rbp                              ┃     .cfi_def_cfa_register rbp                             
    mov    eax, 1                                          ┃     mov    eax, 1                                         
    pop    rbp                                             ┃     pop    rbp                                            
    ret                                                    ┃     ret                                                   
.Lfunc_end0:                                               ┃ .Lfunc_end0:                                              
    .size    f, .Lfunc_end0-f                              ┃     .size    f, .Lfunc_end0-f                             
    .cfi_endproc                                           ┃     .cfi_endproc                                          
                                        # -- End function  ┃                                         # -- End function 
    .section    ".note.GNU-stack","",@progbits             ┃     .section    ".note.GNU-stack","",@progbits            
                                                           ┃                                                           