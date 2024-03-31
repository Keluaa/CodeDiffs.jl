using CodeDiffs
using Documenter

DocMeta.setdocmeta!(CodeDiffs, :DocTestSetup, :(using CodeDiffs); recursive=true)

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
    ],
)

deploydocs(;
    repo="github.com/Keluaa/CodeDiffs.jl",
    devbranch="main",
)
