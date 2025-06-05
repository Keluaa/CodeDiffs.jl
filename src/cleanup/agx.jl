
function cleanup_code(::Val{:agx}, c, dbinfo, cleanup_opts)
    c = replace_llvm_module_name(c)
    return c
end
