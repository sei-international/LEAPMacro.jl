module LEAPfunctions
using DelimitedFiles, PyCall, DataFrames, CSV

export visible, outputtoleap, calculateleap, energyinvestment

include("./IOlib.jl")
using .IOlib

"""
    visible(state::Bool)

Hide or show LEAP by setting visibility.
"""
function visible(state::Bool)
	LEAP = connecttoleap()
	LEAP.Visible = state
	disconnectfromleap(LEAP)
end

"""
    outputtoleap(file::String, indices::Array)

First obtain LEAP branch info from the YAML config file and then send Macro model results to LEAP.
"""
function outputtoleap(file::String, indices::Array, run::Int64)
    # LEAP parameters from config file
    if run == 0
        params = IOlib.parse_input_file(file, force = true)
    else
        params = IOlib.parse_input_file(file)
    end
    base_year = params["years"]["start"]
    final_year = params["years"]["end"]

    # connects program to LEAP
    LEAP = connecttoleap()

    # Set ActiveView
    LEAP.ActiveView = "Analysis"

	branch_data = Dict(:branch => String[], :variable => String[], :last_historical_year => Int64[], :col => Int64[])
	col = 0
    if haskey(params, "GDP-branch")
        col += 1
        append!(branch_data[:branch], [params["GDP-branch"]["branch"]])
        append!(branch_data[:variable], [params["GDP-branch"]["variable"]])
        append!(branch_data[:last_historical_year], [params["GDP-branch"]["last_historical_year"]])
        append!(branch_data[:col], [col])
    end
    if haskey(params, "Employment-branch")
        col += 1
        append!(branch_data[:branch], [params["Employment-branch"]["branch"]])
        append!(branch_data[:variable], [params["Employment-branch"]["variable"]])
        append!(branch_data[:last_historical_year], [params["Employment-branch"]["last_historical_year"]])
        append!(branch_data[:col], [col])
    end

	for leap_sector in params["LEAP-sectors"]
		col += 1
		for branch in leap_sector["branches"]
			append!(branch_data[:branch], [branch["branch"]])
			append!(branch_data[:variable], [branch["variable"]])
			append!(branch_data[:last_historical_year], [branch["last_historical_year"]])
			append!(branch_data[:col], [col])
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
                newexpression = interp_expression(base_year, indices[start_ndx:end_ndx], lasthistoricalyear=lasthistoricalyear)
            else
                newexpression = interp_expression(base_year, indices[start_ndx:end_ndx])
            end
            setbranchvar_expression(LEAP, branch, variable, newexpression, region = params["LEAP-info"]["region"], scenario=params["LEAP-info"]["input_scenario"])

        end
        LEAP.SaveArea()
    finally
	    disconnectfromleap(LEAP)
    end
end

"""
    connecttoleap()

Connect to the currently running instance of LEAP, if one exists; otherwise starts an instance of LEAP.

Return a `PyObject` corresponding to the instance.
If LEAP cannot be started, return `missing`
"""
function connecttoleap()
	try
		LEAPPyObj = pyimport("win32com.client").Dispatch("Leap.LEAPApplication")
        max_loops = 5
        while !LEAPPyObj.ProgramStarted & max_loops > 0
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
        error("Cannot connect to LEAP. Is it installed?")
		return missing
	end
end  # connecttoleap

"""
    disconnectfromleap(LEAPPyObj)

Wrapper for PyCall's pydecref(obj), after saving
"""
function disconnectfromleap(LEAPPyObj)
	pydecref(LEAPPyObj)
end

"""
    interp_expression(base_year::Int64, newdata::Array; lasthistoricalyear::Int64=0)

Create LEAP Interp expression from an array of values.
"""
function interp_expression(base_year::Int64, newdata::Array; lasthistoricalyear::Int64=0)
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

    # Incorporates IO model data into the rest of the expression
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
end

"""
    setbranchvar_expression(leapapplication::PyObject, branch::String, variable::String, newexpression::String; region::String = "", scenario::String = "")

Set a LEAP branch-variable expression.

The region and scenario arguments can be omitted by leaving them as empty strings.
Note that performance is best if neither region nor scenario is specified.
"""
function setbranchvar_expression(leapapplication::PyObject, branch::String, variable::String, newexpression::String; region::String = "", scenario::String = "")
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
end  # setbranchvarexpression

"""
    calculateleap(scen_name::String)

Calculate the LEAP model, returning results for the specified scenario.
"""
function calculateleap(scen_name::String)
    # connects program to LEAP
    LEAP = connecttoleap()
    try
        LEAP.Scenario(scen_name).ResultsShown = true
        LEAP.Calculate()
        LEAP.SaveArea()
    finally
	    disconnectfromleap(LEAP)
    end
end

"""
    energyinvestment(file::String, run::Int64)

Obtain energy investment data from the LEAP model.
"""
function energyinvestment(file::String, run::Int64)
    # LEAP parameters from config file
    if run == 0
        params = IOlib.parse_input_file(file, force = true)
    else
        params = IOlib.parse_input_file(file)
    end
    base_year = params["years"]["start"]
    final_year = params["years"]["end"]

    # connects program to LEAP
    LEAP = connecttoleap()

    # Set ActiveView and ActiveScenario
    LEAP.ActiveView = "Results"
    LEAP.ActiveScenario = params["LEAP-info"]["result_scenario"]

    nrows = (final_year - base_year) + 1
    I_en = Array{Float64}(undef, nrows)
    I_en_temp = Array{Float64}(undef, nrows)

    n_energy = 0
    try
        for b in LEAP.Branches
            if b.BranchType == 2 && b.Level == 2 && b.VariableExists("Investment Costs")
                for y = base_year:final_year
                    I_en_temp[(y-base_year+1)] = b.Variable("Investment Costs").Value(y, params["LEAP-info"]["inv_costs_unit"]) / params["LEAP-info"]["inv_costs_scale"]
                end
                I_en = hcat(I_en, I_en_temp)
                n_energy += 1
            end
        end
    finally
    	disconnectfromleap(LEAP)
    end

    if n_energy > 0
        I_en = sum(I_en[:,2:size(I_en, 2)], dims=2)
    else
        I_en .= 0.0
    end
    writedlm(joinpath(params["results_path"],string("I_en_",run,".csv")), I_en, ',')

    return I_en
end

end
