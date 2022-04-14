```@meta
CurrentModule = LEAPMacro
```

# [Preparing a model](@id prep-model)
Preparing a macroeconomic model is always complicated. The Macro model was built to reduce the complexities to some extent, but they cannot be entirely eliminated.

With that in mind, here are some proposed steps. It is best to start with an existing [configuration file](@ref config), for example the one from the [Freedonia sample model](@ref quick-start):
  1. Prepare the [supply-use table](@ref sut);
  1. Estimate or assume [external parameters](@ref params);
  1. Set the `run_leap` value to `false` in the configuration file [general settings](@ref config-general-settings);
  1. Set the list of excluded `energy` sectors and products to an empty list `[]` in the [configuration file](@ref config-sut);
  1. Set the [initial value adjustments](@ref config-init-val-adj) to zero;
  1. Set to run for one year by changing the final year in the [configuration file](@ref config-general-settings);
  1. Run the model by calling `LEAPMacro.run()`, using the sample `LEAP-Macro-run.jl` file as a guide;
  1. If there is an error, check the `LEAPMacro_log_XXXX.txt` logfile for the error message, where `XXXX` is the name of the output folder;
  1. Troubleshoot using the [`diagnostics` files](@ref model-outputs-diagnostics);
  1. Decide on a reasonable number of years for calibration (e.g., based on availability of historical data or other forward-looking studies);
  1. Adjust [model parameters](@ref config-model-params) systematically to calibrate and set them in the [configuration file](@ref config-general-settings);
  1. If needed, adjust [initial values](@ref config-init-val-adj) to fine-tune the calibration.

When calibrating, note the possible "sanity checks" listed in the page on [output files](@ref model-outputs).

To link to LEAP:
  1. Set the list of excluded `energy` sectors to ones relevant to the analysis;
  1. Ensure that the link between the Macro model and LEAP is set correctly in the [configuration file](@ref config-link-LEAP);
  1. Set `run_leap` to `true`;
  1. Follow the instructions in the LEAP tutorial for running LEAP-Macro to place the files and scripts correctly;
  1. Run the Macro model from LEAP.
