```@meta
CurrentModule = LEAPMacro
```

# [Quick start](@id quick-start)

This documentation explains how to quickly run Macro without linking it to LEAP. To learn how to run Macro with LEAP, see the [LEAP exercise](@ref leap-exercise), but it is a good idea to follow this Quick Start first.

The quickest way to get started with Macro is by running the "Freedonia" sample model:
1. Download the [demonstration files](assets/Macro.zip) as a zip file and save it to the folder of your choice
1. Unzip the `Macro.zip` file
1. Go the folder where you unzipped it (it will have a file in it named `LEAPMacro_params.yml`, together with several other files)
1. Start Julia in that folder and run the demo model:
```
julia> import LEAPMacro

julia> LEAPMacro.run()
With configuration file 'LEAPMacro_params.yml':
Macro model run (0)...completed
0
```
If you see `Macro model run (0)...completed` followed by `0` then the model ran without any errors. The line reading `With configuration file 'LEAPMacro_params.yml'` says that Macro found and applied a [configuration file](@ref config) with the default filename `LEAPMacro_params.yml`.

All of the interesting output is in files. You should see a new file called `LEAPMacro_log_Baseline.txt` and a new `outputs` folder.

## The log file
The log file `LEAPMacro_log_Baseline.txt` should show something like:
```
[ Info: 2022-08-21T10:43:55.627
[ Info: Configuration file: 'LEAPMacro_params.yml'
[ Info: Macro model run (0)...
[ Info: Loading data...
[ Info: Preparing model...
[ Info: Calibrating for 2010: FEASIBLE_POINT
[ Info: Running from 2011 to 2040:
[ Info: Simulating for 2011: FEASIBLE_POINT
[ Info: Simulating for 2012: FEASIBLE_POINT
[ Info: Simulating for 2013: FEASIBLE_POINT
[ Info: Simulating for 2014: FEASIBLE_POINT
[ Info: Simulating for 2015: FEASIBLE_POINT
...
[ Info: Simulating for 2035: FEASIBLE_POINT
[ Info: Simulating for 2036: FEASIBLE_POINT
[ Info: Simulating for 2037: FEASIBLE_POINT
[ Info: Simulating for 2038: FEASIBLE_POINT
[ Info: Simulating for 2039: FEASIBLE_POINT
[ Info: Simulating for 2040: FEASIBLE_POINT
[ Info: 2022-08-21T10:44:28.068
```
The time stamps at the start and end show that the model ran in 32 seconds. The repeated `FEASIBLE_POINT` for each year means that the model in each year yielded a feasible solution to the [linear goal program](@ref lgp).

## The outputs folder
The `outputs` folder should have a subfolder called `Baseline`. Inside that folder are three other folders, with CSV files containing diagnostic information and the results of the model run.

!!! info "Comma-separated variable (CSV) files"
    CSV-formatted files are plain text files that can be viewed in a text editor. They can also be opened and modified in Excel, Google Sheets, or other spreadsheet program, which is a convenient way to edit them. 

The folder structure looks like this:
```
otuputs 
└───Baseline
    └───calibration
        │   basic_prices_0.csv
        │   capacity_utilization_0.csv
        │   ...
        │   wage_share_0.csv
    └───diagnostics
        │   demand_coefficients.csv
        │   domestic_production.csv
        │   ...
        │   wages.csv
    └───results
        │   autonomous_investment_rate_0.csv
        │   basic_prices_0.csv
        │   ...
        │   sector_output_0.csv
```
There is a great deal of information in the files: see the pages on the [configuration file](@ref config) and the [output files](@ref model-outputs).
