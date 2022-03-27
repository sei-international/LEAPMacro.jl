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
            "Demand-led growth" => "demand-led-growth.md"
            "Uses and limitations" => "uses-limitations.md"
        ]
        "Model detail" => [
            "Variables" => "variables.md"
            "Linear goal program" => "lgp.md"
            "Dynamics" => "dynamics.md"
        ]
        "Building a model" => [
            "Preparing supply-use tables" => "prep-sut.md"
            "Preparing exogenous parameters" => "prep-params.md"
            "Preparing the configuration file" => "prep-config.md"
            "Calibrating the model" => "calib.md"
            "Troubleshooting" => "troubleshoot.md"
            "Linking to LEAP" => "link-to-leap.md"
        ]
    ]
)

deploydocs(
    repo = "github.com/sei-international/LEAPMacro.git"
)
