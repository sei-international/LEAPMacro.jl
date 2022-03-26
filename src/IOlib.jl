module IOlib
using CSV, DataFrames, LinearAlgebra, DelimitedFiles, YAML, Printf

export supplyusedata, inputoutputcalc, prices_init, parse_input_file, write_matrix_to_csv, write_vector_to_csv,
       IOdata, PriceData, ExogParams

"Global variable to store the result of parsing the configuration file"
global_params = nothing

"Small number for avoiding divide-by-zero problems"
const ϵ = 1.0e-11

"Values calculated from supply-use and associated tables"
mutable struct IOdata
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
    μ::Array{Float64,1} # ns
    τd::Array{Float64,1} # np
end

"Price indices"
mutable struct PriceData
    pb::Array{Float64,1}
    pd::Array{Float64,1}
    pp::Array{Float64,1}
    pw::Array{Float64,1}
    Pg::Float64
    Pc::Float64
end

"User-specified parameters"
mutable struct ExogParams
    πw::Array{Float64,1} # World inflation rate x year
    world_grs::Array{Float64,1} # Real world GDP growth rate x year
	working_age_grs::Array{Float64,1} # Growth rate of the working age population x year
	αKV::Array{Float64,1} # Kaldor-Verdoorn coefficient x year
	βKV::Array{Float64,1} # Kaldor-Verdoorn intercept x year
	xr::Array{Float64,1} # Nominal exchange rate x year
    δ::Array{Float64,1} # ns
    export_elast_demand::Array{Any,1} # np x year
    wage_elast_demand::Array{Any,1} # np x year
end

"""
    write_matrix_to_csv(filename, array, colnames, rownames)

Write a matrix to a CSV file.
"""
function write_matrix_to_csv(filename, array, rownames, colnames)
	open(filename, "w") do io
        # Write header
		write(io, string("", ',', join(colnames, ','), '\n'))
        # Write each row
        for i in 1:length(rownames)
            write(io, string(rownames[i], ',', join(array[i,:], ','), '\n'))
        end
	end
end

"""
    write_vector_to_csv(filename, vector, varname, rownames)

Write a vector to a CSV file.
"""
function write_vector_to_csv(filename, vector, varname, rownames)
	open(filename, "w") do io
        # Write header
		write(io, string("", ',', varname, '\n'))
        for i in 1:length(rownames)
            write(io, string(rownames[i], ',', vector[i], '\n'))
        end
	end
end

"""
    string_to_float(str)

Convert strings in Dataframe to floats and fill in missing values with 0.
"""
function string_to_float(str)
    try return(parse(Float64, str)) catch
        return(0.0) # Missing values set to zero
    end
end

"""
    char_index_to_int(str)

Convert an index in the form of characters as used in Excel (e.g., "AC") into an integer index
"""
function char_index_to_int(str)
	str_up = uppercase(str)
	mult = 26^length(str_up) # 26 is number of characters in the Roman alphabet
	ndx = 0
	for c in str_up
		mult /= 26
		ndx += mult * (Int(c) - Int('A') + 1)
	end
	return(Int(ndx))
end

"""
    excel_ref_to_rowcol(str)

Convert a cell reference in Excel form (e.g., "AB3") to [row, col] (eg., [3,28])
"""
function excel_ref_to_rowcol(str)
	m = match(r"([A-Za-z]+)([0-9]+)", strip(str)) # Be tolerant of leading and trailing spaces
	if m === nothing
		error("Cell reference '$str' is not in the correct format (e.g., 'AB3')")
		return nothing
	else
		c = m.captures
		return[parse(Int64,c[2]),char_index_to_int(c[1])]
	end
end

"""
    excel_cell_to_float(df, str)

Find the value of a cell in dataframe df referenced in Excel form (e.g., "AB3") and convert to float
"""
function excel_cell_to_float(df, str)
	rowcol = excel_ref_to_rowcol(str)
	return string_to_float(df[rowcol[1],rowcol[2]])
end

"""
    excel_range_to_rowcol_pair(str)

Convert a cell range in Excel form (e.g., "AB3:BG10") to [[row, col],[row,col]]
"""
function excel_range_to_rowcol_pair(str)
	range_ends = split(str,":")
	if length(range_ends) != 2
		error("Cell range '$str' is not in the correct format (e.g., 'AB3:BG10')")
		return nothing
	else
		return excel_ref_to_rowcol.(range_ends)
	end
end

"""
    df_to_mat(df)

First convert strings in a Dataframe to floats and then convert the Dataframe to a Matrix.
"""
function df_to_mat(df)
    for x = 1:size(df,2)
        df[!,x] = map(string_to_float, df[!,x]) # converts string to float
    end
    mat = Matrix(df) # convert dataframe to matrix
    return mat
end

"""
    excel_range_to_mat(df, str)

Extract a range in Excel format from a dataframe and return a numeric matrix
"""
function excel_range_to_mat(df, str)
	rng = excel_range_to_rowcol_pair(str)
	return df_to_mat(df[rng[1][1]:rng[2][1],rng[1][2]:rng[2][2]])
end

"""
    parse_input_file(YAML_file::String; force = false)

Read in YAML input file and convert ranges if necessary.
Force: reset global_params
"""
function parse_input_file(YAML_file::String; force = false)
	global global_params

	if !force & !isnothing(global_params)
		return global_params
	end

    global_params = YAML.load_file(YAML_file)

    global_params["results_path"] = joinpath("outputs/", global_params["output_folder"], "results")
    global_params["calibration_path"] = joinpath("outputs/", global_params["output_folder"], "calibration")
    global_params["diagnostics_path"] = joinpath("outputs/", global_params["output_folder"], "diagnostics")

	# First, check if any sectors or products should be excluded because production is zero (or effectively zero, for products)
	SUT_df = CSV.read(joinpath("inputs",global_params["files"]["SUT"]), header=false, DataFrame)
	M = vec(sum(excel_range_to_mat(SUT_df, global_params["SUT_ranges"]["imports"]), dims=2))
	supply_table = excel_range_to_mat(SUT_df, global_params["SUT_ranges"]["supply_table"])
	qs = vec(sum(supply_table, dims=2))
	g = vec(sum(supply_table, dims=1))
    M_equiv = transpose(supply_table) * Diagonal(1 ./ (qs .+ ϵ)) * M
    # Remove all sectors for which there is negligible domestic production relative to imports
	θ = global_params["domestic_production_share_threshold"]/100
	zero_domprod_ndxs = findall(x -> x < 0, (1 - θ) * g - θ * M_equiv)
    # Remove all products for which there is negligible total supply (domestic + imported) relative to total domestic output
	zero_prod_ndxs = findall(x -> abs(x) < ϵ, (qs + M)/sum(g))

	all_sectors = CSV.read(joinpath("inputs",global_params["files"]["sector_info"]), header=1, types=Dict(:code => String, :name => String), select=[:code,:name], NamedTuple)
	all_products = CSV.read(joinpath("inputs",global_params["files"]["product_info"]), header=1, types=Dict(:code => String, :name => String), select=[:code,:name], NamedTuple)
	sector_codes = all_sectors[:code]
    product_codes = all_products[:code]

	excluded_sectors = vcat(global_params["excluded_sectors"]["territorial_adjustment"],
							global_params["excluded_sectors"]["others"],
							global_params["excluded_sectors"]["energy"])
	excluded_products = vcat(global_params["excluded_products"]["territorial_adjustment"],
							 global_params["excluded_products"]["others"],
							 global_params["excluded_products"]["energy"])
	# These are the indexes used for the Macro model
	user_defined_sector_ndxs = findall(.!in(excluded_sectors).(sector_codes))
	user_defined_product_ndxs = findall(.!in(excluded_products).(product_codes))
	global_params["sector-indexes"] = sort(setdiff(user_defined_sector_ndxs, zero_domprod_ndxs))
	global_params["product-indexes"] = sort(setdiff(user_defined_product_ndxs, zero_prod_ndxs))

	user_defined_energy_sector_ndxs = findall(in(global_params["excluded_sectors"]["energy"]).(sector_codes))
	user_defined_energy_product_ndxs = findall(in(global_params["excluded_products"]["energy"]).(sector_codes))
	global_params["energy-sector-indexes"] = sort(setdiff(user_defined_energy_sector_ndxs, zero_domprod_ndxs))
	global_params["energy-product-indexes"] = sort(setdiff(user_defined_energy_product_ndxs, zero_prod_ndxs))

	global_params["terr-adj-sector-indexes"] = findall(in(global_params["excluded_sectors"]["territorial_adjustment"]).(sector_codes))
	global_params["terr-adj-product-indexes"] = findall(in(global_params["excluded_products"]["territorial_adjustment"]).(sector_codes))

	global_params["included_sector_names"] = all_sectors[:name][global_params["sector-indexes"]]
	global_params["included_sector_codes"] = all_sectors[:code][global_params["sector-indexes"]]
	global_params["included_product_names"] = all_products[:name][global_params["product-indexes"]]
	global_params["included_product_codes"] = all_products[:code][global_params["product-indexes"]]

	# These indices are with respect to the list of included product codes, not the full list
	global_params["non-tradeable-range"] = findall(in(global_params["non_tradeable_products"]).(global_params["included_product_codes"]))

	global_params["LEAP_sector_names"] = [x["name"] for x in global_params["LEAP-sectors"]]
	LEAP_sector_codes = [x["codes"] for x in global_params["LEAP-sectors"]]
	global_params["LEAP_sector_indices"] = Array{Any}(undef,length(LEAP_sector_codes))
	for i in 1:length(LEAP_sector_codes)
		global_params["LEAP_sector_indices"][i] = findall([in(x, LEAP_sector_codes[i]) for x in global_params["included_sector_codes"]])
	end

    return global_params
end

"""
    get_var_params(param_file::String)

Pull in user-specified parameters from different CSV input files with filenames specified in the YAML configuration file.
"""
function get_var_params(param_file::String)
    # Return an ExogParams struct
    retval = ExogParams(
                    Array{Float64}(undef, 0), # πw
                    Array{Float64}(undef, 0), # world_grs
					Array{Float64}(undef, 0), # working_age_grs
					Array{Float64}(undef, 0), # αKV
					Array{Float64}(undef, 0), # βKV
					Array{Float64}(undef, 0), # xr
                    Array{Float64}(undef, 0), # δ
                    [], # export_elast_demand
                    []) # wage_elast_demand

    params = parse_input_file(param_file)
    base_year = params["years"]["start"]
    final_year = params["years"]["end"]
    sec_ndxs = params["sector-indexes"]
    prod_ndxs = params["product-indexes"]

    # Read in info from CSV files
    sector_info = CSV.read(joinpath("inputs",params["files"]["sector_info"]), DataFrame)
    product_info = CSV.read(joinpath("inputs",params["files"]["product_info"]), DataFrame)
    time_series = CSV.read(joinpath("inputs",params["files"]["time_series"]), DataFrame)
    prod_codes = product_info[prod_ndxs,:code]

    #--------------------------------------------------------------------------------------
    # Sector-specific
    #--------------------------------------------------------------------------------------
    # Use same value for each year, but it can vary by sector
    retval.δ = sector_info[sec_ndxs,:depr_rate]

    #--------------------------------------------------------------------------------------
    # Product-specific
    #--------------------------------------------------------------------------------------
    #--- Demand model parameters
    # Note, these are used later to make time-varying parameters
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
    # World inflation rate (apply to world prices only, others induced)
    world_infl_temp = time_series[!,:world_infl_rate]
    world_infl_default = params["global-params"]["infl_default"]
    world_infl_start = floor(Int64, time_series[1,:year])
    world_infl_end = world_infl_start + length(world_infl_temp) - 1

    # World GDP growth rate (including historical, for calibration)
    world_grs_temp = time_series[!,:world_gr]
    world_grs_default = params["global-params"]["gr_default"]
    world_grs_start = floor(Int64, time_series[1,:year])
    world_grs_end = world_grs_start + length(world_grs_temp) - 1

	# Working age growth rate (No default -- must provide all values for specified time period)
    working_age_grs_temp = time_series[!,:working_age_gr]
    working_age_grs_start = floor(Int64, time_series[1,:year])
    working_age_grs_end = working_age_grs_start + length(working_age_grs_temp) - 1

	# Exchange rate (No default -- must provide all values for specified time period)
    xr_temp = time_series[!,:exchange_rate]
    xr_start = floor(Int64, time_series[1,:year])
    xr_end = xr_start + length(xr_temp) - 1

    # Kaldor-Verdoorn parameters
    αKV_temp = time_series[!,:KV_coeff]
    αKV_default = params["labor-prod-fcn"]["KV_coeff_default"]
    αKV_start = floor(Int64, time_series[1,:year])
    αKV_end = αKV_start + length(αKV_temp) - 1

	βKV_temp = time_series[!,:KV_intercept]
    βKV_default = params["labor-prod-fcn"]["KV_intercept_default"]
    βKV_start = floor(Int64, time_series[1,:year])
    βKV_end = βKV_start + length(βKV_temp) - 1
    #--------------------------------------------------------------------------------------
    # Fill in by looping over years
    #--------------------------------------------------------------------------------------
    for year in base_year:final_year
        # creates world inflation rate array for use in the model, using model years
        if year in world_infl_start:world_infl_end
            push!(retval.πw, world_infl_temp[year - world_infl_start + 1])
        else
            push!(retval.πw, world_infl_default)
        end

        # creates world growth rate array for use in the model, using model years
        if year in world_grs_start:world_grs_end
            push!(retval.world_grs, world_grs_temp[year - world_grs_start + 1])
        else
            push!(retval.world_grs, world_grs_default)
        end

		# creates working age growth rate array for use in the model, using model years
        if year in working_age_grs_start:working_age_grs_end
            push!(retval.working_age_grs, working_age_grs_temp[year - working_age_grs_start + 1])
        else
			error_string = "Year is not in range " * string(working_age_grs_start) * ":" * string(working_age_grs_end) * " for working age growth rates"
            throw(DomainError(year, error_string))
        end

		# creates exchange rate array for use in the model, using model years
        if year in xr_start:xr_end
            push!(retval.xr, xr_temp[year - xr_start + 1])
        else
			error_string = "Year is not in range " * string(xr_start) * ":" * string(xr_end) * " for exchange rates"
            throw(DomainError(year, error_string))
        end

		# fill in Kaldor-Verdoorn coefficient and intercept
        if year in αKV_start:αKV_end
            push!(retval.αKV, αKV_temp[year - αKV_start + 1])
        else
            push!(retval.αKV, αKV_default)
        end
		if year in βKV_start:βKV_end
            push!(retval.βKV, βKV_temp[year - βKV_start + 1])
        else
            push!(retval.βKV, βKV_default)
        end

        deltat = max(0, year - base_year + 1) # Year past the end of calibration period

        # Bring high values down, but don't bring low values up
        export_elast_demand_temp = export_elast_demand0 - (1 - exp(-export_elast_decay * deltat)) * (export_elast_demand0 - asympt_export_elast)
        push!(retval.export_elast_demand, export_elast_demand_temp)

        wage_elast_demand_temp = wage_elast_demand0 - (1 - exp(-wage_elast_decay * deltat)) * (wage_elast_demand0 - asympt_wage_elast)
        push!(retval.wage_elast_demand, wage_elast_demand_temp)
    end

    return retval

end

"""
    energy_nonenergy_link_measure(param_file::String)

Calculate a measure of how important the demand for non-energy goods from the energy sector is.

The measure is a ratio of the sum of the elements of two Leontief inverses: one for the whole matrix of
technical coefficients and the other for the matrix with A_{NE} sub-block excluded.

The sum of the elements of a Leontief inverse can be interpreted as the change in total output
from an increase in final demand that is the same across all sectors.
"""
function energy_nonenergy_link_measure(param_file::String)
	params = parse_input_file(param_file)

	full_sector_ndxs = sort(vcat(params["sector-indexes"],params["energy-sector-indexes"]))
	full_product_ndxs = sort(vcat(params["product-indexes"],params["energy-product-indexes"]))
	ns = length(full_sector_ndxs)

	SUT_df = CSV.read(joinpath("inputs",params["files"]["SUT"]), header=false, DataFrame)

	#--------------------------------
	# Compute S matrix
	#--------------------------------
	supply_table = excel_range_to_mat(SUT_df, params["SUT_ranges"]["supply_table"])[full_product_ndxs,full_sector_ndxs]
	V = transpose(supply_table)
	qs = vec(sum(V, dims=1))
	g = vec(sum(V, dims=2))
	S = V * Diagonal(1.0 ./ (qs .+ ϵ))

	#--------------------------------
	# Compute D matrix
	#--------------------------------
	use_table = excel_range_to_mat(SUT_df, params["SUT_ranges"]["use_table"])[full_product_ndxs,full_sector_ndxs]
	D = use_table * Diagonal(1.0 ./ (g .+ ϵ))

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

end

"""
    supplyusedata(param_file::String)

Pull in supply-use data from CSV input files.
"""
function supplyusedata(param_file::String)
    retval = IOdata(Array{Float64}(undef, 0, 0), # D
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
                    Array{Float64}(undef, 0), # μ
                    Array{Float64}(undef, 0)) # τd
    # Reads in key parameters from the YAML config file
    params = parse_input_file(param_file)

	sector_ndxs = params["sector-indexes"]
	product_ndxs = params["product-indexes"]

	ns = length(sector_ndxs)
	np = length(product_ndxs)

	terr_adj_sector_ndx = params["terr-adj-sector-indexes"]
	terr_adj_product_ndx = params["terr-adj-product-indexes"]

    SUT_df = CSV.read(joinpath("inputs",params["files"]["SUT"]), header=false, DataFrame)

	#--------------------------------
	# Supply table
	#--------------------------------
	supply_table = excel_range_to_mat(SUT_df, params["SUT_ranges"]["supply_table"])[product_ndxs,sector_ndxs]
	V = transpose(supply_table)
	qs = vec(sum(V, dims=1))
	retval.S = V * Diagonal(1 ./ (qs .+ ϵ))
    retval.g = vec(sum(V, dims=2))
	retval.Vnorm = Diagonal(1 ./ retval.g) * V

	# Get total supply column
	tot_supply = excel_range_to_mat(SUT_df, params["SUT_ranges"]["tot_supply"])[product_ndxs]

	#--------------------------------
	# Use table
	#--------------------------------
	use_table = excel_range_to_mat(SUT_df, params["SUT_ranges"]["use_table"])[product_ndxs,sector_ndxs]
	retval.D = use_table * Diagonal(1.0 ./ retval.g)

	#--------------------------------
	# Margins
	#--------------------------------
	margins = vec(sum(excel_range_to_mat(SUT_df, params["SUT_ranges"]["margins"])[product_ndxs,:], dims=2))
	margins_stat_adj = sum(excel_range_to_mat(SUT_df, params["SUT_ranges"]["margins"])[terr_adj_product_ndx,:])
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
	taxes = vec(sum(excel_range_to_mat(SUT_df, params["SUT_ranges"]["taxes"])[product_ndxs,:], dims=2))
	retval.τd = taxes ./ tot_supply

	#--------------------------------
	# Imports
	#--------------------------------
	M = vec(sum(excel_range_to_mat(SUT_df, params["SUT_ranges"]["imports"])[product_ndxs,:], dims=2))
	M_stat_adj = sum(excel_range_to_mat(SUT_df, params["SUT_ranges"]["imports"])[terr_adj_product_ndx,:])
    M = M * (1.0 + M_stat_adj/(sum(M) + ϵ))
    M[params["non-tradeable-range"]] .= 0.0 # If it is declared non-tradeable, set imports to zero
	retval.M = M

	#--------------------------------
	# Exports -- will be adjusted later
	#--------------------------------
	X = vec(sum(excel_range_to_mat(SUT_df, params["SUT_ranges"]["exports"])[product_ndxs,:], dims=2))
	X_stat_adj = sum(excel_range_to_mat(SUT_df, params["SUT_ranges"]["exports"])[terr_adj_product_ndx,:])
    X = X * (1.0 + X_stat_adj/(sum(X) + ϵ))
    X[params["non-tradeable-range"]] .= 0.0 # If it is declared non-tradeable, set exports to zero
	retval.X = X

	#--------------------------------
	# Final demand -- will be adjusted later
	#--------------------------------
	F = vec(sum(excel_range_to_mat(SUT_df, params["SUT_ranges"]["final_demand"])[product_ndxs,:], dims=2))
	F_stat_adj = sum(excel_range_to_mat(SUT_df, params["SUT_ranges"]["final_demand"])[terr_adj_product_ndx,:])
    F = F * (1.0 + F_stat_adj/(sum(F) + ϵ))
	retval.F = F

	#--------------------------------
	# Investment -- will be adjusted later
	#--------------------------------
	I = vec(sum(excel_range_to_mat(SUT_df, params["SUT_ranges"]["investment"])[product_ndxs,:], dims=2))
	I_stat_adj = sum(excel_range_to_mat(SUT_df, params["SUT_ranges"]["investment"])[terr_adj_product_ndx,:])
    I = I * (1.0 + I_stat_adj/(sum(I) + ϵ))
	retval.I = I

	#--------------------------------
	# Allocate imports (by a common fraction for each product) to final demand and intermediate demand
	#--------------------------------
	tot_int_sup = vec(sum(excel_range_to_mat(SUT_df, params["SUT_ranges"]["tot_intermediate_supply"])[product_ndxs,:], dims=2))
    # The fraction m_frac applies to imports excluding imported investment goods
    retval.m_frac = retval.M ./ (tot_int_sup + retval.F + retval.I)
	#--------------------------------
	# Correct demands
	#--------------------------------
	stock_change = vec(sum(excel_range_to_mat(SUT_df, params["SUT_ranges"]["stock_change"])[product_ndxs,:], dims=2))
    # Correct for stock changes and tax leakage
    corr = 1 .+ (stock_change - taxes) ./ (retval.F + retval.I + retval.X .+ ϵ)
    retval.F = corr .* retval.F
    retval.X = corr .* retval.X
    retval.I = corr .* retval.I

	#--------------------------------
	# Wages
	#--------------------------------
	retval.W = vec(sum(excel_range_to_mat(SUT_df, params["SUT_ranges"]["wages"])[:,sector_ndxs], dims=1))

	#--------------------------------
	# Profit margin
	#--------------------------------
	tot_int_dmd = vec(sum(excel_range_to_mat(SUT_df, params["SUT_ranges"]["tot_intermediate_demand"])[:,sector_ndxs], dims=1))
	profit = max.(retval.g - tot_int_dmd - retval.W,zeros(ns))
	retval.μ = retval.g ./ (retval.g - profit .+ ϵ)

    if params["report-diagnostics"]
        qd = vec(sum(use_table, dims=2)) # Assign to a variable for clarity
        # Values by product
        write_vector_to_csv(joinpath(params["diagnostics_path"],"domestic_production.csv"), qs, "domestic production", params["included_product_codes"])
        write_vector_to_csv(joinpath(params["diagnostics_path"],"imports.csv"),  M, "imports", params["included_product_codes"])
        write_vector_to_csv(joinpath(params["diagnostics_path"],"margins.csv"),  margins, "margins", params["included_product_codes"])
		write_vector_to_csv(joinpath(params["diagnostics_path"],"imported_fraction.csv"),  retval.m_frac, "imported fraction", params["included_product_codes"])
        write_vector_to_csv(joinpath(params["diagnostics_path"],"tot_intermediate_supply_non-energy_sectors.csv"), qd, "intermediate supply from non-energy sectors", params["included_product_codes"])
        write_vector_to_csv(joinpath(params["diagnostics_path"],"tot_intermediate_supply_all_sectors.csv"),  tot_int_sup, "intermediate supply", params["included_product_codes"])
        write_vector_to_csv(joinpath(params["diagnostics_path"],"exports.csv"),  retval.X, "exports", params["included_product_codes"])
        write_vector_to_csv(joinpath(params["diagnostics_path"],"final_demand.csv"),  retval.F, "final demand", params["included_product_codes"])
        write_vector_to_csv(joinpath(params["diagnostics_path"],"investment.csv"),  retval.I, "investment", params["included_product_codes"])
        write_vector_to_csv(joinpath(params["diagnostics_path"],"tax_rate.csv"), retval.τd, "taxes on products", params["included_product_codes"])
        # Values by sector
        write_vector_to_csv(joinpath(params["diagnostics_path"],"sector_output.csv"), retval.g, "output", params["included_sector_codes"])
        write_vector_to_csv(joinpath(params["diagnostics_path"],"tot_intermediate_demand_all_products.csv"),  tot_int_dmd, "intermediate demand", params["included_sector_codes"])
        write_vector_to_csv(joinpath(params["diagnostics_path"],"wages.csv"),  retval.W, "wages", params["included_sector_codes"])
        write_vector_to_csv(joinpath(params["diagnostics_path"],"profit_margins.csv"), retval.μ, "profit margins", params["included_sector_codes"])
        # Matrices
        write_matrix_to_csv(joinpath(params["diagnostics_path"],"supply_fractions.csv"), retval.S, params["included_sector_codes"], params["included_product_codes"])
        write_matrix_to_csv(joinpath(params["diagnostics_path"],"demand_coefficients.csv"), retval.D, params["included_product_codes"], params["included_sector_codes"])
		# Write out nonenergy-energy link metric
        open(joinpath(params["diagnostics_path"],"nonenergy_energy_link_measure.txt"), "w") do fhndl
			R = 100 .* energy_nonenergy_link_measure(param_file)
			A_NE_metric_string = @sprintf("This value should be small: %.2f%%.", R)
			println(fhndl, "Measure of the significance to the economy of the supply of non-energy goods and services to the energy sector:")
		    println(fhndl, A_NE_metric_string)
		end
    end

    return retval, np, ns

end

"""
    prices_init(np::Int64, io::IOdata)

Initialize price structure.
"""
# All domestic prices are initialized to one
function prices_init(np::Int64, io::IOdata)
    return PriceData(ones(np), #pb
                     ones(np), #pd
                     ones(np), #pp
                     ones(np) + io.τd, #pw in domestic currency (converted using xr in Macro.jl)
                     1,1)
end

end
