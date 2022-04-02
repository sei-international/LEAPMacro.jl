```@meta
CurrentModule = LEAPMacro
```

# [Quick start](@id quick-start)

This documentation explains how to quickly run Macro without linking it to LEAP. To learn how to run Macro with LEAP, see the LEAP exercise for the LEAP-Macro plugin available to registered users on the [LEAP](https://leap.sei.org/) website.

The quickest way to get started with Macro is by running the demonstration model that is part of the GitHub distribution.
```@raw html
<p>First, <a href="https://downgit.github.io/#/home?url=https://github.com/sei-international/LEAPMacro/tree/main/test&rootDirectory=false" target="_blank">Download the demonstration files</a> as a zip file from GitHub and save it to the folder of your choice. (Clicking on the link will open a new window, where the zip file can be downloaded.)</p>
```
Next:
1. Unzip the `test.zip` file
2. Go the folder where you unzipped it (it will have a file in it named `LEAPMacro_params.yml`)
3. Start Julia and run the demo model:
```
julia> import LEAPMacro

julia> LEAPMacro.run()
Macro model run (0)...completed
0
```
If you see `Macro model run (0)...completed` followed by `0` then the model ran without any errors.

All of the interesting output is in files. You should see a new file called `LEAPMacro_log.txt` and a new `outputs` folder.

## The log file
The log file should show something like:
```
[ Info: 2022-03-25T11:55:23.846
[ Info: Configuration file: 'LEAPMacro_params.yml'
[ Info: Macro model run (0)...
[ Info: Loading data...
[ Info: Preparing model...
[ Info: Calibrating: FEASIBLE_POINT
[ Info: Running from 2010 to 2040:
[ Info: Simulating for 2010: FEASIBLE_POINT
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
[ Info: 2022-03-25T11:55:57.797
```
The time stamps at the start and end show that the model ran in 34 seconds. The repeated `FEASIBLE_POINT` for each year means that the model in each year yielded a feasible solution to the linear program.

## The outputs folder
The `outputs` folder should have a subfolder called `Baseline`. Inside that folder are three other folders, with CSV files containing diagnostic information and the results of the model run:
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
