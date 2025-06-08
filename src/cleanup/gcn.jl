
# The GCN output of LLVM's AMDGPU backend has a comment with the mangled function name
const GCN_FUNC_NAME_COMMENT_REGEX = r".globl\s+"m * MANGLED_NAME_REGEX * r"\b"m


function cleanup_code(::Val{:gcn}, c, dbinfo, cleanup_opts)
    c = clean_function_name(GCN_FUNC_NAME_COMMENT_REGEX, c)

    extra_patterns = []

    if !get(cleanup_opts, :metadata, false)
        # Remove everything after the "; -- End function", as it is only metadata.
        func_end = findfirst(r"^\s*; -- End function"m, c)
        if !isnothing(func_end)
            c = c[1:first(func_end) - 1]
        end
    else
        # Remove the hundreds of '.ident "clang version ..."'  included in the metadata, as no
        # human being wants to see that. I am quite sure there is a bug somewhere which causes that...
        push!(extra_patterns, r"\t\.ident\t.+\n" => "")
    end
    if get(cleanup_opts, :demangle, true)
        push!(extra_patterns, demangle_all())
    end
    if !get(cleanup_opts, :keep_loop_comments, false)
        # Loop comments are interesting, but can be quite annoying with complex loop structures
        push!(extra_patterns, r"\R\s+;\s+(=>\s*)?(Parent|This|This Inner|Child|in) Loop[^\n]+" => "")
    end
    if !get(cleanup_opts, :keep_block_comments, false)
        # Block comments are placed after labels, or at the beginning of a line
        # They look like "some_label: ; %blabla" or "; %blabla".
        push!(extra_patterns, r"(^\.\w+:)?(?:\s*); %.+"m => s"\1")
    end
    if !get(cleanup_opts, :keep_misc_comments, false)
        # Remove "; divergent unreachable" comments and others
        push!(extra_patterns,
            r"\R\s*; divergent unreachable"m => "",
            r"\R\s*; implicit-def:.+$"m => "",
        )
    end
    if !get(cleanup_opts, :kernel_metadata, false)
        # Kernel metadata is stored within its dedicated ".amdhsa_kernel" section.
        # It is a bit large and somewhat relevant to the code, therefore we remove it by default.
        push!(extra_patterns, r"^\s*\.amdhsa_kernel.+\.end_amdhsa_kernel\R"sm => "")
    end
    if (align_operands = get(cleanup_opts, :align_operands, 12); align_operands > 0)
        # Align instruction operands such that the first operand is at the next multiple of `align_operands`.
        push!(extra_patterns, align_instruction_operand(align_operands))
    end

    c = replace(c,
        llvm_module_name_patterns()...,
        # This "begin" comment is redundant
        r"\s*; -- Begin function.+$"m => "",
        extra_patterns...,
    )
    return rstrip(c)  # remove trailing newlines
end


function align_instruction_operand(column)
    # The regex extracts the operands from "   any_instruction ops..." to the second match group.
    operand_regex = r"^\s*\w+(\h+)(.+)$"m
    min_spaces = max(4, cld(column, 4))

    function align_to_nth_column(c)
        m = match(operand_regex, c)
        isnothing(m) && return c

        mnemonic_end     = m.offsets[1]
        old_operands_pos = m.offsets[2]

        # Set a minimum of spaces between the mnemonic and the operands
        old_spaces_count = old_operands_pos - mnemonic_end
        if old_spaces_count < min_spaces
            operands_pos = old_operands_pos - old_spaces_count + min_spaces
        else
            operands_pos = old_operands_pos
        end

        new_operands_pos = cld(operands_pos, column) * column
        if old_operands_pos == new_operands_pos
            return c
        else
            extra_spaces = " "^(new_operands_pos - old_operands_pos)
            return m.match[1:mnemonic_end-1] * extra_spaces * m[2]
        end
    end

    return operand_regex => align_to_nth_column
end
