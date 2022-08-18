module MacroModel
using JuMP, GLPK, DelimitedFiles, LinearAlgebra, DataFrames, CSV, Logging, Printf, Suppressor

export leapmacro

include("./IOlib.jl")
include("./LEAPfunctions.jl")
using .IOlib, .LEAPfunctions

# Declared type unions
NumOrArray = Union{Nothing,Number,Array}
NumOrVector = Union{Nothing,Number,Vector}

"Parameters for investment function"
mutable struct InvestmentFunction
	util::AbstractFloat
	profit::AbstractFloat
	bank::AbstractFloat
end

"Parameters for the Taylor function"
mutable struct TaylorFunction
	γ0::AbstractFloat
	min_γ0::AbstractFloat
	max_γ0::AbstractFloat
	gr_resp::AbstractFloat
	π_targ::AbstractFloat
	π_targ_use_πw::Bool
	π_init::AbstractFloat
	infl_resp::AbstractFloat
	i_targ::AbstractFloat
	i_targ0::AbstractFloat
	i_targ_max::AbstractFloat
	i_targ_min::AbstractFloat
	i_targ_coeff::AbstractFloat
	i_targ_xr_sens::AbstractFloat
	i_targ_adj_time::AbstractFloat
end

"Parameters for wage adjustment"
mutable struct WageAdjustment
	h::AbstractFloat
	k::AbstractFloat
end

"Report output values by writing to specified CSV files."
function write_values_to_csv(params::Dict, values::NumOrArray, filename::AbstractString, index::Integer, rowlabel::Union{Number,String}, mode::AbstractString)
	if isa(values, Array)
		usevalue = join(values, ',')
	else
		usevalue = values
	end
	open(joinpath(params["results_path"], string(filename, "_", index,".csv")), mode) do io
		write(io, string(rowlabel, ',', usevalue, "\r\n"))
	end
end # write_values_to_csv

"Convenience wrapper for write_values_to_csv"
function write_header_to_csv(params::Dict, values::NumOrArray, filename::AbstractString, index::Integer)
	write_values_to_csv(params, values, filename, index, "", "w")
end

"Convenience wrapper for write_values_to_csv"
function append_row_to_csv(params::Dict, values::NumOrArray, filename::AbstractString, index::Integer, rowlabel::Union{Number,String})
	write_values_to_csv(params, values, filename, index, rowlabel, "a")
end

"""
Convert a vector of strings by wrapping each string in quotes (for putting into CSV files).
This function converts `svec` in-place, so should only be run once. Double quotation marks
are removed to avoid that problem.
"""
function stringvec_to_quotedstringvec!(svec::Vector)
	for i in eachindex(svec)
		svec[i] = replace(string('\"', svec[i], '\"'), "\"\"" => "\"")
	end
end # stringvec_to_quotedstringvec!

"""
Calculate the Sraffa matrix, which is used to calculate domestic prices
	# np: number of products
	# ns: number of sectors
	# io: IOdata data structure
"""
function calc_sraffa_matrix(np::Integer, ns::Integer, io::IOdata)
	sraffa_matrix = Array{Float64}(undef, np, np)
	# Domestic prices
	for i in 1:np
		for j in 1:np
			sraffa_matrix[i,j] = sum(io.μ[r] * io.S[r,i] * io.D[j,r] for r in 1:ns)
		end
	end
    return sraffa_matrix
end # calc_sraffa_matrix

"""
Evaluate the Sraffa system to get domestic prices
	# t: time index (for exchange rate)
	# np: number of products
	# ns: number of sectors
	# ω: wage share by sector
	# io: IOdata data structure
"""
function calc_dom_prices(t::Integer, np::Integer, ns::Integer, ω::Array{Float64,1}, prices::PriceData, io::IOdata, exog::ExogParams)
	sraffa_matrix = calc_sraffa_matrix(np, ns, io)
	wage_vector = Array{Float64}(undef, np)
	world_price_vector = Array{Float64}(undef, np)
	for i in 1:np
		wage_vector[i] = prices.Pg * sum(io.μ[r] * io.S[r,i] * (ω[r] + io.energy_share[r]) for r in 1:ns)
		world_price_vector[i] = exog.xr[t] * sum(sraffa_matrix[i,j] * io.m_frac[j] * prices.pw[j] for j in 1:np)
	end
	sraffa_RHS = wage_vector + world_price_vector
	# Solve the Sraffa system and return the result
	inv(LinearAlgebra.I - [sraffa_matrix[i,j] * (1 - io.m_frac[j]) for i in 1:np, j in 1:np]) * sraffa_RHS
end # calc_dom_prices


"""
Calculate growth rate of intermediate demand coefficients (that is, io.D entries), or the intercepts (for initialization)	
	σ(np,ns) = matrix of cost shares
	k = single value or a vector (ns) of rate coefficients
	θ = single value or vector (ns) of exponents
	c(np,ns) = matrix of intercepts (if c = nothing it is set to zero)
	b(np,ns) = matrix of weights (if b = nothing it is set to one)
"""
function calc_intermed_techchange(σ::Array{Float64,2}, k::NumOrVector, θ::NumOrVector = 2.0, c::NumOrVector = nothing, b::NumOrVector = nothing)
	# Initialize values
	(np, ns) = size(σ)
	if isa(k, Number)
		k = k * ones(ns)
	end
	if isa(θ, Number)
		θ = θ * ones(ns)
	end
	if isnothing(b)
		b = ones(np, ns)
	end
	if isnothing(c)
		c = zeros(np, ns)
	end
	
	cost_shares_exponentiated = [σ[p,s]^θ[s] for p in 1:np, s in 1:ns]
	denom = sum(cost_shares_exponentiated .* b, dims = 1).^(1.0 .- 1.0 ./ θ)'
	num = [(cost_shares_exponentiated .* b ./ (σ .+ IOlib.ϵ))[p,s] * k[s] for p in 1:np, s in 1:ns]

	return c .- num ./ (denom .+ IOlib.ϵ)
end # calc_intermed_techchange

"Clean up folders if specified in params"
function clean_folders(params::Dict)
	if params["clear-folders"]["results"] && isdir(params["results_path"])
		for f in readdir(params["results_path"])
			rm(joinpath(params["results_path"], f))
		end
	end
	if params["clear-folders"]["calibration"] && isdir(params["calibration_path"])
		for f in readdir(params["calibration_path"])
			rm(joinpath(params["calibration_path"], f))
		end
	end
	if params["clear-folders"]["diagnostics"] && isdir(params["diagnostics_path"])
		for f in readdir(params["diagnostics_path"])
			rm(joinpath(params["diagnostics_path"], f))
		end
		if !params["report-diagnostics"]
			rm(params["diagnostics_path"])
		end
	end

	# Ensure that they exist
	mkpath(params["results_path"])
	mkpath(params["calibration_path"])
	if params["report-diagnostics"]
		mkpath(params["diagnostics_path"])
	end
end

"Implement the Macro model. This is the main function for LEAP-Macro"
function macro_main(params::Dict, leapvals::LEAPfunctions.LEAPresults, run::Integer, continue_if_error::Bool)

    #------------status
    @info "Loading data..."
    #------------status

	# Clean up folders if requested
	if run == 0
		clean_folders(params)
	end

	io, np, ns = IOlib.process_sut(params)
	prices = IOlib.initialize_prices(np, io)
	exog = IOlib.get_var_params(params)

	# For exogenous potential output and world prices, values must be specified for all years, so get indices for first year
	pot_output_ndxs = findall(x -> !ismissing(x), exog.exog_pot_output[1,:])
	pw_ndxs = findall(x -> !ismissing(x), exog.exog_price[1,:])

	# Convert pw into global currency
	prices.pw = prices.pw/exog.xr[1]

	#############################################################################
	#
    # Assign selected configuration file parameters to variables
	#
	#############################################################################

	# Years
	years = params["years"]["start"]:params["years"]["end"]
	# Investment function
	α = InvestmentFunction(
		params["investment-fcn"]["util_sens"], # util
		params["investment-fcn"]["profit_sens"], # profit
		params["investment-fcn"]["intrate_sens"] # bank
	)
    growth_adj = params["investment-fcn"]["growth_adj"]
	# Linear program objective function
    wu = params["objective-fcn"]["category_weights"]["utilization"]
    wf = params["objective-fcn"]["category_weights"]["final_demand_cov"]
    wx = params["objective-fcn"]["category_weights"]["exports_cov"]
    wm = params["objective-fcn"]["category_weights"]["imports_cov"]
	ϕu = params["objective-fcn"]["product_sector_weight_factors"]["utilization"]
	ϕf = params["objective-fcn"]["product_sector_weight_factors"]["final_demand_cov"]
	ϕx = params["objective-fcn"]["product_sector_weight_factors"]["exports_cov"]
	# Taylor function
	tf = TaylorFunction(
		params["investment-fcn"]["init_neutral_growth"], # γ0
		params["taylor-fcn"]["neutral_growth_band"][1], # min_γ0
		params["taylor-fcn"]["neutral_growth_band"][2], # max_γ0
		params["taylor-fcn"]["gr_resp"], # gr_resp
		0.0, # π_targ, assigned below
		!haskey(params["taylor-fcn"], "target_infl") || isnothing(params["taylor-fcn"]["target_infl"]), # π_targ_use_πw
		0.0, # π_init, assigned below
		params["taylor-fcn"]["infl_resp"], # infl_resp
		params["taylor-fcn"]["target_intrate"]["init"], # i_targ
		params["taylor-fcn"]["target_intrate"]["init"], # i_targ0
		params["taylor-fcn"]["target_intrate"]["band"][2], # i_targ_max
		params["taylor-fcn"]["target_intrate"]["band"][1], # i_targ_min
		NaN, # i_targ_coeff
		params["taylor-fcn"]["target_intrate"]["xr_sens"], # i_targ_xr_sens
		params["taylor-fcn"]["target_intrate"]["adj_time"] # i_targ_adj_time
	)
	tf.i_targ_coeff = (tf.i_targ_max - tf.i_targ0)/(tf.i_targ0 - tf.i_targ_min)
	# If params["taylor-fcn"]["target_infl"] not present, use world inflation rate
	if !tf.π_targ_use_πw
		tf.π_targ = params["taylor-fcn"]["target_infl"]
	else
		tf.π_targ = exog.πw_base[1]
	end
	# If params["taylor-fcn"]["init_infl"] not present, use target
	if haskey(params["taylor-fcn"], "init_infl") && !isnothing(params["taylor-fcn"]["init_infl"])
		tf.π_init = params["taylor-fcn"]["init_infl"]
	else
		tf.π_init = tf.π_targ
	end
	# Wage rate function
	wage_fn = WageAdjustment(
		params["wage-fcn"]["infl_passthrough"], # h
		params["wage-fcn"]["lab_constr_coeff"] # k
	)
	# Optionally update technical coefficients (the scaled Use matrix, io.D)
	calc_use_matrix_tech_change = haskey(params, "tech-param-change") && !isnothing(params["tech-param-change"]) && haskey(params["tech-param-change"], "rate_constant")
	if calc_use_matrix_tech_change
		tech_change_rate_constant = params["tech-param-change"]["rate_constant"]
	else
		tech_change_rate_constant = 0.0 # Not used in this case, but assign a value
	end
	# Link to LEAP
	LEAP_indices = params["LEAP_sector_indices"]
	# Initial autonomous growth rate
	γ_0 = params["investment-fcn"]["init_neutral_growth"] * ones(ns)

	#############################################################################
	#
    # Initialize variables (some of them adjusted after a later calibration step)
	#
	#############################################################################

	#----------------------------------
    # For calibration, apply a user-specified adjustment to exports, final demands, and potential output
    #----------------------------------
	Xmax = (1.0 + params["calib"]["max_export_adj_factor"]) * io.X
    Fmax = (1.0 + params["calib"]["max_hh_dmd_adj_factor"]) * max.(io.F,zeros(np))
	z = (1.0 + params["calib"]["pot_output_adj_factor"]) * io.g

	#----------------------------------
    # Investment
    #----------------------------------
	# Total investment
    I_total = sum(io.I)
	# Track non-energy investment separate from energy investment (which is supplied from LEAP)
    I_ne = I_total - leapvals.I_en[1]
    # Share of supply of investment goods
    θ = io.I / sum(io.I)
	# Initial values: These will change endogenously over time
	γ = γ_0
	i_bank = tf.i_targ

	#----------------------------------
    # Wages
    #----------------------------------
    W = io.W
	ω = io.W ./ io.g
    replace!(ω, NaN=>0)
	wage_ratio = 1.0

	#----------------------------------
    # Domestic prices using a Sraffian price system
    #----------------------------------
	prices.pd = calc_dom_prices(1, np, ns, ω, prices, io, exog)
	prices.pb = exog.xr[1] * io.m_frac .* prices.pw + (1 .- io.m_frac) .* prices.pd

	#----------------------------------
    # Capital productivity of new investment
    #----------------------------------
	# Intermediate variables
	profit_per_output = io.Vnorm * prices.pd - (prices.Pg .* (ω + io.energy_share) +  transpose(io.D) * prices.pb)
	price_of_capital = dot(θ,prices.pb)
	I_nextper = (1 + params["investment-fcn"]["init_neutral_growth"]) * (1 + params["calib"]["nextper_inv_adj_factor"]) * I_ne
	profit_share_rel_capprice = (1/price_of_capital) * profit_per_output
	init_profit = sum((γ_0 + exog.δ) .* io.g .* profit_share_rel_capprice)
    init_profit_rate = init_profit/I_nextper
	# Capital productivity
    capital_output_ratio = profit_share_rel_capprice / init_profit_rate
	replace!(capital_output_ratio, NaN=>0) # In this case, catch divide-by-zero by replacing NaN with zero
	# Initialize for the investment function
	targ_profit_rate = init_profit_rate

	#############################################################################
	#
    # Define linear goal program
	#
	#############################################################################

    #------------status
    @info "Preparing model..."
    #------------status

    # model
    mdl = Model(GLPK.Optimizer)

	#----------------------------------
	# Product and sector weights for the objective function
	#----------------------------------
	u_sector_wt = ϕu * io.g / sum(io.g) + (1.0 - ϕu) * ones(ns)/ns
	f_sector_wt = ϕf * io.F / sum(io.F) + (1.0 - ϕf) * ones(np)/np
	x_sector_wt = ϕx * io.X / sum(io.X) + (1.0 - ϕx) * ones(np)/np

	#----------------------------------
	# A filter for products that are domestically supplied
	#----------------------------------
	no_dom_production = vec(sum(io.S, dims=1)) .== 0

	#----------------------------------
    # Dynamic parameters
    #----------------------------------
	param_z = z
	param_Xmax = Xmax
	param_Fmax = Fmax
	param_I_tot = I_total
	param_prev_I_tot = 2 * I_total # Allow extra slack -- this sets a scale
	param_pw = prices.pw
	param_pd = prices.pd
	param_Pg = prices.Pg
	param_pb = prices.pb
	param_Mref = 2 * io.M # Allow for some extra slack -- this just sets a scale
	param_mfrac = io.m_frac
	# Initialize maximum utilization in multiple steps
	param_max_util = ones(ns)
	max_util_ndxs = findall(x -> !ismissing(x), exog.exog_max_util[1,:])
	param_max_util[max_util_ndxs] .= exog.exog_max_util[1,max_util_ndxs]
	#----------------------------------
    # Variables
    #----------------------------------
    # For objective function
    @variable(mdl, 0 <= ugap[i in 1:ns] <= 1)
    @variable(mdl, 0 <= fgap[i in 1:np] <= 1)
    @variable(mdl, 0 <= xgap[i in 1:np] <= 1)
    @variable(mdl, 0 <= ψ_pos[i in 1:np] <= 1) # Excess over target imports (as a relative amount)
    @variable(mdl, 0 <= ψ_neg[i in 1:np] <= 1) # Deficit below target imports (as a relative amount)
    # Supply and demand quantities
    @variable(mdl, qs[i in 1:np] >= 0)
    @variable(mdl, qd[i in 1:np] >= 0)
    # Final demand
    @variable(mdl, F[i in 1:np] >= 0)
    @variable(mdl, 0 <= fshare[i in 1:np] <= 1)
    @variable(mdl, M[i in 1:np] >= 0)
    @variable(mdl, 0 <= M_share[i in 1:np] <= 1)
    @variable(mdl, X[i in 1:np] >= 0)
    @variable(mdl, 0 <= xshare[i in 1:np] <= 1)
	@variable(mdl, I_tot) # Fix to equal param_I_tot
	@variable(mdl, I_supply[i in 1:np]) # Supply of investment goods by product
    # Output
    @variable(mdl, 0 <= u[i in 1:ns] <= 1)
    # Margins
    @variable(mdl, margins_pos[i in 1:np] >= 0)
    @variable(mdl, margins_neg[i in 1:np] >= 0)

    #----------------------------------
    # Objective function (goal program)
    #----------------------------------
    @objective(mdl, Min, wu * sum(u_sector_wt[i] * ugap[i] for i in 1:ns) +
					     wf * sum(f_sector_wt[i] * fgap[i] for i in 1:np) +
						 wx * sum(x_sector_wt[i] * xgap[i] for i in 1:np) +
						 wm * (sum(ψ_pos[i] + ψ_neg[i] for i in 1:np)))

    #----------------------------------
    # Constraints
    #----------------------------------
    # Sector constraints
	@constraint(mdl, eq_util[i = 1:ns], u[i] + ugap[i] == param_max_util[i])
	# Fundamental input-output equation
	@constraint(mdl, eq_io[i = 1:ns], sum(io.S[i,j] * param_pb[j] * qs[j] for j in 1:np) - param_Pg * param_z[i] * u[i] == 0)
    # Product constraints
	# Variables for objective function (goal program)
	@constraint(mdl, eq_xshare[i = 1:np], xshare[i] + xgap[i] == 1.0)
	@constraint(mdl, eq_X[i = 1:np], X[i] == xshare[i] * param_Xmax[i])
	@constraint(mdl, eq_fshare[i = 1:np], fshare[i] + fgap[i] == 1.0)
	@constraint(mdl, eq_F[i = 1:np], F[i] == fshare[i] * param_Fmax[i])
	# Intermediate demand
	@constraint(mdl, eq_intdmd[i = 1:np], qd[i] - sum(io.D[i,j] * u[j] * param_z[j] for j in 1:ns) == 0)
	# Investment
	fix(I_tot, param_I_tot)
	@constraint(mdl, eq_inv_supply[i = 1:np], I_supply[i] == θ[i] * I_tot)
	# Total supply
	@constraint(mdl, eq_totsupply[i = 1:np], qs[i] == qd[i] - margins_pos[i] + margins_neg[i] + X[i] + F[i] + I_supply[i] - M[i])
	@constraint(mdl, eq_no_dom_prod[i = 1:np], qs[i] * no_dom_production[i] == 0)
	# Imports
	@constraint(mdl, eq_M[i = 1:np], M[i] == param_mfrac[i] * (qd[i] + F[i] + I_supply[i]) + param_Mref[i] * (ψ_pos[i] - ψ_neg[i]))
	# Margins
	@constraint(mdl, eq_margpos[i = 1:np], margins_pos[i] == io.marg_pos_ratio[i] * (qs[i] + M[i]))
	@constraint(mdl, eq_margneg[i = 1:np], margins_neg[i] == io.marg_neg_share[i] * sum(margins_pos[j] for j in 1:np))

    #------------------------------------------
    # Calibration run
    #------------------------------------------
	if params["report-diagnostics"]
		open(joinpath(params["diagnostics_path"], string("model_", run, "_calib_1", ".txt")), "w") do f
			print(f, mdl)
		end
	end
    optim_output = @capture_out begin
		optimize!(mdl)
	end
	if !isempty(optim_output)
		@info optim_output
	end
    status = primal_status(mdl)
    @info "Calibrating for " * string(years[1]) * ": $status"

	# Sector variables
    IOlib.write_vector_to_csv(joinpath(params["calibration_path"], string("capacity_utilization_",run,".csv")), value.(u), "capacity utilization", params["included_sector_codes"])
    IOlib.write_vector_to_csv(joinpath(params["calibration_path"], string("sector_output_",run,".csv")), value.(u) .* z, "sector output", params["included_sector_codes"])
    IOlib.write_vector_to_csv(joinpath(params["calibration_path"], string("wage_share_",run,".csv")), ω, "wage share", params["included_sector_codes"])
	IOlib.write_vector_to_csv(joinpath(params["calibration_path"], string("capital_output_ratio_",run,".csv")), capital_output_ratio, "capital-output ratio", params["included_sector_codes"])
    
	# Product variables
	IOlib.write_vector_to_csv(joinpath(params["calibration_path"], string("exports_",run,".csv")), value.(X), "exports", params["included_product_codes"])
    IOlib.write_vector_to_csv(joinpath(params["calibration_path"], string("final_demand_",run,".csv")), value.(F), "final demand", params["included_product_codes"])
    IOlib.write_vector_to_csv(joinpath(params["calibration_path"], string("imports_",run,".csv")), value.(M), "imports", params["included_product_codes"])
    IOlib.write_vector_to_csv(joinpath(params["calibration_path"], string("domestic_production_",run,".csv")), value.(qs), "domestic production", params["included_product_codes"])
    IOlib.write_vector_to_csv(joinpath(params["calibration_path"], string("tot_intermediate_supply_non-energy_sectors_",run,".csv")), value.(qd), "intermediate supply from non-energy sectors", params["included_product_codes"])
    IOlib.write_vector_to_csv(joinpath(params["calibration_path"], string("basic_prices_",run,".csv")), param_pb, "basic prices", params["included_product_codes"])
    IOlib.write_vector_to_csv(joinpath(params["calibration_path"], string("margins_neg_",run,".csv")), value.(margins_neg), "negative margins", params["included_product_codes"])
    IOlib.write_vector_to_csv(joinpath(params["calibration_path"], string("margins_pos_",run,".csv")), value.(margins_pos), "positive margins", params["included_product_codes"])

    # First run is calibration -- now set Xmax and Fmax based on solution and run again
    Xmax = max.(Xmax, value.(X))
    Fmax = max.(Fmax, value.(F))
	param_Xmax = Xmax
	param_Fmax = Fmax
	for i in 1:np
		set_normalized_coefficient(eq_X[i], xshare[i], -param_Xmax[i])
		set_normalized_coefficient(eq_F[i], fshare[i], -param_Fmax[i])
	end
	if params["report-diagnostics"]
		open(joinpath(params["diagnostics_path"], string("model_", run, "_calib_2", ".txt")), "w") do f
			print(f, mdl)
		end
	end
	optim_output = @capture_out begin
		optimize!(mdl)
	end
	if !isempty(optim_output)
		@info optim_output
	end
    status = primal_status(mdl)

	#--------------------------------
	# Initialize variables for calculating inflation, growth rates, etc.
	#--------------------------------
    πd = ones(length(prices.pd)) * tf.π_init
    πw = ones(length(prices.pw)) * exog.πw_base[1]
    πb = ones(length(prices.pb)) .* (io.m_frac .* πw + (1 .- io.m_frac) .* πd)

	pw_prev = prices.pw ./ (1 .+ πw)
	pd_prev = prices.pd ./ (1 .+ πd)
    pb_prev = param_pb ./ (1 .+ πb)
    prev_GDP = sum(param_pb[i] * (value.(qs) - value.(qd))[i] for i in 1:np)/(1 + params["investment-fcn"]["init_neutral_growth"])
	prev_g = value.(u) .* z
	prev_g_share = pd_prev .* value.(qs)/sum(pd_prev .* value.(qs))

	smoothed_world_gr = params["global-params"]["gr_default"]

	if !all(ismissing.(exog.exog_pot_output[1,:]))
		prev_exog_pot_prod = sum(exog.exog_pot_output[1,i] * io.Vnorm[i,:] for i in pot_output_ndxs)
	else
		prev_exog_pot_prod = zeros(np)
	end

	prev_GDP_deflator = 1
    prev_GDP_gr = params["investment-fcn"]["init_neutral_growth"]
    πg = sum(prev_g_share .* πb)
	πF = sum(πb .* value.(F))/sum(value.(F))
	if calc_use_matrix_tech_change
		sector_price_level = (io.S * (pd_prev .* value.(qs))) ./ (value.(u) .* z)
		intermed_cost_shares = [pb_prev[i] * io.D[i,j] / sector_price_level[j] for i in 1:np, j in 1:ns]
		calc_intermed_techchange_intercept = -calc_intermed_techchange(intermed_cost_shares, tech_change_rate_constant)
	end

	lab_force_index = 1

	#--------------------------------
	# Initialize array of indices to pass to LEAP
	#--------------------------------
	labels = ["Year"]
	if haskey(params, "GDP-branch")
		labels = vcat(labels, params["GDP-branch"]["name"])
	end
	if haskey(params, "Employment-branch")
		labels = vcat(labels, params["Employment-branch"]["name"])
	end
	labels = vcat(labels, params["LEAP_sector_names"])
    indices = Array{Float64}(undef, length(years), length(labels))

	#------------------------------------------
    # Initialize files for writing results
    #------------------------------------------
	# Get sector and product labels
	sector_names = params["included_sector_names"]
	product_names = params["included_product_names"]
	# Quote the sector and product names (for putting into CSV files)
	stringvec_to_quotedstringvec!(sector_names)
	stringvec_to_quotedstringvec!(product_names)

	# Create files for sector variables
	write_header_to_csv(params, sector_names, "sector_output", run)
	write_header_to_csv(params, sector_names, "potential_sector_output", run)
	write_header_to_csv(params, sector_names, "capacity_utilization", run)
	write_header_to_csv(params, sector_names, "real_value_added", run)
	write_header_to_csv(params, sector_names, "profit_rate", run)
	write_header_to_csv(params, sector_names, "autonomous_investment_rate", run)
	# Create files for product variables
	write_header_to_csv(params, product_names, "final_demand", run)
	write_header_to_csv(params, product_names, "imports", run)
	write_header_to_csv(params, product_names, "exports", run)
	write_header_to_csv(params, product_names, "basic_prices", run)
	write_header_to_csv(params, product_names, "domestic_prices", run)
	# Create a file to hold scalar variables
	scalar_var_list = ["GDP gr", "curr acct surplus to GDP ratio", "curr acct surplus", "real GDP",
					   "GDP deflator", "labor productivity gr", "labor force gr", "wage rate gr",
					   "wage per effective worker gr", "real investment", "central bank rate",
					   "terms of trade index", "real xr index", "nominal xr index"]
	stringvec_to_quotedstringvec!(scalar_var_list)
	write_header_to_csv(params, scalar_var_list, "collected_variables", run)

	#############################################################################
	#
    # Run simulation
	#
	#############################################################################
    @info "Running from " * string(years[2]) * " to " * string(last(years)) * ":"

    previous_failed = false
    for t in eachindex(years)
		#--------------------------------
		# Output
		#--------------------------------
		if !previous_failed
			g = value.(u) .* z
			g_share = pd_prev .* value.(qs)/sum(pd_prev .* value.(qs))
			prev_g = g
			prev_g_share = g_share
		else
			g = prev_g
			g_share = prev_g_share
		end

		#--------------------------------
		# Price indices and deflators
		#--------------------------------
        # This is used here if the previous calculation failed, but is also reported below
        va_at_prev_prices_1 = prices.Pg * g
        va_at_prev_prices_2 = sum(pb_prev[j] * io.D[j,:] for j in 1:np) .* g
        value_added_at_prev_prices = va_at_prev_prices_1 - va_at_prev_prices_2
        if previous_failed
            pd_prev = pd_prev .* (1 .+ πd)
            pb_prev = pb_prev .* (1 .+ πb)
            pw_prev = pw_prev .* (1 .+ πw)
            va1 = (1 + πg) * prices.Pg * g
            va2 = sum(value.(param_pb)[j] * io.D[j,:] for j in 1:np) .* g
            value_added = va1 - va2
            πGDP = sum(value_added)/sum(value_added_at_prev_prices) - 1
			π_imp = exog.πw_base[1]
			π_exp = exog.πw_base[1]
			π_trade = exog.πw_base[1]
            GDP_gr = prev_GDP_gr
			GDP = prev_GDP * (1 + GDP_gr)
        else
			πd = (param_pd - pd_prev) ./ (pd_prev .+ IOlib.ϵ) # If not produced, pd_prev = 0
	        πb = (param_pb - pb_prev) ./ pb_prev
	        πw = (prices.pw - pw_prev) ./ pw_prev # exog.πw_base is a single value, applied to all products; this is by product
            πg = sum(g_share .* πb)
			πF = sum(πb .* value.(F))/sum(value.(F))
			π_imp = sum(πw .* value.(M))/sum(value.(M))
			π_exp = sum(πw .* value.(X))/sum(value.(X))
			π_trade = sum(πw .* (value.(X) + value.(M)))/sum(value.(X) + value.(M))
			val_findmd = pb_prev .* (value.(X) + value.(F) + value.(I_supply) - value.(M))
	        val_findmd_share = val_findmd/sum(val_findmd)
            πGDP = sum(val_findmd_share .* πb)
            pd_prev = param_pd
            pb_prev = param_pb
			pw_prev = prices.pw
			#--------------------------------
			# GDP
			#--------------------------------
			GDP = sum(param_pb[i] * (value.(qs) - value.(qd))[i] for i in 1:np)/prev_GDP_deflator
            GDP_gr = GDP/prev_GDP - 1.0
        end
		prev_GDP = GDP
		prev_GDP_gr = GDP_gr
        GDP_deflator = prev_GDP_deflator
        prev_GDP_deflator = (1 + πGDP) * prev_GDP_deflator

		if tf.π_targ_use_πw
			tf.π_targ = exog.πw_base[t]
		end

		#--------------------------------
		# Wages and the labor force
		#--------------------------------
		λ_gr = exog.αKV[t] * GDP_gr + exog.βKV[t] # Kaldor-Verdoorn equation for labor productivity
		L_gr = GDP_gr - λ_gr # Labor force growth rate

		lab_force_index *= 1 + L_gr

		w_gr = wage_fn.h * πF + λ_gr * (1.0 + wage_fn.k * (L_gr - exog.working_age_grs[t]))
		ω_gr = w_gr - λ_gr - πg
		ω = (1.0 + ω_gr) * ω

		#--------------------------------
		# Update use matrix
		#--------------------------------
		if calc_use_matrix_tech_change && !previous_failed
			sector_price_level = (io.S * (pd_prev .* value.(qs))) ./ g
			intermed_cost_shares = [pb_prev[i] * io.D[i,j] / sector_price_level[j] for i in 1:np, j in 1:ns]
			D_hat = calc_intermed_techchange_intercept + calc_intermed_techchange(intermed_cost_shares, tech_change_rate_constant)
			io.D = io.D .* exp.(D_hat) # This ensures that io.D will not become negative
			if params["report-diagnostics"]
				IOlib.write_matrix_to_csv(joinpath(params["diagnostics_path"],"demand_coefficients_" * string(years[t]) * ".csv"), io.D, params["included_product_codes"], params["included_sector_codes"])
			end
		end

		#--------------------------------
		# Profits
		#--------------------------------
		if !previous_failed
			# First, update the Vnorm matrix
			io.Vnorm = Diagonal(1 ./ (g .+ IOlib.ϵ)) * io.S * Diagonal(value.(qs))
			# Calculate export-weighted price
			export_share = value.(X) ./ (value.(qs) .+ IOlib.ϵ)
			px = exog.xr[t] * export_share .* prices.pw + (1 .- export_share) .* prices.pd
			profit_per_output = io.Vnorm * px - (prices.Pg .* (ω + io.energy_share) +  transpose(io.D) * prices.pb)
			pK = dot(θ, prices.pb)
			profit_rate = profit_per_output ./ (pK * capital_output_ratio)
		else
			profit_rate = fill(NaN, ns)
		end

		#--------------------------------
		# Investment
		#--------------------------------
		if !previous_failed
			# Investment function
			γ_u = α.util * (value.(u) .- 1)
			γ_r = α.profit * (profit_rate .- targ_profit_rate)
			γ_i = -α.bank * (i_bank - tf.i_targ0) * ones(ns)
			γ = max.(γ_0 + γ_u + γ_r + γ_i, -exog.δ)
			# Override default behavior if production is exogenously specified
			if t > 1
				γ_spec = exog.exog_pot_output[t,:] ./ exog.exog_pot_output[t - 1,:] .- 1.0
				γ[pot_output_ndxs] .= γ_spec[pot_output_ndxs]
			end
		end

		# Non-energy investment, by sector and total
        I_ne_disag = z .* (γ + exog.δ) .* capital_output_ratio
        I_ne = sum(I_ne_disag)
		# Combine with energy investment and any additional exogenous investment
        I_total = I_ne + leapvals.I_en[t] + exog.I_addl[t]
		# Update autonomous investment term
        γ_0 = γ_0 + growth_adj * (γ - γ_0)

		#--------------------------------
		# Export demand
		#--------------------------------
		if !all(ismissing.(exog.exog_pot_output[t,:]))
			# Export demand is calculated differently when potential output is exogenously specified
			exog_pot_prod = sum(exog.exog_pot_output[t,i] * io.Vnorm[i,:] for i in pot_output_ndxs)
			# -- extent of externally specified output
			pot_prod_spec_factor = sum(io.Vnorm[i,:] * z[i] for i in pot_output_ndxs) ./ (io.Vnorm' * z .+ IOlib.ϵ)
		else
			exog_pot_prod = zeros(np)
			pot_prod_spec_factor = zeros(np)
		end
		# -- scale factor
		Xmax_scale_factor = (1 .- pot_prod_spec_factor) .+  pot_prod_spec_factor .* exog_pot_prod ./ (prev_exog_pot_prod .+ IOlib.ϵ)
		prev_exog_pot_prod = exog_pot_prod
		# -- income factor
		smoothed_world_gr += growth_adj * (exog.world_grs[t] - smoothed_world_gr)
		Xmax_income_factor = (1 + exog.world_grs[t]) ./ (1 .+ pot_prod_spec_factor * smoothed_world_gr)
		# -- price factor
		Xmax_price_factor = (1 .+ πw)./(1 .+ πd)
		# -- updated value
        Xmax = Xmax .* Xmax_scale_factor .* Xmax_income_factor.^exog.export_elast_demand[t] .* Xmax_price_factor.^exog.export_price_elast

		#--------------------------------
		# Final domestic consumption demand
		#--------------------------------
		# Wage ratio drives increase in quantity, so use real wage increase, deflate by Pg
		W_curr = sum(W)
        W = ((1 + w_gr)/(1 + λ_gr)) * W .* (1 .+ γ)
        wage_ratio = (1/(1 + πF)) * sum(W)/W_curr
        Fmax = Fmax .* max.(IOlib.ϵ,wage_ratio).^exog.wage_elast_demand[t]

		#--------------------------------
		# Calculate indices to pass to LEAP
		#--------------------------------
        indices[t,1] = years[t]
		curr_index = 1
		if haskey(params, "GDP-branch")
			curr_index += 1
			indices[t,curr_index] = GDP
		end
		if haskey(params, "Employment-branch")
			curr_index += 1
			indices[t,curr_index] = lab_force_index
		end
	
 		for i in eachindex(LEAP_indices)
			indices[t, curr_index + i] = 0
			for j in LEAP_indices[i]
				indices[t, curr_index + i] += g[j]
			end
		end

		#--------------------------------
		# Reporting
		#--------------------------------
		# These variables are only reported, not used
		if !previous_failed
			CA_surplus = sum(prices.pw .* (value.(X) - value.(M)))/GDP_deflator
			CA_to_GDP_ratio = CA_surplus/GDP
		else
			CA_surplus = NaN
			CA_to_GDP_ratio = NaN
		end

		if !previous_failed
			u_report = value.(u)
			F_report = value.(F)
			M_report = value.(M)
			X_report = value.(X)
		else
			u_report = fill(NaN, ns)
			F_report = fill(NaN, np)
			M_report = fill(NaN, np)
			X_report = fill(NaN, np)
		end

		#--------------------------------
		# Update Taylor rule
		#--------------------------------
		tf_i_targ_ref = tf.i_targ_min + (tf.i_targ_max - tf.i_targ_min)/(1 + tf.i_targ_coeff * prices.XR^tf.i_targ_xr_sens)
		tf.i_targ = tf.i_targ + (1/tf.i_targ_adj_time) * (tf_i_targ_ref - tf.i_targ)
        i_bank = tf.i_targ + tf.gr_resp * (GDP_gr - tf.γ0) + tf.infl_resp * (πF - tf.π_targ)
		# Apply adaptive expectations, then bound
		tf.γ0 = min(max(tf.γ0 + growth_adj * (GDP_gr - tf.γ0), tf.min_γ0), tf.max_γ0)

		#--------------------------------
		# Update prices
		#--------------------------------
		# If the specified XR series is real, convert to nominal using modeled price indices
		if params["files"]["xr-is-real"]
			exog.xr[t] *= prices.Pg/prices.Ptrade
		end
		prices.RER = prices.XR * prices.Ptrade/prices.Pg
		prices.Pg *= (1 + πg)
		prices.Pm *= (1 + π_imp)
		prices.Px *= (1 + π_exp)
		prices.Ptrade *= (1 + π_trade)
		# For pw, first apply global inflation rate to world prices
		prices.pw = prices.pw * (1 + exog.πw_base[t])
		# Then adjust for any exogenous price indices
		if t > 1
			pw_spec = exog.exog_price[t,:] ./ exog.exog_price[t - 1,:]
			prices.pw[pw_ndxs] .= prices.pw[pw_ndxs] .* pw_spec[pw_ndxs]
		end
		# Calculate XR trend
		if t > 1
			prices.XR *= exog.xr[t]/exog.xr[t-1]
		end	

		if !previous_failed
			io.m_frac = (value.(M) + IOlib.ϵ * io.m_frac) ./ (value.(qd) + value.(F) + value.(I_supply) .+ IOlib.ϵ)
		end
		prices.pd = calc_dom_prices(t, np, ns, ω, prices, io, exog)
		prices.pb = exog.xr[t] * io.m_frac .* prices.pw + (1 .- io.m_frac) .* prices.pd
		
		# Sector variables
		append_row_to_csv(params, g, "sector_output", run, years[t])
		append_row_to_csv(params, z, "potential_sector_output", run, years[t])
		append_row_to_csv(params, u_report, "capacity_utilization", run, years[t])
		append_row_to_csv(params, value_added_at_prev_prices/prev_GDP_deflator, "real_value_added", run, years[t])
		append_row_to_csv(params, profit_rate, "profit_rate", run, years[t])
		append_row_to_csv(params, γ_0, "autonomous_investment_rate", run, years[t])
	    # Product variables
		append_row_to_csv(params, F_report, "final_demand", run, years[t])
		append_row_to_csv(params, M_report, "imports", run, years[t])
		append_row_to_csv(params, X_report, "exports", run, years[t])
		append_row_to_csv(params, param_pb, "basic_prices", run, years[t])
		append_row_to_csv(params, param_pd, "domestic_prices", run, years[t])
		# Scalar variables
		scalar_var_vals = [GDP_gr, CA_to_GDP_ratio, CA_surplus, GDP, GDP_deflator, λ_gr, L_gr,
							w_gr, ω_gr, param_I_tot, i_bank, prices.Px/prices.Pm,
							prices.RER, prices.XR]
		append_row_to_csv(params, scalar_var_vals, "collected_variables", run, years[t])

		if t == length(years)
			break
		end

		#--------------------------------
		# Update potential output
		#--------------------------------
        z = (1 .+ γ) .* z

		#--------------------------------
		# Update the linear goal program
		#--------------------------------
		if !previous_failed
			param_Mref = 2 * value.(M) # Allow for some extra slack -- this just sets a scale
		end
		param_Pg = prices.Pg
		param_Xmax = Xmax
		param_Fmax = Fmax
		param_I_tot = I_total
		param_prev_I_tot = 2 * I_total # Allow extra slack -- this sets a scale
		param_pw = prices.pw
		param_pd = prices.pd
		param_pb = prices.pb
		param_z = z
		# Caluculate updated m_frac for use in goal program
		adj_import_price_elast = max.(0, 1 .- io.m_frac) .* exog.import_price_elast
		param_mfrac = io.m_frac .* ((1 .+ πd)./(1 .+ πw)).^adj_import_price_elast
		# Set maximum utilization in multiple steps
		param_max_util = ones(ns)
		max_util_ndxs = findall(x -> !ismissing(x), exog.exog_max_util[t + 1,:])
		param_max_util[max_util_ndxs] .= exog.exog_max_util[t + 1,max_util_ndxs]

		for i in 1:ns
			set_normalized_coefficient(eq_io[i], u[i], -param_Pg * param_z[i])
			set_normalized_rhs(eq_util[i], param_max_util[i])
			for j in 1:np
				set_normalized_coefficient(eq_io[i], qs[j], io.S[i,j] * param_pb[j])
			end
		end
		for i in 1:np
			set_normalized_coefficient(eq_X[i], xshare[i], -param_Xmax[i])
			set_normalized_coefficient(eq_F[i], fshare[i], -param_Fmax[i])
			set_normalized_coefficient(eq_M[i], ψ_pos[i], -param_Mref[i])
			set_normalized_coefficient(eq_M[i], ψ_neg[i], param_Mref[i])
			set_normalized_coefficient(eq_M[i], qd[i], -param_mfrac[i])
			set_normalized_coefficient(eq_M[i], F[i], -param_mfrac[i])
			set_normalized_coefficient(eq_M[i], I_supply[i], -param_mfrac[i])
			for j in 1:ns
				set_normalized_coefficient(eq_intdmd[i], u[j], -io.D[i,j] * param_z[j])
			end
		end
		fix(I_tot, param_I_tot)

		if params["report-diagnostics"]
			open(joinpath(params["diagnostics_path"], string("model_", run, "_", years[t], ".txt")), "w") do f
				print(f, mdl)
			end
		end
		optim_output = @capture_out begin
			optimize!(mdl)
		end
		if !isempty(optim_output)
			@info optim_output
		end
        status = primal_status(mdl)
		# Add one to year to report the year currently being calculated
        @info "Simulating for " * string(years[t + 1]) * ": $status"
        previous_failed = status != MOI.FEASIBLE_POINT
        if previous_failed
			finndx = length(LEAP_indices) + 2 # Adds column for year and for GDP
            indices[t,2:finndx] = fill(NaN, (finndx - 2) + 1)
			if !continue_if_error
				throw(ErrorException("Linear goal program failed to solve: $status"))
			end
        end
    end

    # Make indices into indices
    indices_0 = indices[1,:]
    for t in eachindex(years)
        indices[t,2:end] = indices[t,2:end] ./ indices_0[2:end]
    end
    open(joinpath(params["results_path"], string("indices_",run,".csv")), "w") do io
               writedlm(io, reshape(labels, 1, :), ',')
               writedlm(io, indices, ',')
           end;

	# Release the model
	mdl = nothing

    return indices
end # macro_main

"Compare the GDP, employment, and value added indices generated from different runs and calculate the maximum difference."
function compare_results(params::Dict, run::Integer)
    # Obtains data from indices files for current run and previous run
    file1 = joinpath(params["results_path"], string("indices_",run,".csv"))
    file2 = joinpath(params["results_path"], string("indices_",run-1,".csv"))

    file1_dat = CSV.read(file1, header=1, missingstring=["0"], DataFrame)
    file2_dat = CSV.read(file2, header=1, missingstring=["0"], DataFrame)

    max_diff = 0

    # Compares run data
    for i = axes(file1_dat, 2)[2:end]
        diff = abs.((file1_dat[:,i]-file2_dat[:,i])./file2_dat[:,i]*100)
        deleteat!(diff, findall(x->isnan(x), diff))
        if maximum(diff) > max_diff
            max_diff = maximum(diff)
        end
    end

    return max_diff
end # compare_results

"Iteratively run the Macro model and LEAP until convergence. This is the primary entry point for LEAP-Macro."
function leapmacro(param_file::AbstractString, logfile::IOStream, include_energy_sectors::Bool = false, continue_if_error::Bool = false)

    # Read in global parameters
    params = IOlib.parse_param_file(param_file, include_energy_sectors = include_energy_sectors)

    # set model run parameters and initial values
    leapvals = LEAPfunctions.initialize_leapresults(params)
    run_leap = params["model"]["run_leap"]
    if run_leap
        max_runs = params["model"]["max_runs"]
        ## checks that user has LEAP installed
        if ismissing(LEAPfunctions.connect_to_leap())
            @error "Cannot connect to LEAP. Please check that LEAP is installed, or set 'run_leap: false' in the configuration file."
            return
        end
    else
        max_runs = 0
    end
    max_tolerance = params["model"]["max_tolerance"]

    for run = 0:max_runs
        ## Run Macro model
        #------------status
		print("Macro model run ($run)...")
        @info "Macro model run ($run)..."
        #------------status
        indices = macro_main(params, leapvals, run, continue_if_error)
		#------------status
		println("completed")
        #------------status

        ## Compare run results
        if run >= 1
            tolerance = compare_results(params, run)
            if tolerance <= max_tolerance
                @info @sprintf("Convergence in run number %d at %.2f%% ≤ %.2f%% target...", run, tolerance, max_tolerance)
                return
            else
                @info @sprintf("Results did not converge: %.2f%% > %.2f%% target...", tolerance, max_tolerance)
                if run == max_runs
                    return
                end
            end
        end

        ## Send output to LEAP
        if run_leap
			if params["model"]["hide_leap"]
				#------------status
				@info "Hiding LEAP to improve performance..."
				#------------status
				LEAPfunctions.hide_leap(true)
			end

            #------------status
            @info "Sending Macro output to LEAP..."
            #------------status
            LEAPfunctions.send_results_to_leap(params, indices)
            ## Run LEAP model
			try
				#------------status
				@info "Running LEAP model..."
				flush(logfile)
				#------------status
				LEAPfunctions.calculate_leap(params["LEAP-info"]["result_scenario"])

				## Obtain energy investment data from LEAP
				#------------status
				@info "Obtaining LEAP results..."
				flush(logfile)
				#------------status
				leapvals = LEAPfunctions.get_results_from_leap(params, run)
			finally
				if params["model"]["hide_leap"]
					#------------status
					@info "Restoring LEAP..."
					#------------status
					LEAPfunctions.hide_leap(false)
				end
				flush(logfile)
			end
        end

    end

end # leapmacro

end # MacroModel
