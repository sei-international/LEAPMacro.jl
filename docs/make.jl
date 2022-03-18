push!(LOAD_PATH,"../src/")
using Documenter, LEAPMacro

makedocs(
    sitename = "LEAP-Macro",
    format = Documenter.HTML(),
    pages = [
        "Introduction" => "index.md"
    ],
)
