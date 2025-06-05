module Stats

import ..CodeDiffs
export extract_stats

using YAML


"""
    extract_stats(::Val{code_type}, code, stats_opts=(;))

Analyses `code` and extracts high-level information about it (instruction count, register usage,
function calls...).

`stats_opts` are passed by the user, and have specific meaning depending on the `code_type`.
"""
extract_stats(type, code) = extract_stats(type, code, (;))

include("ptx.jl")
include("gcn.jl")
include("x86.jl")
include("native.jl")

end
