
cleanup_code(::Val{:llvm}, c, dbinfo, cleanup_opts) = replace_llvm_module_name(c)

function cleanup_code(::Val{:gpu_llvm}, c, dbinfo, cleanup_opts)
    c = replace_llvm_module_name(c)
    c = clean_function_name(LLVM_IR_FUNC_NAME_MANGLED_REGEX, c)
    return c
end
