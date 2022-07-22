```@meta
CurrentModule = LEAPMacro
```

# [About demand-led growth](@id demand-led-growth)
Macro is a demand-led growth model[^1] built along structuralist lines[^2]. In such models, the growth rate of the economy is _endogenous_. That is, it is determined by the model's own dynamics. Firms are assumed to invest in new productive capacity because they anticipate future demand. They base their assessment on past growth, profitability, and the utilization rate of their current capacity. Once they decide to buy new machinery, equipment, and buildings -- that is, new capital -- those purchases add to total demand.

In demand-led growth models, capacity utilization is a key adjusting variable. If firms' expectations are not met, then their capacity utilization will be either below or above what they anticipated. If demand is high and they are already producing at capacity, then they will be unable to satisfy all of the demand, and imports may rise.

Demand-led growth models can be contrasted with the more common supply-led growth models, in which growth is determined by the supply of savings. Savings are converted into investment and expanded production capacity. That capacity is presumed to be fully used, so capacity utilization is not an adjusting variable. Instead, prices adjust to clear markets.

Prices for goods and services may be treated with greater or lesser sophistication in demand-led models, but they play a less central role than in supply-led models. In general, demand for products is considered to be more responsive to income than to price, and firms are assumed to set prices by mark-up. More emphasis is placed on "macroeconomic prices", including wage rates, the interest rate set by the central bank, and the exchange rate. The Macro model includes these macroeconomic prices, as well as domestic and world prices of goods and services, which influence the volume of imports and exports.

!!! warning "Macro does not include financial assets"
    An important component in many structuralist models, as well as demand-led Stock-Flow Consistent (SFC) models, is the impact on the non-financial economy of changing wealth allocation and valuations of financial assets. The Macro model does not keep track of financial assets. One consequence is that possible relationships between the exchange rate, the interest rate, and the current account balance are not captured by the model.

[^1]: E.g., see: [_The Economics of Demand-Led Growth_](https://www.e-elgar.com/shop/usd/the-economics-of-demand-led-growth-9781840641776.html) by Mark Setterfield and [_Post-Keynesian Economics: New Foundations_](https://www.e-elgar.com/shop/usd/post-keynesian-economics-9781783475285.html) by Marc Lavoie.
[^2]: See: [_Socially Relevant Policy Analysis: Structuralist Computable General Equilibrium Models for the Developing World_](https://mitpress.mit.edu/books/socially-relevant-policy-analysis) and [_Reconstructing Macroeconomics: Structuralist Proposals and Critiques of the Mainstream_](https://www.hup.harvard.edu/catalog.php?isbn=9780674010734) by Lance Taylor; [_Growth and Policy in Developing Countries: A Structuralist Approach_](https://cup.columbia.edu/book/growth-and-policy-in-developing-countries/9780231150149) by Jose Ocampo, Codrina Rada, and Lance Taylor.

## Demand in the Macro model
Demand in the Macro model comes from three sources: final demand (made up of households, non-profits serving households, and government); exports net of imports; and investment expenditure.

Final demand is assumed to grow with total wages, adjusted by an elasticity for each product. The elasticities account for different responses to rising income. For example, household demand for processed food in a developing country might rise faster than demand for agricultural produce as wages rise. Because household and government expenditure are combined in the Macro model, wages are assumed to drive all components of final demand.

Exports are driven by global GDP growth, adjusted by an elasticity for each product, with a further adjustment due to relative changes between the prices prevailing on world markets and the prices offered by domestic producers. The growth rate of global GDP is set outside the model in the `time_series.csv` [parameter file](@ref params-time-series). If global demand for a country's products is expected to grow particularly fast, for example from export promotion policies, then the elasticity can be set to a high value in the `product_parameters.csv` [parameter file](@ref params-products). The price elasticity of export demand is also set in the `product_parameters.csv` file.

Imports are adjusted in order to meet the goals in the [linear goal program](@ref lgp). They are anchored based on a "normal" level of imports as a fraction of domestic demand. The normal level is initialized based on the [supply-use table](@ref sut). It is then adjusted in two ways: first, by following trends in imports as calculated by the linear goal program; second, through a price adjustment. The price adjustment depends on a price elasticity of substitution between imports and exports that is set in the `product_parameters.csv` [parameter file](@ref params-products).

Investment expenditure is a key variable in demand-led models, and is calculated endogenously. In Macro, investment rates depend on profitability, the past growth trajectory, capacity utilization, and the (simulated) interest rate set by the central bank.

## Prices in the macro model
Five prices appear in the Macro model:
  1. World prices for traded goods and services
  2. The exchange rate
  3. Domestic prices for non-traded goods and services
  4. Wages
  5. The central bank rate

In the Macro model, prices of trading partners (the "world prices") are set exogenously. By default, world prices for all goods and services rise at the same inflation rate, with a constant real price. Optionally, [real price trends for selected tradeables](@ref params-optional-price-trend) can be specified on a product-by-product basis.

The exchange rate is specified outside the model in the `time_series.csv` [parameter file](@ref params).

Basic prices -- what domestic consumers pay -- is a trade-weighted average of world and domestic prices. Domestic prices for goods and services are determined as a mark-up on cost of labor and intermediate inputs. Because intermediate input costs enter the calculation, and some of those inputs will typically be imported, domestic prices tend to track world prices in the model.

Wages rise more or less in proportion to inflation through a wage indexation parameter (called `infl_passthrough` in the [configuration file](@ref config)). They also rise and fall in response to the difference between the growth rate of the demand for labor and the growth rate of the working-age population (through a further parameter, `lab_constr_coeff`). The growth rate of the working-age population is exogenous, and is specified in the `time_series.csv` [parameter file](@ref params), while the demand for labor is calculated endogenously.

The central bank rate is set using what is known as a "Taylor rule". Under such a rule, the interest rate is raised when the economy grows faster than a target rate in order to "cool off" an expansion and reduced when it grows more slowly. It is also raised when inflation exceeds a target, on the assumption that inflation is driven by an economic expansion, and reduced when inflation is below the target. The Taylor rule parameters are set in the [configuration file](@ref config).
