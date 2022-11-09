#=
jgettext: Extract gettext strings from Julia files

Authors:
  Eric Kemp-Benedict

Copyright ©2022 Stockholm Environment Institute
=#

using ArgParse

function jgettext(infiles, outfile)
	# Look for function signature gettext(s), where s is a literal string
	re = r"gettext\((\"[^\"]+\")\)"
	msgids = Dict()
	for infile in infiles
		fname = basename(infile)
		
		lineno = 1
		for line in eachline(infile)
			for s in eachmatch(re, line)
				msgid = s.captures[1]
				if haskey(msgids, msgid)
					push!(msgids[msgid], "$fname:$lineno")
				else
					msgids[msgid] = ["$fname:$lineno"]
				end
			end
			lineno += 1
		end
	end
	open(outfile, "w") do f
		for (msgid, loc) in msgids
			write(f, "\n#: ")
			write(f, join(loc, "; "))
			write(f, "\nmsgid $msgid")
			write(f, "\nmsgstr \"\"\n")
		end
	end
end

function parse_commandline()
    argp = ArgParseSettings(autofix_names = true)
    @add_arg_table! argp begin
        "inputfiles"
            help = "one or more Julia input files"
            arg_type = AbstractString
            nargs = '+'
        "--default-domain", "-d"
            help = "Use <name>.po for output (instead of messages.po)"
            arg_type = AbstractString
            default = "messages"
        "--output", "-o"
            help = "Write output to specified file (instead of <name>.po or messages.po)"
            arg_type = AbstractString
            default = ""
        "--output-dir", "-p"
            help = "Place output files in specified directory"
            arg_type = AbstractString
            default = "."
    end

    return parse_args(argp)
end

parsed_args = parse_commandline()

if parsed_args["output"] == ""
	parsed_args["output"] = parsed_args["default_domain"] * ".pot"
end

if !ispath(parsed_args["output_dir"])
	mkpath(parsed_args["output_dir"])
end

jgettext(parsed_args["inputfiles"], joinpath(parsed_args["output_dir"], parsed_args["output"]))
