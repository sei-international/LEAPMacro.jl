```@meta
CurrentModule = LEAPMacro
```

# [Output files](@id model-outputs)
When Macro is run, it generates several output files in the following folders:
```
otuputs 
└───NAME
    └───calibration
    └───[diagnostics]
    └───results
```
The `NAME` of the folder under `outputs` is specified by the `output_folder` parameter in the [configuration file](@ref config-general-settings). The `diagnostics` folder is only present if the `report-diagnostics` parameter is set to `true` in the [configuration file](@ref config-output-folders).

Different scenarios can be specified by different configuration files, with different `output_folder` parameters set. In that case, there will be several folders:
```
otuputs 
└───NAME 1
    └───calibration
    └───[diagnostics]
    └───results
└───NAME 2
    └───calibration
    └───[diagnostics]
    └───results
...
```

In addition, Macro writes a log file called `LEAPMacro_log_XXXX.txt` to the main folder, where `XXXX` is the `output_folder` specified in the [configuration file](@ref config-general-settings). If the model fails, then the error message will be written to the log file.

!!! info "Naming convention when Macro is run with energy sectors included"
    The Macro model is meant to be run together with LEAP, as explained in the page on the [LEAP-Macro link](@ref leap-macro-link). LEAP calculates demand for energy and energy production, while Macro covers the rest of the economy -- the energy sectors specified in the [configuration file](@ref config-sut) are excluded from Macro's calculations. However, for calibration it can be useful to run Macro separately from LEAP, with the energy sectors included. This is done by setting `include_energy_sectors = true` when calling the `LEAPMacro.run()` function (see [Running the Macro model](@ref running-macro) for details.)

    When Macro is run with energy sectors included, the output folder is named `XXXX_full`, where `XXXX` is the `output_folder` specified in the [configuration file](@ref config-general-settings).


## [The `diagnostics` folder](@id model-outputs-diagnostics)
When the `report-diagnostics` parameter is set to `true`, a variety of diagnostic outputs are reported.

One crucial diagnostic indicator, which is motivated in [Isolating the energy sector](@ref isolate-energy) is given in the file `nonenergy_energy_link_measure.txt`. It contains a message like the following:
```
Measure of the significance to the economy of the supply of non-energy goods and services to the energy sector:
This value should be small: 2.52%.
```
Whether the estimated parameter is sufficiently small or not depends on the purposes of the analysis. For the Freedonia sample model, it suggests that excluding the demand by the energy sector of non-energy goods and services could lead to a 2.52% discrepancy.

An additional set of files with names such as `model_0_2010.txt` provide an export of the [linear goal program](@ref lgp) prepared by the Macro model. Examining these files can sometimes be helpful when the log file indicates an error in JuMP (the Julia mathematical programming library). The file offers an explicit formulation of the model, with the calculated parameters:
```
Min 1.7333333333333334 ugap[1] + 0.5333333333333333 ugap[2] + 0.6000000000000001 ugap[3] + ...
Subject to
 eq_util[1] : ugap[1] + u[1] == 1.0
 eq_util[2] : ugap[2] + u[2] == 1.0
 eq_util[3] : ugap[3] + u[3] == 1.0
 eq_util[4] : ugap[4] + u[4] == 1.0
...
```

Some of the files provide "sanity checks" on the input data. 
  * `demand_coefficients.csv`: These should sum to a total less than one down the columns
  * `[energy_share.csv]`: If present, these should be less than one (only reported if energy sectors are excluded)
  * `imported_fraction.csv`: These should be less than one
  * `profit_margins.csv`: These should be greater than 1 but (usually) less than 2
  * `supply_fractions.csv`: These should sum to one along columns (unless the product is not produced domestically, in which case the sum will be zero)

Other files report figures that should be close to, although not necessarily identical to, the corresponding values in the supply-use table. The differences arise because Macro compensates for territorial adjustments or stock changes:
  * `domestic_production.csv`
  * `exports.csv`
  * `final_demand.csv`
  * `imports.csv`
  * `investment.csv`
  * `margins.csv`
  * `sector_output.csv`
  * `tot_intermediate_demand_all_products.csv`
  * `tot_intermediate_supply_all_sectors.csv`
  * `tot_intermediate_supply_non-energy_sectors.csv`: Note that these values will be lower than in the supply-use table due to the excluded energy sectors
  * `wages.csv`

If intermediate demand coefficients are [calculated endogenously](@ref config-intermed-dmd-change), then a further set of files will be reported containing tables of intermediate demand coefficients for each year of the simulation:
  * `demand_coefficients_[year].csv`

## The `calibration` folder
The files in this folder are generated after further adjustments and a calibration run of the [linear goal program](@ref lgp). Some of these files can also be used as a "sanity check", including:
  * `basic_prices_0.csv`: These should be close to 1
  * `capacity_utilization_0.csv`: These should be less than or equal to 1, and most should be close to 1
  * `capital_output_ratio_0.csv`: These should normally lie between 1 and 4, but may be outside that range
  * `margins_neg_0.csv` and `margins_pos_0.csv`: These should sum to the same total
  * `wage_share_0.csv`: These should be less than 1

Others of the files in the `calibration` folder have names similar to the `diagnostics` folder. The values may be noticeably different due to the adjustments carried out by the Macro model:
  * `domestic_production_0.csv`
  * `exports_0.csv`
  * `final_demand_0.csv`
  * `imports_0.csv`
  * `sector_output_0.csv`
  * `tot_intermediate_supply_non-energy_sectors_0.csv`

## [The `results` folder](@id model-outputs-results)
The `results` folder contains the simulation results from the model. Once the model is fully developed, calibrated, and running in practice, this is the most interesting folder to look at.

When running with LEAP, the Macro model may be run several times to converge on a consistent set of results. The results folder contains outputs from each of the runs:
![Results folder contents](assets/images/results_folder_files.png)

!!! warning "Results cover only non-energy sectors"
    By default, the Macro model reports results only for non-energy sectors. To include all sectors, set the option `include_energy_sectors = true` when [running the Macro model](@ref running-macro). 

Two of the results files (with the run number indicated by `#`) contain multiple variables:
  * `indices_#.csv`: The indices that are passed to LEAP, as specified in the [configuration file](@ref config-indices-for-LEAP-Macro-link) (if no indices are defined, then this file will not be written)
  * `collected_variables_#.csv`: A set of key variables, such as the current accounts balance, GDP, and so on

Macro is a [demand-driven model](@ref theoretical-background), so economic growth is driven by final demand, exports net of imports, and investment. Total investment expenditure is reported in `collected_variables_#.csv`. Final demand, exports, and imports are reported by product:
  * `final_demand_#.csv`
  * `exports_#.csv` and `imports_#.csv`

Output by sector is reported as actual output and potential output (that is, output at full capacity utilization). The ratio of actual to potential output is capacity utilization, which is reported separately:
  * `sector_output_#.csv`
  * `potential_sector_output_#.csv`
  * `capacity_utilization_#.csv`
Real value added by sector -- that is, sector output less the cost of intermediate goods and services -- is also reported:
  * `real_value_added_#.csv`

Investment rates are determined by the autonomous investment rate, the profit rate, capacity utilization, and the interest rate. The autonomous investment rate is an expectation of future growth, which gradually adjusts over time in response to realized growth (that is, [the model features "adaptive expectations"](@ref dynamics-potential-output)). The interest rate is reported in `collected_variables_#.csv`, while the capacity utilization file was listed above. The other relevant files are:
  * `profit_rate_#.csv`
  * `autonomous_investment_rate_#.csv`

In Macro, world prices of tradeable goods and services are exogenous, so they are not reported. Domestic prices are [calculated endogenously by applying a markup](@ref dynamics-prices). "Basic" prices of goods and services are calculated as a trade-weighted average of the world and domestic price. Domestic and basic prices are reported in the files:
  * `domestic_prices_#.csv`
  * `basic_prices_#.csv`
