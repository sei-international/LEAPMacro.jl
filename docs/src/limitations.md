```@meta
CurrentModule = LEAPMacro
```

# [Limitations of the model](@id limitations)
The LEAP-Macro plugin is designed so that a detailed energy systems model, built in LEAP, can be paired with a moderately complex economic model. It is offered as an improvement over simply entering economic drivers by hand. It is most useful in LEAP models that track energy investment costs. In that case, the investment expenditure (in LEAP) helps drive economic activity (in Macro), which then drives energy consumption (in LEAP). The LEAP-Macro plugin will iteratively solve LEAP and Macro until the results converge to within a user-specified tolerance.

The goal of making a reasonably flexible model entails some trade-offs. Some of the most important missing elements are listed below.

## Changes in the terms of trade
The Macro model applies a uniform inflation rate to global prices. For traded goods, whether imports or exports, the model economy is assumed to be a price taker. For domestic goods, prices are determined as a markup on the costs of labor and of intermediate goods.

This means that international prices can interact with purely domestic prices through the cost of intermediates. Moreover, the terms of trade can change to the extent that the basket of imported or exported goods changes. However, the model does not allow for changing relative prices for traded goods.

## Current account deficits
Most developing countries face chronic challenges with their current account balances and accumulated international debt. A manageable debt obligation can become unmanageable if it is denominated in an international currency and the exchange rate changes, or if the terms of trade turn against the country's exports. If international investors perceive the country as particularly risky, they may withdraw capital or choose to invest elsewhere.

While this is an important issue, policies to respond to rising debt or adverse current accounts movements differ between countries, and diverse actors influence the path the economy can take: the executive branch; the central 
bank; domestic firms, financial institutions, and individual households; international portfolio investors; and foreign firms.

Because of the complexities, the Macro model does not try to estimate international debt and international investor response to debt and current account deficits. However, it does estimate and report the current account balance (for the non-energy economy) in a file called `collected_variables_#.csv`, where `#` is the model run number. The reported figures can be used to check the consistency of the scenario. If the balance is persistently negative and, in particular, if the deficit grows faster than GDP, that may contradict the implicit model assumption that international debt and current account deficits are _not_ a problem.

## Sector-specific employment
The Macro model calculates labor productivity and employment indices. They apply at the level of the whole economy, not for individual sectors. That choice was dictated by the highly uneven availability of employment data. However, labor productivity varies substantially between sectors, and as a result the capacity of sectors to absorb labor also varies considerably. If the Macro model indicates specific sectors are declining or expanding, then a more detailed employment analysis might be called for.

## Non-energy strategic investment
The LEAP-Macro model is designed to explore the macroeconomic implications of energy investment. A LEAP model will typically simulate different energy sector strategies, so LEAP-Macro captures the impact of strategic investment in the energy sector. In other sectors, investment is endogenous, based on profitability and capacity utilization. For that reason, the Macro model cannot represent strategic investment in non-energy sectors.
