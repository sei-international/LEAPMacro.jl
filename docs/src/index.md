```@meta
CurrentModule = LEAPMacro
```

# [LEAP-Macro](@id introduction)
This documentation explains how to use **LEAP-Macro** to build a linked energy-economic model.

The energy system in a LEAP-Macro application is represented in [LEAP](https://leap.sei.org/), the Low Emissions Analysis Platform. The economy is represented in a macroeconomic model called **Macro**. This documentation will explain how to build a Macro model and link LEAP to Macro, but not how to build the LEAP model.

> To learn how to build LEAP models, go to the [LEAP](https://leap.sei.org/) website to access [documentation](https://leap.sei.org/help/leap.htm#t=Concepts%2FIntroduction.htm) and other learning materials.

LEAP-Macro is a [demand-led growth model](@ref demand-led-growth) for an open, multi-sector economy. It takes supply-use tables[^1] or social accounting matrices[^2] as inputs. It is a flexible model that can be adapted to specific country circumstances.

LEAP-Macro was developed with two purposes in mind:
1. To provide economic drivers to LEAP that are grounded in the structure of the economy;
2. To estimate the impact of different energy investment scenarios on output and employment outside the energy sector.
What is more, it is intended to be used in a wide range of contexts. To meet these goals, some compromises had to be made while developing the model. These are summarized in [Limitations of the model](@ref limitations).

To simplify model development and maintenance, LEAP-Macro assumes that energy is a crucial input into the rest of the economy, but is not a major source of demand for the products and services supplied by the rest of the economy. That is true for most countries, but is not true for major energy exporters. If energy production dominates GDP or employment, then a fully integrated energy-economy model is more appropriate.

[^1]: <https://unstats.un.org/unsd/nationalaccount/docs/SUT_IOT_HB_Final_Cover.pdf> _Handbook on Supply and Use Tables and Input-Output Tables with Extensions and Applications_ from UN Statistics
[^2]: <https://www.ifpri.org/publication/social-accounting-matrices-and-multiplier-analysis> _Social accounting matrices and multiplier analysis: An introduction with exercises_ from the International Food Policy Research Institute
