julia --trace-compile=LEAPMacro_precompile.jl LEAP-Macro-run.jl
julia -e "using PackageCompiler; PackageCompiler.create_sysimage([\"LEAPMacro\"]; sysimage_path=\"LEAPMacro-sysimage.so\", precompile_statements_file=\"LEAPMacro_precompile.jl\")"
