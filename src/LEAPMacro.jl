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

function run(params_file = nothing; dump_err_stack::Bool = false)
	# Ensure needed folders exist
	if !isdir("inputs")
		throw(ErrorException("The \"inputs\" folder is needed, but does not exist"))
	end

	if isnothing(params_file)
		params_file = "LEAPMacro_params.yml"
	end
	params = YAML.load_file(params_file)

	# Enable logging
	logfile = open(string("LEAPMacro_log_", params["output_folder"], ".txt"), "w+")
	logger = ConsoleLogger(logfile)
	global_logger(logger)
	@info now()
	@info "Configuration file: '$params_file'"
	exit_status = 0
	try
		println(string(now(), ": ", @__LINE__, ": ", basename(@__FILE__)))
		MacroModel.runleapmacromodel(params_file, logfile)
		println(string(now(), ": ", @__LINE__, ": ", basename(@__FILE__)))
	catch err
		exit_status = 1
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
