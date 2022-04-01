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
            "Configuration file" => "config.md"
            "Output files" => "model-outputs.md"
            "About demand-led growth" => "demand-led-growth.md"
            "Limitations of the model" => "limitations.md"
        ]
        "Model detail" => [
            "Variables" => "variables.md"
            "Linear goal program" => "lgp.md"
            "Dynamics" => "dynamics.md" # TODO: dynamics
            "Isolating the energy sector" => "isolate-energy.md" # TODO: isolating energy sector
            "Processing the supply-use table" => "process-sut.md" # TODO: processing the SUT
        ]
        "Building a model" => [
            "Preparing supply-use tables" => "prep-sut.md" # TODO: prep SUT
            "Preparing exogenous parameters" => "prep-params.md" # TODO: prep params
            "Preparing the configuration file" => "prep-config.md" # TODO: prep config
            "Calibrating the model" => "calib.md" # TODO: calibration
            "Troubleshooting" => "troubleshoot.md" # TODO: troubleshooting
            "Linking to LEAP" => "link-to-leap.md" # TODO: linking to LEAP
        ]
    ]
)

deploydocs(
    repo = "github.com/sei-international/LEAPMacro.git"
)
