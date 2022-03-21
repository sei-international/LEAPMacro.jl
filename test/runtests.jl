using LEAPMacro
using Test

curr_working_dir = pwd()
cd(@__DIR__)

@testset "LEAPMacro.run" begin
	@test LEAPMacro.run("LEAPMacro_params_BASELINE.yml", dump_err_stack = true) == 0
end

cd(curr_working_dir)
