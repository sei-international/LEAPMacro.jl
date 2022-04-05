using Documenter, LEAPMacro

"""
    Documenter.Writers.HTMLWriter.analytics_script(line::String)

Overload of Documenter.Writers.HTMLWriter.analytics_script() that provides
compatibility with Google Analytics 4.
"""
function Documenter.Writers.HTMLWriter.analytics_script(tracking_id::AbstractString)
    if isempty(tracking_id)
        return Documenter.Utilities.DOM.Tag(Symbol("#RAW#"))("")
    else
        return Documenter.Utilities.DOM.Tag(Symbol("#RAW#"))("""<!-- Global site tag (gtag.js) - Google Analytics -->
        <script async src="https://www.googletagmanager.com/gtag/js?id=$(tracking_id)"></script>
        <script>
          window.dataLayer = window.dataLayer || [];
          function gtag(){dataLayer.push(arguments);}
          gtag('js', new Date());
          gtag('config', '$(tracking_id)');
        </script>""")
    end
end  # Documenter.Writers.HTMLWriter.analytics_script(tracking_id::AbstractString)

makedocs(
    sitename = "LEAP-Macro",
    format = Documenter.HTML(analytics="G-515LD56GHH"),
    pages = [
        "Introduction" => "index.md"
        "Getting started" => [
            "Installation" => "installation.md"
            "Quick start" => "quickstart.md"
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
