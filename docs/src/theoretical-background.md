```@meta
CurrentModule = LEAPMacro
```

# [Theoretical background](@id theoretical-background)
Macro is a demand-led growth model[^1] built along structuralist lines[^2]. In such models, the growth rate of the economy is _endogenous_. That is, it is determined by the model's own dynamics. Firms are assumed to invest in new productive capacity because they anticipate future demand. They base their assessment on past growth, profitability, and the utilization rate of their current capacity. Once they decide to buy new machinery, equipment, and buildings -- that is, new capital -- those purchases add to total demand.

In demand-led growth models, capacity utilization is a key adjusting variable. If firms' expectations are not met, then their capacity utilization will be either below or above what they anticipated. If demand is high and they are already producing at capacity, then they will be unable to satisfy all of the demand, and imports may rise.

Demand-led growth models can be contrasted with the more common supply-led growth models, in which growth is determined by the supply of savings. Savings are converted into investment and expanded production capacity. That capacity is presumed to be fully used, so capacity utilization is not an adjusting variable. Instead, prices adjust to clear markets.

!!! info "Comparison with CGE models"
    The most common types of macroeconomic models are econometric (statistical) models and computable general equilibrium (CGE) models. The Macro model is closest in spirit to CGE models. The core of a CGE is an accounting identity, and Macro imposes that identity through a [linear goal program](@ref lgp) (LGP). In fact, CGE modeling is fully compatible with a structuralist approach: examples can be found in the book [_Socially Relevant Policy Analysis: Structuralist Computable General Equilibrium Models for the Developing World_](https://mitpress.mit.edu/books/socially-relevant-policy-analysis), edited by Lance Taylor. The Macro model differs from a CGE because it combines the LGP with [dynamic processes](@ref dynamics) that can be out of equilibrium.

Prices for goods and services may be treated with greater or lesser sophistication in demand-led models, but they play a less central role than in supply-led models. In general, demand for products is considered to be more responsive to income than to price, and firms are assumed to set prices by mark-up. More emphasis is placed on "macroeconomic prices", including wage rates, the interest rate set by the central bank, and the exchange rate. The Macro model includes these macroeconomic prices, as well as domestic and world prices of goods and services, which influence the volume of imports and exports.

!!! warning "Macro does not include financial assets"
    An important component in many structuralist models, as well as demand-led Stock-Flow Consistent (SFC) models, is the impact on the non-financial economy of changing wealth allocation and valuations of financial assets. The Macro model does not keep track of financial assets, which limits the policies that it can simulate.

[^1]: E.g., see: [_The Economics of Demand-Led Growth_](https://www.e-elgar.com/shop/usd/the-economics-of-theoretical-background-9781840641776.html) by Mark Setterfield and [_Post-Keynesian Economics: New Foundations_](https://www.e-elgar.com/shop/usd/post-keynesian-economics-9781783475285.html) by Marc Lavoie.
[^2]: See: [_Reconstructing Macroeconomics: Structuralist Proposals and Critiques of the Mainstream_](https://www.hup.harvard.edu/catalog.php?isbn=9780674010734) by Lance Taylor; [_Growth and Policy in Developing Countries: A Structuralist Approach_](https://cup.columbia.edu/book/growth-and-policy-in-developing-countries/9780231150149) by Jose Ocampo, Codrina Rada, and Lance Taylor.

## Demand in the Macro model
Demand in the Macro model comes from four sources: final domestic demand (made up of households, non-profits serving households, and government); export demand net of imports; investment expenditure; and intermediate demand by economic sectors for the products of other sectors.

[Final domestic demand](@ref dynamics-final-dom-demand) is assumed to grow with total wages, adjusted by an elasticity for each product. The elasticities account for different responses to rising income. For example, household demand for processed food in a developing country might rise faster than demand for agricultural produce as wages rise. Because household and government expenditure are combined in the Macro model, wages are assumed to drive all components of final domestic demand.

Income elasticities of demand have been observed to change as incomes rise; for example, demand for manufactures responds more strongly to income at low income levels than at high income levels. The Macro model mimics this pattern by having most (but not all) income elasticities approach a value of one over time; for details, see the explanation for [long-run demand elasticities](@ref config-longrun-demand-elast).

[Exports](@ref dynamics-export-demand) are driven by global GDP growth, adjusted by an elasticity for each product, with a further adjustment due to relative changes between the prices prevailing on world markets and the prices offered by domestic producers. The growth rate of global GDP is set outside the model in the [time series](@ref params-time-series) parameter file. If global demand for a country's products is expected to grow particularly fast, for example from export promotion policies, then the elasticity can be set to a high value in the [product parameters](@ref params-products) file; as for the income elasticities of final domestic demand, most export income elasticities approach a value of one over time. To capture the impact of domestic versus world prices, the price elasticity of export demand can also set in the product parameters file.

[Imports](@ref dynamics-imports) are adjusted in order to meet goals in a [linear goal program](@ref lgp). Imports are anchored based on a "normal" level as a fraction of domestic demand. The normal level is initialized based on the [supply-use table](@ref sut). It is then [adjusted in two ways](@ref dynamics-imports): first, by following trends in imports as calculated by the linear goal program; second, through a price adjustment. The price adjustment depends on a price elasticity of substitution between imports and exports that is set in the [product parameters file](@ref params-products).

[Investment expenditure](@ref dynamics-inv-dmd) is a key variable in demand-led models, and is calculated endogenously. In Macro, [investment rates depend](@ref dynamics-potential-output) on profitability, the past growth trajectory, capacity utilization, the (simulated) interest rate set by the central bank, and (optionally) the current account-to-GDP ratio.

Intermediate demand is determined through the [supply-use table](@ref sut), and is calculated through the Macro model's [linear goal program](@ref lgp). Intermediate demand coefficients can optionally depend on changing relative prices, as explained in the [Technical Details](@ref dynamics-intermed-dmd-coeff).

## [Prices in the macro model](@id theoretical-background-prices)
Five prices appear in the Macro model:
  1. World prices for traded goods and services
  2. The exchange rate
  3. Domestic prices of goods and services
  4. Wages
  5. The central bank rate

In the Macro model, prices of trading partners (the "world prices") are set exogenously. By default, world prices for all goods and services rise at the same inflation rate, with a constant real price. Optionally, [real price trends for selected tradeables](@ref params-optional-price-trend) can be specified on a product-by-product basis.

The exchange rate is also exogenous, and is specified in the [time series](@ref params-time-series) parameter file. By default, the series is the nominal exchange rate, but can alternatively be set as the real exchange rate.

Basic prices -- what domestic consumers pay -- is a trade-weighted average of world and domestic prices. Domestic prices for goods and services are determined as a mark-up on cost of labor and intermediate inputs. Because some intermediate inputs are imported, domestic prices tend to track world prices in the model.

[Wages](@ref dynamics-wages) rise more or less in proportion to inflation through a wage indexation parameter (called `infl_passthrough` in the [configuration file](@ref config-empl-labprod-wage)). They also rise and fall in response to the difference between the growth rate of the demand for labor and the growth rate of the working-age population (through a further parameter, `lab_constr_coeff`). The growth rate of the working-age population is exogenous, and is specified in the [time series](@ref params-time-series) parameter file, while the demand for labor is calculated endogenously.

The [central bank rate is set](@ref dynamics-taylor-rule) using what is known as a ["Taylor rule"](@ref dynamics-taylor-rule). Under such a rule, the interest rate is raised when the economy grows faster than a target rate in order to "cool off" an expansion and reduced when it grows more slowly. It is also raised when inflation exceeds a target, on the assumption that inflation is driven by an economic expansion, and reduced when inflation is below the target. The Taylor rule parameters are set in the [configuration file](@ref config-taylor-rule), including the initial value for the neutral interest rate -- that is, the rate that prevails when the economy is at its target growth and inflation rates.

In reality, interest rates and exchange rates are linked, with influences flowing in both directions. Many developing countries feature strong currencies, reflected in an appreciated (low) exchange rate, combined with high interest rates. Conversely, a devaulation, which raises the exchange rate, can lead to a decline in the interest rate. Together, these observations suggest that interest rates and exchange rates tend to move in opposite directions. While that is a common pattern, it is possible for the interest rate to be positively related. The Macro model allows the [target interest rate to adjust](@ref dynamics-taylor-rule) towards a level that depends either positively or negatively on the nominal exchange rate.
