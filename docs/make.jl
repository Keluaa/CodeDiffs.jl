using CodeDifferences
using Documenter

DocMeta.setdocmeta!(CodeDifferences, :DocTestSetup, :(using CodeDifferences); recursive=true)

makedocs(;
    modules=[CodeDifferences],
    authors="Luc Briand <34173752+Keluaa@users.noreply.github.com> and contributors",
    sitename="CodeDifferences.jl",
    format=Documenter.HTML(;
        canonical="https://Keluaa.github.io/CodeDifferences.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/Keluaa/CodeDifferences.jl",
    devbranch="main",
)
