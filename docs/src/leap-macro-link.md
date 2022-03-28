```@meta
CurrentModule = LEAPMacro
```

# [LEAP-Macro link](@id leap-macro-link)
The link between the LEAP energy model and the Macro economic model is shown in the diagram below. Nearly all of the development of each model can be done separately. That allows energy experts to work on LEAP and economists to work on Macro, collaborating only where the models interact. The combined model is solved iteratively.

The Macro model is run first, generating economic activity levels as inputs to LEAP. LEAP is then run to determine needed investment in energy supply, demand for primary energy sources, and trade in energy carriers. LEAP’s investment demand is an input to the Macro model. The Macro model is run again, and the iteration proceeds until the maximum percent difference in economic activity levels in subsequent runs falls below a user-specified tolerance. In practice, only a few iterations (2 to 3) should be sufficient.

![The LEAP-Macro process diagram](assets/images/LEAP-Macro-diagram.svg)

The Macro model requires a [supply-use table](@ref prep-sut) and some [parameter files](@ref prep-params) as inputs, as well as a configuration file. The LEAP-Macro link is managed through the configuration file. This documentation contains an [overview of the configuration file](@ref config) as well as [instructions for preparing the configuration file](@ref prep-config).
