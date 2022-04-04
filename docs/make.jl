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
            "About demand-led growth" => "demand-led-growth.md"
            "Limitations of the model" => "limitations.md"
        ]
        "Using LEAP-Macro" => [
            "Configuration file" => "config.md"
            "Supply-use table" => "sut.md"
            "External parameter files" => "params.md"
            "Output files" => "model-outputs.md"
            "Preparing a model" => "prep-model.md"
         ]
        "Technical details" => [
            "Variables" => "variables.md"
            "Linear goal program" => "lgp.md"
            "Dynamics" => "dynamics.md"
            "Isolating the energy sector" => "isolate-energy.md"
            "Processing the supply-use table" => "process-sut.md"
        ]
    ]
)

deploydocs(
    repo = "github.com/sei-international/LEAPMacro.git"
)
