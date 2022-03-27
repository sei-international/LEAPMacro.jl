using Documenter, LEAPMacro

makedocs(
    sitename = "LEAP-Macro",
    format = Documenter.HTML(),
    pages = [
        "Introduction" => "index.md"
        "Getting started" => [
            "Installation" => "installation.md"
            "Quickstart" => "quickstart.md"
        ]
        "Model overview" => [
            "LEAP-Macro link" => "leap-macro-link.md"
        ]
        "Model detail" => [
            "Variables" => "variables.md"
        ]
    ]
)

deploydocs(repo = "https://github.com/sei-international/LEAPMacro.git")
