
# Extract the mangled name of the kernel's entry point
const SPIRV_FUNC_NAME_REGEX = r"\bOpEntryPoint\s+Kernel\s+%\d+\s+\""m * MANGLED_NAME_REGEX * r"\""m


"""
    cleanup_code(::Val{:spirv}, code, dbinfo, cleanup_opts)

Cleanup SPIRV `code`.

Accepted `cleanup_opts` and their default values:
 - `metadata=false`: keep the meta operations around the main function's body
 - `demangle=true`: demangle names within the code
"""
function cleanup_code(::Val{:spirv}, c, dbinfo, cleanup_opts)
    c = clean_function_name(SPIRV_FUNC_NAME_REGEX, c)

    if !get(cleanup_opts, :metadata, false)
        c = strip_spirv_meta_operations(c)
    end

    extra_patterns = []

    if get(cleanup_opts, :demangle, true)
        push!(extra_patterns, demangle_all())
    end

    return replace(c,
        llvm_module_name_patterns()...,
        extra_patterns...,
    )
end


function strip_spirv_meta_operations(spirv_source)
    # SPIRV is a high-level IR: functions, their arguments, instructions, etc... are all in SSA form.
    # Here we want to strip everything but the core function body.

    # Retreive the the function name from the `OpEntryPoint` declaration.
    entry_point_regex = r"\bOpEntryPoint\s+Kernel\s+%\d+\s+\"([^\s\"]+)\""
    m = match(entry_point_regex, spirv_source)
    isnothing(m) && return spirv_source
    entry_point_name = m[1]

    # Because of how the SPIRV source is generated, the our kernel function always starts at
    # "%<func_name> = OpFunction ..."
    kernel_start_regex = r"%" * entry_point_name * r" = OpFunction\b"
    kernel_start = findfirst(kernel_start_regex, spirv_source)
    isnothing(kernel_start) && return spirv_source
    kernel_start = first(kernel_start)

    # And the kernel function ends at the next occurance of "OpFunctionEnd"
    kernel_end_regex = r"OpFunctionEnd$"m
    kernel_end = findnext(kernel_end_regex, spirv_source, kernel_start)
    isnothing(kernel_end) && return spirv_source
    kernel_end = last(kernel_end)

    # Note: we could re-number the slots at this point, if needed.
    return String(spirv_source[kernel_start:kernel_end])
end
