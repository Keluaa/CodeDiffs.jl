module CodeDiffs

# TODO: option to ignore differences in code comments (such as when comparing methods in different worlds)
# TODO: add `using CodeTracking: definition`, then do like `Cthuhlu.jl` to retrive the function def from its call: https://github.com/JuliaDebug/Cthulhu.jl/blob/9ba8bfc53efed453cb150c9f3e4c279521c5cb17/src/codeview.jl#L54C9-L54C33
# TODO: GPU assembly / LLVM IR support
# TODO: explain in the docs how to interface with this package

using DeepDiffs
using InteractiveUtils
using MacroTools
using Markdown
using StringDistances
using WidthLimitedIO

const USE_STYLED_STRINGS = VERSION ≥ v"1.11-"
@static USE_STYLED_STRINGS && using JuliaSyntaxHighlighting

export @code_diff

const ANSI_REGEX = r"(?>\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~]))+"
const OhMYREPL_PKG_ID = Base.PkgId(Base.UUID("5fb14364-9ced-5910-84b2-373655c76a03"), "OhMyREPL")

include("CodeDiff.jl")
include("compare.jl")
include("display.jl")

end
