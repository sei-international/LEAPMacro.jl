using LEAPMacro
using YAML
using ArgParse

function parse_commandline()
    argp = ArgParseSettings(autofix_names = true)
    @add_arg_table! argp begin
        "--calibrate", "-c"
            help = "flag to do a calibration run"
            action = :store_true
        "config-file"
            help = "name of config file"
            arg_type = AbstractString
            default = "LEAPMacro_params.yml"
            required = false
		"--sleep", "-s"
			help = "delay between iterations by this many seconds"
            arg_type = Float64
			default = 0.1
			required = false
		"--data-files", "-d"
			help = "name(s) of the data file(s) in the results folder"
			nargs = '+'
        "--verbose-errors", "-v"
            help = "send detailed error message to log file"
            action = :store_true
        "--include-energy-sectors", "-e"
            help = "include energy sectors in the model simulation"
            action = :store_true
        "--resume-if-error", "-r"
            help = "try to continue if the linear goal program returns an error"
            action = :store_true
    end

    return parse_args(argp)
end

curr_working_dir = pwd()
cd(@__DIR__)

parsed_args = parse_commandline()

params = YAML.load_file(parsed_args["config_file"])
output_folder = joinpath("outputs", joinpath(params["output_folder"] * "_full", "results"))

if parsed_args["calibrate"]
	# Minimum allowed value is 0.001; ignore if less than that (e.g., if set to zero)
	if parsed_args["sleep"] >= 0.001
		sleep(parsed_args["sleep"])
	end
	println("Running LEAP-Macro...")
	res = LEAPMacro.run(parsed_args["config_file"], dump_err_stack = parsed_args["verbose_errors"], include_energy_sectors = true, continue_if_error = true)
	
    if res == 0
		if parsed_args["sleep"] >= 0.001
			sleep(parsed_args["sleep"])
		end
        for datafname in parsed_args["data_files"]
            cp(joinpath(output_folder, datafname), datafname, force = true)
        end
    else
        # If no results, delete the previously copied results files if they exist
        for datafname in parsed_args["data_files"]
            if isfile(datafname)
                rm(datafname)
            end
        end
    end
	if parsed_args["sleep"] >= 0.001
		sleep(parsed_args["sleep"])
	end
else
    LEAPMacro.run(parsed_args["config_file"],
                  dump_err_stack = parsed_args["verbose_errors"],
                  include_energy_sectors = parsed_args["include_energy_sectors"],
                  continue_if_error = parsed_args["resume_if_error"])
end

cd(curr_working_dir)
