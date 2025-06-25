
# For SASS, suppose that the first `.global` declaration is the name of our function.
const SASS_FUNC_NAME_COMMENT_REGEX = r"^\s*\.global\s+"m * MANGLED_NAME_REGEX * r"\b"m


"""
    cleanup_code(::Val{:sass}, code, dbinfo, cleanup_opts)

Cleanup SASS `code`.

If `dbinfo`, then location comments are kept.

Accepted `cleanup_opts` and their default values:
 - `demangle=true`: demangle names within the code
"""
function cleanup_code(::Val{:sass}, c, dbinfo, cleanup_opts)
    # TODO: SASS problems:
    # Registers seem to be assigned randomly, changing from one call to another with the
    # same input, as well as some immediate values (maybe related to the functions order in PTX?).
    # Some instructions (only `MOV` from what I saw) might be ordered differently, or even
    # in different numbers (max of what I could see is 1, but still surprising).
    c = replace_llvm_module_name(c)
    c = clean_function_name(SASS_FUNC_NAME_COMMENT_REGEX, c)

    extra_patterns = []
    if get(cleanup_opts, :demangle, true)
        # Demangle only names which aren't the function's name
        push!(extra_patterns, demangle_all())
    end
    if !dbinfo
        push!(extra_patterns, r"; Location .+\R" => "")  # Remove location comments
    end

    c = replace(c, extra_patterns...)

    # SASS output uses 8 spaces as indent, but there is still some tabs in some places.
    return replace(c, replace_tabs(8))
end
