```@meta
CurrentModule = LEAPMacro
```

# [LEAP-Macro link](@id leap-macro-link)
The link between the LEAP energy model and the Macro economic model is shown in the diagram below. For each of the sub-models -- LEAP and Macro -- most of the model development can be done independently. That allows energy experts to work on LEAP and economists to work on Macro, collaborating only where the models interact.

The combined model is solved iteratively. The Macro model is run first, generating economic activity levels as inputs to LEAP. LEAP is then run to determine needed investment in energy supply, demand for primary energy sources, and trade in energy carriers. LEAP’s investment demand is an input to the Macro model. The Macro model is run again, and the iteration proceeds until the maximum percent difference in economic activity levels in subsequent runs falls below a user-specified tolerance. In practice, only a few iterations (2 to 3) should be sufficient.

![The LEAP-Macro process diagram](assets/images/LEAP-Macro-diagram.svg)

The Macro model requires a [supply-use table](@ref sut) and some [parameter files](@ref params) as inputs, as well as a [configuration file](@ref config). The [mapping between Macro and LEAP](@ref config-link-LEAP) is managed through the configuration file.
