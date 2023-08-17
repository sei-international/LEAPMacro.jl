```@meta
CurrentModule = LEAPMacro
```

# [LEAP-Macro](@id introduction)
This documentation explains how to use **LEAP-Macro** to build a linked energy-economic model.

!!! info "Accessing the code"
    LEAP-Macro is open source and hosted on GitHub. If you wish to access the code, please visit the [LEAP-Macro GitHub repository](https://github.com/sei-international/LEAPMacro.jl).

The energy system in a LEAP-Macro application is represented in [LEAP](https://leap.sei.org/), the Low Emissions Analysis Platform. The economy is represented in a macroeconomic model called **Macro**. This documentation will explain how to build a Macro model and link the model to LEAP.

!!! tip "Learning about LEAP"
    To learn how to build LEAP models, the [LEAP](https://leap.sei.org/) website has extensive [documentation](https://leap.sei.org/help/leap.htm#t=Concepts%2FIntroduction.htm) and other learning materials. A demonstration version of the software can be downloaded at no cost. Free or discounted licenses are available for students and for those in low-income and middle-income countries: see LEAP's [licensing policy](https://leap.sei.org/default.asp?action=license) for more detail.

LEAP-Macro is a [demand-led growth model](@ref theoretical-background) for an open, multi-sector economy. It takes a set of [supply and use tables](@ref sut) as an input. It is a flexible model that can be adapted to specific country circumstances.

The focus of LEAP-Macro is on energy policy analysis. It is an economic extension -- the Macro model -- to the LEAP energy policy analysis and climate change mitigation assessment tool. While Macro can be run independently, it is not intended for use as a stand-alone economic planning model. Specifically, it was developed with two purposes in mind:
1. To provide economic drivers to LEAP that are grounded in the structure of the economy;
2. To estimate the impact of different energy investment scenarios on output and employment outside the energy sector.

!!! info "The role of energy in the economy"
    LEAP-Macro assumes that energy is a crucial input into the rest of the economy. Also, the energy sector is assumed to be an important source of demand for investment goods. However, to simplify model development and maintenance, LEAP-Macro assumes that the energy transformation sector is not a major source of demand for goods and services supplied by the rest of the economy. LEAP-Macro calculates a statistic that estimates the importance of the energy transformation sector: see [Isolating the energy sector](@ref isolate-energy) for more details.

    In some countries, the energy extraction sector is important as a source of demand. In that case, LEAP can supply Macro with trends in primary production of resources such as coal, crude oil, and natural gas.
