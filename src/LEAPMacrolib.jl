"Module `LMlib` is a collection of common functions and constants for `LEAPMacro.jl`"
module LMlib

using DataFrames, Formatting, PyCall

export write_matrix_to_csv, write_vector_to_csv, excel_range_to_mat, haskeyvalue, ϵ,
	   write_header_to_csv, append_row_to_csv, stringvec_to_quotedstringvec!,
	   get_nonmissing_values, float_to_int, gettext

# Declared type unions
NumOrVector = Union{Nothing,Number,Vector}
NumOrArray = Union{Nothing,Number,Array}

"Small number for avoiding divide-by-zero problems"
const ϵ = 1.0e-11

"Translate string using gettext"
function gettext(s::AbstractString)
	gt = pyimport("gettext")
	gt.bindtextdomain("LEAPMacro", joinpath(@__DIR__, "locale"))
	gt.textdomain("LEAPMacro")
	return(gt.gettext(s))
end

"Write a matrix to a CSV file."
function write_matrix_to_csv(filename::AbstractString, array::Array, rownames::Vector, colnames::Vector)
	open(filename, "w") do io
        # Write header
		write(io, string("", ',', join(colnames, ','), "\r\n"))
        # Write each row
        for i in eachindex(rownames)
            write(io, string(rownames[i], ',', join(array[i,:], ','), "\r\n"))
        end
	end
end # write_matrix_to_csv

"Write a vector to a CSV file."
function write_vector_to_csv(filename::AbstractString, vector::Vector, varname::AbstractString, rownames::Vector)
	open(filename, "w") do io
        # Write header
		write(io, string("", ',', varname, "\r\n"))
        for i in eachindex(rownames)
            write(io, string(rownames[i], ',', vector[i], "\r\n"))
        end
	end
end # write_vector_to_csv

"Convert a float to nearest int using `round()`"
function float_to_int(x::Number)
	return(trunc(Int, round(x)))
end

"Convert a string (e.g., from a Dataframe) to a float; supply 0.0 for missing values."
function string_to_float(str::Union{Missing,AbstractString})
    try return(parse(Float64, str)) catch
        return(0.0) # Missing values set to zero
    end
end # string_to_float

"Convert an index in the form of characters as used in Excel (e.g., 'AC') into an integer index"
function char_index_to_int(str::AbstractString)
	str_up = uppercase(str)
	mult = 26^length(str_up) # 26 is number of characters in the Roman alphabet
	ndx = 0
	for c in str_up
		mult /= 26
		ndx += mult * (Int(c) - Int('A') + 1)
	end
	return(Int(ndx))
end # char_index_to_int

"Convert a cell reference in Excel form (e.g., 'AB3') to [row, col] (eg., [3,28])"
function excel_ref_to_rowcol(str::AbstractString)
	m = match(r"([A-Za-z]+)([0-9]+)", strip(str)) # Be tolerant of leading and trailing spaces
	if m === nothing
		error(format(gettext("Cell reference '{1}' is not in the correct format (e.g., 'AB3')"), str))
		return nothing
	else
		c = m.captures
		return[parse(Int64,c[2]),char_index_to_int(c[1])]
	end
end # excel_ref_to_rowcol

"Find the value of a cell in dataframe df referenced in Excel form (e.g., 'AB3') and convert to float"
function excel_cell_to_float(df::DataFrame, str::AbstractString)
	rowcol = excel_ref_to_rowcol(str)
	return string_to_float(df[rowcol[1],rowcol[2]])
end # excel_cell_to_float

"Convert a cell range in Excel form (e.g., 'AB3:BG10') to [[row, col],[row,col]]"
function excel_range_to_rowcol_pair(str::AbstractString)
	range_ends = split(str,":")
	if length(range_ends) != 2
		error(format(gettext("Cell range '{1}' is not in the correct format (e.g., 'AB3:BG10')"), str))
		return nothing
	else
		return excel_ref_to_rowcol.(range_ends)
	end
end # excel_range_to_rowcol_pair

"First convert strings in a Dataframe to floats and then convert the Dataframe to a Matrix."
function df_to_mat(df::DataFrame)
    for x = axes(df,2)
        df[!,x] = map(string_to_float, df[!,x]) # converts string to float
    end
    mat = Matrix(df) # convert dataframe to matrix
    return mat
end # df_to_mat

"Extract a range in Excel format from a dataframe and return a numeric matrix"
function excel_range_to_mat(df::DataFrame, str::AbstractString)
	rng = excel_range_to_rowcol_pair(str)
	return df_to_mat(df[rng[1][1]:rng[2][1],rng[1][2]:rng[2][2]])
end # excel_range_to_mat

"Check whether a Dict has a key and that the value is not `nothing`"
function haskeyvalue(d::Dict, k::Any)
    return haskey(d,k) && !isnothing(d[k])
end # haskeyvalue

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
This function converts `svec` in place, so only needs to be run once. In case it is run
multiple times, double quotation marks are replaced with single quotation marks.
"""
function stringvec_to_quotedstringvec!(svec::Vector)
	for i in eachindex(svec)
		svec[i] = replace(string('\"', svec[i], '\"'), "\"\"" => "\"")
	end
end # stringvec_to_quotedstringvec!

"Function to preemptively take values from A first, then B, based on whether values are `missing`"
function get_nonmissing_values(A, B)
	return [if !ismissing(A[i]) A[i] else B[i] end for i in CartesianIndices(A)]
end

end # LMlib
