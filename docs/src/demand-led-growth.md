```@meta
CurrentModule = LEAPMacro
```

# [About demand-led growth](@id demand-led-growth)
Macro is a demand-led growth model.[^1] In such models, the growth rate of the economy is _endogenous_. That is, it is determined by the model's own dynamics. Firms are assumed to invest in new productive capacity because they anticipate future demand. They base their assessment on past growth, profitability, and the utilization rate of their current capacity. Once they decide to buy new machinery, equipment, and buildings -- that is, new capital -- those purchases add to total demand.

In demand-led growth models, capacity utilization is a key adjusting variable. If firms' expectations are not met, then their capacity utilization will be either below or above what they anticipated. If demand is high and they are already producing at capacity, then they will be unable to satisfy all of the demand, and imports may rise.

Demand-led growth models can be contrasted with the more common supply-led growth models, in which growth is determined by the supply of savings. Savings are converted into investment and expanded production capacity. That capacity is presumed to be fully used, so capacity utilization is not an adjusting variable. Instead, prices adjust to clear markets.

Prices may be treated with greater or lesser sophistication in demand-led models, but they play a less central role. In general, demand is considered to be more responsive to income than to price, and firms are assumed to set prices by mark-up.

[^1]: E.g., see <https://www.e-elgar.com/shop/usd/the-economics-of-demand-led-growth-9781840641776.html> _The Economics of Demand-Led Growth_ by Mark Setterfield

## Demand in the Macro model
Demand in the Macro model comes from three sources: final demand (made up of households, non-profits serving households, and government); exports net of imports; and investment expenditure.

Final demand is assumed to grow with total wages, adjusted by an elasticity for each product. So, for example, household demand for processed food in a developing country might rise faster than household demand for agricultural produce as wages rise. The particularly simple structure of final demand in the model means that wages are a proxy for all components of final demand, including by government.

Exports are driven by global GDP growth, adjusted by an elasticity for each product. If global demand for a country's products is expected to grow particularly fast, for example from export promotion policies, then the elasticity can be set to a high value.

Imports are calculated in the model based on patterns seen in the supply-use tables but adjusted in order to meet the goals in the [linear goal program](@ref lgp).

Investment expenditure is calculated endogenously within the model. Investment rates depend on profitability, the past growth trajectory, capacity utilization, and the (simulated) interest rate set by the central bank.

## Prices in the macro model
Four prices appear in the Macro model:
  1. World prices for traded goods and services
  2. Domestic prices for non-traded goods and services
  3. Wages
  4. The central bank rate

World prices for goods and services are treated very simply: all prices rise at the same inflation rate. While this is an acknowledged [limitation of the model](@ref terms-of-trade), it reduces the number of parameters the model developer must set and simplifies the application of the LEAP-Macro plugin in a LEAP model.

Domestic prices for goods and services are determined as a mark-up on cost of labor and intermediate inputs. Because intermediate input costs enter the calculation, and some of those inputs will typically be imported, domestic prices tend to track world prices in the model.

Wages rise more or less in proportion to inflation (with a proportionality factor set in the [configuration file](@ref config)) and in response to the difference between the growth rate of the demand for labor and the growth rate of the working-age population, which is set in the `time_series.csv` [parameter file](@ref prep-params).

The central bank rate is set using a Taylor rule-type bank reaction function. The interest rate rises when the economy grows faster than a target and falls when it grows more slowly. It also rises when inflation exceeds a target and falls when inflation is below the target. The parameters are set in the [configuration file](@ref config).

