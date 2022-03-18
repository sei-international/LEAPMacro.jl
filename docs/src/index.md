```@meta
CurrentModule = LEAPMacro
```

This documentation explains how to use **LEAP-Macro** to build a linked energy-economic model.

The energy system in a LEAP-Macro application is represented in [LEAP](https://leap.sei.org/), the Low Emissions Analysis Platform. The economy is represented in a macroeconomic model called **Macro**. This documentation will explain how to build a Macro model and link LEAP to Macro, but not how to build the LEAP model.

> To learn how to build LEAP models, go to the [LEAP](https://leap.sei.org/) website to access [documentation](https://leap.sei.org/help/leap.htm#t=Concepts%2FIntroduction.htm) and other learning materials.

The link between the LEAP energy model and the Macro economic model is shown in the diagram below. Nearly all of the development of each model can be done separately. That allows energy experts to work on LEAP and economists to work on Macro, collaborating only where the models interact. The combined model is solved iteratively.

The Macro model is run first, generating economic activity levels as inputs to LEAP. LEAP is then run to determine needed investment in energy supply, demand for primary energy sources, and trade in energy carriers. LEAP’s investment demand is an input to the Macro model. The Macro model is run again, and the iteration proceeds until the maximum percent difference in economic activity levels in subsequent runs falls below a user-specified tolerance. In practice, only a few iterations (2 to 3) should be sufficient.

![The diagram](assets/images/LEAP-Macro-diagram.svg)
