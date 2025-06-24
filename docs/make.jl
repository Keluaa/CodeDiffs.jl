using CodeDiffs
using Documenter

DocMeta.setdocmeta!(CodeDiffs, :DocTestSetup, :(using CodeDiffs); recursive=true)

can_doctest = Sys.islinux() && Sys.ARCH === :x86_84

makedocs(;
    modules=[CodeDiffs],
    authors="Luc Briand <34173752+Keluaa@users.noreply.github.com> and contributors",
    sitename="CodeDiffs.jl",
    format=Documenter.HTML(;
        canonical="https://Keluaa.github.io/CodeDiffs.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
        "GPU Extensions" => "extensions.md",
        "API" => [
            "Main API" => "code_disp_and_diff.md",
            "Cleanup" => "cleanup.md",
            "Code stats" => "stats.md",
            "Defining a new extension" => "new_extension.md",
        ],
    ],
    doctest = can_doctest
)

deploydocs(;
    repo="github.com/Keluaa/CodeDiffs.jl",
    devbranch="main",
)
