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

include("julia_names.jl")
include("typed_ir.jl")
include("llvm_ir.jl")
include("native.jl")
include("ptx.jl")
include("gcn.jl")
include("agx.jl")
include("spirv.jl")

end
