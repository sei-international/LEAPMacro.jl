"Module `SUTlib` exports functions for parsing the configuration file, supply-use table, and paramter files for `LEAPMacro.jl`"
module SUTlib
using CSV, DataFrames, LinearAlgebra, YAML, Logging, Formatting

export process_sut, initialize_prices, parse_param_file,
       SUTdata, PriceData, ExogParams, TechChangeParams

include("./LEAPMacrolib.jl")
using .LMlib

"Values calculated from supply-use and associated tables"
mutable struct SUTdata
    D::Array{Float64,2} # np x ns
    S::Array{Float64,2} # ns x np
	Vnorm::Array{Float64,2} # ns x np
    F::Array{Float64,1} # np
    I::Array{Float64,1} # np
    X::Array{Float64,1} # np
	M::Array{Float64,1} # np
    W::Array{Float64,1} # ns
    g::Array{Float64,1} # ns
    marg_pos_ratio::Array{Float64,1} # np
    marg_neg_share::Array{Float64,1} # np
    m_frac::Array{Float64,1} # np
    energy_share::Array{Float64,1} # ns
    μ::Array{Float64,1} # ns
end

"Price indices"
mutable struct PriceData
    pb::Array{Float64,1}
    pd::Array{Float64,1}
    pw::Array{Float64,1}
    Pg::AbstractFloat
    Pw::AbstractFloat
    Px::AbstractFloat
    Pm::AbstractFloat
    Ptrade::AbstractFloat
    XR::AbstractFloat
    RER::AbstractFloat
end

"User-specified parameters"
mutable struct ExogParams
    πw_base::Array{Float64,1} # World inflation rate x year
    world_grs::Array{Float64,1} # Real world GDP growth rate x year
	working_age_grs::Array{Float64,1} # Growth rate of the working age population x year
	αKV::Array{Float64,1} # Kaldor-Verdoorn coefficient x (year or sector)
	βKV::Array{Float64,1} # Kaldor-Verdoorn intercept x (year or sector)
    ℓ0::Array{Float64,1} # Initial employment (if applicable) x sector
	xr::Array{Float64,1} # Nominal exchange rate x year
    δ::Array{Float64,1} # ns
    I_addl::Array{Any,1} # Additional investment x year
    pot_output::Array{Any,2} # Exogenously specified potential output (converted to index) ns x year
    max_util::Array{Any,2} # Exogenous max capacity utilization (forced to lie between 0 and 1) ns x year
    price::Array{Any,2} # Exogenously specified real prices (converted to index) np x year
    export_elast_demand::Array{Any,1} # np x year
    wage_elast_demand::Array{Any,1} # np x year
    export_price_elast::Array{Any,1} # np
    import_price_elast::Array{Any,1} # np
end

"Parameters for updating technical coefficients"
mutable struct TechChangeParams
    rate_const::Array{Float64,1} # ns
    exponent::Array{Float64,1} # ns
    constants::Array{Float64,2} # np,ns
    coefficients::Array{Float64,2} # np,ns
end

"Read LEAP-Macro model configuration file (in YAML syntax). Add or modify entries as needed."
function parse_param_file(YAML_file::AbstractString; include_energy_sectors::Bool = false)
    global_params = YAML.load_file(YAML_file)

    global_params["include-energy-sectors"] = include_energy_sectors

    if include_energy_sectors
        output_folder_name = string(global_params["output_folder"], "_full")
    else
        output_folder_name = global_params["output_folder"]
    end
    global_params["results_path"] = joinpath("outputs/", output_folder_name, "results")
    global_params["calibration_path"] = joinpath("outputs/", output_folder_name, "calibration")
    global_params["diagnostics_path"] = joinpath("outputs/", output_folder_name, "diagnostics")

	# First, check if any sectors or products should be excluded because production is zero (or effectively zero, for products)
	SUT_df = CSV.read(joinpath("inputs",global_params["files"]["SUT"]), header=false, DataFrame)
	M = vec(sum(LMlib.excel_range_to_mat(SUT_df, global_params["SUT_ranges"]["imports"]), dims=2))
	supply_table = LMlib.excel_range_to_mat(SUT_df, global_params["SUT_ranges"]["supply_table"])
	qs = vec(sum(supply_table, dims=2))
	g = vec(sum(supply_table, dims=1))
    M_equiv = transpose(supply_table) * Diagonal(1 ./ (qs .+ LMlib.ϵ)) * M
    # Remove all sectors for which there is negligible domestic production relative to imports or where g = 0
	θ = global_params["domestic_production_share_threshold"]/100
	zero_domprod_ndxs = findall(x -> x <= 0, min(g, (1 - θ) * g - θ * M_equiv))
    # Remove all products for which there is negligible total supply (domestic + imported) relative to total domestic output
	zero_prod_ndxs = findall(x -> abs(x) < LMlib.ϵ, (qs + M)/sum(g))

	all_sectors = CSV.read(joinpath("inputs",global_params["files"]["sector_info"]), header=1, types=Dict(:code => String, :name => String), select=[:code,:name], NamedTuple)
	all_products = CSV.read(joinpath("inputs",global_params["files"]["product_info"]), header=1, types=Dict(:code => String, :name => String), select=[:code,:name], NamedTuple)
	sector_codes = all_sectors[:code]
    product_codes = all_products[:code]

    # Get lists of excluded sectors other than energy, defaulting to empty list
    if !LMlib.haskeyvalue(global_params, "excluded_sectors")
        global_params["excluded_sectors"] = Dict()
    end
    if !LMlib.haskeyvalue(global_params["excluded_sectors"], "territorial_adjustment")
        global_params["excluded_sectors"]["territorial_adjustment"] = []
    end
    if !LMlib.haskeyvalue(global_params["excluded_sectors"], "others")
        global_params["excluded_sectors"]["others"] = []
    end
	excluded_sectors = vcat(global_params["excluded_sectors"]["territorial_adjustment"],
							global_params["excluded_sectors"]["others"])

    # Get lists of excluded products other than energy, defaulting to empty list
    if !LMlib.haskeyvalue(global_params, "excluded_products")
        global_params["excluded_products"] = Dict()
    end
    if !LMlib.haskeyvalue(global_params["excluded_products"], "territorial_adjustment")
        global_params["excluded_products"]["territorial_adjustment"] = []
    end
    if !LMlib.haskeyvalue(global_params["excluded_products"], "others")
        global_params["excluded_products"]["others"] = []
    end
    excluded_products = vcat(global_params["excluded_products"]["territorial_adjustment"],
                             global_params["excluded_products"]["others"])
   
    # Unless energy sectors & products are included in the calculation, get the lists of excluded energy sectors & products
    if !include_energy_sectors
        # Energy sectors
        if !LMlib.haskeyvalue(global_params["excluded_sectors"], "energy")
            global_params["excluded_sectors"]["energy"] = []
        end
        excluded_sectors = vcat(excluded_sectors, global_params["excluded_sectors"]["energy"])
        # Energy products
        if !LMlib.haskeyvalue(global_params["excluded_products"], "energy")
            global_params["excluded_products"]["energy"] = []
        end
        excluded_products = vcat(excluded_products, global_params["excluded_products"]["energy"])
    end

	# These are the indexes used for the Macro model
	user_defined_sector_ndxs = findall(.!in(excluded_sectors).(sector_codes))
	user_defined_product_ndxs = findall(.!in(excluded_products).(product_codes))
	global_params["sector-indexes"] = sort(setdiff(user_defined_sector_ndxs, zero_domprod_ndxs))
	global_params["product-indexes"] = sort(setdiff(user_defined_product_ndxs, zero_prod_ndxs))

    global_params["energy-sector-indexes"] = []
    global_params["energy-product-indexes"] = []

    if !include_energy_sectors
        user_defined_energy_sector_ndxs = findall(in(global_params["excluded_sectors"]["energy"]).(sector_codes))
        user_defined_energy_product_ndxs = findall(in(global_params["excluded_products"]["energy"]).(product_codes))
        global_params["energy-sector-indexes"] = sort(setdiff(user_defined_energy_sector_ndxs, zero_domprod_ndxs))
        global_params["energy-product-indexes"] = sort(setdiff(user_defined_energy_product_ndxs, zero_prod_ndxs))
    end

	global_params["terr-adj-sector-indexes"] = findall(in(global_params["excluded_sectors"]["territorial_adjustment"]).(sector_codes))
	global_params["terr-adj-product-indexes"] = findall(in(global_params["excluded_products"]["territorial_adjustment"]).(product_codes))

	global_params["included_sector_names"] = all_sectors[:name][global_params["sector-indexes"]]
	global_params["included_sector_codes"] = all_sectors[:code][global_params["sector-indexes"]]
	global_params["included_product_names"] = all_products[:name][global_params["product-indexes"]]
	global_params["included_product_codes"] = all_products[:code][global_params["product-indexes"]]

	# These indices are with respect to the list of included product codes, not the full list
	global_params["non-tradeable-range"] = findall(in(global_params["non_tradeable_products"]).(global_params["included_product_codes"]))

    # Default LEAP driver variable is production, but can set to "VA" for "Value added"
    if LMlib.haskeyvalue(global_params, "LEAP-drivers") && LMlib.haskeyvalue(global_params["LEAP-drivers"], "default")
        default_LEAP_driver = global_params["LEAP-drivers"]["default"]
    else
        default_LEAP_driver = "PROD"
    end
    if LMlib.haskeyvalue(global_params, "LEAP-drivers") && LMlib.haskeyvalue(global_params["LEAP-drivers"], "options")
        LEAP_drivers = global_params["LEAP-drivers"]["options"]
    else
        LEAP_drivers = Dict("PROD" => "production", "VA" => "value added")
    end
    if LMlib.haskeyvalue(global_params, "LEAP-sectors")
        # Optionally override the default LEAP driver
        global_params["LEAP_sector_drivers"] = [LMlib.haskeyvalue(x, "driver") ? x["driver"] : default_LEAP_driver for x in global_params["LEAP-sectors"]]
        # LEAP sectors allow for multiple Macro sector codes (production or value added is summed) and multiple branch/variable combos (the index is applied to each combination)
        global_params["LEAP_sector_names"] = [x["name"] for x in global_params["LEAP-sectors"]]
        LEAP_sector_codes = [x["codes"] for x in global_params["LEAP-sectors"]]
        global_params["LEAP_sector_indices"] = Array{Any}(undef,length(LEAP_sector_codes))
        for i in eachindex(LEAP_sector_codes)
            global_params["LEAP_sector_indices"][i] = findall([in(x, LEAP_sector_codes[i]) for x in global_params["included_sector_codes"]])
        end
    else
        global_params["LEAP_sector_drivers"] = []
        global_params["LEAP_sector_names"] = []
        global_params["LEAP_sector_indices"] = []
    end
    for d in global_params["LEAP_sector_drivers"]
        if d ∉ keys(LEAP_drivers)
            throw(DomainError(d, format(LMlib.gettext("LEAP driver must be one of \"{1}\""), join(keys(LEAP_drivers), "\", \""))))
            break
        end
    end

    # Investment function parameters
    if !LMlib.haskeyvalue(global_params, "investment-fcn")
        # This entry must be present
        throw(KeyError("investment-fcn"))
    end
    # Default is that the profit rate is based on realized profits
    if !LMlib.haskeyvalue(global_params["investment-fcn"], "use_profits_at_full_capacity")
        global_params["investment-fcn"]["use_profits_at_full_capacity"] = false
    end
    # If missing, quietly set to zero (the base model)
    if !LMlib.haskeyvalue(global_params["investment-fcn"], "net_export")
        global_params["investment-fcn"]["net_export"] = 0.0
    end
    # Set the following to zero if absent, but issue a warning
    if !LMlib.haskeyvalue(global_params["investment-fcn"], "util_sens")
        @warn LMlib.gettext("Parameter 'util_sens' is missing from the configuration file: setting to zero")
        global_params["investment-fcn"]["util_sens"] = 0.0
    end
    if !LMlib.haskeyvalue(global_params["investment-fcn"], "profit_sens")
        @warn LMlib.gettext("Parameter 'profit_sens' is missing from the configuration file: setting to zero")
        global_params["investment-fcn"]["profit_sens"] = 0.0
    end
    if !LMlib.haskeyvalue(global_params["investment-fcn"], "intrate_sens")
        @warn LMlib.gettext("Parameter 'intrate_sens' is missing from the configuration file: setting to zero")
        global_params["investment-fcn"]["intrate_sens"] = 0.0
    end

    # Labor productivity growth parameters
    if !LMlib.haskeyvalue(global_params, "labor-prod-fcn")
        global_params["labor-prod-fcn"] = Dict()
        global_params["labor-prod-fcn"]["use_KV_model"] = true
        global_params["labor-prod-fcn"]["use_sector_params_if_available"] = true
        global_params["labor-prod-fcn"]["labor_prod_gr_default"] = 0.0
        global_params["labor-prod-fcn"]["KV_coeff_default"] = 0.5
        global_params["labor-prod-fcn"]["KV_intercept_default"] = 0.0
    else
        if !LMlib.haskeyvalue(global_params["labor-prod-fcn"], "use_KV_model")
            # If this key is missing and there are no defaults for the KV parameters, presume that a specified labor productivity is intended
            global_params["labor-prod-fcn"]["use_KV_model"] = LMlib.haskeyvalue(global_params["labor-prod-fcn"], "KV_coeff_default") ||
                                                              LMlib.haskeyvalue(global_params["labor-prod-fcn"], "KV_intercept_default")
        end
        if !LMlib.haskeyvalue(global_params["labor-prod-fcn"], "use_sector_params_if_available")
            global_params["labor-prod-fcn"]["use_sector_params_if_available"] = true
        end
        if !LMlib.haskeyvalue(global_params["labor-prod-fcn"], "labor_prod_gr_default")
            global_params["labor-prod-fcn"]["labor_prod_gr_default"] = 0.0
        end
        if !LMlib.haskeyvalue(global_params["labor-prod-fcn"], "KV_coeff_default")
            global_params["labor-prod-fcn"]["KV_coeff_default"] = 0.5
        end
        if !LMlib.haskeyvalue(global_params["labor-prod-fcn"], "KV_intercept_default")
            global_params["labor-prod-fcn"]["KV_intercept_default"] = 0.0
        end
    end

    # Introduce a new key, "use_sector_params", set to true only if use_sector_params_if_available = true and they are available
    global_params["labor-prod-fcn"]["use_sector_params"] = false
    if global_params["labor-prod-fcn"]["use_sector_params_if_available"]
        # Check whether sectoral values are specified
        sector_info_df = CSV.read(joinpath("inputs", global_params["files"]["sector_info"]), DataFrame)
        if hasproperty(sector_info_df, :empl0) && sum(ismissing.(sector_info_df.empl0)) == 0 # Check that full employment data are present (no defaults)
            if global_params["labor-prod-fcn"]["use_KV_model"]
                global_params["labor-prod-fcn"]["use_sector_params"] = hasproperty(sector_info_df, :KV_coeff) && hasproperty(sector_info_df, :KV_intercept)
            else
                global_params["labor-prod-fcn"]["use_sector_params"] = hasproperty(sector_info_df, :labor_prod_gr)
            end
        end
    end

    # Wage function defaults
    if !LMlib.haskeyvalue(global_params, "wage-fcn")
        global_params["wage-fcn"] = Dict()
        global_params["wage-fcn"]["infl_passthrough"] = 1.0
        global_params["wage-fcn"]["lab_constr_coeff"] = 0.0
    else
        if !LMlib.haskeyvalue(global_params["wage-fcn"], "infl_passthrough")
            global_params["wage-fcn"]["infl_passthrough"] = 1.0
        end
        if !LMlib.haskeyvalue(global_params["wage-fcn"], "lab_constr_coeff")
            global_params["wage-fcn"]["lab_constr_coeff"] = 0.0
        end
    end

    # Intermediate coefficient technological change
    if LMlib.haskeyvalue(global_params, "tech-param-change")
        # Backwards compatability: Allow either "rate_constant" or "rate_constant_default"
        if LMlib.haskeyvalue(global_params["tech-param-change"], "rate_constant") && !LMlib.haskeyvalue(global_params["tech-param-change"], "rate_constant_default")
            global_params["tech-param-change"]["rate_constant_default"] = global_params["tech-param-change"]["rate_constant"]
        end
        if LMlib.haskeyvalue(global_params["tech-param-change"], "rate_constant_default") || LMlib.haskeyvalue(global_params["tech-param-change"], "exponent_default")
            if !LMlib.haskeyvalue(global_params["tech-param-change"], "calculate")
                global_params["tech-param-change"]["calculate"] = true
            end
        else
            # If no parameter defaults, calculate only if use_sector_params_if_available explicitly set to true
            if !LMlib.haskeyvalue(global_params["tech-param-change"], "calculate")
                global_params["tech-param-change"]["calculate"] = LMlib.haskeyvalue(global_params["tech-param-change"], "use_sector_params_if_available") &&
                                                                    global_params["tech-param-change"]["use_sector_params_if_available"]
            end
        end
        if !LMlib.haskeyvalue(global_params["tech-param-change"], "use_sector_params_if_available")
            global_params["tech-param-change"]["use_sector_params_if_available"] = true
        end
        if !LMlib.haskeyvalue(global_params["tech-param-change"], "rate_constant_default")
            global_params["tech-param-change"]["rate_constant_default"] = 0.0
        end
        if !LMlib.haskeyvalue(global_params["tech-param-change"], "exponent_default")
            global_params["tech-param-change"]["exponent_default"] = 2.0
        end
    else
        global_params["tech-param-change"] = Dict()
        global_params["tech-param-change"]["calculate"] = false # If it is not present, default to false
        global_params["tech-param-change"]["use_sector_params_if_available"] = true
        global_params["tech-param-change"]["rate_constant_default"] = 0.0
        global_params["tech-param-change"]["exponent_default"] = 2.0
    end

    # Provide defaults for the initial value adjustment (calibration) block
    if LMlib.haskeyvalue(global_params, "calib")
        if !LMlib.haskeyvalue(global_params["calib"], "nextper_inv_adj_factor")
            global_params["calib"]["nextper_inv_adj_factor"] = 0.0
        end
        if !LMlib.haskeyvalue(global_params["calib"], "max_export_adj_factor")
            global_params["calib"]["max_export_adj_factor"] = 0.0
        end
        if !LMlib.haskeyvalue(global_params["calib"], "max_hh_dmd_adj_factor")
            global_params["calib"]["max_hh_dmd_adj_factor"] = 0.0
        end
        if !LMlib.haskeyvalue(global_params["calib"], "pot_output_adj_factor")
            global_params["calib"]["pot_output_adj_factor"] = 0.0
        end
    else
        global_params["calib"] = Dict()
        global_params["calib"]["nextper_inv_adj_factor"] = 0.0
        global_params["calib"]["max_export_adj_factor"] = 0.0
        global_params["calib"]["max_hh_dmd_adj_factor"] = 0.0
        global_params["calib"]["pot_output_adj_factor"] = 0.0
    end

    #------------------------------------------------
    # LEAP-related parameters
    #------------------------------------------------
    # Provide defaults for the LEAP model execution parameters if needed
    if LMlib.haskeyvalue(global_params, "model")
        if !LMlib.haskeyvalue(global_params["model"], "run_leap")
            global_params["model"]["run_leap"] = false
        end
        if !LMlib.haskeyvalue(global_params["model"], "hide_leap")
            global_params["model"]["hide_leap"] = false
        end
        if !LMlib.haskeyvalue(global_params["model"], "max_runs")
            global_params["model"]["max_runs"] = 5
        end
        if !LMlib.haskeyvalue(global_params["model"], "max_tolerance")
            global_params["model"]["max_tolerance"] = 5.0
        end
    else
        global_params["model"] = Dict()
        global_params["model"]["run_leap"] = false
        # These are unused if run_leap is false, but set anyway
        global_params["model"]["hide_leap"] = false
        global_params["model"]["max_runs"] = 5
        global_params["model"]["max_tolerance"] = 5.0
    end

    # LEAP potential output is specified for a single Macro sector code, but allows for multiple branch/variable combos (values are summed)
    if LMlib.haskeyvalue(global_params, "LEAP-potential-output")
        LEAP_potout_codes = [x["code"] for x in global_params["LEAP-potential-output"]]
        # If the sector code is not included, report its index as "missing"
        global_params["LEAP_potout_indices"] = Array{Union{Missing, Int64}}(missing, length(LEAP_potout_codes))
        for i in eachindex(LEAP_potout_codes)
            if LEAP_potout_codes[i] in global_params["included_sector_codes"]
                global_params["LEAP_potout_indices"][i] = findall(x -> x == LEAP_potout_codes[i], global_params["included_sector_codes"])[1]
            else
                @warn format(LMlib.gettext("Sector code '{1}' is listed in 'LEAP-potential-output' but is not included in the Macro model calculations"), LEAP_potout_codes[i])
            end
        end
    else
        global_params["LEAP_potout_indices"] = []
    end

    # LEAP prices are drawn from a single LEAP branch, but can be assigned to multiple Macro product codes
    if LMlib.haskeyvalue(global_params, "LEAP-prices")
        LEAP_price_codes = [x["codes"] for x in global_params["LEAP-prices"]]
        global_params["LEAP_price_indices"] = Array{Any}(undef,length(LEAP_price_codes))
        for i in eachindex(LEAP_price_codes)
            global_params["LEAP_price_indices"][i] = findall([in(x, LEAP_price_codes[i]) for x in global_params["included_product_codes"]])
        end
    else
        global_params["LEAP_price_indices"] = []
    end

    # Check that LEAP-info keys are reported
    if LMlib.haskeyvalue(global_params, "LEAP-info")
        # Key "scenario" is specified, which overrides "input_scenario" and "result_scenario"
        if LMlib.haskeyvalue(global_params["LEAP-info"], "scenario")
            global_params["LEAP-info"]["input_scenario"] = global_params["LEAP-info"]["scenario"]
            global_params["LEAP-info"]["result_scenario"] = global_params["LEAP-info"]["scenario"]
        end
        # Key "input_scenario" is missing, so default to empty string (so that the currently loaded scenario in LEAP is used)
        if !LMlib.haskeyvalue(global_params["LEAP-info"], "input_scenario")
            global_params["LEAP-info"]["input_scenario"] = ""
        end
        # Key "result_scenario" is not specified, so it defaults to "input_scenario"
        if !LMlib.haskeyvalue(global_params["LEAP-info"], "result_scenario")
            global_params["LEAP-info"]["result_scenario"] = global_params["LEAP-info"]["input_scenario"]
        end
        # Key "region" is missing, so default to empty string
        if !LMlib.haskeyvalue(global_params["LEAP-info"], "region")
            global_params["LEAP-info"]["region"] = ""
        end
        # Key "last_historical_year" is missing, so default to start of scenario
        if !LMlib.haskeyvalue(global_params["LEAP-info"], "last_historical_year")
            global_params["LEAP-info"]["last_historical_year"] = global_params["years"]["start"]
        end
    else
        global_params["LEAP-info"] = Dict()
        global_params["LEAP-info"]["last_historical_year"] = global_params["years"]["start"]
        global_params["LEAP-info"]["input_scenario"] = ""
        global_params["LEAP-info"]["result_scenario"] = ""
    end

    # Check that LEAP-investment keys are reported
    if LMlib.haskeyvalue(global_params, "LEAP-investment")
        # Key "inv_costs_unit" is missing, so apply the default
        if !LMlib.haskeyvalue(global_params["LEAP-investment"], "inv_costs_unit")
            global_params["LEAP-investment"]["inv_costs_unit"] = ""
        end
        # Key "inv_costs_scale" is missing, so default to 1.0
        if !LMlib.haskeyvalue(global_params["LEAP-investment"], "inv_costs_scale")
            global_params["LEAP-investment"]["inv_costs_scale"] = 1.0
        end
        # Key "inv_costs_apply_xr" is missing, so default to false
        if !LMlib.haskeyvalue(global_params["LEAP-investment"], "inv_costs_apply_xr")
            global_params["LEAP-investment"]["inv_costs_apply_xr"] = false
        end
        # Key "excluded_branches" is missing, so default to empty list
        if !LMlib.haskeyvalue(global_params["LEAP-investment"], "excluded_branches")
            global_params["LEAP-investment"]["excluded_branches"] = []
        end
        # Key "distribute_costs_over" is missing, so default to 1 year
        if !LMlib.haskeyvalue(global_params["LEAP-investment"], "distribute_costs_over")
            global_params["LEAP-investment"]["distribute_costs_over"] = Dict("default" => 1, "by_branch" => [])
        else
            # Key "default" is missing, so default to 1 year
            if !LMlib.haskeyvalue(global_params["LEAP-investment"]["distribute_costs_over"], "default")
                global_params["LEAP-investment"]["distribute_costs_over"]["default"] = 1
            end
            # Key "by_branch" is missing, so default to empty list
            if !LMlib.haskeyvalue(global_params["LEAP-investment"]["distribute_costs_over"], "by_branch")
                global_params["LEAP-investment"]["distribute_costs_over"]["by_branch"] = []
            end
        end
    else
        global_params["LEAP-investment"] = Dict()
        global_params["LEAP-investment"]["inv_costs_unit"] = ""
        global_params["LEAP-investment"]["inv_costs_scale"] = 1.0
        global_params["LEAP-investment"]["inv_costs_apply_xr"] = false
        global_params["LEAP-investment"]["excluded_branches"] = []
        global_params["LEAP-investment"]["distribute_costs_over"] = Dict("default" => 1, "by_branch" => [])
    end

    return global_params
end # parse_param_file

"Pull in user-specified parameters from different CSV input files with filenames specified in the YAML configuration file."
function get_var_params(params::Dict)
    # Return an ExogParams struct
    retval_exog = ExogParams(
                    Array{Float64}(undef, 0), # πw_base
                    Array{Float64}(undef, 0), # world_grs
					Array{Float64}(undef, 0), # working_age_grs
					Array{Float64}(undef, 0), # αKV -- either over time or by sector
					Array{Float64}(undef, 0), # βKV -- either over time or by sector
					Array{Float64}(undef, 0), # ℓ0
					Array{Float64}(undef, 0), # xr
                    Array{Float64}(undef, 0), # δ
                    Array{Any}(undef, 0), # I_addl
                    Array{Any}(undef, 0, 0), # pot_output
                    Array{Any}(undef, 0, 0), # max_util
                    Array{Any}(undef, 0, 0), # price
                    [], # export_elast_demand
                    [], # wage_elast_demand
                    Array{Float64}(undef, 0), # export_price_elast
                    Array{Float64}(undef, 0)) # import_price_elast
    
    retval_techchange = TechChangeParams(
        Array{Float64}(undef, 0), # rate_const
        Array{Float64}(undef, 0), # exponent
        Array{Float64}(undef, 0, 0), # constants
        Array{Float64}(undef, 0, 0)) # coefficients

    sim_years = params["years"]["start"]:params["years"]["end"]
    sec_ndxs = params["sector-indexes"]
    prod_ndxs = params["product-indexes"]

    # Read in info from CSV files
    sector_info = CSV.read(joinpath("inputs",params["files"]["sector_info"]), DataFrame)
    product_info = CSV.read(joinpath("inputs",params["files"]["product_info"]), DataFrame)
    time_series = CSV.read(joinpath("inputs",params["files"]["time_series"]), DataFrame)
    prod_codes = product_info[prod_ndxs,:code]

    # Catch if the "xr-is-normal" flag is present or not, default to false
    if !LMlib.haskeyvalue(params["files"], "xr-is-real")
        params["files"]["xr-is-real"] = false
    end

    # Optional files
    investment_df = nothing
    pot_output_df = nothing
    max_util_df = nothing
    real_price_df = nothing
    if LMlib.haskeyvalue(params, "exog-files")
        file_list = params["exog-files"]
        if LMlib.haskeyvalue(file_list, "investment")
            if isfile(joinpath("inputs",file_list["investment"]))
                investment_df = CSV.read(joinpath("inputs",file_list["investment"]), DataFrame)
            else
                @warn format(LMlib.gettext("Exogenous investment file '{1}' does not exist in the 'inputs' folder"), file_list["investment"])
            end
        end
        if LMlib.haskeyvalue(file_list, "pot_output")
            if isfile(joinpath("inputs",file_list["pot_output"]))
                pot_output_df = CSV.read(joinpath("inputs",file_list["pot_output"]), DataFrame)
            else
                @warn format(LMlib.gettext("Exogenous potential output file '{1}' does not exist in the 'inputs' folder"), file_list["pot_output"])
            end
        end
        if LMlib.haskeyvalue(file_list, "max_utilization")
            if isfile(joinpath("inputs",file_list["max_utilization"]))
                max_util_df = CSV.read(joinpath("inputs",file_list["max_utilization"]), DataFrame)
            else
                @warn format(LMlib.gettext("Exogenous maximum capacity utilization file '{1}' does not exist in the 'inputs' folder"), file_list["max_utilization"])
            end
        end
        if LMlib.haskeyvalue(file_list, "real_price")
            if isfile(joinpath("inputs",file_list["real_price"]))
                real_price_df = CSV.read(joinpath("inputs",file_list["real_price"]), DataFrame)
            else
                @warn format(LMlib.gettext("Exogenous real price file '{1}' does not exist in the 'inputs' folder"), file_list["real_price"])
            end
        end
    end
    
    #--------------------------------------------------------------------------------------
    # Sector-specific
    #--------------------------------------------------------------------------------------
    # Use same value for each year, but it can vary by sector
    retval_exog.δ = sector_info[sec_ndxs,:depr_rate]

    #--------------------------------------------------------------------------------------
    # Product-specific
    #--------------------------------------------------------------------------------------
    #--- Demand model parameters
    if hasproperty(product_info, :import_price_elast)
        retval_exog.import_price_elast = product_info[prod_ndxs,:import_price_elast]
    else
        retval_exog.import_price_elast = zeros(length(prod_codes))
    end
    if hasproperty(product_info, :export_price_elast)
        retval_exog.export_price_elast = product_info[prod_ndxs,:export_price_elast]
    else
        retval_exog.export_price_elast = zeros(length(prod_codes))
    end

    # Note, export and household demand parameters are used later to make time-varying parameters
    # Export demand
    export_elast_decay = params["export_elast_demand"]["decay"]
    # Get initial value
    export_elast_demand0 = product_info[prod_ndxs,:export_elast_demand0]
    # Constrain to grow with global economy in the long run (with elasticity 1.0)
    asympt_export_elast = min.(convert(Array,export_elast_demand0), 1.0 * ones(length(export_elast_demand0)))

    # Household demand
    wage_elast_decay = params["wage_elast_demand"]["decay"]
    # Get initial value
    wage_elast_demand0 = product_info[prod_ndxs,:wage_elast_demand0]
    # For asymptotic value, first bring below 1.0
    asympt_wage_elast = min.(convert(Array,wage_elast_demand0), 1.0 * ones(length(wage_elast_demand0)))
    # Next, for Engel's Law, set long-run elasticity for food below 1.0
    engel_products = params["wage_elast_demand"]["engel_prods"]
    engel_ndxs = findall(x -> x in engel_products, prod_codes)
    asympt_wage_elast[engel_ndxs] = params["wage_elast_demand"]["engel_asympt_elast"] * ones(length(engel_products))

    #--------------------------------------------------------------------------------------
    # Time series
    #--------------------------------------------------------------------------------------
    data_start_year = floor(Int64, time_series[1,:year])
    data_end_year = data_start_year + length(time_series[!,:year]) - 1

    # World inflation rate (apply to world prices only, others induced)
    world_infl_default = params["global-params"]["infl_default"]
    if hasproperty(time_series, :world_infl_rate)
        world_infl_temp = time_series[!,:world_infl_rate]
    else
        world_infl_temp = world_infl_default * ones(data_end_year - data_start_year + 1)
    end

    # World GDP growth rate (including historical, for calibration)
    world_grs_default = params["global-params"]["gr_default"]
    if hasproperty(time_series, :world_gr)
        world_grs_temp = time_series[!,:world_gr]
    else
        world_grs_temp = world_grs_default * ones(data_end_year - data_start_year + 1)
    end

	# Working age growth rate (No default -- must provide all values for specified time period)
    working_age_grs_temp = time_series[!,:working_age_gr]

	# Exchange rate
    #   If present, then no default -- must provide all values for specified time period
    #   If absent, then default to one
    if hasproperty(time_series, :exchange_rate)
        xr_temp = time_series[!,:exchange_rate]
    else
        xr_temp = ones(data_end_year - data_start_year + 1)
    end

    # Labor productivity parameters
    if params["labor-prod-fcn"]["use_KV_model"]
        # Kaldor-Verdoorn parameters
        αKV_default = params["labor-prod-fcn"]["KV_coeff_default"]
        βKV_default = params["labor-prod-fcn"]["KV_intercept_default"]
    else
        # If there is no growth response, then αKV = 0 and βKV is equal to the labor productivity growth rate
        αKV_default = 0.0
        βKV_default = params["labor-prod-fcn"]["labor_prod_gr_default"]
    end
    if params["labor-prod-fcn"]["use_sector_params"]
        # The presence of these columns has already been confirmed
        if params["labor-prod-fcn"]["use_KV_model"]
            retval_exog.αKV = sector_info[sec_ndxs,:KV_coeff]
            replace!(retval_exog.αKV, missing => αKV_default)
            retval_exog.βKV = sector_info[sec_ndxs,:KV_intercept]
            replace!(retval_exog.βKV, missing => βKV_default)
        else
            retval_exog.αKV = fill(0.0, length(sector_info[sec_ndxs,:labor_prod_gr]))
            retval_exog.βKV = sector_info[sec_ndxs,:labor_prod_gr]
            replace!(retval_exog.βKV, missing => βKV_default)
        end
        # It is already confirmed that there are no missing values in this column
        retval_exog.ℓ0 = sector_info[sec_ndxs,:empl0]
    else
        if params["labor-prod-fcn"]["use_KV_model"]
            if hasproperty(time_series, :KV_coeff)
                αKV_temp = time_series[!,:KV_coeff]
            else
                αKV_temp = fill(αKV_default, length(time_series[!,:year]))
            end
            if hasproperty(time_series, :KV_intercept)
                βKV_temp = time_series[!,:KV_intercept]
            else
                βKV_temp = fill(βKV_default, length(time_series[!,:year]))
            end
        else
            αKV_temp = fill(0.0, length(time_series[!,:year]))
            if hasproperty(time_series, :labor_prod_gr)
                βKV_temp = time_series[!,:labor_prod_gr]
            else
                βKV_temp = fill(βKV_default, length(time_series[!,:year]))
            end
        end
    end

    # Intermediate technical change parameters
    # These are set in the main routine
    retval_techchange.constants = zeros(length(prod_ndxs), length(sec_ndxs))
    retval_techchange.coefficients = ones(length(prod_ndxs), length(sec_ndxs))
    if params["tech-param-change"]["calculate"] && params["tech-param-change"]["use_sector_params_if_available"]
        if hasproperty(sector_info, :rate_const)
            retval_techchange.rate_const = sector_info[sec_ndxs,:rate_const]
            replace!(retval_techchange.rate_const, missing => params["tech-param-change"]["rate_constant_default"])
        else
            retval_techchange.rate_const = params["tech-param-change"]["rate_constant_default"] * ones(length(sec_ndxs))
        end
        if hasproperty(sector_info, :exponent)
            retval_techchange.exponent = sector_info[sec_ndxs,:exponent]
            replace!(retval_techchange.exponent, missing => params["tech-param-change"]["exponent_default"])
        else
            retval_techchange.exponent = params["tech-param-change"]["exponent_default"] * ones(length(sec_ndxs))
        end
    else
        retval_techchange.rate_const = params["tech-param-change"]["rate_constant_default"] * ones(length(sec_ndxs))
        retval_techchange.exponent = params["tech-param-change"]["exponent_default"] * ones(length(sec_ndxs))
    end

    #--------------------------------------------------------------------------------------
    # Fill in by looping over years
    #--------------------------------------------------------------------------------------
    for year in sim_years
        if year in data_start_year:data_end_year
            year_ndx = year - data_start_year + 1
            # These have no defaults: check first
            if !ismissing(working_age_grs_temp[year_ndx])
                push!(retval_exog.working_age_grs, working_age_grs_temp[year_ndx])
            else
                error_string = format(LMlib.gettext("Value for working age growth rate missing in year {1:d}, with no default"), year)
                throw(MissingException(error_string))
            end
            if !ismissing(xr_temp[year_ndx])
                push!(retval_exog.xr, xr_temp[year_ndx])
            else
                error_string = format(LMlib.gettext("Value for exchange rate missing in year {1:d}, with no default"), year)
                throw(MissingException(error_string))
            end
            # These have defaults
            if !ismissing(world_infl_temp[year_ndx])
                push!(retval_exog.πw_base, world_infl_temp[year_ndx])
            else
                push!(retval_exog.πw_base, world_infl_default)
            end
            if !ismissing(world_grs_temp[year_ndx])
                push!(retval_exog.world_grs, world_grs_temp[year_ndx])
            else
                push!(retval_exog.world_grs, world_grs_default)
            end
            if !params["labor-prod-fcn"]["use_sector_params"]
                if !ismissing(αKV_temp[year_ndx])
                    push!(retval_exog.αKV, αKV_temp[year_ndx])
                else
                    push!(retval_exog.αKV, αKV_default)
                end
                if !ismissing(βKV_temp[year_ndx])
                    push!(retval_exog.βKV, βKV_temp[year_ndx])
                else
                    push!(retval_exog.βKV, βKV_default)
                end
            end
        else
			error_string = format(LMlib.gettext("Year {1:d} is not in time series range {2:d}:{3:d}"), year, data_start_year, data_end_year)
            throw(DomainError(year, error_string))
        end

        deltat = max(0, year - sim_years[1] + 1) # Year past the end of calibration period

        # Bring high values down, but don't bring low values up
        export_elast_demand_temp = export_elast_demand0 - (1 - exp(-export_elast_decay * deltat)) * (export_elast_demand0 - asympt_export_elast)
        push!(retval_exog.export_elast_demand, export_elast_demand_temp)

        wage_elast_demand_temp = wage_elast_demand0 - (1 - exp(-wage_elast_decay * deltat)) * (wage_elast_demand0 - asympt_wage_elast)
        push!(retval_exog.wage_elast_demand, wage_elast_demand_temp)
    end

    #--------------------------------------------------------------------------------------
    # Optional files
    #--------------------------------------------------------------------------------------

    retval_exog.I_addl = zeros(length(sim_years))
    retval_exog.pot_output = Array{Union{Missing, Float64}}(missing, length(sim_years), length(sec_ndxs))
    retval_exog.max_util = Array{Union{Missing, Float64}}(missing, length(sim_years), length(sec_ndxs))
    retval_exog.price = Array{Union{Missing, Float64}}(missing, length(sim_years), length(prod_ndxs))

    if !isnothing(investment_df)
        for row in eachrow(investment_df)
            data_year = floor(Int64, row[:year])
            if data_year in sim_years
                retval_exog.I_addl[data_year - sim_years[1] + 1] = row[:addl_investment]
            end
       end
    end

    if !isnothing(pot_output_df)
        data_sec_codes = names(pot_output_df)[2:end]
        # Using findfirst: there should only be one entry per code
        data_sec_ndxs = [findfirst(params["included_sector_codes"] .== sec_code) for sec_code in data_sec_codes]
        # Confirm that the sectors are included
        if !isnothing(findfirst(isnothing.(data_sec_ndxs)))
            invalid_sec_ndxs = findall(x -> isnothing(x), data_sec_ndxs)
            invalid_sec_codes = data_sec_codes[invalid_sec_ndxs]
            if length(invalid_sec_codes) > 1
                invalid_sec_codes_str = format(LMlib.gettext("Sector codes '{1}' in input file '{2}' not valid"), join(invalid_sec_codes, "', '"), params["exog-files"]["pot_output"])
            else
                invalid_sec_codes_str = format(LMlib.gettext("Sector code '{1}' in input file '{2}' not valid"), invalid_sec_codes[1], params["exog-files"]["pot_output"])
            end
            deleteat!(data_sec_ndxs, invalid_sec_ndxs)
            pot_output_df = pot_output_df[:,Not(1 .+ invalid_sec_ndxs)]
            @warn invalid_sec_codes_str
        end
        for row in eachrow(pot_output_df)
            data_year = floor(Int64, row[:year])
            if data_year in sim_years
                retval_exog.pot_output[data_year - sim_years[1] + 1, data_sec_ndxs] .= Vector(row[2:end])
            end
       end
    end

    if !isnothing(max_util_df)
        data_sec_codes = names(max_util_df)[2:end]
        # Using findfirst: there should only be one entry per code
        data_sec_ndxs = [findfirst(params["included_sector_codes"] .== sec_code) for sec_code in data_sec_codes]
        # Confirm that the sectors are included
        if !isnothing(findfirst(isnothing.(data_sec_ndxs)))
            invalid_sec_ndxs = findall(x -> isnothing(x), data_sec_ndxs)
            invalid_sec_codes = data_sec_codes[invalid_sec_ndxs]
            if length(invalid_sec_codes) > 1
                invalid_sec_codes_str = format(LMlib.gettext("Sector codes '{1}' in input file '{2}' not valid"), join(invalid_sec_codes, "', '"), params["exog-files"]["max_utilization"])
            else
                invalid_sec_codes_str = format(LMlib.gettext("Sector code '{1}' in input file '{2}' not valid"), invalid_sec_codes[1], params["exog-files"]["max_utilization"])
            end
            deleteat!(data_sec_ndxs, invalid_sec_ndxs)
            max_util_df = max_util_df[:,Not(1 .+ invalid_sec_ndxs)]
            @warn invalid_sec_codes_str
        end
        for row in eachrow(max_util_df)
            data_year = floor(Int64, row[:year])
            if data_year in sim_years
                retval_exog.max_util[data_year - sim_years[1] + 1, data_sec_ndxs] .= Vector(row[2:end])
            end
       end
    end

    if !isnothing(real_price_df)
        data_prod_codes = names(real_price_df)[2:end]
        # Using findfirst: there should only be one entry per code
        data_prod_ndxs = [findfirst(params["included_product_codes"] .== prod_code) for prod_code in data_prod_codes]
        # Confirm that the products are included
        if !isnothing(findfirst(isnothing.(data_prod_ndxs)))
            invalid_prod_ndxs = findall(x -> isnothing(x), data_prod_ndxs)
            invalid_prod_codes = data_prod_codes[invalid_prod_ndxs]
            if length(invalid_prod_codes) > 1
                invalid_prod_codes_str = format(LMlib.gettext("Product codes '{1}' in input file '{2}' not valid"), join(invalid_prod_codes, "', '"), params["exog-files"]["real_price"])
            else
                invalid_prod_codes_str = format(LMlib.gettext("Product code '{1}' in input file '{2}' not valid"), invalid_prod_codes[1], params["exog-files"]["real_price"])
            end
            deleteat!(data_prod_ndxs, invalid_prod_ndxs)
            real_price_df = real_price_df[:,Not(1 .+ invalid_prod_ndxs)]
            @warn invalid_prod_codes_str
        end
        for row in eachrow(real_price_df)
            data_year = floor(Int64, row[:year])
            if data_year in sim_years
                retval_exog.price[data_year - sim_years[1] + 1, data_prod_ndxs] .= Vector(row[2:end])
            end
       end
    end

    return retval_exog, retval_techchange

end # get_var_params

"""
Calculate a measure of how important the demand for non-energy goods from the energy sector is.

The measure is a ratio of the sum of the elements of two Leontief inverses: one for the whole matrix of
technical coefficients and the other for the matrix with the ``A_{NE}`` sub-block excluded.

The sum of the elements of a Leontief inverse can be interpreted as the change in total output
from an increase in final demand that is the same across all sectors.
"""
function energy_nonenergy_link_measure(params::Dict)
	full_sector_ndxs = sort(vcat(params["sector-indexes"],params["energy-sector-indexes"]))
	full_product_ndxs = sort(vcat(params["product-indexes"],params["energy-product-indexes"]))
	ns = length(full_sector_ndxs)

	SUT_df = CSV.read(joinpath("inputs",params["files"]["SUT"]), header=false, DataFrame)

	#--------------------------------
	# Compute S matrix
	#--------------------------------
	supply_table = LMlib.excel_range_to_mat(SUT_df, params["SUT_ranges"]["supply_table"])[full_product_ndxs,full_sector_ndxs]
	V = transpose(supply_table)
	qs = vec(sum(V, dims=1))
	g = vec(sum(V, dims=2))
	S = V * Diagonal(1.0 ./ (qs .+ LMlib.ϵ))

	#--------------------------------
	# Compute D matrix
	#--------------------------------
	use_table = LMlib.excel_range_to_mat(SUT_df, params["SUT_ranges"]["use_table"])[full_product_ndxs,full_sector_ndxs]
	D = use_table * Diagonal(1.0 ./ (g .+ LMlib.ϵ))

	#--------------------------------
	# Compute A matrix and Leontief matrix
	#--------------------------------
	A = S * D
	L = inv(LinearAlgebra.I - A)

	#--------------------------------
	# Set A_NE set to zero and compute the Leontief matrix
	#--------------------------------
	A_reduced = A
	for col in 1:ns
		if !in(full_sector_ndxs[col], params["energy-sector-indexes"])
			continue
		end
		for row in 1:ns
			if in(full_sector_ndxs[row], params["sector-indexes"])
				A_reduced[row,col] = 0.0
			end
		end
	end
	L_reduced = inv(LinearAlgebra.I - A_reduced)

	#--------------------------------
	# Calculate and return measure
	#--------------------------------
	return 1.0 - sum(L_reduced)/sum(L)

end # energy_nonenergy_link_measure

"Process supply-use data from CSV input file."
function process_sut(params::Dict)
    retval = SUTdata(Array{Float64}(undef, 0, 0), # D
                    Array{Float64}(undef, 0, 0), # S
                    Array{Float64}(undef, 0, 0), # Vnorm
                    Array{Float64}(undef, 0), # F
                    Array{Float64}(undef, 0), # I
                    Array{Float64}(undef, 0), # X
                    Array{Float64}(undef, 0), # M
                    Array{Float64}(undef, 0), # W
                    Array{Float64}(undef, 0), # g
                    Array{Float64}(undef, 0), # marg_pos_ratio
                    Array{Float64}(undef, 0), # marg_neg_share
                    Array{Float64}(undef, 0), # m_frac
                    Array{Float64}(undef, 0), # energy_share
                    Array{Float64}(undef, 0)) # μ
    
	sector_ndxs = params["sector-indexes"]
	product_ndxs = params["product-indexes"]

	ns = length(sector_ndxs)
	np = length(product_ndxs)

	terr_adj_sector_ndx = params["terr-adj-sector-indexes"] # TODO: This isn't used
	terr_adj_product_ndx = params["terr-adj-product-indexes"]

    energy_product_ndxs = params["energy-product-indexes"]

    SUT_df = CSV.read(joinpath("inputs",params["files"]["SUT"]), header=false, DataFrame)

	#--------------------------------
	# Supply table
	#--------------------------------
	supply_table = LMlib.excel_range_to_mat(SUT_df, params["SUT_ranges"]["supply_table"])[product_ndxs,sector_ndxs]
	V = transpose(supply_table)
	qs = vec(sum(V, dims=1))
	retval.S = V * Diagonal(1 ./ (qs .+ LMlib.ϵ))
    retval.g = vec(sum(V, dims=2))
	retval.Vnorm = Diagonal(1 ./ retval.g) * V

	# Get total supply column
	tot_supply = LMlib.excel_range_to_mat(SUT_df, params["SUT_ranges"]["tot_supply"])[product_ndxs]

	#--------------------------------
	# Use table
	#--------------------------------
	use_table = LMlib.excel_range_to_mat(SUT_df, params["SUT_ranges"]["use_table"])[product_ndxs,sector_ndxs]
	retval.D = use_table * Diagonal(1.0 ./ retval.g)
    # For pricing algorithm, keep track of energy cost share if energy sectors are excluded (e.g., when running together with LEAP)
    energy_use = vec(sum(LMlib.excel_range_to_mat(SUT_df, params["SUT_ranges"]["use_table"])[energy_product_ndxs,sector_ndxs], dims=1))
    retval.energy_share = energy_use ./ retval.g

	#--------------------------------
	# Margins
	#--------------------------------
	margins = vec(sum(LMlib.excel_range_to_mat(SUT_df, params["SUT_ranges"]["margins"])[product_ndxs,:], dims=2))
	margins_stat_adj = sum(LMlib.excel_range_to_mat(SUT_df, params["SUT_ranges"]["margins"])[terr_adj_product_ndx,:])
	# Calculate margin ratios
    margins_pos = max.(margins, zeros(np))
    margins_pos = margins_pos * (1.0 + margins_stat_adj/sum(margins_pos))
    margins_neg = max.(-margins, zeros(np))
    margins_neg = margins_neg * (1.0 - margins_stat_adj/sum(margins_neg))
	retval.marg_pos_ratio = margins_pos ./ tot_supply
	retval.marg_neg_share = margins_neg / sum(margins_neg)

	#--------------------------------
	# Taxes
	#--------------------------------
	taxes = vec(sum(LMlib.excel_range_to_mat(SUT_df, params["SUT_ranges"]["taxes"])[product_ndxs,:], dims=2))

	#--------------------------------
	# Imports
	#--------------------------------
	M = vec(sum(LMlib.excel_range_to_mat(SUT_df, params["SUT_ranges"]["imports"])[product_ndxs,:], dims=2))
	M_stat_adj = sum(LMlib.excel_range_to_mat(SUT_df, params["SUT_ranges"]["imports"])[terr_adj_product_ndx,:])
    M = M * (1.0 + M_stat_adj/(sum(M) + LMlib.ϵ))
    M[params["non-tradeable-range"]] .= 0.0 # If it is declared non-tradeable, set imports to zero
	retval.M = M

	#--------------------------------
	# Exports -- will be adjusted later
	#--------------------------------
	X = vec(sum(LMlib.excel_range_to_mat(SUT_df, params["SUT_ranges"]["exports"])[product_ndxs,:], dims=2))
	X_stat_adj = sum(LMlib.excel_range_to_mat(SUT_df, params["SUT_ranges"]["exports"])[terr_adj_product_ndx,:])
    X = X * (1.0 + X_stat_adj/(sum(X) + LMlib.ϵ))
    X[params["non-tradeable-range"]] .= 0.0 # If it is declared non-tradeable, set exports to zero
	retval.X = X

	#--------------------------------
	# Final demand -- will be adjusted later
	#--------------------------------
	F = vec(sum(LMlib.excel_range_to_mat(SUT_df, params["SUT_ranges"]["final_demand"])[product_ndxs,:], dims=2))
	F_stat_adj = sum(LMlib.excel_range_to_mat(SUT_df, params["SUT_ranges"]["final_demand"])[terr_adj_product_ndx,:])
    F = F * (1.0 + F_stat_adj/(sum(F) + LMlib.ϵ))
	retval.F = F

	#--------------------------------
	# Investment -- will be adjusted later
	#--------------------------------
	I = vec(sum(LMlib.excel_range_to_mat(SUT_df, params["SUT_ranges"]["investment"])[product_ndxs,:], dims=2))
	I_stat_adj = sum(LMlib.excel_range_to_mat(SUT_df, params["SUT_ranges"]["investment"])[terr_adj_product_ndx,:])
    I = I * (1.0 + I_stat_adj/(sum(I) + LMlib.ϵ))
	retval.I = I

	#--------------------------------
	# Allocate imports (by a common fraction for each product) to final demand and intermediate demand
	#--------------------------------
	tot_int_sup = vec(sum(LMlib.excel_range_to_mat(SUT_df, params["SUT_ranges"]["tot_intermediate_supply"])[product_ndxs,:], dims=2))
    # The fraction m_frac applies to imports excluding imported investment goods
    retval.m_frac = retval.M ./ (tot_int_sup + retval.F + retval.I .+ LMlib.ϵ)
	#--------------------------------
	# Correct demands
	#--------------------------------
	stock_change = vec(sum(LMlib.excel_range_to_mat(SUT_df, params["SUT_ranges"]["stock_change"])[product_ndxs,:], dims=2))
    # Correct for stock changes and tax leakage
    corr = 1 .+ (stock_change - taxes) ./ (retval.F + retval.I + retval.X .+ LMlib.ϵ)
    retval.F = corr .* retval.F
    retval.X = corr .* retval.X
    retval.I = corr .* retval.I

	#--------------------------------
	# Wages
	#--------------------------------
	retval.W = vec(sum(LMlib.excel_range_to_mat(SUT_df, params["SUT_ranges"]["wages"])[:,sector_ndxs], dims=1))

	#--------------------------------
	# Profit margin
	#--------------------------------
	tot_int_dmd = vec(sum(LMlib.excel_range_to_mat(SUT_df, params["SUT_ranges"]["tot_intermediate_demand"])[:,sector_ndxs], dims=1))
	profit = max.(retval.g - tot_int_dmd - retval.W, zeros(ns))
	retval.μ = retval.g ./ (retval.g - profit .+ LMlib.ϵ)

    if params["report-diagnostics"]
        qd = vec(sum(use_table, dims=2)) # Assign to a variable for clarity
        # Values by product
        LMlib.write_vector_to_csv(joinpath(params["diagnostics_path"],"domestic_production.csv"), qs, "domestic production", params["included_product_codes"])
        LMlib.write_vector_to_csv(joinpath(params["diagnostics_path"],"imports.csv"),  M, "imports", params["included_product_codes"])
        LMlib.write_vector_to_csv(joinpath(params["diagnostics_path"],"margins.csv"),  margins, "margins", params["included_product_codes"])
		LMlib.write_vector_to_csv(joinpath(params["diagnostics_path"],"imported_fraction.csv"),  retval.m_frac, "imported fraction", params["included_product_codes"])
        LMlib.write_vector_to_csv(joinpath(params["diagnostics_path"],"tot_intermediate_supply_non-energy_sectors.csv"), qd, "intermediate supply from non-energy sectors", params["included_product_codes"])
        LMlib.write_vector_to_csv(joinpath(params["diagnostics_path"],"tot_intermediate_supply_all_sectors.csv"),  tot_int_sup, "intermediate supply", params["included_product_codes"])
        LMlib.write_vector_to_csv(joinpath(params["diagnostics_path"],"exports.csv"),  retval.X, "exports", params["included_product_codes"])
        LMlib.write_vector_to_csv(joinpath(params["diagnostics_path"],"final_demand.csv"),  retval.F, "final demand", params["included_product_codes"])
        LMlib.write_vector_to_csv(joinpath(params["diagnostics_path"],"investment.csv"),  retval.I, "investment", params["included_product_codes"])
        # Values by sector
        LMlib.write_vector_to_csv(joinpath(params["diagnostics_path"],"sector_output.csv"), retval.g, "output", params["included_sector_codes"])
        LMlib.write_vector_to_csv(joinpath(params["diagnostics_path"],"tot_intermediate_demand_all_products.csv"),  tot_int_dmd, "intermediate demand", params["included_sector_codes"])
        LMlib.write_vector_to_csv(joinpath(params["diagnostics_path"],"wages.csv"),  retval.W, "wages", params["included_sector_codes"])
        LMlib.write_vector_to_csv(joinpath(params["diagnostics_path"],"profit_margins.csv"), retval.μ, "profit margins", params["included_sector_codes"])
        if sum(retval.energy_share) != 0
            LMlib.write_vector_to_csv(joinpath(params["diagnostics_path"],"energy_share.csv"), retval.energy_share, "energy share", params["included_sector_codes"])
        end
        # Matrices
        LMlib.write_matrix_to_csv(joinpath(params["diagnostics_path"],"supply_fractions.csv"), retval.S, params["included_sector_codes"], params["included_product_codes"])
        LMlib.write_matrix_to_csv(joinpath(params["diagnostics_path"],"demand_coefficients.csv"), retval.D, params["included_product_codes"], params["included_sector_codes"])
		# Write out nonenergy-energy link metric
        open(joinpath(params["diagnostics_path"],"nonenergy_energy_link_measure.txt"), "w") do fhndl
			R = 100 .* energy_nonenergy_link_measure(params)
			A_NE_metric_string = format(LMlib.gettext("This value should be small: {1:.2f}%."), R)
			println(fhndl, LMlib.gettext("Measure of the significance to the economy of the supply of non-energy goods and services to the energy sector:"))
		    println(fhndl, A_NE_metric_string)
		end
    end

    return retval, np, ns

end # process_sut

"Initialize price structure."
# All domestic price indices are initialized to one
function initialize_prices(np::Integer, io::SUTdata)
    return PriceData(ones(np), #pb
                     ones(np), #pd
                     ones(np), #pw in domestic currency (converted using xr in macro_main)
                     1, # Pg
                     1, # Pw
                     1, # Px
                     1, # Pm
                     1, # Ptrade
                     1, # XR
                     1) # RER
end # initialize_prices

end # SUTlib
