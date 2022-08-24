module SUTlib
using CSV, DataFrames, LinearAlgebra, YAML, Printf, Logging

export process_sut, initialize_prices, parse_param_file,
       SUTdata, PriceData, ExogParams

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
	αKV::Array{Float64,1} # Kaldor-Verdoorn coefficient x year
	βKV::Array{Float64,1} # Kaldor-Verdoorn intercept x year
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

"Read in YAML input file and convert ranges if necessary."
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

    # LEAP sectors allow for multiple Macro sector codes (production is summed) and multiple branch/variable combos (the index is applied to each combination)
    if LMlib.haskeyvalue(global_params, "LEAP-sectors")
        global_params["LEAP_sector_names"] = [x["name"] for x in global_params["LEAP-sectors"]]
        LEAP_sector_codes = [x["codes"] for x in global_params["LEAP-sectors"]]
        global_params["LEAP_sector_indices"] = Array{Any}(undef,length(LEAP_sector_codes))
        for i in eachindex(LEAP_sector_codes)
            global_params["LEAP_sector_indices"][i] = findall([in(x, LEAP_sector_codes[i]) for x in global_params["included_sector_codes"]])
        end
    else
        global_params["LEAP_sector_names"] = []
        global_params["LEAP_sector_indices"] = []
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
                @warn "Sector code '" * LEAP_potout_codes[i] * "' is listed in 'LEAP-potential-output' but is not included in the Macro model calculations."
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
        # Key "inv_costs_unit" is missing, so apply the default
        if !LMlib.haskeyvalue(global_params["LEAP-info"], "inv_costs_unit")
            global_params["LEAP-info"]["inv_costs_unit"] = ""
        end
        # Key "inv_costs_scale" is missing, so default to 1.0
        if !LMlib.haskeyvalue(global_params["LEAP-info"], "inv_costs_scale")
            global_params["LEAP-info"]["inv_costs_scale"] = 1.0
        end
        if !LMlib.haskeyvalue(global_params["LEAP-info"], "last_historical_year")
            global_params["LEAP-info"]["last_historical_year"] = global_params["years"]["start"]
        end
    else
        global_params["LEAP-info"] = Dict()
        global_params["LEAP-info"]["last_historical_year"] = global_params["years"]["start"]
        global_params["LEAP-info"]["input_scenario"] = ""
        global_params["LEAP-info"]["result_scenario"] = ""
        global_params["LEAP-info"]["inv_costs_unit"] = ""
        global_params["LEAP-info"]["inv_costs_scale"] = 1.0
    end

    return global_params
end # parse_param_file

"Pull in user-specified parameters from different CSV input files with filenames specified in the YAML configuration file."
function get_var_params(params::Dict)
    # Return an ExogParams struct
    retval = ExogParams(
                    Array{Float64}(undef, 0), # πw_base
                    Array{Float64}(undef, 0), # world_grs
					Array{Float64}(undef, 0), # working_age_grs
					Array{Float64}(undef, 0), # αKV
					Array{Float64}(undef, 0), # βKV
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
        if LMlib.haskeyvalue(file_list, "investment") && isfile(joinpath("inputs",file_list["investment"]))
            investment_df = CSV.read(joinpath("inputs",file_list["investment"]), DataFrame)
        end
        if LMlib.haskeyvalue(file_list, "pot_output") && isfile(joinpath("inputs",file_list["pot_output"]))
            pot_output_df = CSV.read(joinpath("inputs",file_list["pot_output"]), DataFrame)
        end
        if LMlib.haskeyvalue(file_list, "max_utilization") && isfile(joinpath("inputs",file_list["max_utilization"]))
            max_util_df = CSV.read(joinpath("inputs",file_list["max_utilization"]), DataFrame)
        end
        if LMlib.haskeyvalue(file_list, "real_price") && isfile(joinpath("inputs",file_list["real_price"]))
            real_price_df = CSV.read(joinpath("inputs",file_list["real_price"]), DataFrame)
        end
    end
    
    #--------------------------------------------------------------------------------------
    # Sector-specific
    #--------------------------------------------------------------------------------------
    # Use same value for each year, but it can vary by sector
    retval.δ = sector_info[sec_ndxs,:depr_rate]

    #--------------------------------------------------------------------------------------
    # Product-specific
    #--------------------------------------------------------------------------------------
    #--- Demand model parameters
    if hasproperty(product_info, :import_price_elast)
        retval.import_price_elast = product_info[prod_ndxs,:import_price_elast]
    else
        retval.import_price_elast = zeros(length(prod_codes))
    end
    if hasproperty(product_info, :export_price_elast)
        retval.export_price_elast = product_info[prod_ndxs,:export_price_elast]
    else
        retval.export_price_elast = zeros(length(prod_codes))
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
    world_infl_temp = time_series[!,:world_infl_rate]
    world_infl_default = params["global-params"]["infl_default"]

    # World GDP growth rate (including historical, for calibration)
    world_grs_temp = time_series[!,:world_gr]
    world_grs_default = params["global-params"]["gr_default"]

	# Working age growth rate (No default -- must provide all values for specified time period)
    working_age_grs_temp = time_series[!,:working_age_gr]

	# Exchange rate (No default -- must provide all values for specified time period)
    xr_temp = time_series[!,:exchange_rate]

    # Kaldor-Verdoorn parameters
    αKV_default = params["labor-prod-fcn"]["KV_coeff_default"]
    if hasproperty(time_series, :KV_coeff)
        αKV_temp = time_series[!,:KV_coeff]
    else
        αKV_temp = fill(αKV_default, length(time_series[!,:year]))
    end

    βKV_default = params["labor-prod-fcn"]["KV_intercept_default"]
    if hasproperty(time_series, :KV_intercept)
        βKV_temp = time_series[!,:KV_intercept]
    else
        βKV_temp = fill(βKV_default, length(time_series[!,:year]))
    end

    #--------------------------------------------------------------------------------------
    # Fill in by looping over years
    #--------------------------------------------------------------------------------------
    for year in sim_years
        if year in data_start_year:data_end_year
            year_ndx = year - data_start_year + 1
            # These have no defaults: check first
            if !ismissing(working_age_grs_temp[year_ndx])
                push!(retval.working_age_grs, working_age_grs_temp[year_ndx])
            else
                error_string = "Value for working age growth rate missing in year " * string(year) * ", with no default"
                throw(MissingException(error_string))
            end
            if !ismissing(xr_temp[year_ndx])
                push!(retval.xr, xr_temp[year_ndx])
            else
                error_string = "Value for exchange rate missing in year " * string(year) * ", with no default"
                throw(MissingException(error_string))
            end
            # These have defaults
            if !ismissing(world_infl_temp[year_ndx])
                push!(retval.πw_base, world_infl_temp[year_ndx])
            else
                push!(retval.πw_base, world_infl_default)
            end
            if !ismissing(world_grs_temp[year_ndx])
                push!(retval.world_grs, world_grs_temp[year_ndx])
            else
                push!(retval.world_grs, world_grs_default)
            end
            if !ismissing(αKV_temp[year_ndx])
                push!(retval.αKV, αKV_temp[year_ndx])
            else
                push!(retval.αKV, αKV_default)
            end
            if !ismissing(βKV_temp[year_ndx])
                push!(retval.βKV, βKV_temp[year_ndx])
            else
                push!(retval.βKV, βKV_default)
            end
        else
			error_string = "Year " * string(year) * " is not in time series range " * string(data_start_year) * ":" * string(data_end_year)
            throw(DomainError(year, error_string))
        end

        deltat = max(0, year - sim_years[1] + 1) # Year past the end of calibration period

        # Bring high values down, but don't bring low values up
        export_elast_demand_temp = export_elast_demand0 - (1 - exp(-export_elast_decay * deltat)) * (export_elast_demand0 - asympt_export_elast)
        push!(retval.export_elast_demand, export_elast_demand_temp)

        wage_elast_demand_temp = wage_elast_demand0 - (1 - exp(-wage_elast_decay * deltat)) * (wage_elast_demand0 - asympt_wage_elast)
        push!(retval.wage_elast_demand, wage_elast_demand_temp)
    end

    #--------------------------------------------------------------------------------------
    # Optional files
    #--------------------------------------------------------------------------------------

    retval.I_addl = zeros(length(sim_years))
    retval.pot_output = Array{Union{Missing, Float64}}(missing, length(sim_years), length(sec_ndxs))
    retval.max_util = Array{Union{Missing, Float64}}(missing, length(sim_years), length(sec_ndxs))
    retval.price = Array{Union{Missing, Float64}}(missing, length(sim_years), length(prod_ndxs))

    if !isnothing(investment_df)
        for row in eachrow(investment_df)
            data_year = floor(Int64, row[:year])
            if data_year in sim_years
                retval.I_addl[data_year - sim_years[1] + 1] = row[:addl_investment]
            end
       end
    end

    if !isnothing(pot_output_df)
        data_sec_codes = names(pot_output_df)[2:end]
        # Using findfirst: there should only be one entry per code
        data_sec_ndxs = [findfirst(params["included_sector_codes"] .== sec_code) for sec_code in data_sec_codes]
        # Confirm that the sectors are included
        if !isnothing(findfirst(isnothing.(data_sec_ndxs)))
            invalid_sec_codes = data_sec_codes[findall(x -> isnothing(x), data_sec_ndxs)]
            if length(invalid_sec_codes) > 1
                invalid_sec_codes_str = "Sector codes '" * join(invalid_sec_codes, "', '") * "'"
            else
                invalid_sec_codes_str = "Sector code '" * invalid_sec_codes[1] * "'"
            end
            throw(DomainError(invalid_sec_codes, invalid_sec_codes_str * " in input file '" * params["exog-files"]["pot_output"] * "' not valid"))
        end
        for row in eachrow(pot_output_df)
            data_year = floor(Int64, row[:year])
            if data_year in sim_years
                retval.pot_output[data_year - sim_years[1] + 1, data_sec_ndxs] .= Vector(row[2:end])
            end
       end
    end

    if !isnothing(max_util_df)
        data_sec_codes = names(max_util_df)[2:end]
        # Using findfirst: there should only be one entry per code
        data_sec_ndxs = [findfirst(params["included_sector_codes"] .== sec_code) for sec_code in data_sec_codes]
        # Confirm that the sectors are included
        if !isnothing(findfirst(isnothing.(data_sec_ndxs)))
            invalid_sec_codes = data_sec_codes[findall(x -> isnothing(x), data_sec_ndxs)]
            if length(invalid_sec_codes) > 1
                invalid_sec_codes_str = "Sector codes '" * join(invalid_sec_codes, "', '") * "'"
            else
                invalid_sec_codes_str = "Sector code '" * invalid_sec_codes[1] * "'"
            end
            throw(DomainError(invalid_sec_codes, invalid_sec_codes_str * " in input file '" * params["exog-files"]["max_utilization"] * "' not valid"))
        end
        for row in eachrow(max_util_df)
            data_year = floor(Int64, row[:year])
            if data_year in sim_years
                retval.max_util[data_year - sim_years[1] + 1, data_sec_ndxs] .= Vector(row[2:end])
            end
       end
    end

    if !isnothing(real_price_df)
        data_prod_codes = names(real_price_df)[2:end]
        # Using findfirst: there should only be one entry per code
        data_prod_ndxs = [findfirst(params["included_product_codes"] .== prod_code) for prod_code in data_prod_codes]
        # Confirm that the products are included
        if !isnothing(findfirst(isnothing.(data_prod_ndxs)))
            invalid_prod_codes = data_prod_codes[findall(x -> isnothing(x), data_prod_ndxs)]
            if length(invalid_prod_codes) > 1
                invalid_prod_codes_str = "Product codes '" * join(invalid_prod_codes, "', '") * "'"
            else
                invalid_prod_codes_str = "Product code '" * invalid_prod_codes[1] * "'"
            end
            throw(DomainError(invalid_prod_codes, invalid_prod_codes_str * " in input file '" * params["exog-files"]["real_price"] * "' not valid"))
        end
        for row in eachrow(real_price_df)
            data_year = floor(Int64, row[:year])
            if data_year in sim_years
                retval.price[data_year - sim_years[1] + 1, data_prod_ndxs] .= Vector(row[2:end])
            end
       end
    end

    return retval

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

	terr_adj_sector_ndx = params["terr-adj-sector-indexes"]
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
    retval.m_frac = retval.M ./ (tot_int_sup + retval.F + retval.I)
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
			A_NE_metric_string = @sprintf("This value should be small: %.2f%%.", R)
			println(fhndl, "Measure of the significance to the economy of the supply of non-energy goods and services to the energy sector:")
		    println(fhndl, A_NE_metric_string)
		end
    end

    return retval, np, ns

end # process_sut

"Initialize price structure."
# All domestic prices are initialized to one
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
