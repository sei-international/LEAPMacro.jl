```@meta
CurrentModule = LEAPMacro
```

# [About demand-led growth](@id demand-led-growth)
Macro is a demand-led growth model[^1] built along structuralist lines[^2]. In such models, the growth rate of the economy is _endogenous_. That is, it is determined by the model's own dynamics. Firms are assumed to invest in new productive capacity because they anticipate future demand. They base their assessment on past growth, profitability, and the utilization rate of their current capacity. Once they decide to buy new machinery, equipment, and buildings -- that is, new capital -- those purchases add to total demand.

In demand-led growth models, capacity utilization is a key adjusting variable. If firms' expectations are not met, then their capacity utilization will be either below or above what they anticipated. If demand is high and they are already producing at capacity, then they will be unable to satisfy all of the demand, and imports may rise.

Demand-led growth models can be contrasted with the more common supply-led growth models, in which growth is determined by the supply of savings. Savings are converted into investment and expanded production capacity. That capacity is presumed to be fully used, so capacity utilization is not an adjusting variable. Instead, prices adjust to clear markets.

Prices for goods and services may be treated with greater or lesser sophistication in demand-led models, but they play a less central role than in supply-led models. In general, demand for products is considered to be more responsive to income than to price, and firms are assumed to set prices by mark-up. More emphasis is placed on "macroeconomic prices", including wage rates, the interest rate set by the central bank, and the exchange rate.

[^1]: E.g., see: [_The Economics of Demand-Led Growth_](https://www.e-elgar.com/shop/usd/the-economics-of-demand-led-growth-9781840641776.html) by Mark Setterfield and [_Post-Keynesian Economics: New Foundations_](https://www.e-elgar.com/shop/usd/post-keynesian-economics-9781783475285.html) by Marc Lavoie.
[^2]: See: [_Socially Relevant Policy Analysis: Structuralist Computable General Equilibrium Models for the Developing World_](https://mitpress.mit.edu/books/socially-relevant-policy-analysis) and [_Reconstructing Macroeconomics: Structuralist Proposals and Critiques of the Mainstream_](https://www.hup.harvard.edu/catalog.php?isbn=9780674010734) by Lance Taylor; [_Growth and Policy in Developing Countries: A Structuralist Approach_](https://cup.columbia.edu/book/growth-and-policy-in-developing-countries/9780231150149) by Jose Ocampo, Codrina Rada, and Lance Taylor.

## Demand in the Macro model
Demand in the Macro model comes from three sources: final demand (made up of households, non-profits serving households, and government); exports net of imports; and investment expenditure.

Final demand is assumed to grow with total wages, adjusted by an elasticity for each product. The elasticities account for different responses to rising income. For example, household demand for processed food in a developing country might rise faster than demand for agricultural produce as wages rise. Because household and government expenditure are combined in the Macro model, wages are assumed to drive all components of final demand.

Exports are driven by global GDP growth, adjusted by an elasticity for each product. The growth rate of global GDP is set outside the model in the `time_series.csv` [parameter file](@ref params). If global demand for a country's products is expected to grow particularly fast, for example from export promotion policies, then the elasticity can be set to a high value.

Imports are calculated in the model based on patterns seen in the supply-use tables but adjusted in order to meet the goals in the [linear goal program](@ref lgp).

Investment expenditure is calculated endogenously within the model. Investment rates depend on profitability, the past growth trajectory, capacity utilization, and the (simulated) interest rate set by the central bank.

## Prices in the macro model
Five prices appear in the Macro model:
  1. World prices for traded goods and services
  2. The exchange rate
  3. Domestic prices for non-traded goods and services
  4. Wages
  5. The central bank rate

World prices for goods and services are treated very simply: all prices rise at the same inflation rate. While this is an acknowledged [limitation of the model](@ref terms-of-trade), it reduces the number of parameters the model developer must set and simplifies the application of the LEAP-Macro plugin in a LEAP model.

The exchange rate is specified outside the model in the `time_series.csv` [parameter file](@ref params).

Domestic prices for goods and services are determined as a mark-up on cost of labor and intermediate inputs. Because intermediate input costs enter the calculation, and some of those inputs will typically be imported, domestic prices tend to track world prices in the model.

Wages rise more or less in proportion to inflation (with a proportionality factor set in the [configuration file](@ref config)) and in response to the difference between the growth rate of the demand for labor and the growth rate of the working-age population, which is set in the `time_series.csv` [parameter file](@ref params).

The central bank rate is set using what is known as a "Taylor rule". Under such a rule, the interest rate is raised when the economy grows faster than a target rate in order to "cool off" an expansion and reduced when it grows more slowly. It is also raised when inflation exceeds a target, on the assumption that inflation is driven by an economic expansion, and reduced when inflation is below the target. The Taylor rule parameters are set in the [configuration file](@ref config).
