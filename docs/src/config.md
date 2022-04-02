```@meta
CurrentModule = LEAPMacro
```

# [Configuration file](@id config)

The configuration file is written in YAML syntax and has a `.yml` extension. By default, Macro assumes the configuration file will be called `LEAPMacro_params.yml`, but other names are possible, and in fact encouraged, because each configuration file corresponds to a different scenario.

## High-level settings

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

The following block says how to manage the output folders. Reporting diagnostics is optional. It is highly recommended while developing a model, but `report-diagnostics` can be set to `false` for a model in active use. Ordinarily it is useful to clear the folders with each run, since files will be overwritten. Sometimes during model development it is useful set `clear-folders` to `false` temporarily. Output files from one run can be renamed, so they are not overwritten in a subsequent run and the results compared.
```yaml
# Say whether to clear the contents of the results, calibration, and diagnostic folders before the run
clear-folders:
    results: true
    calibration: true
    diagnostics: true
# Set to "true" to send results to the diagnostics folder, including dumps of the linear goal program
report-diagnostics: true
```

The next block sets the start and end years for the simulation. These should normally be the same as the base year and final year in LEAP, and the start year should be appropriate for the supply-use table. However, during model development, the start year might be set to an earlier value to calibrate against historical data. Also, the end year can be set closer to the start year, but Macro normally runs quickly, so that is rarely necessary for performance.
```yaml
#---------------------------------------------------------------------------
# Start and end years for the simulation
#   Note: the supply-use table above must be appropriate for the start year
#---------------------------------------------------------------------------
years:
    start:  2010
    end:    2040
```

## Model parameters
<!-- TODO: Fill in model parameters -->

## Linking to the supply-use table
The next block is for specifying the structure of the supply-use table and how it relates to Macro.

The first section of this block specifies sectors and products that are excluded from the simulation. There are three categories:
1. First, and most important, are energy sectors and products. Those are excluded from the Macro calculation because the energy sector analysis is handled on a physical basis within LEAP.
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
