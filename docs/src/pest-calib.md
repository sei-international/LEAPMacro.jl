```@meta
CurrentModule = LEAPMacro
```

# [Calibrating with PEST](@id pest-calib)
Calibrating a Macro model can sometimes require very many iterations of _running_ -- _changing parameters_ -- _rerunning_ -- _comparing results_. When this is the case, it is best to take a systematic approach, but that adds the burden of keeping track of prior changes and results. Automated calibration can make the process much easier.

Starting with version 2.2.5, the LEAP-Macro [demonstration files](assets/Macro.zip) come with a Julia script called `pest.jl` that will run the freely-available third-party parameter estimation tool [PEST](https://pesthomepage.org/). Together with its associated files `pest_run_leapmacro.jl` and `pest_config.yml`, the script first builds the input files needed by PEST and then, if PEST installed (see the [PEST download page](https://pesthomepage.org/programs)), it runs the PEST program.

## About PEST
PEST was first written in 1994. Since then, it has been under continual development. It is widely used in environmental applications. From the [PEST homepage](https://pesthomepage.org/),

> “PEST” refers to a software package and to a suite of utility programs which supports it. Collectively, these are essential tools in decision-support environmental modelling.
> 
> PEST, the software package, automates calibration, and calibration-constrained uncertainty analysis of any numerical model. It interacts with a model through the model’s own input and output files. While estimating or adjusting its parameters, it runs a model many times. These model runs can be conducted either in serial or in parallel. PEST records what it does in easily-understood output files.

The software suite supports and extends the core PEST functionality. The full PEST suite is quite powerful, but LEAP-Macro's `pest.jl` script uses only one tool in the suite, `pestchek.exe`, to check that the PEST input files are correctly prepared. It then runs the main program `pest.exe` in serial mode.

As the description claims, PEST can work with an enormous variety of models by accommodating a wide range of input and output files. The only requirement is that they are text files. Beyond that, PEST can work with nearly any file format. Moreover, PEST has numerous options to overcome problems in specific models, or to take advantage of their features.

## About LEAP-Macro's PEST script
The practical consequence of PEST's flexibility is that its input files can be challenging to build, update, and modify for use in later projects. The `pest.jl` script makes the process much easier for LEAP-Macro applications. The configuration file for the `pest.jl` script, `pest_config.yml`, includes options specific to LEAP-Macro while offering a subset of the PEST options.

!!! tip "Editing the PEST input files"
    The `pest.jl` script pre-fills many PEST parameters with reasonable values. Once the PEST input files are created, you are free to edit the PEST input files and assign different values to the pre-filled parameters. You can then run PEST by hand.

The `pest.jl` program has several command-line options. Each option has a default. The options and their defaults are:
```
usage: pest.jl [-p PEST_CONFIG_FILE] [-c CONTROL_FILE] [-h] [config_file]

positional arguments:
  config_file                               name of LEAP-Macro config file (default: "LEAPMacro_params.yml")

optional arguments:
  -p, --pest-config-file PEST_CONFIG_FILE   name of PEST config file (default: "pest_config.yml")
  -c, --control-file CONTROL_FILE           name to assign the control file (default: "LEAPMacro_control.pst")
  -h, --help                                show this help message and exit
```

Below is part of the output from running the `pest.jl` script included in the LEAP-Macro demonstration files. The model is called 161 times, which would have taken a great deal of time if done by hand, and the optimum values for the parameters are chosen in a systematic way. Some points to note:
  * The PEST program must be downloaded from the [PEST website](https://pesthomepage.org/programs) and installed before the script can be run, and the script will issue an error and halt if `pest.exe` cannot be found;
  * The script builds three kinds of files: a template file (ending in `.tpl`), instruction files (ending in `.ins`), and a control file (ending in `.pst`);
  * As recorded in the `Model command line:` the PEST control file calls the script `pest_run_leapmacro.jl`, which runs the Macro model;
  * The model is run with a sysimage `LEAPMacro-sysimage.so`, which dramatically reduces the time it takes to load LEAP-Macro (see the Tip on "Speeding up LEAPMacro with a pre-compiled system image" in the page on [running the Macro model](@ref running-macro));
  * The `pestchek.exe` program issues a warning, but that is not a problem: both PEST and the script allow output files to be used multiple times;
  * Information on the calibration is provided in files ending in `.rec`, `.sen`, `.res`, and `.svd`. (PEST produces a large number of other files as well.)
```
C:\path\to\model> julia .\pest.jl
Generating PEST template file...
Generating PEST instruction file(s)...
Generating PEST control file...
Checking files...

PESTCHEK Version 17.3. Watermark Numerical Computing.

Errors ----->
No errors encountered.

Warnings ----->
Model output file collected_variables_0.csv read using more than one
  instruction file.
Running PEST...

PEST Version 17.3. Watermark Numerical Computing.

PEST is running in parameter estimation mode.

PEST run record: case leapmacro_control
(See file leapmacro_control.rec for full details.)

Model command line:
julia --sysimage=LEAPMacro-sysimage.so pest_run_leapmacro.jl LEAPMacro_params_calib.yml -c -e -v -s 1 -d collected_variables_0.csv

Running model .....

   Running model 1 time....Running LEAP-Macro...
With configuration file 'LEAPMacro_params_calib.yml' (including energy sectors):
Macro model run (0)...completed

   Sum of squared weighted residuals (ie phi)               =  5.32221E-03
   Contribution to phi from observation group "labgr"       =  1.31664E-03
   Contribution to phi from observation group "gdpgr"       =  4.00556E-03
```
..._several hundred lines omitted_...
```
   No more lambdas: relative phi reduction between lambdas less than 0.0300
   Lowest phi this iteration:  2.47742E-03
   Maximum relative change: 0.6270     ["intrate_sens"]

   Optimisation complete:   3 optimisation iterations have elapsed since lowest
                          phi was achieved.
   Total model calls:    161

Running model one last time with best parameters.....Running LEAP-Macro...
With configuration file 'LEAPMacro_params_calib.yml' (including energy sectors):
Macro model run (0)...completed


Recording run statistics .....

See file leapmacro_control.rec for full run details.
See file leapmacro_control.sen for parameter sensitivities.
See file leapmacro_control.seo for observation sensitivities.
See file leapmacro_control.res for residuals.
See file leapmacro_control.svd for history of SVD process.
```

## The `pest_config.yml` file
All of the operation of the `pest.jl` script is controled from a configuration file. By default, it is called `pest_config.yml`. The configuration file has two main blocks, `pest:` and `LEAP-Macro`:
```yaml
pest:
  program_path: \path\to\pest\program
  ...
LEAP-Macro:
  output_folder: Calibration
  ...
```

The structure of each of the blocks can be illustrated using the example from the [demonstration files](assets/Macro.zip). If PEST is installed, this script can be run from the command line using the Macro model distributed in the demonstration files.

### The `pest:` block
The `pest:` block starts with some basic settings. The `program_path:` should point to the folder where you have installed the [PEST programs](https://pesthomepage.org/programs). The other settings can be changed if desired, but they are suitable for calibration runs.
```yaml
pest:
  program_path: C:\pest17
  delimiter: "|"
  precision: single # Can be "single" or "double"
  allow_restart: true
  max_iterations: 30 # Per parameter estimation run -- there can be many runs (see p. 78 in the PEST User Manual Part I for 0, -1, -2)
```
The next sub-block, `parameters:` provides names, initial values, and ranges for the parameters that will be adjusted between runs of the model. Any name will do, as long as it consists of letters, digits, and underscores, and does not exceed 12 characters in length.

Values are entered as `[minimum, initial, maximum]`. Given the assumptions made by the `pest.jl` script, the initial value cannot be zero. It should also not be too small in comparison to the maximum value. If the initial value must be zero or very small, then the PEST control file generate by the `pest.jl` script (which will have a `.pst` extension) can be edited by hand.
```yaml
  # Assign names to parameters (12 characters maximum)
  # Give values as [minimum, initial, maximum]
  # NOTE: The initial value cannot be zero
  parameters:
    gamma_0: [0.040, 0.055, 0.100]
    i_xr_sens: [-2.0, 0.5, 2.0]
    util_sens: [0.01, 0.05, 1.00]
    profit_sens: [0.01, 0.10, 1.25]
    intrate_sens: [0.01, 0.10, 1.25]
    growth_adj: [0.01, 0.10, 1.25]
    infl_pass: [0.6, 0.8, 1.0]
    lab_ccoeff: [0.3, 0.6, 0.8]
    pot_out_adj: [-0.05, 0.02, 0.05]
    tech_par_adj: [0.02, 0.50, 1.00]
```
The next sub-block, `calibration:`, specifies the years for the calibration run and observations to compare to the results. Some points to note:
  * The range given by `calibration: => years:` may exceed the years of observations, but all observations must lie within that range (e.g., in the sample configuration file, the initial year is 2010, while the first year of data is 2012);
  * Results are assigned a name (e.g., `GDPgr`), which is case-insensitive: `GDPgr` is treated the same as `gdpgr`;
  * Each result variable is taken from a single column in one of Macro's output files from [the `results` folder](@ref model-outputs-results).
Values are provided as `[value, weight]`. Weights can often be set to one, but there are exceptions:
  * In the example below, the years 2020 and 2021 are outliers (because of COVID-19), so observations are given a low weight;
  * In the example below, it is presumed that there is a long-run growth target of 3.0%/year around 2035, so this value is entered and given a weight of 3;
  * While the values in the example are growth rates, and hence around the same magnitude in any year, values that are growing over time can be down-weighted by an average growth index (not shown in the example).
```yaml
  calibration:
    years: [2010, 2040]
    # For files, it is assumed that column 1 is the year
    # Record observations as year: [value, weight]
    # To omit an observation, set the weight to zero
    results:
      GDPgr:
          filename: collected_variables_0.csv
          column: 2
          observations:
            2012: [0.074, 1]
            2013: [0.050, 1]
            ...
            2019: [0.058, 1]
            2020: [-0.02, 0.1]
            2021: [0.02, 0.1]
            2035: [0.030, 3]
      LABgr:
          filename: collected_variables_0.csv
          column: 7
          observations:
            2015: [0.018, 1]
            2016: [0.023, 1]
            ...
            2019: [0.027, 1]
            2020: [-0.017, 0.1]
```

### The `LEAP-Macro:` block
The `LEAP-Macro:` block contains information for running the Macro model. It starts with some general information, including the name for the output folder and commands for running Julia. Note that the entry for `julia: => command:`, which is the command for running the Julia program, has two important features. First, it assumes that Julia is on the Windows path, as specified by the PATH environment variable -- if not, then the full path to the Julia executable should be provided. Second, it calls a sysimage. This is highly recommended, because it saves a great deal of running time: see the Tip on "Speeding up LEAPMacro with a pre-compiled system image" in the page on [running the Macro model](@ref running-macro).

The `julia: => resume_if_error:` entry should be set to `true` if the calibration halts due to errors when running PEST. The control file generated by the `pest.jl` script stipulates that PEST should attempt to restart the calculation with different starting parameter values in case Macro encounters an error (through the `lamforgive` and  `derforgive` settings). However, if that is insufficient, setting `resume_if_error:` to `true` tells Macro to attempt to recover in case of an error. This is less satisfactory, because some output files will be incomplete, but may be more robust.

The `julia: => verbose_errors:` entry can be set to `true` to show where in the LEAP-Macro Julia code an error originated. It is useful for developers modifying the LEAP-Macro code, but less useful for standard LEAP-Macro applications.

The `julia: => sleep:` entry needs to be changed only if time lags from writing and reading files leads to collisions. These will sometimes show up as error messages about accessing files. If such messages appear, then the sleep time can be increased.
```yaml
LEAP-Macro:
  output_folder: Calibration
  julia:
    # Note that script must accept thse flags:
    # usage: pest_run_leapmacro.jl [-c] [-s SLEEP] [-d DATA_FILES [DATA_FILES...]] [-v] [-e] [-r] [-h] [config_file]
    # positional arguments:
    #   config_file                                 name of config file (default: "LEAPMacro_params.yml")
    # optional arguments:
    #   -c, --calibrate                             flag to do a calibration run
    #   -s, --sleep SLEEP                           delay between iterations by this many seconds (default: 5)
    #   -d, --data-files DATA_FILES [DATA_FILES...] name(s) of the data file(s) in the results folder
    #   -v, --verbose-errors                        send detailed error message to log file
    #   -e, --include-energy-sectors                include energy sectors in the model simulation
    #   -r, --resume-if-error                       try to continue if the linear goal program returns an error
    #   -h, --help                                  show the help message and exit
    command: julia --sysimage=LEAPMacro-sysimage.so
    script: pest_run_leapmacro.jl
    resume_if_error: false
    verbose_errors: false
    sleep: 1 # seconds, to avoid collisions with opening & closing files 
```
The next (and final) sub-block is called `config:`. Entries in the sub-block follow the structure of a LEAP-Macro configuration file. The `pest.jl` script takes a full LEAP-Macro configuration file as a starting point, appends `_calibration` to the name of the file and gives it a PEST template extension (`.tpl`). By default the starting configuration file is called `LEAPMacro_params.yml`, but it can be assigned a different file when running the `pest.jl` program by calling, e.g., `\path\to\model>julia pest.jl MyConfigFile.yml`.

The PEST template file is exactly like the starting LEAP-Macro configuration file, with these changes:
  * It starts with a line reading `ptf |`, where "|" is the delimiter specified near the start of the `pest:` block;
  * The start and end years are given by the values specified in the `pest: => calibration:` block;
  * Any numerical values specified in the `config:` block, below, replace the values in the starting configuration file;
  * Any text labels, e.g., `label_name`, in the `config:` block, below, appear in the template as `| label_name  |`.
Where values are replaced, the original values are shown in a comment.

The text labels correspond to the names in the `pest: => parameters:` block described above. The `pest.jl` script generates an error if a label in the `config:` block has no corresponding entry in the `pest: => parameters:` block. The PEST program generates an error if an entry in the `pest: => parameters:` block does not appear in the template file.
```yaml
  config:
    calib:
      pot_output_adj_factor: pot_out_adj
    taylor-fcn:
      neutral_growth_band: [0.02, gamma_0]
      target_intrate:
        xr_sens: i_xr_sens
    investment-fcn:
          init_neutral_growth: gamma_0
          util_sens:  util_sens
          profit_sens: profit_sens
          intrate_sens: intrate_sens
          growth_adj: growth_adj
    wage-fcn:
        infl_passthrough: infl_pass
        lab_constr_coeff: lab_ccoeff
    tech-param-change:
        rate_constant: tech_par_adj
```

### The LEAP-Macro configuration file generated by PEST
The PEST calibration procedure results in a calibrated LEAP-Macro configuration file. It will be named `[starting_config_file]_calib.yml`, where `[starting_config_file].yml` is the starting configuration file -- by default, this will be `LEAPMacro_params.yml`. The final calibrated values will be assigned to parameters, with the original values from the starting configuration file stored in comments. Here is a selection from the file generated by the LEAP-Macro [demonstration files](assets/Macro.zip): 
```yaml
#---------------------------------------------------------------------------
# Parameters for the investment function
#---------------------------------------------------------------------------
investment-fcn:
    # Starting point for the autonomous investment growth rate: also the initial target GDP growth rate for the Taylor rule
    init_neutral_growth:   6.3485615E-02 # 0.060
    # Change in induced investment with a change in utilization
    util_sens:   5.9571348E-02 # 0.07
    # Change in induced investment with a change in the profit rate
    profit_sens:   1.0000000E-02 # 0.05
    # Change in induced investment with a change in the central bank lending rate
    intrate_sens:   3.8500000E-01 # 0.20
    # Rate of adjustment of the autonomous investment rate towards the actual investment rate
    growth_adj:   1.2278759E+00 # 0.10
```

## Final comments
Automated calibration can substantially speed up the calibration process. However, it is not a substitute for understanding the model. It is important to start calibrating by hand, to gain some intuition in how the Macro model responds to parameter changes.

Even when running the `pest.jl` script, it may be necessary to make make multiple changes to the `pest_config.yml` file. If parameter estimates appear precisely at the minimum or maximum values specified in the configuration file, and if the minimum or maximum are not "hard" values determined by fundamentals, then the range should likely be expanded in order to find the optimumum.

In short, model calibration is challenging, even with a tool as powerful as PEST. But it can substantially shorten the process.
