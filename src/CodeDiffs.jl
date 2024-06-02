module CodeDiffs

# TODO: option to ignore differences in code comments (such as when comparing methods in different worlds)
# TODO: option to display only differences, collapsing similar sections into '...' + option for number of lines of context

using CodeTracking
using DeepDiffs
using InteractiveUtils
using MacroTools
using Markdown
using StringDistances
using WidthLimitedIO

export @code_diff, code_diff, @code_for

# From https://en.wikipedia.org/wiki/ANSI_escape_code#CSI_(Control_Sequence_Introducer)_sequences
const ANSI_REGEX = r"(?>\x1B\[[0-?]*[ -/]*[@-~])+"

const OhMYREPL_PKG_ID = Base.PkgId(Base.UUID("5fb14364-9ced-5910-84b2-373655c76a03"), "OhMyREPL")
const Revise_PKG_ID = Base.PkgId(Base.UUID("295af30f-e4ad-537b-8983-00126c2a3abe"), "Revise")

include("CodeDiff.jl")
include("get_code.jl")
include("highlighting.jl")
include("cleanup.jl")
include("compare.jl")
include("display.jl")

end
