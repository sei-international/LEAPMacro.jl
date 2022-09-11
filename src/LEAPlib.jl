module LEAPlib
using PyCall, DataFrames, CSV

export hide_leap, send_results_to_leap, calculate_leap, get_results_from_leap, LEAPresults

include("./LEAPMacrolib.jl")
using .LMlib

"Values passed from LEAP to Macro"
mutable struct LEAPresults
    I_en::Array{Any,1} # Investment in the energy sector x year
    pot_output::Array{Any,2} # Potential output from LEAP (converted to index) ns x year
    price::Array{Any,2} # Real prices from LEAP (converted to index) np x year
end

# A list of all LEAP branch types
@enum LEAPBranch begin
	DemandCategoryBranchType = 1
	TransformationModuleBranchType = 2
	TransformationProcessBranchType = 3
	DemandTechnologyBranchType = 4
	TransformationProcessCategoryType = 5
	TransformationOutputCategoryType = 6
	TransformationOutputBranchType = 7
	KeyAssumptionCategoryType = 9
	KeyAssumptionBranchType = 10
	ResourceRootType = 11
	PrimaryBranchCategoryType = 12
	SecondaryBranchCategoryType = 13
	ResourceBranchType = 15
	ResourceDisagType = 16
	StatDiffRootType = 18
	StockChangeRootType = 19
	StatDiffPrimaryCategoryType = 20
	StatDiffSecondaryCategoryType = 21
	StockChangePrimaryCategoryType = 22
	StockChangeSecondaryCategoryType = 23
	StatDiffBranchType = 24
	StockChangeBranchType = 25
	NonEnergyCategoryType = 26
	NonEnergyBranchType = 27
	AuxCategoryType = 30
	AuxBranchType = 31
	FeedstockCategoryType = 32
	FeedstockBranchType = 33
	DMDPollutionBranchType = 34
	TransformationPollutionBranchType = 35
	DemandFuelBranchType = 36
	IndicatorCategoryType = 37
	IndicatorBranchType = 38
	EmissionConstraintBranchType = 39
end

"Return an initialized LEAPresults struct"
function initialize_leapresults(params::Dict)
    ny = params["years"]["end"] - params["years"]["start"] + 1
	ns = length(params["sector-indexes"])
	np = length(params["product-indexes"])
    return LEAPresults(
        zeros(ny), # I_en
        Array{Union{Missing, Float64}}(missing, ny, ns), # pot_output
        Array{Union{Missing, Float64}}(missing, ny, np) # price
    )
end # initialize_leapresults

"Hide or show LEAP by setting visibility."
function hide_leap(state::Bool)
	LEAP = connect_to_leap()
	LEAP.Visible = !state
	disconnect_from_leap(LEAP)
end # hide_leap

"First obtain LEAP branch info from `params` and then send Macro model results to LEAP."
function send_results_to_leap(params::Dict, indices::Array)
    base_year = params["years"]["start"]
    final_year = params["years"]["end"]

    # connects program to LEAP
    LEAP = connect_to_leap()

    # Set ActiveView
    LEAP.ActiveView = "Analysis"

	branch_data = Dict(:branch => String[], :variable => String[], :last_historical_year => Int64[], :col => Int64[])
	col = 0
    if LMlib.haskeyvalue(params, "GDP-branch")
        col += 1
        append!(branch_data[:branch], [params["GDP-branch"]["branch"]])
        append!(branch_data[:variable], [params["GDP-branch"]["variable"]])
        append!(branch_data[:last_historical_year], [params["LEAP-info"]["last_historical_year"]])
        append!(branch_data[:col], [col])
    end
    if LMlib.haskeyvalue(params, "Employment-branch")
        col += 1
        append!(branch_data[:branch], [params["Employment-branch"]["branch"]])
        append!(branch_data[:variable], [params["Employment-branch"]["variable"]])
        append!(branch_data[:last_historical_year], [params["LEAP-info"]["last_historical_year"]])
        append!(branch_data[:col], [col])
    end

    if LMlib.haskeyvalue(params, "LEAP-sectors")
        for leap_sector in params["LEAP-sectors"]
            col += 1
            for branch in leap_sector["branches"]
                append!(branch_data[:branch], [branch["branch"]])
                append!(branch_data[:variable], [branch["variable"]])
                append!(branch_data[:last_historical_year], [params["LEAP-info"]["last_historical_year"]])
                append!(branch_data[:col], [col])
            end
        end
    end

	branch_df = DataFrame(branch_data)

    # send results to LEAP
    ndxrows = final_year - base_year + 1
    try
        for i = axes(branch_df, 1) # loops through each branch path
            branch = branch_df[i,:branch]
            variable = branch_df[i,:variable]
            lasthistoricalyear = branch_df[i,:last_historical_year]
            col = branch_df[i,:col]
            start_ndx = (1+(col*ndxrows))
            end_ndx = (col+1)*ndxrows

            if lasthistoricalyear > base_year
                newexpression = build_interp_expression(base_year, indices[start_ndx:end_ndx], lasthistoricalyear=lasthistoricalyear)
            else
                newexpression = build_interp_expression(base_year, indices[start_ndx:end_ndx])
            end
            set_branchvar_expression(LEAP, branch, variable, newexpression, region = params["LEAP-info"]["region"], scenario=params["LEAP-info"]["input_scenario"])

        end
        LEAP.SaveArea()
    finally
	    disconnect_from_leap(LEAP)
    end
end # send_results_to_leap

"""
Connect to the currently running instance of LEAP, if one exists; otherwise starts an instance of LEAP.

Return a `PyObject` corresponding to the instance.
If LEAP cannot be started, return `missing`
"""
function connect_to_leap()
	try
		LEAPPyObj = pyimport("win32com.client").Dispatch("Leap.LEAPApplication")
        max_loops = 5
        while !LEAPPyObj.ProgramStarted && max_loops > 0
            sleep(5)
            max_loops -= 1
        end
        if !LEAPPyObj.ProgramStarted
            error("LEAP is not responding.")
            return missing
        else
            return LEAPPyObj
        end
	catch
        error("Cannot connect to LEAP. Is it installed and running?")
		return missing
	end
end  # connect_to_leap

"Repeatedly call PyCall's `pydecref(obj)` until null"
function disconnect_from_leap(LEAPPyObj)
    while !ispynull(LEAPPyObj)
    	pydecref(LEAPPyObj)
    end
end # disconnect_from_leap

"Create LEAP Interp expression from an array of values."
function build_interp_expression(base_year::Integer, newdata::Array; lasthistoricalyear::Integer=0)
    # Creates start of expression. Includes historical data if available
    if lasthistoricalyear > 0
        newexpression = string("If(year <= ", lasthistoricalyear, ", ScenarioValue(Current Accounts), Value(", base_year,") * Interp(")
        diff = lasthistoricalyear - base_year + 2
        year = lasthistoricalyear + 1
    else
        newexpression = string("(Value(", base_year,") * Interp(")
        diff = 2
        year = base_year + 1
    end

    # Incorporates Macro results into the rest of the expression
    for i = diff:size(newdata,1)
        if isnan(newdata[i]) == false
            newexpression = string(newexpression, year, ", ", newdata[i], ", ")
        end
        if i == size(newdata,1)
            newexpression = newexpression[1:(lastindex(newexpression)-2)]
            newexpression = string(newexpression, "))")
        end
        year = year + 1
    end
    return newexpression
end # build_interp_expression

"""
Set a LEAP branch-variable expression.

The region and scenario arguments can be omitted by leaving them as empty strings.
Note that performance is best if neither region nor scenario is specified.
"""
function set_branchvar_expression(leapapplication::PyObject, branch::AbstractString, variable::AbstractString, newexpression::AbstractString; region::AbstractString = "", scenario::AbstractString = "")
    # Set ActiveRegion and ActiveScenario as Julia doesn't allow a function call (ExpressionRS) to be set to a value
    if region != ""
        leapapplication.ActiveRegion = region
    end

    if scenario != ""
        leapapplication.ActiveScenario = scenario
    end

    # Set expression
    leapapplication.Branch(branch).Variable(variable).Expression = newexpression

    # Refresh LEAP display
    leapapplication.Refresh()
end  # set_branchvar_expression

"Calculate the LEAP model, returning results for the specified scenario."
function calculate_leap(scen_name::AbstractString)
    # connects program to LEAP
    LEAP = connect_to_leap()
    try
        LEAP.ForceCalculation()
        LEAP.Scenario(scen_name).ResultsShown = true
        LEAP.Calculate(false) # This sets RunWEAP = false
        LEAP.SaveArea()
    catch e
        error("Encountered an error when running LEAP: " * sprint(showerror, e))
    finally
	    disconnect_from_leap(LEAP)
    end
end # calculate_leap

"Obtain energy investment data from the LEAP model."
function get_results_from_leap(params::Dict, run_number::Integer, )
    sim_years = params["years"]["start"]:params["years"]["end"]

    # connects program to LEAP
    LEAP = connect_to_leap()

    # Set ActiveView and, if specified, ActiveScenario and ActiveRegion
    LEAP.ActiveView = "Results"

    if params["LEAP-info"]["result_scenario"] != ""
        LEAP.ActiveScenario = params["LEAP-info"]["result_scenario"]
    end

    if params["LEAP-info"]["region"] != ""
        LEAP.ActiveRegion = params["LEAP-info"]["region"]
    end

    # Initialize all elements in the LEAPresults structure (I_en = 0, others are `missing`)
    leapvals = initialize_leapresults(params)

    #--------------------------------
    # Investment expenditure
    #--------------------------------
    I_en_temp = Array{Float64}(undef, length(sim_years))

    try
        for b in LEAP.Branches
            if b.BranchType == Int(TransformationProcessBranchType) && b.Level == 4 && b.VariableExists("Investment Costs")
                is_excluded = false
                for excluded_text in params["LEAP-info"]["excluded_inv_branches"]
                    is_excluded = is_excluded || occursin(Regex(excluded_text, "i"), b.FullName)
                end
                if !is_excluded
                    for t in eachindex(sim_years)
                        if params["LEAP-info"]["inv_costs_unit"] != ""
                            I_en_temp[t] = b.Variable("Investment Costs").Value(sim_years[t], params["LEAP-info"]["inv_costs_unit"]) / params["LEAP-info"]["inv_costs_scale"]
                        else
                            I_en_temp[t] = b.Variable("Investment Costs").Value(sim_years[t]) / params["LEAP-info"]["inv_costs_scale"]
                        end
                    end
                    leapvals.I_en += I_en_temp
                end
            end
        end

        LMlib.write_vector_to_csv(joinpath(params["results_path"],string("I_en_",run_number,".csv")), leapvals.I_en, "energy investment", Vector(sim_years))

        #--------------------------------
        # Potential output
        #--------------------------------
        if LMlib.haskeyvalue(params, "LEAP-potential-output")
            for i in eachindex(params["LEAP-potential-output"])
                s = params["LEAP_potout_indices"][i] # This is a single value
                if !ismissing(s)
                    leapvals.pot_output[:,s] = zeros(length(sim_years))
                    # Driver is allowed to be a sum across multiple branches
                    for b in params["LEAP-potential-output"][i]["branches"]
                        for t in eachindex(sim_years)
                            leapvals.pot_output[t,s] += LEAP.Branch(b["branch"]).Variable(b["variable"]).Value(sim_years[t])
                        end
                    end
                end
            end
        end

        #--------------------------------
        # Energy prices
        #--------------------------------
        if LMlib.haskeyvalue(params, "LEAP-prices")
            for i in eachindex(params["LEAP-prices"])
                b = params["LEAP-prices"][i] # This is a single branch/variable combination
                for t in eachindex(sim_years)
                    price = LEAP.Branch(b["branch"]).Variable(b["variable"]).Value(sim_years[t])
                    # Assign price to each product in a list of product codes
                    for p in params["LEAP_price_indices"][i]
                        leapvals.price[t,p] = price
                    end
                end
            end
        end

    finally
        disconnect_from_leap(LEAP)
    end

    return leapvals
end # get_results_from_leap

end # LEAPlib
