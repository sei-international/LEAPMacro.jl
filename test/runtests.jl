using LEAPMacro
using Test

curr_working_dir = pwd()
cd(@__DIR__)

@testset "LEAPMacro.run" begin
	@test LEAPMacro.run("LEAPMacro_params.yml", dump_err_stack = true, continue_if_error = false, include_energy_sectors = true) == 0
	@test LEAPMacro.run("LEAPMacro_params.yml", dump_err_stack = true, continue_if_error = false, include_energy_sectors = false) == 0
	@test LEAPMacro.run("LEAPMacro_params_all_options.yml", dump_err_stack = true, continue_if_error = false, include_energy_sectors = true) == 0
	@test LEAPMacro.run("LEAPMacro_params_all_options.yml", dump_err_stack = true, continue_if_error = false, include_energy_sectors = false) == 0
end

cd(curr_working_dir)
