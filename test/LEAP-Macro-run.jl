using LEAPMacro

curr_working_dir = pwd()
cd(@__DIR__)

println("Running Baseline...")
LEAPMacro.run("LEAPMacro_params.yml", dump_err_stack = false)

cd(curr_working_dir)
