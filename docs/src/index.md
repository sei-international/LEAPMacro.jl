```@meta
CurrentModule = LEAPMacro
```

# [LEAP-Macro](@id introduction)
This documentation explains how to use **LEAP-Macro** to build a linked energy-economic model.

The energy system in a LEAP-Macro application is represented in [LEAP](https://leap.sei.org/), the Low Emissions Analysis Platform. The economy is represented in a macroeconomic model called **Macro**. This documentation will explain how to build a Macro model and link the model to LEAP.

!!! tip "Learning about LEAP"
    To learn how to build LEAP models, go to the [LEAP](https://leap.sei.org/) website to access [documentation](https://leap.sei.org/help/leap.htm#t=Concepts%2FIntroduction.htm) and other learning materials.

LEAP-Macro is a [demand-led growth model](@ref demand-led-growth) for an open, multi-sector economy. It takes a set of [supply and use tables](@ref sut) as an input. It is a flexible model that can be adapted to specific country circumstances.

The focus of LEAP-Macro is on energy policy analysis. It is an economic extension -- the Macro model -- to the LEAP energy energy policy analysis and climate change mitigation assessment tool. While Macro can be run independently, it is not intended for use as a stand-alone economic planning model. Specifically, it was developed with two purposes in mind:
1. To provide economic drivers to LEAP that are grounded in the structure of the economy;
2. To estimate the impact of different energy investment scenarios on output and employment outside the energy sector.

!!! warning "The role of energy in the economy"
    LEAP-Macro assumes that energy is a crucial input into the rest of the economy. Also, the energy sector is assumed to be an important source of demand for investment goods. However, to simplify model development and maintenance,  LEAP-Macro assumes that the energy transformation sector is not a major source of demand for goods and services supplied by the rest of the economy (see [Isolating the energy sector](@ref isolate-energy) for more details). That assumption is likely to apply in most countries, but may not hold for major energy exporters. If energy production dominates economic output or employment, then a fully integrated energy-economy model might be more appropriate.
