```@meta
CurrentModule = LEAPMacro
```

# [Preparing a model](@id prep-model)
Preparing a macroeconomic model is always complicated. The Macro model was built to reduce the complexities to some extent, but they cannot be entirely eliminated.

With that in mind, here are some proposed steps. It is best to start with an existing [configuration file](@ref config), for example the one from the [Freedonia sample model](@ref quick-start):
  1. Prepare the [supply-use table](@ref sut);
  1. Estimate or assume [external parameters](@ref params);
  1. Set the `report-diagnostics` value to `true` in the [configuration file](@ref config-output-folders);
  1. Set the `run_leap` value to `false` in the configuration file [general settings](@ref config-leap-run-settings);
  1. Set the [initial value adjustments](@ref config-init-val-adj) to zero;
  1. Set the start and end years appropriately (see below) in the configuration file [general settings](@ref config-general-settings);
  1. [Run the model](@ref running-macro) by calling `LEAPMacro.run(CONFIG_FILE, include_energy_sectors = true)`, where `CONFIG_FILE` is the name of your [configuration file](@ref config);
  1. Check the `LEAPMacro_log_XXXX_full.txt` log file[^1], where `XXXX` is the name of the `output_folder` setting in the configuration file [general settings](@ref config-general-settings), to check that the model ran without errors;
  1. If there were errors, troubleshoot using the [`diagnostics` files](@ref model-outputs-diagnostics);
  1. Confirm that the reported value in the `nonenergy_energy_link_measure.txt` file in the [`diagnostics` folder](@ref model-outputs-diagnostics) is reasonably small (see the Tip at the end of this page for what to do if it is large);
  1. Once the model is running without errors, calibrate by adjusting [model parameters](@ref config-model-params) systematically in the configuration file;
  1. If needed, adjust [initial values](@ref config-init-val-adj) to fine-tune the calibration and, optionally, further adjust the model parameters.

[^1]: The log file and output folder names have `_full` added at the end because the call to `LEAPMacro.run()` included energy sectors: see the page on [Output files](@ref model-outputs).

!!! tip "What is an appropriate range of years?"
    When calibrating, the start and end years for the simulation should:

      * Include all of the years for which there is data;
      * Extend far enough in the future to ensure the parameter set does not create instabilities.

!!! tip "Carry out sanity checks"
    When calibrating, note the "sanity checks" listed in the page on [output files](@ref model-outputs).

To link to LEAP:
  1. Set the list of [excluded `energy` sectors](@ref config-sut) to ones relevant to the analysis;
  1. Ensure that the link between the Macro model and LEAP is set correctly in the [configuration file](@ref config-link-LEAP);
  1. Set `run_leap` to `true` in the configuration file [general settings](@ref config-leap-run-settings);
  1. See the guidelines for [running the Macro model](@ref running-macro-from-LEAP) to place the files and scripts correctly;
  1. Run the Macro model from LEAP.

!!! tip "Follow the LEAP-Macro tutorial"
    It is a good idea to follow the LEAP tutorial for running LEAP-Macro. It explains where to place the files and how to set up multiple scenario runs.

!!! tip "What to do if the non-energy - energy link measure is large"
    The reported value in the `nonenergy_energy_link_measure.txt` file saved in the [`diagnostics` folder](@ref model-outputs-diagnostics) is a measure of how important the energy sector is as a source of demand for non-energy goods and services. A key assumption of LEAP-Macro is that the energy sector is not an important source of non-energy demand: see [Isolating the energy sector](@ref isolate-energy). That is a reasonable assumption if the non-energy--energy link measure is a few percent at most. However, even if the value is large, it may be possible to apply LEAP-Macro. An example is given in the documentation for the [configuration file](@ref config-pass-vals-LEAP-to-Macro), where the energy sector `coal` is included in Macro's calculations, but potential production is taken from LEAP. That way, demand by the coal sector for non-energy products are calculated by Macro, but the level of activity in the coal sector is provided by LEAP.
