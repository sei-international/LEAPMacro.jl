module MacroModel
using JuMP, GLPK, DelimitedFiles, LinearAlgebra, DataFrames, CSV, Logging, Printf, Suppressor

export runleapmacromodel

include("./IOlib.jl")
include("./LEAPfunctions.jl")
using .IOlib, .LEAPfunctions

"""
    output_var(values, filename, index, rowlabel, mode)

Report output values by writing to specified CSV files.
"""
function output_var(values, filename, index, rowlabel, mode)
	if isa(values, Array)
		usevalue = join(values, ',')
	else
		usevalue = values
	end
	open(string("outputs/", filename, "_", index,".csv"), mode) do io
		write(io, string(rowlabel, ',', usevalue, '\n'))
	end
end

"""
    to_quoted_string_vec(svec)

Convert a vector of strings by wrapping each string in quotes (for putting into CSV files).
This function converts `svec` in-place, so only run once.
"""
function to_quoted_string_vec(svec)
	for i in 1:length(svec)
		svec[i] = string('\"', svec[i], '\"')
	end
end

"""
    calc_sraffa_inverse(np::Int64, ns::Int64, tradeables::Array{Bool,1}, io::IOdata)

Calculate the Sraffa inverse matrix, which is used to calculate domestic prices
"""
function calc_sraffa_inverse(np::Int64, ns::Int64, tradeables::Array{Bool,1}, io::IOdata)
	sraffa_matrix = Array{Float64}(undef, np, np)
	sraffa_matrix .= 0.0
	# Domestic prices
	for i in findall(.!tradeables)
		for j in 1:np
			sraffa_matrix[i,j] = ((1 + io.τd[j])/(1 + io.τd[i])) * sum(io.μ[r] * io.S[r,i] * io.D[j,r] for r in 1:ns)
		end
	end
    inv(LinearAlgebra.I - sraffa_matrix)
end

"""
    calc_sraffa_RHS(t::Int64, np::Int64, ns::Int64, ω::Array{Float64,1}, tradeables::Array{Bool,1}, prices::PriceData, io::IOdata, iovar::IOvarParams)

Calculate the Sraffa right-hand side expression, which is multiplied by the Sraffa inverse matrix to give domestic prices
"""
function calc_sraffa_RHS(t::Int64, np::Int64, ns::Int64, ω::Array{Float64,1}, tradeables::Array{Bool,1}, prices::PriceData, io::IOdata, iovar::IOvarParams)
	sraffa_wage_vector = Array{Float64}(undef, np)
	sraffa_wage_vector .= 0.0 # Initialize to zero
	for i in findall(.!tradeables)
		sraffa_wage_vector[i] = (1/(1 + io.τd[i])) * sum(io.μ[r] * io.S[r,i] * ω[r] for r in 1:ns)
	end
	# Initialize prices.pd
	sraffa_RHS = prices.Pg * sraffa_wage_vector
	for i in findall(tradeables)
		sraffa_RHS[i] = iovar.xr[t] * prices.pw[i]
	end
	return sraffa_RHS
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
		if params["report-diagnostics"] & !isdir("diagnostics")
			mkdir("diagnostics")
		end

		if params["clear-folders"]["outputs"]
			for f in readdir("outputs/")
				rm(joinpath("outputs/", f))
			end
		end
		if params["clear-folders"]["calibration"]
			for f in readdir("calibration/")
				rm(joinpath("calibration/", f))
			end
		end
		if params["clear-folders"]["diagnostics"] & isdir("diagnostics")
			for f in readdir("diagnostics/")
				rm(joinpath("diagnostics/", f))
			end
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
    neutral_growth = params["investment-fcn"]["neutral_growth"]
    util_sens_scalar = params["investment-fcn"]["util_sens"]
    profit_sens = params["investment-fcn"]["profit_sens"]
    intrate_sens = params["investment-fcn"]["intrate_sens"]
    growth_adj = params["investment-fcn"]["growth_adj"]
	# Linear program objective function
    wu = params["objective-fcn"]["category_weights"]["utilization"]
    wf = params["objective-fcn"]["category_weights"]["fin_dmd_cov"]
    wx = params["objective-fcn"]["category_weights"]["exports_cov"]
    wm = params["objective-fcn"]["category_weights"]["imports_cov"]
	ϕu = params["objective-fcn"]["product_sector_weight_factors"]["utilization"]
	ϕf = params["objective-fcn"]["product_sector_weight_factors"]["fin_dmd_cov"]
	ϕx = params["objective-fcn"]["product_sector_weight_factors"]["exports_cov"]
	# Taylor function
    tf_i_targ = params["taylor-fcn"]["target_intrate"]
    tf_gr_resp = params["taylor-fcn"]["gr_resp"]
    tf_π_targ = params["taylor-fcn"]["target_infl"]
	tf_π_targ_use_πw = isnothing(tf_π_targ)
    tf_infl_resp = params["taylor-fcn"]["infl_resp"]
	# Wage rate function
	infl_passthrough = params["wage-fcn"]["infl_passthrough"]
	lab_constr_coeff = params["wage-fcn"]["lab_constr_coeff"]
	LEAP_indices = params["LEAP_sector_indices"]

	#----------------------------------
    # Calculate variables based on parameters
    #----------------------------------
	# Number of time steps
	ntime = 1 + (final_year - base_year)
	# Initial autonomous growth rate
	γ_0 = neutral_growth * ones(ns)
	# Set up a "tradeables" filter
    tradeables = [true for i in 1:np] # Initialize to true
    tradeables[params["non-tradeable-range"]] = [false for i in params["non-tradeable-range"]]

	#----------------------------------
    # Read in exogenous time-varying parameters and sector-specific parameters
    #----------------------------------
	iovar = IOlib.get_var_params(file)
	# Convert pw into global currency
	prices.pw = prices.pw/iovar.xr[1]

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
	# Share of supply of imported investment goods (which excludes non-tradeables, e.g., construction)
	θ_imp = (io.I .* tradeables)/sum(io.I .* tradeables)
	# Investment function parameter -- make a vector
    util_sens = util_sens_scalar * ones(ns)
	# Initial values: These will change endogenously over time
	γ = γ_0
	i_bank = tf_i_targ

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
	sraffa_inverse = calc_sraffa_inverse(np, ns, tradeables, io)
    prices.pd = sraffa_inverse * calc_sraffa_RHS(1, np, ns, ω, tradeables, prices, io, iovar)
	prices.pb = prices.pd

	#----------------------------------
    # Capital productivity of new investment
    #----------------------------------
	# Intermediate variables
	profit_per_output = io.Vnorm * prices.pd - (prices.Pg .* ω +  transpose(io.D) * ((ones(np) + io.τd) .* prices.pd))
	price_of_capital = dot(θ,(ones(np) + io.τd) .* prices.pd)
	I_nextper = (1 + neutral_growth) * (1 + params["calib"]["nextper_inv_adj_factor"]) * I_ne
	profit_share_rel_capprice = (1/price_of_capital) * profit_per_output
	incr_profit = sum((γ_0 + iovar.δ) .* io.g .* profit_share_rel_capprice)
    incr_profit_rate = incr_profit/I_nextper
	# Capital productivity
    capital_output_ratio = profit_share_rel_capprice / incr_profit_rate
	replace!(capital_output_ratio, NaN=>0) # replace NaN with 0
	# Initialize for the investment function
	targ_profit_rate = incr_profit_rate

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
	param_prevM = 2 * io.M # Allow for some extra slack -- this just sets a scale
    #----------------------------------
    # Variables
    #----------------------------------
    # For objective function
    @variable(mdl, 0 <= ugap[i in 1:ns] <= 1)
    @variable(mdl, 0 <= fgap[i in 1:np] <= 1)
    @variable(mdl, 0 <= xgap[i in 1:np] <= 1)
    @variable(mdl, 0 <= ψ_imp[i in 1:np] <= 1) # Excess over desired imports (as a relative amount)
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
	@variable(mdl, I_imp >= 0)
	@variable(mdl, I_dom >= 0)
	@variable(mdl, I_tot) # Fix to equal param_I_tot
	@variable(mdl, 0 <= ψ_inv <= 1)
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
						 wm * (sum(ψ_imp[i] for i in 1:np) + ψ_inv))

    #----------------------------------
    # Constraints
    #----------------------------------
    # Sector constraints
	@constraint(mdl, eq_util[i = 1:ns], u[i] + ugap[i] == 1.0)
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
	@constraint(mdl, eq_investment, I_dom + I_imp == I_tot)
	fix(I_tot, param_I_tot)
	@constraint(mdl, eq_inv_imp_mult, ψ_inv * param_prev_I_tot == I_imp)
	# Total supply
	@constraint(mdl, eq_totsupply[i = 1:np], qs[i] == qd[i] - margins_pos[i] + margins_neg[i] + X[i] + F[i] + θ[i] * I_dom - M[i] - θ_imp[i] * I_imp)
	# Imports
	@constraint(mdl, eq_M[i = 1:np], M[i] == io.m_frac[i] * (qd[i] + F[i]) + param_prevM[i] * ψ_imp[i])
	# Margins
	@constraint(mdl, eq_margpos[i = 1:np], margins_pos[i] == io.marg_pos_ratio[i] * (qs[i] + M[i]))
	@constraint(mdl, eq_margneg[i = 1:np], margins_neg[i] == io.marg_neg_share[i] * sum(margins_pos[j] for j in 1:np))

    #------------------------------------------
    # Calibration run
    #------------------------------------------
	if params["report-diagnostics"]
		open(string("diagnostics/model_", run, "_calib_1", ".txt"), "w") do f
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
    @info "Calibrating: $status"

    writedlm(string("calibration/u_",run,".csv"), value.(u), ',')
    writedlm(string("calibration/X_",run,".csv"), value.(X), ',')
    writedlm(string("calibration/F_",run,".csv"), value.(F), ',')
    writedlm(string("calibration/M_",run,".csv"), value.(M), ',')
    writedlm(string("calibration/qs_",run,".csv"), value.(qs), ',')
    writedlm(string("calibration/qd_",run,".csv"), value.(qd), ',')
    writedlm(string("calibration/pd_",run,".csv"), param_pd, ',')
    writedlm(string("calibration/pb_",run,".csv"), param_pb, ',')
    writedlm(string("calibration/g_",run,".csv"), value.(u) .* z, ',')
    writedlm(string("calibration/margins_neg_",run,".csv"), value.(margins_neg), ',')
    writedlm(string("calibration/margins_pos_",run,".csv"), value.(margins_pos), ',')
    # Not calculated by the model, but report:
    writedlm(string("calibration/wageshare_",run,".csv"), ω, ',')
    writedlm(string("calibration/marg_pos_ratio_",run,".csv"),  io.marg_pos_ratio, ',')
	writedlm(string("calibration/capital_output_ratio",run,".csv"), capital_output_ratio, ',')

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
		open(string("diagnostics/model_", run, "_calib_2", ".txt"), "w") do f
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
    pd_prev = prices.pd/(1 + params["global-params"]["infl_default"])
    pb_prev = param_pb/(1 + params["global-params"]["infl_default"])
    prev_GDP = sum(param_pb[i] * (value.(qs) - value.(qd))[i] for i in 1:np)

	prev_GDP_deflator = 1
    prev_GDP_gr = neutral_growth
    prev_πg = params["global-params"]["infl_default"]

    year = base_year

	#--------------------------------
	# Initialize array of indices to pass to LEAP
	#--------------------------------
	labels = vcat(["Year";params["GDP-branch"]["name"]], params["LEAP_sector_names"])
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
	output_var(sector_names, "g", run, "", "w")
	output_var(sector_names, "z", run, "", "w")
	output_var(sector_names, "u", run, "", "w")
	output_var(sector_names, "real_value_added", run, "", "w")
	output_var(sector_names, "profit_rate", run, "", "w")
	# Create files for product variables
	output_var(product_names, "F", run, "", "w")
	output_var(product_names, "X", run, "", "w")
	output_var(product_names, "pb", run, "", "w")
	# Create a file to hold scalar variables
	scalar_var_list = ["curr acct surplus", "real GDP", "GDP deflator", "average utilization",
						"labor productivity gr", "labor force gr", "wage rate gr", "wage per eff. worker gr",
						"real investment", "investment import share", "central bank rate"]
	to_quoted_string_vec(scalar_var_list)
	output_var(scalar_var_list, "collected_variables", run, "", "w")

	#############################################################################
	#
    # Loop over years
	#
	#############################################################################
    @info "Running from $base_year to $final_year:"

    previous_failed = false
    for t in 1:ntime
		#--------------------------------
		# Output
		#--------------------------------
        g = value.(u) .* z
		g_share = pb_prev .* value.(qs)/sum(pb_prev .* value.(qs))

		#--------------------------------
		# Price indices and deflators
		#--------------------------------
        # This is used here if the previous calculation failed, but is also reported below
        va_at_prev_prices_1 = prices.Pg * g
        va_at_prev_prices_2 = sum(pd_prev[j] * io.D[j,:] for j in 1:np) .* g
        value_added_at_prev_prices = va_at_prev_prices_1 - va_at_prev_prices_2
        if previous_failed
            πg = prev_πg
            pd_prev = pd_prev * (1 + πg)
            pb_prev = pb_prev * (1 + πg)
            va1 = (1 + πg) * prices.Pg * g
            va2 = sum(value.(param_pd)[j] * io.D[j,:] for j in 1:np) .* g
            value_added = va1 - va2
            πGDP = sum(value_added)/sum(value_added_at_prev_prices) - 1
        else
			πd = (param_pd - pd_prev) ./ pd_prev
	        πb = (param_pb - pb_prev) ./ pb_prev
            πg = sum(g_share .* πb)
            prev_πg = πg
			val_findmd = (ones(np) + io.τd) .* pd_prev .* (value.(X) + value.(F) + θ * value.(I_dom))
	        val_findmd_share = val_findmd/sum(val_findmd)
            πGDP = sum(val_findmd_share .* πd)
            pd_prev = param_pd
            pb_prev = param_pb
        end
        GDP_deflator = prev_GDP_deflator
        prev_GDP_deflator = (1 + πGDP) * prev_GDP_deflator

		if tf_π_targ_use_πw
			tf_π_targ = iovar.πw[t]
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
		λ_gr = iovar.αKV[t] * GDP_gr + iovar.βKV[t] # Kaldor-Verdoorn equation for labor productivity
		L_gr = GDP_gr - λ_gr # Labor force growth rate

		w_gr = infl_passthrough * πGDP + λ_gr * (1.0 + lab_constr_coeff * (L_gr - iovar.working_age_grs[t]))
		ω_gr = w_gr - λ_gr - πg
		ω = (1.0 + ω_gr) * ω

		#--------------------------------
		# Profits
		#--------------------------------
		profit_per_output = io.Vnorm * prices.pd - (prices.Pg .* ω +  transpose(io.D) * ((ones(np) + io.τd) .* prices.pd))
		pK = dot(θ,(ones(np) + io.τd) .* prices.pd)
		profit_rate = profit_per_output ./ (pK * capital_output_ratio)

		#--------------------------------
		# Investment
		#--------------------------------
		# Investment function
		γ_u = util_sens .* (value.(u) .- 1)
		γ_r = profit_sens * (profit_rate .- targ_profit_rate)
		γ_i = -intrate_sens * (i_bank - tf_i_targ) * ones(ns)
        γ = max.(γ_0 + γ_u + γ_r + γ_i, -iovar.δ)
		# Non-energy investment, by sector and total
        I_ne_disag = z .* (γ + iovar.δ) .* capital_output_ratio
        I_ne = sum(I_ne_disag)
		# Combine with energy investment
        I_total = I_ne + I_en[t]
		# Update autonomous investment term
        γ_0 = γ_0 + growth_adj * (γ - γ_0)

		#--------------------------------
		# Export demand
		#--------------------------------
        Xmax = Xmax .* (1 + iovar.world_grs[t]).^iovar.export_elast_demand[t]

		#--------------------------------
		# Final domestic consumption demand
		#--------------------------------
		# Wage ratio drives increase in quantity, so use real wage increase, deflate by Pg
		W_curr = sum(W)
        W = ((1 + w_gr)/(1 + λ_gr)) * W .* (1 .+ γ)
        wage_ratio = (1/(1 + πg)) * sum(W)/W_curr
        Fmax = Fmax .* wage_ratio.^iovar.wage_elast_demand[t]

		#--------------------------------
		# Calculate indices to pass to LEAP
		#--------------------------------
        indices[t,1] = year
        indices[t,2] = GDP
		for i in 1:length(LEAP_indices)
			indices[t, 2 + i] = 0
			for j in LEAP_indices[i]
				indices[t, 2 + i] += g[j]
			end
		end

		#--------------------------------
		# Reporting
		#--------------------------------
		# These variables are only reported, not used
		CA_surplus = sum(prices.pw .* (value.(X) - value.(M)))/GDP_deflator
		inv_imp_share = value.(I_imp)/value.(I_tot)
		u_ave = sum(prices.pb .* g)/sum(prices.pb .* z)

		# Sector variables
		output_var(g, "g", run, year, "a")
		output_var(z, "z", run, year, "a")
		output_var(value.(u), "u", run, year, "a")
		output_var(value_added_at_prev_prices/prev_GDP_deflator, "real_value_added", run, year, "a")
		output_var(profit_rate, "profit_rate", run, year, "a")
		# Product variables
		output_var(value.(F), "F", run, year, "a")
		output_var(value.(X), "X", run, year, "a")
		output_var(param_pb, "pb", run, year, "a")
		# Scalar variables
		scalar_var_vals = [CA_surplus, GDP, GDP_deflator, u_ave, λ_gr, L_gr,
							w_gr, ω_gr, value.(I_tot), inv_imp_share, i_bank]
		output_var(scalar_var_vals, "collected_variables", run, year, "a")

		#--------------------------------
		# Update Taylor rule
		#--------------------------------
        i_bank = tf_i_targ + tf_gr_resp * (GDP_gr - neutral_growth) + tf_infl_resp * (πGDP - tf_π_targ)

		#--------------------------------
		# Update potential output
		#--------------------------------
        z = (1 .+ γ) .* z

		#--------------------------------
		# Update prices
		#--------------------------------
		prices.Pg = (1 + πg) * prices.Pg
		prices.pw = prices.pw * (1 + iovar.πw[t])
		prices.pd = sraffa_inverse * calc_sraffa_RHS(t, np, ns, ω, tradeables, prices, io, iovar)
		prices.pb = prices.pd

		#--------------------------------
		# Update the linear goal program
		#--------------------------------
		param_prevM = 2 * value.(M) # Allow for some extra slack -- this just sets a scale
		param_Pg = prices.Pg
		param_Xmax = Xmax
		param_Fmax = Fmax
		param_I_tot = I_total
		param_prev_I_tot = 2 * I_total # Allow extra slack -- this sets a scale
		param_pw = prices.pw
		param_pd = prices.pd
		param_pb = prices.pb
		param_z = z

		for i in 1:ns
			set_normalized_coefficient(eq_io[i], u[i], -param_Pg * param_z[i])
			for j in 1:np
				set_normalized_coefficient(eq_io[i], qs[j], io.S[i,j] * param_pb[j])
				set_normalized_coefficient(eq_intdmd[i], u[j], -io.D[i,j] * param_z[j])
			end
		end
		for i in 1:np
			set_normalized_coefficient(eq_X[i], xshare[i], -param_Xmax[i])
			set_normalized_coefficient(eq_F[i], fshare[i], -param_Fmax[i])
			set_normalized_coefficient(eq_M[i], ψ_imp[i], -param_prevM[i])
		end
		set_normalized_coefficient(eq_inv_imp_mult, ψ_inv, param_prev_I_tot)
		fix(I_tot, param_I_tot)

		if params["report-diagnostics"]
			open(string("diagnostics/model_", run, "_", year, ".txt"), "w") do f
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
        @info "Simulating for $year: $status"
        previous_failed = status != MOI.FEASIBLE_POINT
        if previous_failed
			finndx = length(LEAP_indices) + 2 # Adds column for year and for GDP
            indices[t,2:finndx] = fill(NaN, (finndx - 2) + 1)
        end

		year += 1

    end

    # Make indices into indices
    indices_0 = indices[1,:]
    for t = 1:ntime
        indices[t,2:end] = indices[t,2:end] ./ indices_0[2:end]
    end
    open(string("outputs/indices_",run,".csv"), "w") do io
               writedlm(io, reshape(labels, 1, :), ',')
               writedlm(io, indices, ',')
           end;

    return indices
end # ModelCalculations

"""
    resultcomparison(run::Int64)

Compare the GDP and value added indices generated from different runs and calculate the maximum difference.
Indices are specified in the YAML configuration file.
"""
function resultcomparison(run::Int64)
    # Obtains data from indices files for current run and previous run
    file1 = string("outputs/indices_",run,".csv")
    file2 = string("outputs/indices_",run-1,".csv")

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
    runleapmacromodel(file::String, logile::IOStream)

Iteratively run the Macro model and LEAP until convergence.
"""
function runleapmacromodel(file::String, logfile::IOStream)
	
    ## get base_year and final_year
    params = IOlib.parse_input_file(file)
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
            tolerance = resultcomparison(run)
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
            LEAPfunctions.outputtoleap(file, indices)

            ## Run LEAP model
            #------------status
            @info "Running LEAP model..."
			flush(logfile)
            #------------status
            LEAPfunctions.calculateleap(params["LEAP-info"]["result_scenario"])

            ## Obtain energy investment data from LEAP
            #------------status
            @info "Obtaining LEAP results..."
            #------------status
            I_en = LEAPfunctions.energyinvestment(file, run)

			if params["model"]["hide_leap"]
				#------------status
				@info "Restoring LEAP..."
				#------------status
				LEAPfunctions.visible(true)
			end
			flush(logfile)
        end
		#------------status
		println("completed")
        #------------status

    end

end # runleapmacromodel

end
