"Module `Macro`: Implements the macroeconomic model in `LEAPMacro.jl`"
module Macro
using JuMP, GLPK, DelimitedFiles, LinearAlgebra, DataFrames, CSV, Logging, Suppressor, Formatting

export leapmacro

include("./SUTlib.jl")
include("./LEAPlib.jl")
include("./LEAPMacrolib.jl")
using .SUTlib, .LEAPlib, .LMlib

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

"Category weights for linear goal program"
mutable struct CategoryWeights
	u::AbstractFloat # utilization
	f::AbstractFloat # final demand
	x::AbstractFloat # exports
	m::AbstractFloat # imports
end

"Product & sector weight factors for the linear goal program"
mutable struct ProductSectorWeightFactors
	u::AbstractFloat # utilization
	f::AbstractFloat # final demand
	x::AbstractFloat # exports
end

"""
Calculate the Sraffa matrix, which is used to calculate domestic prices
  - np: number of products
  - ns: number of sectors
  - sut: SUTdata data structure
"""
function calc_sraffa_matrix(np::Integer, ns::Integer, sut::SUTdata)
	sraffa_matrix = Array{Float64}(undef, np, np)
	# Domestic prices
	for i in 1:np
		for j in 1:np
			sraffa_matrix[i,j] = sum(sut.μ[r] * sut.S[r,i] * sut.D[j,r] for r in 1:ns)
		end
	end
    return sraffa_matrix
end # calc_sraffa_matrix

"""
Evaluate the Sraffa system to get domestic prices
  - t: time index (for exchange rate)
  - np: number of products
  - ns: number of sectors
  - ω: wage share by sector
  - sut: SUTdata data structure
"""
function calc_dom_prices(t::Integer, np::Integer, ns::Integer, ω::Array{Float64,1}, prices::PriceData, sut::SUTdata, exog::ExogParams)
	sraffa_matrix = calc_sraffa_matrix(np, ns, sut)
	wage_vector = Array{Float64}(undef, np)
	world_price_vector = Array{Float64}(undef, np)
	for i in 1:np
		wage_vector[i] = prices.Pg * sum(sut.μ[r] * sut.S[r,i] * (ω[r] + sut.energy_share[r]) for r in 1:ns)
		world_price_vector[i] = exog.xr[t] * sum(sraffa_matrix[i,j] * sut.m_frac[j] * prices.pw[j] for j in 1:np)
	end
	sraffa_RHS = wage_vector + world_price_vector
	# Solve the Sraffa system and return the result
	inv(LinearAlgebra.I - [sraffa_matrix[i,j] * (1 - sut.m_frac[j]) for i in 1:np, j in 1:np]) * sraffa_RHS
end # calc_dom_prices

"""
Calculate growth rate of intermediate demand coefficients (that is, sut.D entries), or the intercepts (for initialization)	
  - σ(np,ns) = matrix of cost shares
  - k = single value or a vector (ns) of rate coefficients
  - θ = single value or vector (ns) of exponents
  - c(np,ns) = matrix of intercepts (if c = nothing it is set to zero)
  - b(np,ns) = matrix of weights (if b = nothing it is set to one)
"""
function calc_intermed_techchange(σ::Array{Float64,2}, k::LMlib.NumOrVector, θ::LMlib.NumOrVector = 2.0, c::LMlib.NumOrArray = nothing, b::LMlib.NumOrArray = nothing)
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
	elseif isa(b, Number)
		b = b * ones(np, ns)
	end
	if isnothing(c)
		c = zeros(np, ns)
	elseif isa(c, Number)
		c = c * ones(np, ns)
	end
	
	cost_shares_exponentiated = [σ[p,s]^θ[s] for p in 1:np, s in 1:ns]
	denom = sum(cost_shares_exponentiated .* b, dims = 1).^(1.0 .- 1.0 ./ θ)'
	num = [(cost_shares_exponentiated .* b ./ (σ .+ LMlib.ϵ))[p,s] * k[s] for p in 1:np, s in 1:ns]

	return c .- num ./ (denom .+ LMlib.ϵ)
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
function macro_main(params::Dict, leapvals::LEAPlib.LEAPresults, run_number::Integer, continue_if_error::Bool)
    #------------status
    @info LMlib.gettext("Loading data...")
    #------------status

	sut, np, ns = SUTlib.process_sut(params)
	prices = SUTlib.initialize_prices(np, sut)
	exog, techchange = SUTlib.get_var_params(params)

	# Preferentially take exogenous values from LEAP, if specified, if not then from file
	exog.pot_output = LMlib.get_nonmissing_values(leapvals.pot_output, exog.pot_output)
	exog.price = LMlib.get_nonmissing_values(leapvals.price, exog.price)

	# For exogenous potential output and world prices, values must be specified for all years, so get indices for first year
	pot_output_ndxs = findall(x -> !ismissing(x), exog.pot_output[1,:])
	pw_ndxs = findall(x -> !ismissing(x), exog.price[1,:])

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
	w = CategoryWeights(
		params["objective-fcn"]["category_weights"]["utilization"], # u
		params["objective-fcn"]["category_weights"]["final_demand_cov"], # f
		params["objective-fcn"]["category_weights"]["exports_cov"], # x
		params["objective-fcn"]["category_weights"]["imports_cov"] # m
	)
	ϕ = ProductSectorWeightFactors(
		params["objective-fcn"]["product_sector_weight_factors"]["utilization"], # u
		params["objective-fcn"]["product_sector_weight_factors"]["final_demand_cov"], # f
		params["objective-fcn"]["product_sector_weight_factors"]["exports_cov"] # x
	)
	# Taylor function
	tf = TaylorFunction(
		params["investment-fcn"]["init_neutral_growth"], # γ0
		params["taylor-fcn"]["neutral_growth_band"][1], # min_γ0
		params["taylor-fcn"]["neutral_growth_band"][2], # max_γ0
		params["taylor-fcn"]["gr_resp"], # gr_resp
		0.0, # π_targ, assigned below
		!LMlib.haskeyvalue(params["taylor-fcn"], "target_infl"), # π_targ_use_πw
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
	if LMlib.haskeyvalue(params["taylor-fcn"], "init_infl")
		tf.π_init = params["taylor-fcn"]["init_infl"]
	else
		tf.π_init = tf.π_targ
	end
	# Wage rate function
	wage_fn = WageAdjustment(
		params["wage-fcn"]["infl_passthrough"], # h
		params["wage-fcn"]["lab_constr_coeff"] # k
	)
	# Optionally update technical coefficients (the scaled Use matrix, sut.D)
	if params["tech-param-change"]["calculate"]
		techchange.coefficients = repeat(sum([sut.D[i,j]^techchange.exponent[j] for i = 1:np, j = 1:ns], dims = 1), np)
	end
	# Link to LEAP
	LEAP_indices = params["LEAP_sector_indices"]
	LEAP_drivers = params["LEAP_sector_drivers"]
	LEAP_use_xr = params["LEAP-investment"]["inv_costs_apply_xr"]
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
	Xnorm = (1.0 + params["calib"]["max_export_adj_factor"]) * sut.X
    Fnorm = (1.0 + params["calib"]["max_hh_dmd_adj_factor"]) * max.(sut.F,zeros(np))
	z = (1.0 + params["calib"]["pot_output_adj_factor"]) * sut.g

	#----------------------------------
    # Investment
    #----------------------------------
	# Total investment
    I_total = sum(sut.I)
	# Track non-energy investment separate from energy investment (which is supplied from LEAP)
    I_ne = I_total - leapvals.I_en[1]
    # Share of supply of investment goods
    θ = sut.I / sum(sut.I)
	# Initial values: These will change endogenously over time
	γ = γ_0
	i_bank = tf.i_targ

	#----------------------------------
    # Employment
    #----------------------------------
	# If not defined, then this will be an empty vector
	ℓ = exog.ℓ0

	#----------------------------------
    # Wages
    #----------------------------------
    W = sut.W
	ω = sut.W ./ sut.g
    replace!(ω, NaN=>0)
	wage_ratio = 1.0

	#----------------------------------
    # Domestic prices using a Sraffian price system
    #----------------------------------
	prices.pd = calc_dom_prices(1, np, ns, ω, prices, sut, exog)
	prices.pb = exog.xr[1] * sut.m_frac .* prices.pw + (1 .- sut.m_frac) .* prices.pd

	#----------------------------------
    # Capital productivity of new investment
    #----------------------------------
	# Intermediate variables
	profit_per_output = sut.Vnorm * prices.pd - (prices.Pg .* (ω + sut.energy_share) +  transpose(sut.D) * prices.pb)
	price_of_capital = dot(θ,prices.pb)
	I_nextper = (1 + params["investment-fcn"]["init_neutral_growth"]) * (1 + params["calib"]["nextper_inv_adj_factor"]) * I_ne
	profit_share_rel_capprice = (1/price_of_capital) * profit_per_output
	init_profit = sum((γ_0 + exog.δ) .* sut.g .* profit_share_rel_capprice)
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
    @info LMlib.gettext("Preparing model...")
    #------------status

    # model
    mdl = Model(GLPK.Optimizer)

	#----------------------------------
	# Product and sector weights for the objective function
	#----------------------------------
	u_sector_wt = ϕ.u * sut.g / sum(sut.g) + (1.0 - ϕ.u) * ones(ns)/ns
	f_sector_wt = ϕ.f * sut.F / sum(sut.F) + (1.0 - ϕ.f) * ones(np)/np
	x_sector_wt = ϕ.x * sut.X / sum(sut.X) + (1.0 - ϕ.x) * ones(np)/np

	#----------------------------------
	# A filter for products that are domestically supplied
	#----------------------------------
	no_dom_production = vec(sum(sut.S, dims=1)) .== 0

	#----------------------------------
    # Dynamic parameters
    #----------------------------------
	param_z = z
	param_Xnorm = Xnorm
	param_Fnorm = Fnorm
	param_I_tot = I_total
	param_prev_I_tot = 2 * I_total # Allow extra slack -- this sets a scale
	param_pw = prices.pw
	param_pd = prices.pd
	param_Pg = prices.Pg
	param_pb = prices.pb
	param_Mref = 2 * sut.M # Allow for some extra slack -- this just sets a scale
	param_mfrac = sut.m_frac
	# Initialize maximum utilization in multiple steps
	param_max_util = ones(ns)
	max_util_ndxs = findall(x -> !ismissing(x), exog.max_util[1,:])
	param_max_util[max_util_ndxs] .= exog.max_util[1,max_util_ndxs]
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
    @objective(mdl, Min, w.u * sum(u_sector_wt[i] * ugap[i] for i in 1:ns) +
					     w.f * sum(f_sector_wt[i] * fgap[i] for i in 1:np) +
						 w.x * sum(x_sector_wt[i] * xgap[i] for i in 1:np) +
						 w.m * (sum(ψ_pos[i] + ψ_neg[i] for i in 1:np)))

    #----------------------------------
    # Constraints
    #----------------------------------
    # Sector constraints
	@constraint(mdl, eq_util[i = 1:ns], u[i] + ugap[i] == param_max_util[i])
	# Fundamental input-output equation
	@constraint(mdl, eq_io[i = 1:ns], sum(sut.S[i,j] * param_pb[j] * qs[j] for j in 1:np) - param_Pg * param_z[i] * u[i] == 0)
    # Product constraints
	# Variables for objective function (goal program)
	@constraint(mdl, eq_xshare[i = 1:np], xshare[i] + xgap[i] == 1.0)
	@constraint(mdl, eq_X[i = 1:np], X[i] == xshare[i] * param_Xnorm[i])
	@constraint(mdl, eq_fshare[i = 1:np], fshare[i] + fgap[i] == 1.0)
	@constraint(mdl, eq_F[i = 1:np], F[i] == fshare[i] * param_Fnorm[i])
	# Intermediate demand
	@constraint(mdl, eq_intdmd[i = 1:np], qd[i] - sum(sut.D[i,j] * u[j] * param_z[j] for j in 1:ns) == 0)
	# Investment
	fix(I_tot, param_I_tot)
	@constraint(mdl, eq_inv_supply[i = 1:np], I_supply[i] == θ[i] * I_tot)
	# Total supply
	@constraint(mdl, eq_totsupply[i = 1:np], qs[i] == qd[i] - margins_pos[i] + margins_neg[i] + X[i] + F[i] + I_supply[i] - M[i])
	@constraint(mdl, eq_no_dom_prod[i = 1:np], qs[i] * no_dom_production[i] == 0)
	# Imports
	@constraint(mdl, eq_M[i = 1:np], M[i] == param_mfrac[i] * (qd[i] + F[i] + I_supply[i]) + param_Mref[i] * (ψ_pos[i] - ψ_neg[i]))
	# Margins
	@constraint(mdl, eq_margpos[i = 1:np], margins_pos[i] == sut.marg_pos_ratio[i] * (qs[i] + M[i]))
	@constraint(mdl, eq_margneg[i = 1:np], margins_neg[i] == sut.marg_neg_share[i] * sum(margins_pos[j] for j in 1:np))

    #------------------------------------------
    # Calibration run
    #------------------------------------------
	if params["report-diagnostics"]
		open(joinpath(params["diagnostics_path"], format("{1}_{2}_{3}_1.txt", LMlib.gettext("model"), run_number, LMlib.gettext("calibration"))), "w") do f
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
    @info format(LMlib.gettext("Calibrating for {1}: {2}"), years[1], status)

	# Sector variables
    LMlib.write_vector_to_csv(joinpath(params["calibration_path"], string("capacity_utilization_",run_number,".csv")), value.(u), LMlib.gettext("capacity utilization"), params["included_sector_codes"])
    LMlib.write_vector_to_csv(joinpath(params["calibration_path"], string("sector_output_",run_number,".csv")), value.(u) .* z, LMlib.gettext("sector output"), params["included_sector_codes"])
    LMlib.write_vector_to_csv(joinpath(params["calibration_path"], string("wage_share_",run_number,".csv")), ω, LMlib.gettext("wage share"), params["included_sector_codes"])
	LMlib.write_vector_to_csv(joinpath(params["calibration_path"], string("capital_output_ratio_",run_number,".csv")), capital_output_ratio, LMlib.gettext("capital-output ratio"), params["included_sector_codes"])
    
	# Product variables
	LMlib.write_vector_to_csv(joinpath(params["calibration_path"], string("exports_",run_number,".csv")), value.(X), LMlib.gettext("exports"), params["included_product_codes"])
    LMlib.write_vector_to_csv(joinpath(params["calibration_path"], string("final_demand_",run_number,".csv")), value.(F), LMlib.gettext("final demand"), params["included_product_codes"])
    LMlib.write_vector_to_csv(joinpath(params["calibration_path"], string("imports_",run_number,".csv")), value.(M), LMlib.gettext("imports"), params["included_product_codes"])
    LMlib.write_vector_to_csv(joinpath(params["calibration_path"], string("domestic_production_",run_number,".csv")), value.(qs), LMlib.gettext("domestic production"), params["included_product_codes"])
    LMlib.write_vector_to_csv(joinpath(params["calibration_path"], string("tot_intermediate_supply_non-energy_sectors_",run_number,".csv")), value.(qd), LMlib.gettext("intermediate supply from non-energy sectors"), params["included_product_codes"])
    LMlib.write_vector_to_csv(joinpath(params["calibration_path"], string("basic_prices_",run_number,".csv")), param_pb, LMlib.gettext("basic prices"), params["included_product_codes"])
    LMlib.write_vector_to_csv(joinpath(params["calibration_path"], string("margins_neg_",run_number,".csv")), value.(margins_neg), LMlib.gettext("negative margins"), params["included_product_codes"])
    LMlib.write_vector_to_csv(joinpath(params["calibration_path"], string("margins_pos_",run_number,".csv")), value.(margins_pos), LMlib.gettext("positive margins"), params["included_product_codes"])

    # First run is calibration -- now set Xnorm and Fnorm based on solution and run again
    Xnorm = max.(Xnorm, value.(X))
    Fnorm = max.(Fnorm, value.(F))
	param_Xnorm = Xnorm
	param_Fnorm = Fnorm
	for i in 1:np
		set_normalized_coefficient(eq_X[i], xshare[i], -param_Xnorm[i])
		set_normalized_coefficient(eq_F[i], fshare[i], -param_Fnorm[i])
	end
	if params["report-diagnostics"]
		open(joinpath(params["diagnostics_path"], format("{1}_{2}_{3}_2.txt", LMlib.gettext("model"), run_number, LMlib.gettext("calibration"))), "w") do f
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
    πb = ones(length(prices.pb)) .* (sut.m_frac .* πw + (1 .- sut.m_frac) .* πd)

	pw_prev = prices.pw ./ (1 .+ πw)
	pd_prev = prices.pd ./ (1 .+ πd)
    pb_prev = param_pb ./ (1 .+ πb)
    prev_GDP = sum(param_pb[i] * (value.(qs) - value.(qd))[i] for i in 1:np)/(1 + params["investment-fcn"]["init_neutral_growth"])
	prev_g = value.(u) .* z
	prev_g_share = pd_prev .* value.(qs)/sum(pd_prev .* value.(qs))
	prev_g_gr = ones(ns) * params["investment-fcn"]["init_neutral_growth"]

	smoothed_world_gr = params["global-params"]["gr_default"]

	if !all(ismissing.(exog.pot_output[1,:]))
		prev_pot_prod = sum(exog.pot_output[1,i] * sut.Vnorm[i,:] for i in pot_output_ndxs)
	else
		prev_pot_prod = zeros(np)
	end

	prev_GDP_deflator = 1
    prev_GDP_gr = params["investment-fcn"]["init_neutral_growth"]
    πg = sum(prev_g_share .* πb)
	πF = sum(πb .* value.(F))/sum(value.(F))
	if params["tech-param-change"]["calculate"]
		sector_price_level = (sut.S * (pd_prev .* value.(qs))) ./ (value.(u) .* z)
		intermed_cost_shares = [pb_prev[i] * sut.D[i,j] / sector_price_level[j] for i in 1:np, j in 1:ns]
		# Initialize intercepts so that productivity growth rates are zero with initial cost shares
		techchange.constants = -calc_intermed_techchange(intermed_cost_shares,
														 techchange.rate_const,
														 techchange.exponent,
														 nothing,
														 techchange.coefficients)
	end

	lab_force_index = 1

	#--------------------------------
	# Initialize array of indices to pass to LEAP
	#--------------------------------
	labels = [LMlib.gettext("Year")]
	if LMlib.haskeyvalue(params, "GDP-branch")
		labels = vcat(labels, params["GDP-branch"]["name"])
	end
	if LMlib.haskeyvalue(params, "Employment-branch")
		labels = vcat(labels, params["Employment-branch"]["name"])
	end
	if LMlib.haskeyvalue(params, "LEAP_sector_names")
		labels = vcat(labels, params["LEAP_sector_names"])
	end
	indices = Array{Float64}(undef, length(years), length(labels))

	#------------------------------------------
    # Initialize files for writing results
    #------------------------------------------
	# Get sector and product labels
	sector_names = params["included_sector_names"]
	product_names = params["included_product_names"]
	# Quote the sector and product names (for putting into CSV files)
	LMlib.stringvec_to_quotedstringvec!(sector_names)
	LMlib.stringvec_to_quotedstringvec!(product_names)

	# Create files for sector variables
	LMlib.write_header_to_csv(params, sector_names, "sector_output", run_number)
	LMlib.write_header_to_csv(params, sector_names, "potential_sector_output", run_number)
	LMlib.write_header_to_csv(params, sector_names, "capacity_utilization", run_number)
	LMlib.write_header_to_csv(params, sector_names, "real_value_added", run_number)
	LMlib.write_header_to_csv(params, sector_names, "profit_rate", run_number)
	LMlib.write_header_to_csv(params, sector_names, "autonomous_investment_rate", run_number)
	LMlib.write_header_to_csv(params, sector_names, "domestic_insertion", run_number)
	if params["labor-prod-fcn"]["use_sector_params"]
		LMlib.write_header_to_csv(params, sector_names, "sector_employment", run_number)
	end
	# Create files for product variables
	LMlib.write_header_to_csv(params, product_names, "final_demand", run_number)
	LMlib.write_header_to_csv(params, product_names, "imports", run_number)
	LMlib.write_header_to_csv(params, product_names, "exports", run_number)
	LMlib.write_header_to_csv(params, product_names, "basic_prices", run_number)
	LMlib.write_header_to_csv(params, product_names, "domestic_prices", run_number)
	# Create a file to hold scalar variables
	scalar_var_list = [LMlib.gettext("GDP gr"), LMlib.gettext("curr acct surplus to GDP ratio"), LMlib.gettext("curr acct surplus"), LMlib.gettext("real GDP"),
					   LMlib.gettext("GDP deflator"), LMlib.gettext("labor productivity gr"), LMlib.gettext("labor force gr"), LMlib.gettext("real investment"),
					   LMlib.gettext("central bank rate"), LMlib.gettext("terms of trade index"), LMlib.gettext("real xr index"), LMlib.gettext("nominal xr index")]
	LMlib.stringvec_to_quotedstringvec!(scalar_var_list)
	LMlib.write_header_to_csv(params, scalar_var_list, "collected_variables", run_number)

	#############################################################################
	#
    # Run simulation
	#
	#############################################################################
    @info format(LMlib.gettext("Running from {1} to {2}:"), years[2], last(years))

    previous_failed = false
    for t in eachindex(years)
		#--------------------------------
		# Output
		#--------------------------------
		if !previous_failed
			g = value.(u) .* z
			g_gr = g ./ prev_g .- 1.0
			g_share = pd_prev .* value.(qs)/sum(pd_prev .* value.(qs))
			prev_g = g
			prev_g_share = g_share
		else
			g = prev_g
			g_gr = prev_g_gr
			g_share = prev_g_share
		end

		#--------------------------------
		# Price indices and deflators
		#--------------------------------
		# If the specified XR series is real, convert to nominal using modeled price indices
		if params["files"]["xr-is-real"]
			exog.xr[t] *= prices.Pg/prices.Ptrade
		end		
        # This is used here if the previous calculation failed, but is also reported below
        va_at_prev_prices_1 = prices.Pg * g
        va_at_prev_prices_2 = sum(pb_prev[j] * sut.D[j,:] for j in 1:np) .* g
        value_added_at_prev_prices = va_at_prev_prices_1 - va_at_prev_prices_2
        if previous_failed
            pd_prev = pd_prev .* (1 .+ πd)
            pb_prev = pb_prev .* (1 .+ πb)
            pw_prev = pw_prev .* (1 .+ πw)
            va1 = (1 + πg) * prices.Pg * g
            va2 = sum(value.(param_pb)[j] * sut.D[j,:] for j in 1:np) .* g
            value_added = va1 - va2
            πGDP = sum(value_added)/sum(value_added_at_prev_prices) - 1
			π_imp = exog.πw_base[1]
			π_exp = exog.πw_base[1]
			π_trade = exog.πw_base[1]
            GDP_gr = prev_GDP_gr
			GDP = prev_GDP * (1 + GDP_gr)
        else
			πd = (param_pd - pd_prev) ./ (pd_prev .+ LMlib.ϵ) # If not produced, pd_prev = 0
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
		# Apply the Kaldor-Verdoorn equation for labor productivity (if not used, then αKV = 0 and βKV = fixed labor productivity growth rate)
		if !params["labor-prod-fcn"]["use_sector_params"]
			λ_gr_scalar = exog.αKV[t] * GDP_gr + exog.βKV[t]
			L_gr = (1.0 + GDP_gr)/(1.0 + λ_gr_scalar) - 1.0 # Labor force growth rate
			λ_gr = ones(ns) * λ_gr_scalar # Sectoral labor productivity growth rate
		else
			λ_gr = exog.αKV .* g_gr + exog.βKV # Sectoral labor productivity growth rate
			ℓ_gr = (1.0 .+ g_gr)./(1.0 .+ λ_gr) .- 1.0
			L_prev = sum(ℓ)
			ℓ = (1.0 .+ ℓ_gr) .* ℓ
			L_gr = sum(ℓ)/L_prev - 1.0 # Labor force growth rate
			λ_gr_scalar = (1.0 + GDP_gr)/(1.0 + L_gr) - 1.0
		end
	
		lab_force_index *= 1.0 + L_gr

		w_gr = wage_fn.h * πF .+ λ_gr * (1.0 + wage_fn.k * (L_gr - exog.working_age_grs[t]))
		ω_gr = ((1.0 .+ w_gr)./(1.0 .+ λ_gr))/(1.0 + πg) .- 1.0
		ω = (1.0 .+ ω_gr) .* ω

		#--------------------------------
		# Update use matrix
		#--------------------------------
		if params["tech-param-change"]["calculate"] && !previous_failed
			sector_price_level = (sut.S * (pd_prev .* value.(qs))) ./ g
			intermed_cost_shares = [pb_prev[i] * sut.D[i,j] / sector_price_level[j] for i in 1:np, j in 1:ns]
			D_hat = calc_intermed_techchange(intermed_cost_shares,
											 techchange.rate_const,
											 techchange.exponent,
											 techchange.constants,
											 techchange.coefficients)
			sut.D = sut.D .* exp.(D_hat) # This ensures that sut.D will not become negative
			if params["report-diagnostics"]
				LMlib.write_matrix_to_csv(joinpath(params["diagnostics_path"],"demand_coefficients_" * string(years[t]) * ".csv"), sut.D, params["included_product_codes"], params["included_sector_codes"])
			end
		end

		#--------------------------------
		# Profits
		#--------------------------------
		if !previous_failed
			# First, update the Vnorm matrix
			sut.Vnorm = Diagonal(1 ./ (g .+ LMlib.ϵ)) * sut.S * Diagonal(value.(qs))
			# Calculate export-weighted price
			export_share = value.(X) ./ (value.(qs) .+ LMlib.ϵ)
			px = exog.xr[t] * export_share .* prices.pw + (1 .- export_share) .* prices.pd
			profit_per_output = sut.Vnorm * px - (prices.Pg .* (ω + sut.energy_share) +  transpose(sut.D) * prices.pb)
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
			if t < length(years)
				γ_spec = exog.pot_output[t + 1,:] ./ exog.pot_output[t,:] .- 1.0
				γ[pot_output_ndxs] .= γ_spec[pot_output_ndxs]
			end
		end

		# Non-energy investment, by sector and total
        I_ne_disag = z .* (γ + exog.δ) .* capital_output_ratio
        I_ne = sum(I_ne_disag)
		# Combine with energy investment and any additional exogenous investment
        I_total = I_ne + (LEAP_use_xr ? exog.xr[t] : 1) * leapvals.I_en[t] + exog.I_addl[t]
		# Update autonomous investment term
        γ_0 = γ_0 + growth_adj * (γ - γ_0)

		#--------------------------------
		# Export demand
		#--------------------------------
		if !all(ismissing.(exog.pot_output[t,:]))
			# Export demand is calculated differently when potential output is exogenously specified
			pot_prod = sum(exog.pot_output[t,i] * sut.Vnorm[i,:] for i in pot_output_ndxs)
			# -- extent of externally specified output
			pot_prod_spec_factor = sum(sut.Vnorm[i,:] * z[i] for i in pot_output_ndxs) ./ (sut.Vnorm' * z .+ LMlib.ϵ)
		else
			pot_prod = zeros(np)
			pot_prod_spec_factor = zeros(np)
		end
		# -- scale factor
		Xnorm_scale_factor = (1 .- pot_prod_spec_factor) .+  pot_prod_spec_factor .* pot_prod ./ (prev_pot_prod .+ LMlib.ϵ)
		prev_pot_prod = pot_prod
		# -- income factor
		smoothed_world_gr += growth_adj * (exog.world_grs[t] - smoothed_world_gr)
		Xnorm_income_factor = (1 + exog.world_grs[t]) ./ (1 .+ pot_prod_spec_factor * smoothed_world_gr)
		# -- price factor
		Xnorm_price_factor = (1 .+ πw)./(1 .+ πd)
		# -- updated value
        Xnorm = Xnorm .* Xnorm_scale_factor .* Xnorm_income_factor.^exog.export_elast_demand[t] .* Xnorm_price_factor.^exog.export_price_elast

		#--------------------------------
		# Final domestic consumption demand
		#--------------------------------
		# Wage ratio drives increase in quantity, so use real wage increase, deflate by Pg
		W_curr = sum(W)
        W = ((1 .+ w_gr)./(1 .+ λ_gr)) .* W .* (1 .+ γ)
        wage_ratio = (1/(1 + πF)) * sum(W)/W_curr
        Fnorm = Fnorm .* max.(LMlib.ϵ,wage_ratio).^exog.wage_elast_demand[t]

		#--------------------------------
		# Calculate indices to pass to LEAP
		#--------------------------------
        indices[t,1] = years[t]
		curr_index = 1
		if LMlib.haskeyvalue(params, "GDP-branch")
			curr_index += 1
			indices[t,curr_index] = GDP
		end
		if LMlib.haskeyvalue(params, "Employment-branch")
			curr_index += 1
			indices[t,curr_index] = lab_force_index
		end
	
 		for i in eachindex(LEAP_indices)
			indices[t, curr_index + i] = 0
			for j in LEAP_indices[i]
				if LEAP_drivers[i] == "VA"
					indices[t, curr_index + i] += value_added_at_prev_prices[j]/prev_GDP_deflator
				else
					indices[t, curr_index + i] += g[j]
				end
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
		prices.RER = prices.XR * prices.Ptrade/prices.Pg
		prices.Pg *= (1 + πg)
		prices.Pm *= (1 + π_imp)
		prices.Px *= (1 + π_exp)
		prices.Ptrade *= (1 + π_trade)
		# For pw, first apply global inflation rate to world prices
		prices.pw = prices.pw * (1 + exog.πw_base[t])
		# Then adjust for any exogenous price indices
		if t < length(years)
			pw_spec = exog.price[t + 1,:] ./ exog.price[t,:]
			prices.pw[pw_ndxs] .= prices.pw[pw_ndxs] .* pw_spec[pw_ndxs]
		end
		# Calculate XR trend
		if t > 1
			prices.XR *= exog.xr[t]/exog.xr[t-1]
		end	

		if !previous_failed
			sut.m_frac = (value.(M) + LMlib.ϵ * sut.m_frac) ./ (value.(qd) + value.(F) + value.(I_supply) .+ LMlib.ϵ)
		end
		prices.pd = calc_dom_prices(t, np, ns, ω, prices, sut, exog)
		prices.pb = exog.xr[t] * sut.m_frac .* prices.pw + (1 .- sut.m_frac) .* prices.pd
		
		# Domestic insertion statistic
		A = sut.S * sut.D
		#Adom = sut.S * ((1 .- sut.m_frac) .* sut.D)
		Adom = [sum(sut.S[i,k] * (1 - sut.m_frac[k]) * sut.D[k,j] for k in 1:np) for i in 1:ns, j in 1:ns]
		dom_insert = sum(inv(LinearAlgebra.I - Adom), dims = 1) ./ sum(inv(LinearAlgebra.I - A), dims = 1)

		# Sector variables
		LMlib.append_row_to_csv(params, g, "sector_output", run_number, years[t])
		LMlib.append_row_to_csv(params, z, "potential_sector_output", run_number, years[t])
		LMlib.append_row_to_csv(params, u_report, "capacity_utilization", run_number, years[t])
		LMlib.append_row_to_csv(params, value_added_at_prev_prices/prev_GDP_deflator, "real_value_added", run_number, years[t])
		LMlib.append_row_to_csv(params, profit_rate, "profit_rate", run_number, years[t])
		LMlib.append_row_to_csv(params, γ_0, "autonomous_investment_rate", run_number, years[t])
		LMlib.append_row_to_csv(params, dom_insert, "domestic_insertion", run_number, years[t])
		if params["labor-prod-fcn"]["use_sector_params"]
			LMlib.append_row_to_csv(params, ℓ, "sector_employment", run_number, years[t])
		end
		# Product variables
		LMlib.append_row_to_csv(params, F_report, "final_demand", run_number, years[t])
		LMlib.append_row_to_csv(params, M_report, "imports", run_number, years[t])
		LMlib.append_row_to_csv(params, X_report, "exports", run_number, years[t])
		LMlib.append_row_to_csv(params, param_pb, "basic_prices", run_number, years[t])
		LMlib.append_row_to_csv(params, param_pd, "domestic_prices", run_number, years[t])
		# Scalar variables
		scalar_var_vals = [GDP_gr, CA_to_GDP_ratio, CA_surplus, GDP, GDP_deflator, λ_gr_scalar, L_gr,
							param_I_tot, i_bank, prices.Px/prices.Pm, prices.RER, prices.XR]
		LMlib.append_row_to_csv(params, scalar_var_vals, "collected_variables", run_number, years[t])

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
		param_Xnorm = Xnorm
		param_Fnorm = Fnorm
		param_I_tot = I_total
		param_prev_I_tot = 2 * I_total # Allow extra slack -- this sets a scale
		param_pw = prices.pw
		param_pd = prices.pd
		param_pb = prices.pb
		param_z = z
		# Caluculate updated m_frac for use in goal program
		adj_import_price_elast = max.(0, 1 .- sut.m_frac) .* exog.import_price_elast
		param_mfrac = sut.m_frac .* ((1 .+ πd)./(1 .+ πw)).^adj_import_price_elast
		# Set maximum utilization in multiple steps
		param_max_util = ones(ns)
		max_util_ndxs = findall(x -> !ismissing(x), exog.max_util[t + 1,:])
		param_max_util[max_util_ndxs] .= exog.max_util[t + 1,max_util_ndxs]

		for i in 1:ns
			set_normalized_coefficient(eq_io[i], u[i], -param_Pg * param_z[i])
			set_normalized_rhs(eq_util[i], param_max_util[i])
			for j in 1:np
				set_normalized_coefficient(eq_io[i], qs[j], sut.S[i,j] * param_pb[j])
			end
		end
		for i in 1:np
			set_normalized_coefficient(eq_X[i], xshare[i], -param_Xnorm[i])
			set_normalized_coefficient(eq_F[i], fshare[i], -param_Fnorm[i])
			set_normalized_coefficient(eq_M[i], ψ_pos[i], -param_Mref[i])
			set_normalized_coefficient(eq_M[i], ψ_neg[i], param_Mref[i])
			set_normalized_coefficient(eq_M[i], qd[i], -param_mfrac[i])
			set_normalized_coefficient(eq_M[i], F[i], -param_mfrac[i])
			set_normalized_coefficient(eq_M[i], I_supply[i], -param_mfrac[i])
			for j in 1:ns
				set_normalized_coefficient(eq_intdmd[i], u[j], -sut.D[i,j] * param_z[j])
			end
		end
		fix(I_tot, param_I_tot)

		if params["report-diagnostics"]
			open(joinpath(params["diagnostics_path"], format("{1}_{2}_{3}.txt", LMlib.gettext("model"), run_number, years[t])), "w") do f
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
        @info format(LMlib.gettext("Simulating for {1}: {2}"), years[t + 1], status)
        previous_failed = status != MOI.FEASIBLE_POINT
        if previous_failed
			nndx_extra = 1 + (LMlib.haskeyvalue(params, "GDP-branch") ? 1 : 0) + (LMlib.haskeyvalue(params, "Employment-branch") ? 1 : 0)
			finndx = nndx_extra + length(LEAP_indices) # Adds columns for year and, if present, GDP, employment
            indices[t,nndx_extra:finndx] = fill(NaN, (finndx - nndx_extra) + 1)
			if !continue_if_error
				throw(ErrorException(format(LMlib.gettext("Linear goal program failed to solve: {1}"), status)))
			end
        end
    end

    # Make indices into indices
	if size(indices)[2] > 1
		indices_0 = indices[1,:]
		for t in eachindex(years)
			indices[t,2:end] = indices[t,2:end] ./ indices_0[2:end]
		end
		open(joinpath(params["results_path"], format("indices_{1}.csv", run_number)), "w") do io
				writedlm(io, reshape(labels, 1, :), ',')
				writedlm(io, indices, ',')
		end
	end

	# Release the model
	mdl = nothing

    return indices
end # macro_main

"Compare the GDP, employment, and value added indices generated from different runs and calculate the maximum difference."
function compare_results(params::Dict, run_number::Integer)
    # Obtains data from indices files for current run and previous run
    file1 = joinpath(params["results_path"], string("indices_",run_number,".csv"))
    file2 = joinpath(params["results_path"], string("indices_",run_number-1,".csv"))

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
function leapmacro(param_file::AbstractString,
				   logfile::IOStream,
				   include_energy_sectors::Bool = false,
				   load_leap_first::Bool = false,
				   get_results_from_leap_version::Union{Nothing,Integer,AbstractString} = nothing,
				   only_push_leap_results::Bool = false,
				   run_number_start::Integer = 0,
				   continue_if_error::Bool = false)

    # Read in global parameters
    params = SUTlib.parse_param_file(param_file, include_energy_sectors = include_energy_sectors)

	# Clean up folders if requested
	clean_folders(params)

	# set model run parameters and initial values
    leapvals = LEAPlib.initialize_leapresults(params)
    run_leap = params["model"]["run_leap"]
    if run_leap
		if !only_push_leap_results
	        max_runs = run_number_start + params["model"]["max_runs"]
		else
			max_runs = run_number_start
		end
        ## checks that user has LEAP installed
        if ismissing(LEAPlib.connect_to_leap())
            @error LMlib.gettext("Cannot connect to LEAP. Please check that LEAP is installed, or set 'run_leap: false' in the configuration file.")
            return
        end
		if load_leap_first
			## Obtain LEAP results
			if !isnothing(get_results_from_leap_version)
				status_string = format(LMlib.gettext("Obtaining LEAP results from version '{1}'..."), LEAPlib.get_version_info(get_results_from_leap_version))
			else
				status_string = LMlib.gettext("Obtaining LEAP results...")
			end
			#------------status
			@info status_string
			flush(logfile)
			#------------status
			leapvals = LEAPlib.get_results_from_leap(params, run_number_start, get_results_from_leap_version)
		end
    else
        max_runs = run_number_start
    end
    max_tolerance = params["model"]["max_tolerance"]

	if include_energy_sectors
		println(format(LMlib.gettext("With configuration file '{1}' (including energy sectors):"), param_file))
	else
		println(format(LMlib.gettext("With configuration file '{1}':"), param_file))
	end
    for run_number = run_number_start:max_runs
        ## Run Macro model
        #------------status
		run_string = format(LMlib.gettext("Macro model run ({1})..."), run_number)
		print(run_string)
        @info run_string
        indices = macro_main(params, leapvals, run_number, continue_if_error)
		#------------status
		println(LMlib.gettext("completed"))
        #------------status

        ## Compare run results
        if run_number >= run_number_start + 1
            tolerance = compare_results(params, run_number)
            if tolerance <= max_tolerance
                @info format(LMlib.gettext("Convergence in run number {1} at {2:.2f}% ≤ {3:.2f}% target..."), run_number, tolerance, max_tolerance)
                return
            else
                @info format(LMlib.gettext("Results did not converge: {1:.2f}% > {2:.2f}% target..."), tolerance, max_tolerance)
                if run_number == max_runs
                    return
                end
            end
        end

        ## Send output to LEAP
        if run_leap
			if params["model"]["hide_leap"]
				#------------status
				@info LMlib.gettext("Hiding LEAP to improve performance...")
				#------------status
				LEAPlib.hide_leap(true)
			end

            #------------status
            @info LMlib.gettext("Sending Macro output to LEAP...")
            #------------status
            LEAPlib.send_results_to_leap(params, indices)
            ## Run LEAP model
			if !only_push_leap_results
				try
					#------------status
					@info LMlib.gettext("Running LEAP model...")
					flush(logfile)
					#------------status
					LEAPlib.calculate_leap(params["LEAP-info"]["result_scenario"])

					## Obtain LEAP results
					#------------status
					@info LMlib.gettext("Obtaining LEAP results...")
					flush(logfile)
					#------------status
					leapvals = LEAPlib.get_results_from_leap(params, run_number + 1)
				finally
					if params["model"]["hide_leap"]
						#------------status
						@info LMlib.gettext("Restoring LEAP...")
						#------------status
						LEAPlib.hide_leap(false)
					end
					flush(logfile)
				end
			end
        end

    end

end # leapmacro

end # Macro
