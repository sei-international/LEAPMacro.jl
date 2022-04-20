```@meta
CurrentModule = LEAPMacro
```

# [Limitations of the model](@id limitations)
The LEAP-Macro plugin is an economic extension to an energy planning model, LEAP. LEAP-Macro is most useful in LEAP models that track energy investment costs. In that case, the investment expenditure (in LEAP) helps drive economic activity (in Macro), which then drives energy consumption (in LEAP). The LEAP-Macro plugin iteratively solves LEAP and Macro until the results converge to within a user-specified tolerance.

The economic model, Macro, is designed so that a detailed energy systems model, built in LEAP, can be paired with a moderately complex economic model. The Macro model can be run independently of LEAP, which can be useful for calibration, but it is not intended as a stand-alone economic planning model. To offer a reasonably flexible LEAP plug-in, some potentially important factors for economic planning were omitted or implemented in a simplified form.

## [Changes in the terms of trade](@id terms-of-trade)
The Macro model applies a uniform inflation rate to global prices. For traded goods, whether imports or exports, the model economy is assumed to be a price taker. For domestic goods, prices are determined as a markup on the costs of labor and of intermediate goods.

The way that prices are set in the model does create a link between international and domestic prices through the cost of intermediates. Moreover, the terms of trade can change to the extent that the basket of imported or exported goods changes. However, the model does not, at present, allow for changing relative prices for traded goods.

## Current account deficits
Most developing countries face chronic challenges with their current account balances. A manageable debt obligation can become unmanageable if it is denominated in an international currency and the exchange rate changes, or if the terms of trade turn against the country's exports. If international investors perceive the country as particularly risky, they may withdraw capital or choose to invest elsewhere.

While this is an important issue, policies to respond to adverse current accounts movements differ between countries, and over time within the same country. For this reason, the Macro model does not try to estimate international investor response to current account deficits.

However, Macro does estimate and report the current account balance (for the non-energy economy) both as a total and as a share of GDP in a file called `collected_variables_#.csv`, where `#` is the model run number. The reported figures can be used to check whether the scenario seems reasonable. If the balance is persistently negative and becoming more negative as a share of GDP, then it is a signal that some parameters settings in the [configuration file](@ref config) or [exogenous parameters file](@ref params) may not be compatible with financial sustainability, and should be adjusted. At the same time, while Macro is not intended as a stand-alone economic planning model, if it generates a rising current account deficit as a share of GDP, that result may signal a risk of rising external debt that deserves closer scrutiny.

## Financial stocks
Macro is a "real-economy" model that estimates flows of expenditure. In the model, the value of those flows depends on prior flows and exogenous parameters.

A more detailed economic planning model would likely track financial stocks, such as debt, stocks of long-lived goods (machinery, vehicle fleets, buildings, and so on), money, foreign exchange reserves, ownership of equities and bonds, and so on. The implicit assumption in Macro is that the distribution of financial stocks is sufficiently stable that their influence on economic flows can be neglected.

## Sector-specific employment
The Macro model calculates labor productivity and employment indices. They apply at the level of the whole economy, rather than for individual sectors. That choice was dictated by the highly uneven availability of employment data. However, labor productivity does vary significantly between sectors, and as a result the capacity of sectors to absorb labor also varies considerably. If the Macro model indicates that specific sectors are rapidly declining or expanding, then a more detailed employment analysis might be called for.

## Non-energy strategic investment
The LEAP-Macro model is designed to explore the macroeconomic implications of energy investment. A LEAP model will typically simulate different energy sector strategies, so LEAP-Macro captures the impact of strategic investment in the energy sector. In other sectors, investment is endogenous in the Macro model, based on profitability and capacity utilization. For that reason, the Macro model cannot represent strategic investment in non-energy sectors.

## [Instabilities without simulated responses](@id limitations-recovery-from-recession)
[Demand-led growth models](@ref demand-led-growth) can become unstable. This is actually a positive feature of such models, and not a limitation, because actual economies can become unstable. Instabilities can result in either accelerating or decelerating growth due to reinforcing dynamics. A standard way to contain the instabilities is through "ceilings" that put a limit on expansion and "floors" that put a limit on recession (or depression).

The Macro model assumes that the economy is mainly expanding. It therefore has multiple ceilings: capacity utilization must be less than one; [too rapid an expansion of labor demand raises labor costs](@ref dynamics-wages-labor-prod) and lowers profitability; and the [central bank reaction function](@ref dynamics-taylor-rule) raises interest rates as inflation and economic growth rates rise above their target levels, thereby raising borrowing costs. These then influence the [pace of investment](@ref dynamics-potential-output).

The only floor in the model is a [lower bound of zero gross investment](@ref dynamics-potential-output), so the capital stock can only decline as fast as the depreciation rate. However, that is not a particularly robust floor, and a sufficiently large recession can deepen rapidly in the model. In reality, a deepening recession would most likely trigger a government response, but the model does not simulate that possibility.

Given the limitations of the Macro model, if the simulated economy rapidly contracts (a recession or depression), it is best to adjust parameters to remove the instability. At the same time, the appearance of an instability in the Macro model may indicate real-world challenges. The potential for recession can be explored through a separate economic analysis that focuses specifically on that question.
