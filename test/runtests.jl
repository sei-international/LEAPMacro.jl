using LEAPMacro
using Test

curr_working_dir = pwd()
cd(@__DIR__)

@testset "LEAPMacro.run" begin
	@test LEAPMacro.run("LEAPMacro_params.yml", dump_err_stack = true, include_energy_sectors = true) == 0
end

cd(curr_working_dir)
