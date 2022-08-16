#=
Macro: A macroeconomic model for LEAP

Authors:
  Eric Kemp-Benedict
  Jason Veysey
  Emily Ghosh
  Anisha Nazareth

Copyright ©2019-2022 Stockholm Environment Institute
=#

module LEAPMacro

using Logging, Dates, YAML

include("./IOlib.jl")
include("./LEAPfunctions.jl")
include("./MacroModel.jl")
using .IOlib, .LEAPfunctions, .MacroModel

"Run LEAP-Macro by calling `runleapmacromodel`"
function run(config_file::AbstractString = "LEAPMacro_params.yml"; dump_err_stack::Bool = false, include_energy_sectors::Bool = false, continue_if_error::Bool = false)
	# Ensure needed folders exist
	if !isdir("inputs")
		throw(ErrorException("The \"inputs\" folder is needed, but does not exist"))
	end

	params = YAML.load_file(config_file)

	# Enable logging
	if include_energy_sectors
		logfilename = string("LEAPMacro_log_", params["output_folder"], "_full.txt")
	else
		logfilename = string("LEAPMacro_log_", params["output_folder"], ".txt")
	end
	logfile = open(logfilename, "w+")
	logger = ConsoleLogger(logfile)
	global_logger(logger)
	@info now()
	@info "Configuration file: '$config_file'"
	exit_status = 0
	try
		MacroModel.runleapmacromodel(config_file, logfile, include_energy_sectors, continue_if_error)
	catch err
		exit_status = 1
		println(string("Macro exited with an error: Please check the log file '", logfilename,"'"))
		@error err
		if dump_err_stack
			@error stacktrace(catch_backtrace())
		end
	finally
		@info now()
		close(logfile)
		return(exit_status)
	end
end # function run

end #module
