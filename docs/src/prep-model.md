```@meta
CurrentModule = LEAPMacro
```

# [Preparing a model](@id prep-model)
Preparing a macroeconomic model is always complicated. The Macro model was built to reduce the complexities to some extent, but they cannot be entirely eliminated.

With that in mind, here are some proposed steps. It is best to start with an existing [configuration file](@ref config), for example the one from the [Freedonia sample model](@ref quick-start):
  1. Prepare the [supply-use table](@ref sut);
  1. Estimate or assume [external parameters](@ref params);
  1. Set the `run_leap` value to `false` in the configuration file [general settings](@ref config-general-settings);
  1. Set the [initial value adjustments](@ref config-init-val-adj) to zero;
  1. Set the start and end years appropriately (see below) in the configuration file [general settings](@ref config-general-settings);
  1. [Run the model](@ref running-macro) by calling `LEAPMacro.run(CONFIG_FILE, include_energy_sectors = true)`, where `CONFIG_FILE` is the name of your [configuration file](@ref config);
  1. If there is an error, check the `LEAPMacro_log_XXXX.txt` log file for the error message, where `XXXX` is the name of the `output_folder` setting in the configuration file [general settings](@ref config-general-settings);
  1. Troubleshoot using the [`diagnostics` files](@ref model-outputs-diagnostics);
  1. Once the model is running without errors, calibrate by adjusting [model parameters](@ref config-model-params) systematically in the configuration file;
  1. If needed, adjust [initial values](@ref config-init-val-adj) to fine-tune the calibration and, optionally, further adjust the model parameters.

!!! tip "What is an appropriate range of years?"
    When calibrating, the start and end years for the simulation should:

      * Include all of the years for which there is data;
      * Extend far enough in the future to ensure the parameter set does not create instabilities.

!!! tip "Run sanity checks"
    When calibrating, note the "sanity checks" listed in the page on [output files](@ref model-outputs).

To link to LEAP:
  1. Set the list of excluded `energy` sectors to ones relevant to the analysis;
  1. Ensure that the link between the Macro model and LEAP is set correctly in the [configuration file](@ref config-link-LEAP);
  1. Set `run_leap` to `true`;
  1. See the guidelines for [running the Macro model](@ref running-macro) to place the files and scripts correctly;
  1. Run the Macro model from LEAP.

!!! tip "Follow the LEAP-Macro tutorial"
    It is a good idea to follow the LEAP tutorial for running LEAP-Macro. It explains where to place the files and how to set up multiple scenario runs.
