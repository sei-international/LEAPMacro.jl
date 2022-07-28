```@meta
CurrentModule = LEAPMacro
```

# [Running the Macro model](@id running-macro)
Once the configuration and external parameter files have been prepared, the Macro model can be run in a stand-alone mode without LEAP. If the LEAP model is also prepared, then it can be run from LEAP.

## Running Macro stand-alone
When running Macro multiple times -- for example, when calibrating -- it is best to work in Julia's command-line read-eval-print loop (the REPL). That way, LEAPMacro is only included once, which speeds up subsequent runs.

The only command needed is `LEAPMacro.run()`, which is defined as follows, with the default values indicated:
```julia
function run(config_file::AbstractString = "LEAPMacro_params.yml";
             dump_err_stack::Bool = false,
             include_energy_sectors::Bool = false,
             continue_if_error::Bool = false)
```
The options are:
  * `config_file`: The name of the [configuration file](@ref config), if it is not `LEAPMacro_params.yml`;
  * `dump_err_stack`: Report detailed information about an error in the [log file](@ref model-outputs) (useful when debugging the Macro code, but not much use when debugging a model);
  * `include_energy_sectors`: Run the model with the [energy sectors](@ref config-sut) included (only useful in standalone mode, without LEAP, particularly when calibrating);
  * `continue_if_error`: Try to continue if the linear goal program returns an error.

!!! info "When to use `continue_if_error`"
    The `continue_if_error` flag should ordinarily be set to `false`. When there is an error, the results cannot be trusted, and some reported outputs and all LEAP indices are set to `NaN` (Not a Number). Nevertheless, it has some use. It is most useful when running LEAP-Macro many times using different inputs; for example, during an automated calibration or when running an ensemble of LEAP scenarios. In that case, setting the flag to `true` _may_ enable calculations to proceed even if one particular run gives an error. However, there is a chance that the program will halt anyway, if the error is too severe to recover from.

For example, each of the following is a valid call to the `run()` function:
```julia
LEAPMacro.run()
LEAPMacro.run("LEAPMacro_params_MyScenario.yml")
LEAPMacro.run(dump_err_stack = true)
LEAPMacro.run("LEAPMacro_params_Calibration.yml", include_energy_sectors = true)
```

If the `config_file` argument is not specified, then it is set equal to `LEAPMacro_params.yml`. If that is the name of the [configuration file](@ref config), then after [installing the LEAP-Macro package](@ref installation), the model can be run by simply typing the following commands in the Julia REPL:
```julia
julia> import LEAPMacro

julia> LEAPMacro.run()
Macro model run (0)...completed
0
```
### Running from the command line
In some circumstances it can be helpful to specify options as command-line parameters and run Macro from the Windows command line. The ArgParse Julia package makes that relatively easy. Here is a sample script:
```julia
using LEAPMacro
using ArgParse

function parse_commandline()
    argp = ArgParseSettings(autofix_names = true)
    @add_arg_table! argp begin
        "config-file"
            help = "name of the configuration file"
            arg_type = AbstractString
            default = "LEAPMacro_params.yml"
            required = false
        "--verbose-errors", "-v"
            help = "send detailed error message to log file"
            action = :store_true
        "--include-energy-sectors", "-e"
            help = "include energy sectors in the model simulation"
            action = :store_true
        "--continue-if-error", "-c"
            help = "try to continue if the linear goal program returns an error"
            action = :store_true
    end

    return parse_args(argp)
end

parsed_args = parse_commandline()
LEAPMacro.run(parsed_args["config_file"],
              dump_err_stack = parsed_args["verbose_errors"],
              include_energy_sectors = parsed_args["include_energy_sectors"],
              continue_if_error = parsed_args["continue_if_error"])
```
!!! tip "Speeding up LEAPMacro with a pre-compiled system image"
    If Macro will be run multiple times from the command line, execution can be speeded up by pre-compiling the LEAPMacro plugin. In the [sample files](assets/Macro.zip), there is a Windows batch file, `make_LEAPMacro_sysimage.bat`. Running this batch file (from the command line or by double-clicking) will generate a "system image" called `LEAPMacro-sysimage.so`. After running the batch file, put the system image in the folder where you want to run Macro and call Julia with an additional `sysimage` argument -- `julia --sysimage=LEAPMacro-sysimage.so ...` -- where `...` is the name of your script followed by any command-line arguments.

## [Running Macro from LEAP](@id running-macro-from-LEAP)
The [Freedonia sample model](assets/Macro.zip) includes a Visual Basic script for running Macro from LEAP. Located in the `scripts` folder, and called `LEAPMacro_MacroModelCalc.vbs`, it can be placed in a LEAP Area folder and called from LEAP using LEAP's scripting feature. See the [quick start guide](@ref quick-start) for more information.

The Visual Basic script assumes that the Macro model files are in a folder called `Macro` and it calls a Julia file called `LEAP-Macro-run.jl` in that folder. The version of the `LEAP-Macro-run.jl` file distributed with the Freedonia sample model looks like this:
```julia
using LEAPMacro

curr_working_dir = pwd()
cd(@__DIR__)

println("Running Baseline...")
LEAPMacro.run()

cd(curr_working_dir)
```
The default `LEAP-Macro-run.jl` file can be modified to run different configuration files.
