```@meta
CurrentModule = LEAPMacro
```

# [Configuration file](@id config)

The configuration file is written in YAML syntax and has a `.yml` extension. By default, Macro assumes the configuration file will be called `LEAPMacro_params.yml`, but other names are possible, and in fact encouraged, because each configuration file corresponds to a different scenario.

```@contents
Pages = ["config.md"]
Depth = 3
```

## [General settings](@id config-general-settings)

The configuration file is made up of several blocks. The first block names a subfolder for storing outputs. It will be created inside an `outputs` folder. Different configuration files should be given different output folders so that different scenarios can be distinguished.
```yaml
#---------------------------------------------------------------------------
# Folder inside the "outputs" folder to store calibration, results, and diagnostics
#---------------------------------------------------------------------------
output_folder: Baseline
```

The next block specifies the input files. In many cases, these will be the same across a set of scenarios. However, it is possible that they might differ. For example, the supply-use table, given by the `SUT` parameter, could be drawn from different years for calibration purposes, and different `time_series` might distinguish different scenarios.
```yaml
#---------------------------------------------------------------------------
# Supply-use table and supplementary tables as CSV files
#---------------------------------------------------------------------------
# Macro model data files
files:
    SUT: Freedonia_SUT.csv
    sector_info: sector_parameters.csv
    product_info: product_parameters.csv
    time_series: time_series.csv
```

The following block says how to manage the output folders. Reporting diagnostics is optional. It is highly recommended while developing a model, but `report-diagnostics` can be set to `false` for a model in active use. Ordinarily it is useful to clear the folders with each run, since files will be overwritten. Sometimes during model development it is useful set `clear-folders` to `false` temporarily. To compare results from different runs, make a copy of the output files so that they are not overwritten in the subsequent run.
```yaml
# Say whether to clear the contents of the results, calibration, and diagnostic folders before the run
clear-folders:
    results: true
    calibration: true
    diagnostics: true
# Set to "true" to send results to the diagnostics folder, including dumps of the linear goal program
report-diagnostics: true
```

The next block has settings for running LEAP. To develop the Macro model independently of LEAP, set `run_leap` to `false`. To reduce the time spent while running LEAP and Macro together, set `hide_leap` to `true`. The `max_runs` parameter can be left at the default value; it is quite unusual to go that far before convergence. The `max_tolerance` is the percent difference in Macro model outputs between runs. The tolerance can be tightened (a smaller value) or loosened (a larger value) depending on the needs of the analysis.
```yaml
model:
    # Set run_leap to "false" to do a single run of the Macro model without calling LEAP
    run_leap: false
    # Hide LEAP while running to (possibly) improve performance
    hide_leap: false
    # Maximum number of iterations before stopping (ignored if run_leap = false)
    max_runs: 7
    # Tolerance in percentage difference between values for indices between runs
    max_tolerance: 1 # percent
```

The next block is optional, and can be entirely omitted. This block allows for additional exogenous time series that might be of interest in some studies. Any of them can be added or excluded individually. The allowed input files include:
  * `investment`: A time series of exogenous investment demand beyond that simulated by the model (e.g., public investment)
  * `pot_output`: Potential output, which will override the value simulated by the model, where the entered values are converted to an index (e.g., agricultural production might be determined by an independent crop production model)
  * `max_util`: Maximum capacity utilization (e.g., if an exogenous constraint prevents operation at full capacity)
  * `real_price`: Real prices for tradeables; the entered values are converted to an index by Macro and multiplied by an index of inflation at the user-specified world inflation rate
These are explained in more detail under [external parameter files](@ref params-optional-input-files). Examples of each type of file are included in the sample Freedonia model. Any file can be commented out. Alternatively, the filename can be set to "~", meaning that it is omitted.
```yaml
#---------------------------------------------------------------------------
# Optional input files for exogenous time series (CSV files)
#---------------------------------------------------------------------------
# Uncomment the lines below to use the files included in the Freedonia sample model
# For pot_output and max_util, include only those sectors where values are constrained -- the others will be unconstrained
# For real_price:
#   * Include only those products where values are specified -- for others the real price will be held constant
#   * Prices for non-tradeables will be ignored; they are calculated internally by Macro
exog-files:
    # investment: exog_invest.csv # Time series of exogenous investment demand, additional to that simulated by the model
    # pot_output: exog_pot_output.csv # Potential output (any units -- it is applied as an index): sectors label columns; years label rows
    # max_util: exog_max_util.csv # Maximum capacity utilization: sectors label columns; years label rows (must lie between 0 and 1)
    # real_price: exog_price.csv # Real prices for tradeables (any units -- it is applied as an index): products label columns; years label rows
```

The next block sets the start and end years for the simulation. These should normally be the same as the base year and final year in LEAP, and the start year should be appropriate for the supply-use table. However, during model development, the start year might be set to an earlier value to calibrate against historical data. Also, the end year can be set closer to the start year, but Macro normally runs quickly once it is loaded, so that is rarely necessary for performance.
```yaml
#---------------------------------------------------------------------------
# Start and end years for the simulation
#   Note: the supply-use table above must be appropriate for the start year
#---------------------------------------------------------------------------
years:
    start:  2010
    end:    2040
```

## [Model parameters](@id config-model-params)
The next several blocks contain some of the [exogenous parameters](@ref exog-param-vars) for the Macro model.

### [Initial value adjustments](@id config-init-val-adj)
The first block of model parameters contains adjustments that are applied to the initial values. This can help adjust if, for example, the economy was recovering from a recession in the first year. These values should normally be adjusted last when calibrating a model.
```yaml
#---------------------------------------------------------------------------
# Adjustment parameters for initializing variables
#---------------------------------------------------------------------------
# These factors are expressed as a fractional addition/subtraction to the estimate: set to zero to accept the default estimate
calib:
    # Calibration factor for estimating the first-period profit rate and capital productivity
    nextper_inv_adj_factor: 0.00
    # Adjustment factor for maximum export demand in the initial year
    max_export_adj_factor: 0.00
    # Adjustment factor for maximum household demand in the initial year
    max_hh_dmd_adj_factor: 0.00
    # Potential output relative to actual output in the base year
    pot_output_adj_factor: 0.10
```

### Default values for the global economy
The second block of model parameters provides default values for the global inflation rate and growth rate of global GDP (or gross world product, GWP). These are applied only if they are not specified for some year in the [external parameter files](@ref params).

The correspondence between the parameters and the model variables is:
  * `infl_default` : ``\underline{\pi}_{w,k}`` (assumed to be the same for all products ``k``)
  * `gr_default` : ``\underline{\gamma}^\text{world}``
```yaml
#---------------------------------------------------------------------------
# Global economy parameters
#---------------------------------------------------------------------------
global-params:
    # Default world inflation rate
    infl_default: 0.02
    # Default world growth rate
    gr_default: 0.015
```

### [Taylor rule coefficients](@id config-taylor-rule)
The next block contains the parameters for implementing a "Taylor rule", which adjusts the central bank interest rate in response to inflation and economic growth. See the page on [model dynamics](@ref dynamics-taylor-rule) for details.

The correspondence between the parameters and the model variables is:
  * `neutral_growth_band` : ``[\hat{\underline{Y}}^*_\text{min},\hat{\underline{Y}}^*_\text{max}]``
  * `target_intrate` : ``\underline{i}_{b0}``
  * `target_infl` : ``\underline{\pi}^*``
  * `gr_resp` : ``\underline{\rho}_Y``
  * `infl_resp` : ``\underline{\rho}_\pi``
```yaml
#---------------------------------------------------------------------------
# Parameters for setting the central bank lending rate (Taylor rule)
#---------------------------------------------------------------------------
taylor-fcn:
    # Allowable range for neutral growth
    neutral_growth_band: [0.02, 0.06]
    # Target interest rate (as a fraction, e.g., 2%/year = 0.02)
    target_intrate: 0.02
    # Target inflation rate
    target_infl: 0.02
    # Response of the central bank rate to a change in the GDP growth rate
    gr_resp: 0.50
    # Response of the central bank rate to a change in the inflation rate
    infl_resp: 0.50
```

### Investment function coefficients
The next block contains the parameters for the investment function. As explained in the page on [model dynamics](@ref dynamics-inv-dmd), the investment function calculates the demand for investment goods as a function of capacity utilization, profitability, and borrowing costs.

The correspondence between the parameters and the model variables is:
  * `init_neutral_growth`: Initial value of ``\gamma_{i0}`` for every sector ``i``
  * `util_sens` : ``\underline{\alpha}_\text{util}``
  * `profit_sens` : ``\underline{\alpha}_\text{profit}``
  * `intrate_sens` : ``\underline{\alpha}_\text{bank}``
  * `growth_adj` : ``\underline{\xi}``
```yaml
#---------------------------------------------------------------------------
# Parameters for the investment function
#---------------------------------------------------------------------------
investment-fcn:
    # Starting point for the autonomous investment growth rate: also the initial target GDP growth rate for the Taylor rule
    init_neutral_growth: 0.060
    # Change in induced investment with a change in utilization
    util_sens:  0.07
    # Change in induced investment with a change in the profit rate
    profit_sens: 0.05
    # Change in induced investment with a change in the central bank lending rate
    intrate_sens: 0.20
    # Rate of adjustment of the autonomous investment rate towards the actual investment rate
    growth_adj: 0.10
```

### Employment and labor productivity
The next block contains default parameters for the labor productivity function and for the function that determines the growth rate of the wage. See the page on [model dynamics](@ref dynamics-wages-labor-prod) for details. The default productivity parameters are used if they are not specified for some year in the [external parameter files](@ref params).

The correspondence between the parameters and the model variables is:
  * For labor productivity:
    - `KV_coeff_default` : ``\underline{\alpha}_\text{KV}``
    - `KV_intercept_default` : ``\underline{\beta}_\text{KV}``
  * For the wage:
    - `infl_passthrough` : ``\underline{h}``
    - `lab_constr_coeff` : ``\underline{k}``
```yaml
#---------------------------------------------------------------------------
# Parameters for the labor productivity and labor force model
#---------------------------------------------------------------------------
labor-prod-fcn:
    # Default Kaldor-Verdoorn coefficient
    KV_coeff_default: 0.50
    # Default Kaldor-Verdoorn intercept
    KV_intercept_default: 0.00
wage-fcn:
    # Inflation pass-through
    infl_passthrough: 1.00
    # Labor supply constraint coefficent
    lab_constr_coeff: 0.5
```

### [Endogenous change in intermediate demand coefficients](@id config-intermed-dmd-change)
The next block is optional. If it is present, it sets a rate constant for endogenously determining [intermediate demand coefficients](@ref dynamics-intermed-dmd-coeff). If the parameter is set to high, then it can generate unreasonably large rates of change in technical coefficients and can even create model instabilities. It is good practice to check [the `diagnostics` folder](@ref model-outputs-diagnostics) for annual files labeled `demand_coefficients_[year].csv` to see whether the values are reasonable.
```yaml
#---------------------------------------------------------------------------
# Parameter for rate of change in technical parameters
#---------------------------------------------------------------------------
# Uncomment rate_constant line below to endogenize changes in the scaled Use matrix
tech-param-change:
    # Rate constant: Note that if this is too large then it can create instabilities
    # rate_constant: 0.1 # 1/year
```

### [Long-run demand elasticities](@id config-longrun-demand-elast)
Initial values for demand elasticities for products with respect to global GDP (for exports) and the wage bill (for domestic final demand excluding investment) are specified in the [external parameter files](@ref params). The way that the elasticities enter into the model is described in the page on [model dynamics](@ref dynamics-demand-fcns).

For products that are not labeled as "Engel products"[^1] (given by the parameter `engel-prods`):
  * If the initial elasticity is less than one, then it remains at its starting level;
  * If the initial elasticity is greater than one, it asymptotically approaches a value of one over time;
For products labeled as Engel products:
  * The elasticity approaches the `engel_asympt_elast` over time.
The rate of convergence on the long-run values is given by the `decay` parameter, with the possibility of a different rate of convergence for exports and final demand.
```yaml
#---------------------------------------------------------------------------
# Demand model parameters
#---------------------------------------------------------------------------
# For exports, with respect to world GDP
export_elast_demand:
    decay: 0.01
    
# For final demand, with respect to the wage bill
wage_elast_demand:
    decay: 0.01
    engel_prods: [agric, foodpr]
    engel_asympt_elast: 0.7
```
[^1]: [Engel's Law](https://www.investopedia.com/terms/e/engels-law.asp) states that as income rises, the proportion of income spent on food declines. That means that the income elasticity of expenditure on food is less than one.

### [Linear goal program weights](@id config-lgp-weights)
The Macro model solves a linear goal program for each year of the simulation. As described in the documentation for the [linear goal program](@ref lgp), the objective function contains weights, which are specified in the next block.

The correspondence between the parameters and the model variables is:
  * For category weights:
    - `utilization` : ``\underline{w}_u``
    - `final_demand_cov` : ``\underline{w}_F``
    - `exports_cov` : ``\underline{w}_X``
    - `imports_cov` : ``\underline{w}_M``
  * For product and sector weights:
    - `utilization` : ``\underline{\varphi}_u``
    - `final_demand_cov` : ``\underline{\varphi}_F``
    - `exports_cov` : ``\underline{\varphi}_X``
```yaml
#---------------------------------------------------------------------------
# Paramters for implementing the (goal program) obective function
#---------------------------------------------------------------------------
objective-fcn:
    # Category weights on deviations from normal levels
    category_weights:
        utilization: 8.00
        final_demand_cov: 4.00
        exports_cov: 2.00
        imports_cov: 1.00
    # Product & sector weights are defined by: φ * value share + (1 - φ) * 1/number of sectors or products; this is φ
    product_sector_weight_factors:
        utilization: 0.5
        final_demand_cov: 0.5
        exports_cov: 0.5
```

## [Linking to the supply-use table](@id config-sut)
The next block is for specifying the structure of the [supply-use table](@ref sut) and how it relates to Macro.

The first section of this block specifies sectors and products that are excluded from the simulation. There are three categories:
1. First, and most important, are energy sectors and products. Those are excluded from the Macro calculation because the energy sector analysis is handled on a physical basis within LEAP, although they can optionally be included when [running the model](@ref running-macro) in stand-alone mode, without LEAP.
2. Second are any territorial adjustments. Macro recalculates some parameters to take account of those entries. If none are present in the supply-use table, then an empty list `[]` can be entered for this parameter, as in the sample Freedonia model.
3. Finally are any other excluded sectors and products. For example, some tables may have a "fictitious" product or sector entry.
```yaml
#---------------------------------------------------------------------------
# Structure of the supply-use table
#---------------------------------------------------------------------------
# NOTE: Both supply and use tables must have sectors labeling columns and products labeling rows
excluded_sectors:
    energy: [coal, petr, util]
    territorial_adjustment: []
    others: []

excluded_products:
    energy: [coal, petr, util]
    territorial_adjustment: []
    others: []
```

Following that is a list of non-tradeable products and a domestic production share threshold. Imports and exports of products declared non-tradeable are maintained at zero within the Macro model. Furthermore, their prices are determined endogenously by the Macro model.

Other products may be almost entirely imported. That can sometimes cause difficulties. If the domestic share of the total of imports and domestic production falls below the threshold specified in the configuration file, then the corresponding sector is excluded during the simulation.
```yaml
non_tradeable_products: [constr, comm]

# Domestic production as a % share of the total of imports and domestic production must exceed this value
domestic_production_share_threshold: 1 # percent
```

The following section specifies where to find the data needed by Macro within the supply-use table (a `CSV` file). Ranges are specified in standard spreadsheet form.
```yaml
SUT_ranges:
    # Matrices arranged product (rows) x sector (columns)
    supply_table: J3:W16
    use_table: J21:W34
    # Columns indexed by products -- groups of columns will be summed together
    tot_supply: I3:I16
    margins: D3:E16
    taxes: F3:H16
    imports: Y3:Y16
    exports: Y21:Y34
    final_demand: Z21:AB34
    investment: AC21:AC34
    stock_change: AD21:AD34
    tot_intermediate_supply: X21:X34
    # Rows indexed by sector -- groups of rows will be summed together
    tot_intermediate_demand: J35:W35
    wages: J37:W38
```

## [Linking Macro to LEAP](@id config-link-LEAP)
The next, and final, block specifies how LEAP and Macro are linked.

The first section says which LEAP scenario to use for inputs to the Macro model, the LEAP scenario to which Macro returns its results, and currency unit for investment costs, and a scaling factor. For example, if entries in the Macro model input files are in millions of US dollars, and investment costs are reported in US dollars, then the scaling factor is one million (1000000 or 1.0e+6).
```yaml
#---------------------------------------------------------------------------
# Parameters for running LEAP with the Macro model (LEAP-Macro)
#---------------------------------------------------------------------------
LEAP-info:
    # This can be, e.g., a baseline scenario
    input_scenario: Baseline
    # This is the scenario from which LEAP results are drawn
    result_scenario: Baseline
    # Currency units for investment costs
    inv_costs_unit: U.S. Dollar
    # Scaling factor for investment costs (values are divided by this number, e.g., for thousands use 1000 or 1.0e+3)
    inv_costs_scale: 1.0e+6
```

The remaining sections specify where in LEAP to put indices as calculated by Macro. The indices start at 1 in the `start` year specified earlier in the configuration file.

The first index, which is optional, is for GDP. It gives the name for the index to be reported in an `indices` output file. Then, it gives the LEAP branch and variable where the index should be inserted and, to cover cases where the last historical year is after the base year, the last historical year.
```yaml
# Association between LEAP and supply-use sectors
GDP-branch:
    name: GDP
    branch: Key\GDP
    variable: Activity Level
    last_historical_year: 2010
```

The second index, for employment, is also optional. It has the same structure as for GDP.
```yaml
Employment-branch:
    name: Employment
    branch: Key\Employment
    variable: Activity Level
    last_historical_year: 2010
```

Finally, the `LEAP-sectors` parameter contains a list of indices. For each of these, Macro will sum up sector production across all of the sector codes listed. It will then calculate an index starting in the base year, and insert the index into the specified branches. In some cases, the same index might be applied to different branches. For example, if the supply-use table has a "services" sector but no transport, while LEAP has both a services and a commercial transport sector, the same index could be used to drive both.

While the GDP and Employment entries can be omitted from the file if they are not needed, to exclude the `LEAP-sectors` entry, simply set it to an empty list: `LEAP-sectors: []`.
```yaml
LEAP-sectors:
 - {
    name: Iron and Steel,
    codes: [ironstl],
    branches: [
        {
         branch: Demand\Industry\Iron and Steel,
         variable: Activity Level,
         last_historical_year: 2010
        }
    ]
   }
 - {
    name: Other Industry,
    codes: [foodpr, hvymach, othind],
    branches: [
        {
         branch: Demand\Industry\Other Industry,
         variable: Activity Level,
         last_historical_year: 2010
        }
    ]
   }
   ...
```
