```@meta
CurrentModule = LEAPMacro
```

# [Configuration file](@id config)

The configuration file is written in YAML syntax and has a `.yml` extension. By default, Macro assumes the configuration file will be called `LEAPMacro_params.yml`, but other names are possible, and in fact encouraged, because each configuration file corresponds to a different scenario.

!!! tip "Online YAML checkers"
    YAML is a widely-used language for representing data. As explained on the [official YAML website](https://yaml.org/), it is a "human-friendly data serialization language for all programming languages." Because YAML is so widely used, many online tools are available. While LEAP-Macro will report an error if it finds a problem with your YAML script, the online syntax checkers are more user-friendly, including the [YAML checker](https://yamlchecker.com/) and the [YAML validator](https://onlineyamltools.com/validate-yaml).

The configuration file used as an example on this page is the `LEAPMacro_params.yml` file that is distributed with the demonstration files (see the [Quick start](@ref quick-start) page).

```@contents
Pages = ["config.md"]
Depth = 3
```

## [General settings](@id config-general-settings)

The configuration file is made up of several blocks. The first block names a subfolder for storing outputs. It will be created inside an `outputs` folder (see [Output files](@ref model-outputs)). Different configuration files should specify different output folders so that scenarios can be distinguished.
```yaml
#---------------------------------------------------------------------------
# Folder inside the "outputs" folder to store calibration, results, and diagnostics
#---------------------------------------------------------------------------
output_folder: Baseline
```

The next block sets the start and end years for the simulation. When running with LEAP, these should normally be the same as the base year and final year in LEAP, and the start year should be appropriate for the supply-use table. However, during model development, the start year might be set to an earlier value to calibrate against historical data.
```yaml
#---------------------------------------------------------------------------
# Start and end years for the simulation
#   Note: the supply-use table above must be appropriate for the start year
#---------------------------------------------------------------------------
years:
    start:  2010
    end:    2040
```

### [Required input files](@id config-required-input-files)
The next block specifies the required [external parameter files](@ref params). Other, optional input files are described below. In many cases, the input files will be the same across a set of scenarios. However, it is possible that they might differ. For example, the [supply-use table](@ref sut), given by the `SUT` parameter, could be drawn from different years for calibration purposes, and different `time_series` might distinguish different scenarios.

This block also contains a flag saying whether the exchange rate time series, in the `time_series` file, is for the nominal or real exchange rate. This line can be omitted, in which case the default is for a nominal exchange rate. To specify a real exchange rate, set this equal to `true`.
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
    xr-is-real: false
```

### [Output folders](@id config-output-folders)
The following block says how to manage the [output folders](@ref model-outputs).

Ordinarily it is useful to clear the folders with each run, since files will in any case be overwritten. But sometimes during model development it is useful to set `clear-folders` to `false` temporarily -- for example, if only a few files need to be compared between one run to the next. To compare results from different runs, make a copy of output files of interest and set `clear-folders` to `false`, or copy the entire output file folder.

Reporting diagnostics is optional. It is highly recommended while developing a model, but `report-diagnostics` can be set to `false` for a model in active use.
```yaml
# Say whether to clear the contents of the results, calibration, and diagnostic folders before the run
clear-folders:
    results: true
    calibration: true
    diagnostics: true
# Set to "true" to send results to the diagnostics folder, including dumps of the linear goal program
report-diagnostics: true
```

### [LEAP run settings](@id config-leap-run-settings)
The next block has settings for running LEAP. To develop the Macro model independently of LEAP, set `run_leap` to `false`. To reduce the time spent while running LEAP and Macro together, set `hide_leap` to `true`. The `max_runs` parameter can normally be left at the default value; it is quite unusual to go that far before convergence. The `max_tolerance` is the percent difference in Macro model outputs between runs. The tolerance can be tightened (a smaller value) or loosened (a larger value) depending on the needs of the analysis.
```yaml
model:
    # Set run_leap to "false" to do a single run of the Macro model without calling LEAP
    run_leap: false
    # Hide LEAP while running to (possibly) improve performance
    hide_leap: false
    # Maximum number of iterations before stopping (ignored if run_leap = false)
    max_runs: 7
    # Tolerance in percentage difference between values for indices between runs
    max_tolerance: 1.0 # percent
```

### [Optional input files](@id config-optional-input-files)
The next block is optional, and can be entirely omitted. This block allows for additional exogenous time series that might be of interest in some studies. Any of them can be added or excluded individually. The allowed input files include:
  * `investment`: A time series of exogenous investment demand beyond that simulated by the model (e.g., public investment)
  * `pot_output`: Potential output, which will override the value simulated by the model, where the entered values are converted to an index (e.g., agricultural production might be determined by an independent crop production model)
  * `max_utilization`: Maximum capacity utilization (e.g., if an exogenous constraint prevents operation at full capacity)
  * `real_price`: Real prices for tradeables; the entered values are converted to an index by Macro and multiplied by an index of inflation at the user-specified world inflation rate
The format and purpose of these files are explained in more detail under [external parameter files](@ref params-optional-input-files), and examples of each type of file are included in the sample Freedonia model.

Because this block is optional, it can be deleted entirely or commented out (as in the Freedonia configuration file). Alternatively, individual files can be commented out or set to "`~`", which is the way to signal a missing value in YAML.
```yaml
#---------------------------------------------------------------------------
# Optional input files for exogenous time series (CSV files)
#---------------------------------------------------------------------------
# Uncomment the lines below to use the files included in the Freedonia sample model
# For pot_output and max_utilization, include only those sectors where values are constrained -- the others will be unconstrained
# For real_price:
#   * Include only those products where values are specified -- for others the real price will be held constant
#   * Prices for non-tradeables will be ignored; they are calculated internally by Macro
exog-files:
    # investment: exog_invest.csv # Time series of exogenous investment demand, additional to that simulated by the model
    # pot_output: exog_pot_output.csv # Potential output (any units -- it is applied as an index): sectors label columns; years label rows
    # max_utilization: exog_max_util.csv # Maximum capacity utilization: sectors label columns; years label rows (must lie between 0 and 1)
    # real_price: exog_price.csv # Real prices for tradeables (any units -- it is applied as an index): products label columns; years label rows
```

## [Model parameters](@id config-model-params)
The next several blocks contain some of the [exogenous parameters](@ref exog-param-vars) for the Macro model that are not specified in the files identified in earlier blocks.

### [Initial value adjustments](@id config-init-val-adj)
The first block of model parameters specifies adjustments to initial values. They can be used to make a correction if, for example, the economy was recovering from a recession in the first year of the simulation. These parameters should normally be set to zero when starting a calibration.
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
    pot_output_adj_factor: 0.05
```

### Default values for the global economy
The second block of model parameters provides default values for the global inflation rate and growth rate of global GDP (or gross world product, GWP). These are applied if they are not specified for some year in the [external time-series file](@ref params-time-series). Also, the default global inflation rate is applied to price indices when initializing the model.

The correspondence between the parameters and the [model variables](@ref exog-param-vars) is:
  * `infl_default` : ``\underline{\pi}_{w,k}`` (applied uniformly to all products ``k``, modified by the optional `real_price` file in the `exog-files` block)
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

The correspondence between the parameters and the [model variables](@ref exog-param-vars) is:
  * `neutral_growth_band` : ``[\hat{\underline{Y}}^*_\text{min},\hat{\underline{Y}}^*_\text{max}]``
  * `target_intrate` :
    * `init` : ``\underline{i}^\text{init}_{b0}``
    * `band` : ``[\underline{i}^\text{min}_{b0},\underline{i}^\text{max}_{b0}]``
    * `xr_sens` : ``\underline{b}_\text{xr}``
    * `adj_time` : ``\underline{T}_\text{xr}``
  * `target_infl` : ``\underline{\pi}^*``
  * `init_infl` : ``\underline{\pi}_d^\text{init}``
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
    target_intrate:
        init: 0.04
        band: [0.01, 0.10]
        xr_sens: 1
        adj_time: 2 # years
    # Target inflation rate (if missing or if value set to "~", will use global inflation rate)
    target_infl: 0.02
    # Initial inflation rate for domestic prices (if missing, or if value set to "~", will use target inflation rate)
    init_infl: 0.04
    # Response of the central bank rate to a change in the GDP growth rate
    gr_resp: 0.50
    # Response of the central bank rate to a change in the inflation rate
    infl_resp: 0.50
```

### Investment function coefficients
The next block contains the parameters for the investment function. As explained in the page on [model dynamics](@ref dynamics-potential-output), the investment function calculates the demand for investment goods as a function of capacity utilization, profitability, and borrowing costs.

The correspondence between the parameters and the [model variables](@ref exog-param-vars) is:
  * `init_neutral_growth`: Initial value of ``\gamma_{i0}`` (with the same initial value for every sector ``i``)
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

### [Employment, labor productivity, and wages](@id config-empl-labprod-wage)
The next block contains default parameters for the labor productivity function (following the Kaldor-Verdoorn law[^1]) and for the function that determines the growth rate of the wage. See the page on [model dynamics](@ref dynamics-wages-labor-prod) for details.

For labor productivity, the default parameters are used if they are not specified for some year (or if the column is omitted) in the [external time-series file](@ref params-time-series).

The correspondence between the parameters and the [model variables](@ref exog-param-vars) is:
  * For labor productivity:
    - `KV_coeff_default` : ``\underline{\alpha}_\text{KV}``
    - `KV_intercept_default` : ``\underline{\beta}_\text{KV}``
  * For the wage:
    - `infl_passthrough` : ``\underline{h}``
    - `lab_constr_coeff` : ``\underline{k}``
```yaml
#---------------------------------------------------------------------------
# Parameters for labor productivity, labor force, and wages
#---------------------------------------------------------------------------
labor-prod-fcn:
    # Default Kaldor-Verdoorn coefficient
    KV_coeff_default: 0.50
    # Default Kaldor-Verdoorn intercept
    KV_intercept_default: 0.00
wage-fcn:
    # Inflation pass-through (wage indexing coefficient)
    infl_passthrough: 1.00
    # Labor supply constraint coefficient
    lab_constr_coeff: 0.50
```
[^1]: The [Kaldor-Verdoorn law](https://www.encyclopedia.com/social-sciences/applied-and-social-sciences-magazines/verdoorns-law) states that the growth rate of labor productivity is an increasing function of the growth rate of output. In its original form it applies only to manufacturing, and the influences are weaker in services and agriculture. In the Macro model, an economy-wide labor productivity rate is calculated as an increasing function of the GDP growth rate.

### [Endogenous change in intermediate demand coefficients](@id config-intermed-dmd-change)
The next block is optional. If it is present, it sets a rate constant for endogenously determining [intermediate demand coefficients](@ref dynamics-intermed-dmd-coeff).

Note that if the `rate_constant` parameter is set too high, then it can generate unreasonably large rates of change in technical coefficients and can even create model instabilities. It is good practice to check [the `diagnostics` folder](@ref model-outputs-diagnostics) for annual files labeled `demand_coefficients_[year].csv` to see whether the values are reasonable.
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
Initial values for demand elasticities for products with respect to domestic vs. world prices, global GDP (for exports), and the wage bill (for domestic final demand excluding investment) are specified in the [external product parameters file](@ref params-products). The way that the elasticities enter into the model is described in the page on [model dynamics](@ref dynamics-export-demand).

For products that are not labeled as "Engel products"[^2] (given by the parameter `engel-prods`):
  * If the initial wage elasticity is less than one, then it remains at its starting level;
  * If the initial wage elasticity is greater than one, it asymptotically approaches a value of one over time;
For products labeled as Engel products:
  * The wage elasticity approaches the `engel_asympt_elast` over time.
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
[^2]: [Engel's Law](https://www.investopedia.com/terms/e/engels-law.asp) states that as income rises, the proportion of income spent on food declines. That means that the income elasticity of expenditure on food is less than one.

### [Linear goal program weights](@id config-lgp-weights)
The Macro model solves a linear goal program for each year of the simulation. As described in the documentation for the [linear goal program](@ref lgp), the objective function contains weights, which are specified in the next block. The default weights should be suitable for most LEAP-Macro applications.

The correspondence between the parameters and the [model variables](@ref exog-param-vars) is:
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
The next block is for specifying the structure of the [supply-use table](@ref sut) and how it relates to variables in Macro.

The first section of this block specifies sectors and products that are excluded from the simulation. The entire section or any item can be excluded. Alternatively, items can be set to the empty list `[]` or to YAML's "no value" symbol, `~`.

There are three categories:
1. First, and most important, are energy sectors and products. Those are excluded from the Macro calculation because the energy sector analysis is handled on a physical basis within LEAP, although they can optionally be included when [running the model](@ref running-macro) in stand-alone mode, without LEAP.
2. Second are any territorial adjustments. Macro recalculates some parameters to take account of those entries. If none are present in the supply-use table, then an empty list `[]` can be entered for this parameter, as in the sample Freedonia model file shown below.
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

Following that is a list of non-tradeable products and a domestic production share threshold. Imports and exports of products declared non-tradeable are set to zero within the Macro model, if they are not already zero in the supply-use table, and are maintained at zero throughout the simulation.

Other products may be almost entirely imported. That can sometimes cause difficulties. If the domestic share of the total of imports and domestic production falls below the threshold specified in the configuration file, then the corresponding sector (but not the product) is excluded during the simulation.
```yaml
non_tradeable_products: [constr, comm]

# Domestic production as a % share of the total of imports and domestic production must exceed this value
domestic_production_share_threshold: 1.0 # percent
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

## [Mapping Macro to LEAP](@id config-link-LEAP)
The next, and final, block specifies how LEAP and Macro are linked. Each of these entries is optional.

### Core LEAP model information
The first section in this block says which LEAP scenario to send and retrieve results to and from, and for which region. It also identifies the first historical year, if that is different from the start year. (The `last_historical_year` is the year just before LEAP's `First Scenario Year`.)

If this section is omitted, then results are sent to and retrieved from the scenario currently active in LEAP, and for the currently active region (if any regions are specified). The `last_historical_year` is set to the start year.
```yaml
#---------------------------------------------------------------------------
# Parameters for running LEAP with the Macro model (LEAP-Macro)
#---------------------------------------------------------------------------
# Core information for the LEAP application (optional)
LEAP-info:
    # The last historical year (equal to LEAP's First Scenario Year - 1): if missing, it is set equal to the the start year
    last_historical_year: 2010
    # This can be, e.g., a baseline scenario (alternatively, can specify input_scenario and result_scenario separately)
    scenario: Baseline
    # The region (if any -- can omit, or enter a "~", meaning no value)
    region: ~
```
Alternatively, separate scenarios can be specified if LEAP receives inputs from Macro for one scenario (`input_scenario`), but sends results back to Macro from another scenario (`result_scenario`). In this case, `scenario` should be omitted, or set to `~` (meaning "no value"). For example,
```yaml
#---------------------------------------------------------------------------
# Parameters for running LEAP with the Macro model (LEAP-Macro)
#---------------------------------------------------------------------------
# Core information for the LEAP application (optional)
LEAP-info:
    # The last historical year (equal to LEAP's First Scenario Year - 1): if missing, it is set equal to the the start year
    last_historical_year: 2010
    # Scenarios
    input_scenario: Baseline
    result_scenario: Capital Plan
    ...
```

### Pulling investment information from LEAP into Macro
The next section specifies information regarding investment. By default, any investment reported in LEAP in a given year is totaled and passed to Macro with no adjustment: `inv_costs_units` is set to a blank (so LEAP applies the default currency unit) and `inv_costs_scale` is set to 1.0. However, some investment branches can be omitted, investment can be spread over several years, the currency unit can be set to a different value, and the scaling factor can be specified.

As an example for setting the scaling factor, if entries in the Macro model input files are in millions of US dollars, and investment costs in LEAP are reported in US dollars, then the scaling factor is one million (1000000 or 1.0e+6).

The `excluded_branches` entry is set to an empty list `[]` in the Freedonia example below. This entry is particularly useful if NEMO is run with a backstop technology. Any "investment" in the backstop technology is actually needed supply expansion that was not achieved, so the value should be ignored.

The Freedonia configuration file below shows three different ways to specify how costs are spread over multiple years. If this entry is blank, then the default is that all expenditure occurs in one year. Otherwise, a default value can be set that is applied to all branches -- in the example, it is set to 5 years, but it could also be specified as a pattern of expenditure over time. Additionally, a value or pattern can be set for specific branches. An example of each is shown below.

If expenditure is set as a pattern, then it is specified as a list of values in brackets `[]`. The values in the configuration file will be rescaled so that they sum to one. The example below sums to 100, so 10% of expenditure is in the first year, 20% in the second, and so on.
```yaml
LEAP-investment:
    # Currency units for investment costs
    inv_costs_unit: U.S. Dollar
    # Scaling factor for investment costs (values are divided by this number, e.g., for thousands use 1000 or 1.0e+3)
    inv_costs_scale: 1.0e+6
    # Exclude any investment branches that contain any of the text in the list (case-insensitive)
    excluded_branches: []
    distribute_costs_over:
        default: 5 # years: This will be rounded to an integer
        by_branch:
            - {
                path: Transformation\Electricity Generation\Processes\Existing Hydro,
                value: 10 # years: This will be rounded to an integer
            }
            - {
                path: Transformation\Electricity Generation\Processes\New Oil Combustion Turbine,
                value: [10, 20, 20, 20, 10, 10, 5, 5] # percent by years: This will be re-scaled so it sums to 1.0
            }
```

### Passing values from Macro to LEAP
The next sections specify where in LEAP to put indices as calculated by Macro. For each index, LEAP should contain at least one historical value, while the index supplied by Macro is applied to the last historical value in the specified `result_scenario`. Indices appear as columns in an `indices_#.csv` file in the [`results` output folder](@ref model-outputs-results), where `#` is the run number.

The first index is for GDP. It can be omitted, but if it is present, the entry in the configuration file gives the name for the index, the LEAP branch and variable where the index should be inserted and, to cover cases where the last historical year is after the base year, the last historical year.
```yaml
# Association between Macro's GDP result and LEAP (optional)
GDP-branch:
    name: GDP
    branch: Key\GDP
    variable: Activity Level
```

The second index is also optional, and has the same structure as for GDP.
```yaml
# Association between Macro's employment result and LEAP (optional)
Employment-branch:
    name: Employment
    branch: Key\Employment
    variable: Activity Level
```

Finally, the `LEAP-sectors` parameter, if present, contains a list of indices. For each of these, Macro will sum up production[^3] across all of the sector codes listed. It will then calculate an index starting in the base year, and insert the index into the specified branches. In some cases, the same index might be applied to different branches. For example, if the supply-use table has a "services" sector but no transport, while LEAP has both a services and a commercial transport sector, the same index could be used to drive both.

If no sectoral aggregation is desired, then this entry can be excluded entirely, set to `~` (meaning no value), or set to an empty list: `LEAP-sectors: []`.
```yaml
# Association between Macro sectors and LEAP sectors (optional)
LEAP-sectors:
 - {
    name: Iron and Steel,
    codes: [ironstl],
    branches: [
        {
         branch: Demand\Industry\Iron and Steel,
         variable: Activity Level
        }
    ]
   }
 - {
    name: Other Industry,
    codes: [foodpr, hvymach, othind],
    branches: [
        {
         branch: Demand\Industry\Other Industry,
         variable: Activity Level
        }
    ]
   }
   ...
```
[^3]: Production is arguably a better measure of sector activity than is value added. Value added subtracts from the value of production the cost of intermediate goods and services, to avoid double-counting when calculating gross domestic product (GDP).

### [Passing potential output and prices from LEAP to Macro](@id config-pass-vals-LEAP-to-Macro)
The final sections say how to pass results for potential output and prices from LEAP to Macro. These are in addition to investment expenditure, which is automatically collected from LEAP and passed to Macro. Any values for potential output and prices drawn from LEAP override those specified in external [input files](@ref params-optional-input-files), if any. (Investment expenditure from LEAP is added to investment specified in external input files.)

The Freedonia configuration file does not specify potential output and prices from LEAP, so the entries are set equal to empty lists. Alternatively, they can be completely ommitted or set to the YAML "no value" symbol, `~`.
```yaml
LEAP-potential-output: []

LEAP-prices: []
```

To demonstrate how these sections might look, suppose that instead of excluding the `coal` sector as is done in the [link to the supply-use table](@ref config-sut), above, it is included in the Macro model, but potential output from the sector is provided by LEAP. That can be accomplished by setting
```yaml
excluded_sectors:
    energy: [petr, util]
excluded_products:
    energy: [petr, util]
```
and then adding an entry like
```yaml
LEAP-potential-output:
 - {
    branches: [
        {
         branch: Resources\Primary\Coal Bituminous,
         variable: Indigenous Production
        }
    ],
    code: coal
   }
```
Potential output is associated with a single sector in the Macro model, but can include values from multiple LEAP branches. If more than one LEAP branch is listed, then the values are summed together.

If the price of coal is available from the LEAP model, then it can be brought into Macro using an entry like
```yaml
LEAP-prices:
 - {
    branch: Resources\Primary\Coal Bituminous,
    variable: Indigenous Cost,
    codes: [coal]
   }
```
Prices are associated with a single LEAP branch, but can be applied to multiple sectors in Macro.
