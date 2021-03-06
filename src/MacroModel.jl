module MacroModel
using JuMP, GLPK, DelimitedFiles, LinearAlgebra, DataFrames, CSV, Logging, Printf, Suppressor

export runleapmacromodel

include("./IOlib.jl")
include("./LEAPfunctions.jl")
using .IOlib, .LEAPfunctions

"Parameters for the Taylor function"
mutable struct TaylorFunction
	γ0::Float64
	min_γ0::Float64
	max_γ0::Float64
	gr_resp::Float64
	π_targ::Float64
	π_targ_use_πw::Bool
	infl_resp::Float64
	i_targ::Float64
	i_targ0::Float64
	i_targ_max::Float64
	i_targ_min::Float64
	i_targ_coeff::Float64
	i_targ_xr_sens::Float64
	i_targ_adj_time::Float64
end

"""
    output_var(params, values, filename, index, rowlabel, mode)

Report output values by writing to specified CSV files.
"""
function output_var(params, values, filename, index, rowlabel, mode)
	if isa(values, Array)
		usevalue = join(values, ',')
	else
		usevalue = values
	end
	open(joinpath(params["results_path"], string(filename, "_", index,".csv")), mode) do io
		write(io, string(rowlabel, ',', usevalue, "\r\n"))
	end
end

"""
    to_quoted_string_vec(svec)

Convert a vector of strings by wrapping each string in quotes (for putting into CSV files).
This function converts `svec` in-place, so should only be run once. Double quotation marks
are removed to avoid that problem.
"""
function to_quoted_string_vec(svec)
	for i in 1:length(svec)
		svec[i] = replace(string('\"', svec[i], '\"'), "\"\"" => "\"")
	end
end

"""
    calc_sraffa_matrix(np::Int64, ns::Int64, io::IOdata)
	# np: number of products
	# ns: number of sectors
	# io: IOdata data structure

Calculate the Sraffa matrix, which is used to calculate domestic prices
"""
function calc_sraffa_matrix(np::Int64, ns::Int64, io::IOdata)
	sraffa_matrix = Array{Float64}(undef, np, np)
	# Domestic prices
	for i in 1:np
		for j in 1:np
			sraffa_matrix[i,j] = sum(io.μ[r] * io.S[r,i] * io.D[j,r] for r in 1:ns)
		end
	end
    return sraffa_matrix
end

"""
    calc_dom_prices(t::Int64, np::Int64, ns::Int64, ω::Array{Float64,1}, prices::PriceData, io::IOdata, exog::ExogParams)
	# t: time index (for exchange rate)
	# np: number of products
	# ns: number of sectors
	# ω: wage share by sector
	# io: IOdata data structure

Evaluate the Sraffa system to get domestic prices
"""
function calc_dom_prices(t::Int64, np::Int64, ns::Int64, ω::Array{Float64,1}, prices::PriceData, io::IOdata, exog::ExogParams)
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
end


"""
    intermed_tech_change(α, k, θ = nothing, b = nothing)
	
	α(np,ns) = matrix of cost shares
	k = single value or a vector (ns) of rate coefficients
	θ = single value or vector (ns) of exponents
	c(np,ns) = matrix of intercepts (if c = nothing it is set to zero)
	b(np,ns) = matrix of weights (if b = nothing it is set to one)

Calculate growth rate of intermediate demand coefficients (that is, io.D entries), or the intercepts (for initialization)
"""
function intermed_tech_change(α, k, θ = 2.0, c = nothing, b = nothing)
	# Initialize values
	(np, ns) = size(α)
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
	
	cost_shares_exponentiated = [α[p,s]^θ[s] for p in 1:np, s in 1:ns]
	denom = sum(cost_shares_exponentiated .* b, dims = 1).^(1.0 .- 1.0 ./ θ)'
	num = [(cost_shares_exponentiated .* b ./ (α .+ IOlib.ϵ))[p,s] * k[s] for p in 1:np, s in 1:ns]

	return c .- num ./ (denom .+ IOlib.ϵ)
end


"""
    ModelCalculations(file::String, I_en::Array, run::Int64)

Implement the Macro model. This is the main function.
"""
function ModelCalculations(file::String, I_en::Array, run::Int64)

    #------------status
    @info "Loading data..."
    #------------status

    params = IOlib.parse_input_file(file)

	# Clean up folders if requested
	if run == 0
		if params["clear-folders"]["results"] & isdir(params["results_path"])
			for f in readdir(params["results_path"])
				rm(joinpath(params["results_path"], f))
			end
		end
		if params["clear-folders"]["calibration"] & isdir(params["calibration_path"])
			for f in readdir(params["calibration_path"])
				rm(joinpath(params["calibration_path"], f))
			end
		end
		if params["clear-folders"]["diagnostics"] & isdir(params["diagnostics_path"])
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

	io, np, ns = IOlib.supplyusedata(file)
	prices = IOlib.prices_init(np, io)

	#############################################################################
	#
    # Assign selected configuration file parameters to variables
	#
	#############################################################################

	# Years
    base_year = params["years"]["start"]
    final_year = params["years"]["end"]
	# Investment function
    neutral_growth = params["investment-fcn"]["init_neutral_growth"]
    util_sens_scalar = params["investment-fcn"]["util_sens"]
    profit_sens = params["investment-fcn"]["profit_sens"]
    intrate_sens = params["investment-fcn"]["intrate_sens"]
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
		neutral_growth, # γ0
		params["taylor-fcn"]["neutral_growth_band"][1], # min_γ0
		params["taylor-fcn"]["neutral_growth_band"][2], # max_γ0
		params["taylor-fcn"]["gr_resp"], # gr_resp
		params["taylor-fcn"]["target_infl"], # π_targ
		isnothing(params["taylor-fcn"]["target_infl"]), # π_targ_use_πw
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
	# Wage rate function
	infl_passthrough = params["wage-fcn"]["infl_passthrough"]
	lab_constr_coeff = params["wage-fcn"]["lab_constr_coeff"]
	LEAP_indices = params["LEAP_sector_indices"]
	# Optionally update technical coefficients (the scaled Use matrix, io.D)
	calc_use_matrix_tech_change = haskey(params, "tech-param-change") && !isnothing(params["tech-param-change"]) && haskey(params["tech-param-change"], "rate_constant")
	if calc_use_matrix_tech_change
		tech_change_rate_constant = params["tech-param-change"]["rate_constant"]
	else
		tech_change_rate_constant = 0.0 # Not used in this case, but assign a value
	end

	#----------------------------------
    # Calculate variables based on parameters
    #----------------------------------
	# Number of time steps
	ntime = 1 + (final_year - base_year)
	# Initial autonomous growth rate
	γ_0 = neutral_growth * ones(ns)

	#----------------------------------
    # Read in exogenous time-varying parameters and sector-specific parameters
    #----------------------------------
	exog = IOlib.get_var_params(file)
	# Convert pw into global currency
	prices.pw = prices.pw/exog.xr[1]

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
    I_ne = I_total - I_en[1]
    # Share of supply of investment goods
    θ = io.I / sum(io.I)
	# Investment function parameter -- make a vector
    util_sens = util_sens_scalar * ones(ns)
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
	I_nextper = (1 + neutral_growth) * (1 + params["calib"]["nextper_inv_adj_factor"]) * I_ne
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
    @info "Calibrating for $base_year: $status"

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
	pw_prev = prices.pw/(1 + params["global-params"]["infl_default"])
	pd_prev = prices.pd/(1 + params["global-params"]["infl_default"])
    pb_prev = param_pb/(1 + params["global-params"]["infl_default"])
    prev_GDP = sum(param_pb[i] * (value.(qs) - value.(qd))[i] for i in 1:np)/(1 + neutral_growth)

	prev_GDP_deflator = 1
    prev_GDP_gr = neutral_growth
    πg = params["global-params"]["infl_default"]
    πb = ones(length(prices.pb)) * params["global-params"]["infl_default"]
    πd = ones(length(prices.pd)) * params["global-params"]["infl_default"]
    πw = ones(length(prices.pw)) * params["global-params"]["infl_default"]

	if calc_use_matrix_tech_change
		sector_price_level = (io.S * (pd_prev .* value.(qs))) ./ (value.(u) .* z)
		intermed_cost_shares = [pb_prev[i] * io.D[i,j] / sector_price_level[j] for i in 1:np, j in 1:ns]
		intermed_tech_change_intercept = -intermed_tech_change(intermed_cost_shares, tech_change_rate_constant)
	end

	lab_force_index = 1

    year = base_year

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
    indices = Array{Float64}(undef, ntime, length(labels))

	#------------------------------------------
    # Initialize files for writing results
    #------------------------------------------
	# Get sector and product labels
	sector_names = params["included_sector_names"]
	product_names = params["included_product_names"]
	# Quote the sector and product names (for putting into CSV files)
	to_quoted_string_vec(sector_names)
	to_quoted_string_vec(product_names)

	# Create files for sector variables
	output_var(params, sector_names, "sector_output", run, "", "w")
	output_var(params, sector_names, "potential_sector_output", run, "", "w")
	output_var(params, sector_names, "capacity_utilization", run, "", "w")
	output_var(params, sector_names, "real_value_added", run, "", "w")
	output_var(params, sector_names, "profit_rate", run, "", "w")
	output_var(params, sector_names, "autonomous_investment_rate", run, "", "w")
	# Create files for product variables
	output_var(params, product_names, "final_demand", run, "", "w")
	output_var(params, product_names, "imports", run, "", "w")
	output_var(params, product_names, "exports", run, "", "w")
	output_var(params, product_names, "basic_prices", run, "", "w")
	output_var(params, product_names, "domestic_prices", run, "", "w")
	# Create a file to hold scalar variables
	scalar_var_list = ["GDP gr", "curr acct surplus to GDP ratio", "curr acct surplus", "real GDP",
					   "GDP deflator", "labor productivity gr", "labor force gr", "wage rate gr",
					   "wage per effective worker gr", "real investment", "central bank rate",
					   "terms of trade index", "real xr index", "nominal xr index"]
	to_quoted_string_vec(scalar_var_list)
	output_var(params, scalar_var_list, "collected_variables", run, "", "w")

	#############################################################################
	#
    # Loop over years
	#
	#############################################################################
	base_year_plusone = base_year + 1
    @info "Running from $base_year_plusone to $final_year:"

    previous_failed = false
    for t in 1:ntime
		#--------------------------------
		# Output
		#--------------------------------
        g = value.(u) .* z
		g_share = pd_prev .* value.(qs)/sum(pd_prev .* value.(qs))

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
        else
			πd = (param_pd - pd_prev) ./ (pd_prev .+ IOlib.ϵ) # If not produced, pd_prev = 0
	        πb = (param_pb - pb_prev) ./ pb_prev
	        πw = (prices.pw - pw_prev) ./ pw_prev # exog.πw_base is a single value, applied to all products; this is by product
            πg = sum(g_share .* πb)
			val_findmd = pd_prev .* (value.(X) + value.(F) + value.(I_supply) - value.(M))
	        val_findmd_share = val_findmd/sum(val_findmd)
            πGDP = sum(val_findmd_share .* πd)
            pd_prev = param_pd
            pb_prev = param_pb
			pw_prev = prices.pw
        end
        GDP_deflator = prev_GDP_deflator
        prev_GDP_deflator = (1 + πGDP) * prev_GDP_deflator

		if tf.π_targ_use_πw
			tf.π_targ = exog.πw_base[t]
		end

		π_imp = sum(πw .* value.(M))/sum(value.(M))
		π_exp = sum(πw .* value.(X))/sum(value.(X))
		π_trade = sum(πw .* (value.(X) + value.(M)))/sum(value.(X) + value.(M))

		prices.Pm *= (1 + π_imp)
		prices.Px *= (1 + π_exp)
		prices.Ptrade *= (1 + π_trade)

		if params["files"]["xr-is-real"]
			exog.xr[t] *= prices.Pg/prices.Ptrade
		end

		if t > 1
			prices.XR *= exog.xr[t]/exog.xr[t-1]
		end

		#--------------------------------
		# GDP
		#--------------------------------
        GDP = sum(param_pb[i] * (value.(qs) - value.(qd))[i] for i in 1:np)/GDP_deflator
        if previous_failed
            GDP_gr = prev_GDP_gr
            prev_GDP = prev_GDP * (1 + GDP_gr)
        else
            GDP_gr = GDP/prev_GDP - 1.0
            prev_GDP = GDP
            prev_GDP_gr = GDP_gr
        end

		#--------------------------------
		# Wages and the labor force
		#--------------------------------
		λ_gr = exog.αKV[t] * GDP_gr + exog.βKV[t] # Kaldor-Verdoorn equation for labor productivity
		L_gr = GDP_gr - λ_gr # Labor force growth rate

		lab_force_index *= 1 + L_gr

		w_gr = infl_passthrough * πGDP + λ_gr * (1.0 + lab_constr_coeff * (L_gr - exog.working_age_grs[t]))
		ω_gr = w_gr - λ_gr - πg
		ω = (1.0 + ω_gr) * ω

		#--------------------------------
		# Update use matrix
		#--------------------------------
		if calc_use_matrix_tech_change
			sector_price_level = (io.S * (pd_prev .* value.(qs))) ./ g
			intermed_cost_shares = [pb_prev[i] * io.D[i,j] / sector_price_level[j] for i in 1:np, j in 1:ns]
			D_hat = intermed_tech_change_intercept + intermed_tech_change(intermed_cost_shares, tech_change_rate_constant)
			io.D = io.D .* exp.(D_hat) # This ensures that io.D will not become negative
			if params["report-diagnostics"]
				IOlib.write_matrix_to_csv(joinpath(params["diagnostics_path"],"demand_coefficients_" * string(year) * ".csv"), io.D, params["included_product_codes"], params["included_sector_codes"])
			end
		end

		#--------------------------------
		# Profits
		#--------------------------------
		# First, update the Vnorm matrix
		io.Vnorm = Diagonal(1 ./ g) * io.S * Diagonal(value.(qs))
		# Calculate export-weighted price
		export_share = value.(X) ./ (value.(qs) .+ IOlib.ϵ)
		px = exog.xr[t] * export_share .* prices.pw + (1 .- export_share) .* prices.pd
		profit_per_output = io.Vnorm * px - (prices.Pg .* (ω + io.energy_share) +  transpose(io.D) * prices.pb)
		pK = dot(θ, prices.pb)
		profit_rate = profit_per_output ./ (pK * capital_output_ratio)

		#--------------------------------
		# Investment
		#--------------------------------
		# Investment function
		γ_u = util_sens .* (value.(u) .- 1)
		γ_r = profit_sens * (profit_rate .- targ_profit_rate)
		# TODO: Evaluate this change
		γ_i = -intrate_sens * (i_bank - tf.i_targ0) * ones(ns)
        γ = max.(γ_0 + γ_u + γ_r + γ_i, -exog.δ)
		# Override default behavior if production is exogenously specified
		if t > 1
			γ_spec = exog.exog_pot_output[t,:] ./ exog.exog_pot_output[t - 1,:] .- 1.0
			pot_output_ndxs = findall(x -> !ismissing(x), γ_spec)
			γ[pot_output_ndxs] .= γ_spec[pot_output_ndxs]
		end

		# Non-energy investment, by sector and total
        I_ne_disag = z .* (γ + exog.δ) .* capital_output_ratio
        I_ne = sum(I_ne_disag)
		# Combine with energy investment and any additional exogenous investment
        I_total = I_ne + I_en[t] + exog.I_addl[t]
		# Update autonomous investment term
        γ_0 = γ_0 + growth_adj * (γ - γ_0)

		#--------------------------------
		# Export demand
		#--------------------------------
        Xmax = Xmax .* (1 + exog.world_grs[t]).^exog.export_elast_demand[t] .* ((1 .+ πw)./(1 .+ πd)).^exog.export_price_elast

		#--------------------------------
		# Final domestic consumption demand
		#--------------------------------
		# Wage ratio drives increase in quantity, so use real wage increase, deflate by Pg
		W_curr = sum(W)
        W = ((1 + w_gr)/(1 + λ_gr)) * W .* (1 .+ γ)
        wage_ratio = (1/(1 + πGDP)) * sum(W)/W_curr
        Fmax = Fmax .* wage_ratio.^exog.wage_elast_demand[t]

		#--------------------------------
		# Calculate indices to pass to LEAP
		#--------------------------------
        indices[t,1] = year
		curr_index = 1
		if haskey(params, "GDP-branch")
			curr_index += 1
			indices[t,curr_index] = GDP
		end
		if haskey(params, "Employment-branch")
			curr_index += 1
			indices[t,curr_index] = lab_force_index
		end
	
 		for i in 1:length(LEAP_indices)
			indices[t, curr_index + i] = 0
			for j in LEAP_indices[i]
				indices[t, curr_index + i] += g[j]
			end
		end

		#--------------------------------
		# Reporting
		#--------------------------------
		# These variables are only reported, not used
		CA_surplus = sum(prices.pw .* (value.(X) - value.(M)))/GDP_deflator
		CA_to_GDP_ratio = CA_surplus/GDP

		# Sector variables
		output_var(params, g, "sector_output", run, year, "a")
		output_var(params, z, "potential_sector_output", run, year, "a")
		output_var(params, value.(u), "capacity_utilization", run, year, "a")
		output_var(params, value_added_at_prev_prices/prev_GDP_deflator, "real_value_added", run, year, "a")
		output_var(params, profit_rate, "profit_rate", run, year, "a")
		output_var(params, γ_0, "autonomous_investment_rate", run, year, "a")
	    # Product variables
		output_var(params, value.(F), "final_demand", run, year, "a")
		output_var(params, value.(M), "imports", run, year, "a")
		output_var(params, value.(X), "exports", run, year, "a")
		output_var(params, param_pb, "basic_prices", run, year, "a")
		output_var(params, param_pd, "domestic_prices", run, year, "a")
		# Scalar variables
		scalar_var_vals = [GDP_gr, CA_to_GDP_ratio, CA_surplus, GDP, GDP_deflator, λ_gr, L_gr,
							w_gr, ω_gr, value.(I_tot), i_bank, prices.Px/prices.Pm,
							prices.XR * prices.Ptrade/prices.Pg, prices.XR]
		output_var(params, scalar_var_vals, "collected_variables", run, year, "a")

		if t == ntime
			break
		end
		#--------------------------------
		# Update Taylor rule
		#--------------------------------
		# TODO: evaluate the following code
		tf_i_targ_ref = tf.i_targ_min + (tf.i_targ_max - tf.i_targ_min)/(1 + tf.i_targ_coeff * prices.XR^tf.i_targ_xr_sens)
		tf.i_targ = tf.i_targ + (1/tf.i_targ_adj_time) * (tf_i_targ_ref - tf.i_targ)
		# END EVALUATION
        i_bank = tf.i_targ + tf.gr_resp * (GDP_gr - tf.γ0) + tf.infl_resp * (πGDP - tf.π_targ)
		# Apply adaptive expectations, then bound
		tf.γ0 = min(max(tf.γ0 + growth_adj * (GDP_gr - tf.γ0), tf.min_γ0), tf.max_γ0)

		#--------------------------------
		# Update potential output
		#--------------------------------
        z = (1 .+ γ) .* z

		#--------------------------------
		# Update prices
		#--------------------------------
		prices.Pg = (1 + πg) * prices.Pg
		# Apply global inflation rate to world prices
		prices.pw = prices.pw * (1 + exog.πw_base[t])
		# Adjust for any exogenous price indices
		if t > 1
			pw_spec = exog.exog_price[t,:] ./ exog.exog_price[t - 1,:]
			pw_ndxs = findall(x -> !ismissing(x), pw_spec)
			prices.pw[pw_ndxs] .= prices.pw[pw_ndxs] .* pw_spec[pw_ndxs]
		end

		io.m_frac = (value.(M) + IOlib.ϵ * io.m_frac) ./ (value.(qd) + value.(F) + value.(I_supply) .+ IOlib.ϵ)
		prices.pd = calc_dom_prices(t, np, ns, ω, prices, io, exog)
		prices.pb = exog.xr[t] * io.m_frac .* prices.pw + (1 .- io.m_frac) .* prices.pd
		
		#--------------------------------
		# Update the linear goal program
		#--------------------------------
		param_Mref = 2 * value.(M) # Allow for some extra slack -- this just sets a scale
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
			open(joinpath(params["diagnostics_path"], string("model_", run, "_", year, ".txt")), "w") do f
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
		# Increment year to report the correct year is being calculated
		year += 1
        @info "Simulating for $year: $status"
        previous_failed = status != MOI.FEASIBLE_POINT
        if previous_failed
			finndx = length(LEAP_indices) + 2 # Adds column for year and for GDP
            indices[t,2:finndx] = fill(NaN, (finndx - 2) + 1)
        end


    end

    # Make indices into indices
    indices_0 = indices[1,:]
    for t = 1:ntime
        indices[t,2:end] = indices[t,2:end] ./ indices_0[2:end]
    end
    open(joinpath(params["results_path"], string("indices_",run,".csv")), "w") do io
               writedlm(io, reshape(labels, 1, :), ',')
               writedlm(io, indices, ',')
           end;

	# Release the model
	mdl = nothing

    return indices
end # ModelCalculations

"""
    resultcomparison(params, run::Int64)

Compare the GDP and value added indices generated from different runs and calculate the maximum difference.
Indices are specified in the YAML configuration file.
"""
function resultcomparison(params, run::Int64)
    # Obtains data from indices files for current run and previous run
    file1 = joinpath(params["results_path"], string("indices_",run,".csv"))
    file2 = joinpath(params["results_path"], string("indices_",run-1,".csv"))

    file1_dat = CSV.read(file1, header=1, missingstring=["0"], DataFrame)
    file2_dat = CSV.read(file2, header=1, missingstring=["0"], DataFrame)

    max_diff = 0

    # Compares run data
    for i = 2:size(file1_dat, 2)
        diff = abs.((file1_dat[:,i]-file2_dat[:,i])./file2_dat[:,i]*100)
        deleteat!(diff, findall(x->isnan(x), diff))
        if maximum(diff) > max_diff
            max_diff = maximum(diff)
        end
    end

    return max_diff
end

"""
    runleapmacromodel(file::String, logile::IOStream, include_energy_sectors::Bool = false)

Iteratively run the Macro model and LEAP until convergence.
"""
function runleapmacromodel(file::String, logfile::IOStream, include_energy_sectors::Bool = false)

    ## get base_year and final_year, and force fresh start with global_params
    params = IOlib.parse_input_file(file, force = true, include_energy_sectors = include_energy_sectors)
    base_year = params["years"]["start"]
    final_year = params["years"]["end"]
    ntime = 1 + (final_year - base_year)

    # set model run parameters and initial values
    I_en = zeros(ntime, 1)
    run_leap = params["model"]["run_leap"]
    if run_leap
        max_runs = params["model"]["max_runs"]
        ## checks that user has LEAP installed
        if ismissing(LEAPfunctions.connecttoleap())
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
        indices = ModelCalculations(file, I_en, run)

        ## Compare run results
        if run >= 1
            tolerance = resultcomparison(params, run)
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
				LEAPfunctions.visible(false)
			end

            #------------status
            @info "Sending Macro output to LEAP..."
            #------------status
            LEAPfunctions.outputtoleap(file, indices, run)
            ## Run LEAP model
			try
				#------------status
				@info "Running LEAP model..."
				flush(logfile)
				#------------status
				LEAPfunctions.calculateleap(params["LEAP-info"]["result_scenario"])

				## Obtain energy investment data from LEAP
				#------------status
				@info "Obtaining LEAP results..."
				flush(logfile)
				#------------status
				I_en = LEAPfunctions.energyinvestment(file, run)
			finally
				if params["model"]["hide_leap"]
					#------------status
					@info "Restoring LEAP..."
					#------------status
					LEAPfunctions.visible(true)
				end
				flush(logfile)
			end
        end
		#------------status
		println("completed")
        #------------status

    end

end # runleapmacromodel

end
