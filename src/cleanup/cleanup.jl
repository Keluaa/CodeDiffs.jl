module Cleanup

using MacroTools
using demumble_jll

import ..CodeDiffs
export cleanup_code


"""
    cleanup_code(::Val{code_type}, code, dbinfo=true, cleanup_opts=(;))

Perform minor changes to `code` to improve readability and the quality of the differences.

`dbinfo` is a superset of `debuginfo`. It is compatible with all code types, but it may
have no effect.

`cleanup_opts` are passed by the user, and have specific meaning depending on the `code_type`.
"""
cleanup_code(type, code) = cleanup_code(type, code, true, (;))
cleanup_code(type, code, dbinfo) = cleanup_code(type, code, dbinfo, (;))
cleanup_code(_, c, _, _) = c  # default is no cleanup


function replace_tabs(tab_width)
    # Matches any line with at least one tab in it
    line_with_tabs = r"^.*?\t.*$"m

    function replace_all_tabs_within_line(line)
        buf = IOBuffer(; sizehint=ncodeunits(line))
        column = 0
        for char in line
            if char == '\t'
                required_spaces = tab_width - (column % tab_width)
                foreach(_ -> print(buf, ' '), 1:required_spaces)
                column += required_spaces
            else
                print(buf, char)
                column += 1
            end
        end
        return String(take!(buf))
    end

    return line_with_tabs => replace_all_tabs_within_line
end


include("julia_names.jl")
include("typed_ir.jl")
include("llvm_ir.jl")
include("native.jl")
include("ptx.jl")
include("sass.jl")
include("gcn.jl")
include("agx.jl")
include("spirv.jl")

end
