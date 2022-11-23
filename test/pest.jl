using YAML
using ArgParse

function parse_commandline()
    argp = ArgParseSettings(autofix_names = true)
    @add_arg_table! argp begin
        "config-file"
            help = "name of LEAP-Macro config file"
            arg_type = AbstractString
            default = "LEAPMacro_params.yml"
            required = false
        "--pest-config-file", "-p"
            help = "name of PEST config file"
            arg_type = AbstractString
            default = "pest_config.yml"
            required = false
        "--control-file", "-c"
            help = "name to assign the control file"
            arg_type = AbstractString
            default = "LEAPMacro_control.pst"
            required = false
    end

    return parse_args(argp)
end

"Check whether a Dict has a key and that the value is not `nothing`"
function haskeyvalue(d::Dict, k::Any)
    return haskey(d,k) && !isnothing(d[k])
end # haskeyvalue

function delim_param(param_name, params, delimiter, width)
    if !haskey(params, param_name)
        throw(ErrorException("Parameter name '" * param_name * "' is not in the list of parameters [" * join(keys(params),", ") * "]"))
    end
    if length(param_name) > 12 # This is PEST's maximum length for a parameter name
        throw(ErrorException("Parameter name '" * param_name * "' exceeds maximum of 12 characters"))
    end
    return(delimiter * param_name * repeat(" ", width - length(param_name)) * delimiter)
end

function val_or_delim(val, params, delimiter, width)
    return(isa(val, String) ? delim_param(val, params, delimiter, width) : string(val))
end

function writeline(io, args...)
    write(io, " " * join(args, " ") * "\r\n")
end

function writehdr(io, secname)
    write(io, "* " * secname * "\r\n")
end

function padfield(s, fieldwidth)
    return s * repeat(" ", fieldwidth - length(s))
end

"Convert config file (YAML) to basename for template and result file"
function cfg2basename(cfg_name)
    return(splitext(cfg_fname)[1] * "_calib")
end

function write_template_file(pest_opts, cfg_fname)
    tpl_fname = cfg2basename(cfg_fname) * ".tpl"

    pest_params = pest_opts["pest"]["parameters"]
    params = pest_opts["LEAP-Macro"]["config"]
    # Insert a new entry to rewrite years
    params["years"] = Dict("start" => pest_opts["pest"]["calibration"]["years"][1],
                           "end" => pest_opts["pest"]["calibration"]["years"][2])
    delim = pest_opts["pest"]["delimiter"]
    # From PEST documentation (p. 66)
    #  Single precision values will never be greater than 13 characters in length;
    #  The maximum double precision value length is 23 characters
    width = lowercase(pest_opts["pest"]["precision"]) == "single" ? 13 : 23

    re_mainkey = r"^[A-Za-z0-9_\-]+(?=:)"
    # Note that this will uncomment a paramter if it is commented out in the config file
    re_subkey = r"^(\s+)(#\s*)?([A-Za-z0-9_\-]+(?=:)):\s*(.*)"

    tpl_hdnl = open(tpl_fname, "w")
    write(tpl_hdnl, "ptf " * delim * "\r\n")

    sub_params = []
    level = 0
    curr_indent = 0
    open(cfg_fname) do io
        for line in eachline(io, keep=true) # keep so the new line isn't chomped
            if occursin(re_mainkey, line)
                curr_mainkey = match(re_mainkey, line).match
                if curr_mainkey == "output_folder"
                    write(tpl_hdnl, "output_folder: " * pest_opts["LEAP-Macro"]["output_folder"] * "\r\n")
                    continue
                elseif haskeyvalue(params, curr_mainkey)
                    sub_params = [params[curr_mainkey]]
                else
                    sub_params = []
                end
            end
            if length(sub_params) > 0 && occursin(re_subkey, line)
                subkey_captures = match(re_subkey, line).captures
                subkey_indent = length(subkey_captures[1])
                if subkey_indent > curr_indent
                    level += 1
                elseif subkey_indent < curr_indent
                    level -= 1
                    pop!(sub_params)
                end
                curr_subkey = subkey_captures[3]
                subkey_value = subkey_captures[4]
                if  haskeyvalue(sub_params[end], curr_subkey)
                    if isa(sub_params[end][curr_subkey], Dict)
                        if level == 0
                            push!(sub_params, params[curr_subkey])
                        else
                            push!(sub_params, sub_params[end][curr_subkey])
                        end
                    else
                        # Replace the line with parameter
                        curr_val = sub_params[end][curr_subkey]
                        if isa(curr_val, Vector)
                            val_string =  "[" * join([val_or_delim(e, pest_params, delim, width) for e in curr_val], ",") * "]"
                        else
                            val_string = val_or_delim(curr_val, pest_params, delim, width)
                        end
                        # Save the current value by adding as a comment
                        line = repeat(" ", subkey_indent) * curr_subkey * ": " * val_string * " # " * strip(string(subkey_value)) * "\r\n"
                    end
                end
            end
            write(tpl_hdnl, line)
        end
    end
    close(tpl_hdnl)
end

function write_instruction_files(pest_opts)
    y_init = pest_opts["pest"]["calibration"]["years"][1]
    y_fin = pest_opts["pest"]["calibration"]["years"][2]
    for (ogname, ogval) in pest_opts["pest"]["calibration"]["results"]
        colspec = repeat(" @,@", ogval["column"] - 1)
        open(ogname * ".ins", "w") do io
            write(io, "pif @\r\n")
            prevyear = y_init - 2 # Do this because the year is in the first column
            for (year, obs) in sort(collect(ogval["observations"]), by=x->x[1])
                if year < y_init
                    throw(ErrorException("Observation year " * string(year) * " is before the initial year " * string(y_init)))
                end
                if year > y_fin
                    throw(ErrorException("Observation year " * string(year) * " is after final year " * string(y_fin)))
                end
                write(io, "l" * string(year - prevyear) * colspec * " !" * lowercase(ogname) * string(year) * "!\r\n")
                prevyear = year
            end
        end
    end
end

function write_control_file(pest_opts, ctrl_fname, cfg_fname)
    ctrl_hdnl = open(ctrl_fname, "w")
    write(ctrl_hdnl, "pcf\r\n")
    #-------------------------
    # Control data section
    #-------------------------
    # Line 1
    writehdr(ctrl_hdnl, "control data")
    # Line 2
    # RSTFLE PESTMOD
    if pest_opts["pest"]["allow_restart"]
        write(ctrl_hdnl, "restart estimation\r\n")
    else
        write(ctrl_hdnl, "norestart estimation\r\n")
    end
    # Line 3
    # NPAR NOBS NPARGP NPRIOR NOBSGP [MAXCOMPDIM] [DERZEROLIM]
    NPAR = length(pest_opts["pest"]["parameters"])
    NOBS = sum([length(v["observations"]) for (k,v) in pest_opts["pest"]["calibration"]["results"]])
    NPARGP = NPAR
    NPRIOR = 0
    NOBSGP = length(pest_opts["pest"]["calibration"]["results"])
    writeline(ctrl_hdnl, NPAR, NOBS, NPARGP, NPRIOR, NOBSGP)
    # Line 4
    # NTPLFLE NINSFLE PRECIS DPOINT [NUMCOM JACFILE MESSFILE] [OBSREREF]
    NTPLFLE = 1
    NINSFILE = NOBSGP
    PRECIS = lowercase(pest_opts["pest"]["precision"])
    DPOINT = "point"
    NUMCOM = 1
    JACFILE = 0
    MESSFILE = 0
    writeline(ctrl_hdnl, NTPLFLE, NINSFILE, PRECIS, DPOINT, NUMCOM, JACFILE, MESSFILE)
    # Line 5
    # RLAMBDA1 RLAMFAC PHIRATSUF PHIREDLAM NUMLAM [JACUPDATE] [LAMFORGIVE] [DERFORGIVE]
    RLAMBDA1 = 10.0
    RLAMFAC = 2.0
    PHIRATSUF = 0.3
    PHIREDLAM = 0.03
    NUMLAM = 10
    LAMFORGIVE = "lamforgive"
    DERFORGIVE = "derforgive"
    writeline(ctrl_hdnl, RLAMBDA1, RLAMFAC, PHIRATSUF, PHIREDLAM, NUMLAM, LAMFORGIVE, DERFORGIVE)
    # Line 6
    # RELPARMAX FACPARMAX FACORIG [IBOUNDSTICK UPVECBEND] [ABSPARMAX]
    RELPARMAX = 10.0
    FACPARMAX = 10.0
    FACORIG = 0.001
    writeline(ctrl_hdnl, RELPARMAX, FACPARMAX, FACORIG)
    # Line 7
    # PHIREDSWH [NOPTSWITCH] [SPLITSWH] [DOAUI] [DOSENREUSE] [BOUNDSCALE]
    PHIREDSWH = 0.1
    writeline(ctrl_hdnl, PHIREDSWH)
    # Line 8
    # NOPTMAX PHIREDSTP NPHISTP NPHINORED RELPARSTP NRELPAR [PHISTOPTHRESH] [LASTRUN] [PHIABANDON]
    NOPTMAX = pest_opts["pest"]["max_iterations"]
    PHIREDSTP = 0.005
    NPHISTP = 4
    NPHINORED = 3
    RELPARSTP = 0.005
    NRELPAR = 4
    writeline(ctrl_hdnl, NOPTMAX, PHIREDSTP, NPHISTP, NPHINORED, RELPARSTP, NRELPAR)
    # Line 9
    # ICOV ICOR IEIG [IRES] [JCOSAVE] [VERBOSEREC] [JCOSAVEITN] [REISAVEITN] [PARSAVEITN] [PARSAVERUN]
    ICOV = 1
    ICOR = 1
    IEIG = 1
    IRES = 0
    writeline(ctrl_hdnl, ICOV, ICOR, IEIG, IRES)
    #-------------------------
    # SVD section
    #-------------------------
    # Line 1
    writehdr(ctrl_hdnl, "singular value decomposition")
    # Line 2
    # SVDMODE
    SVDMODE = 1
    writeline(ctrl_hdnl, SVDMODE)
    # Line 2
    # MAXSING EIGTHRESH
    MAXSING = NPAR
    EIGTHRESH = 5.0e-7
    writeline(ctrl_hdnl, MAXSING, EIGTHRESH)
    # Line 3
    # EIGWRITE
    EIGWRITE = 0
    writeline(ctrl_hdnl, EIGWRITE)
    #-------------------------
    # Parameter groups section
    #-------------------------
    # Line 1
    writehdr(ctrl_hdnl, "parameter groups")
    # Lines 2...
    # PARGPNME INCTYP DERINC DERINCLB FORCEN DERINCMUL DERMTHD
    INCTYP = "relative"
    DERINC = 0.01
    DERINCLB = 0.0
    FORCEN = "switch"
    DERINCMUL = 2.0
    DERMTHD = "parabolic"
    param_field_width = maximum([length(p) for p in keys(pest_opts["pest"]["parameters"])]) + 1
    for p in keys(pest_opts["pest"]["parameters"])
        PARGPNME = padfield(p, param_field_width)
        writeline(ctrl_hdnl, PARGPNME, INCTYP, DERINC, DERINCLB, FORCEN, DERINCMUL, DERMTHD)
    end
    #-------------------------
    # Parameter data section
    #-------------------------
    # Line 1
    writehdr(ctrl_hdnl, "parameter data")
    # Lines 2...
    # PARNME PARTRANS PARCHGLIM PARVAL1 PARLBND PARUBND PARGP SCALE OFFSET DERCOM
    for (p, vals) in pest_opts["pest"]["parameters"]
        PARNME = padfield(p, param_field_width)
        PARGP = p
        PARTRANS = "none"
        PARCHGLIM = "relative"
        PARVAL1 = vals[2]
        PARLBND = vals[1]
        PARUBND = vals[3]
        SCALE = 1.0
        OFFSET = 0.0
        DERCOM = 1
        writeline(ctrl_hdnl, PARNME, PARTRANS, PARCHGLIM, PARVAL1, PARLBND, PARUBND, PARGP, SCALE, OFFSET, DERCOM)
    end
    #-------------------------
    # Observation groups section
    #-------------------------
    # Line 1
    writehdr(ctrl_hdnl, "observation groups")
    # Lines 2...
    # OBGNME [GTARG] [COVFLE]
    for OBGNAME in keys(pest_opts["pest"]["calibration"]["results"])
        writeline(ctrl_hdnl, OBGNAME)
    end
    #-------------------------
    # Observation data section
    #-------------------------
    # Line 1
    writehdr(ctrl_hdnl, "observation data")
    # Lines 2...
    # OBSNME OBSVAL WEIGHT OBGNME
    for (OBGNME, obgrp) in pest_opts["pest"]["calibration"]["results"]
        for (year, obs) in sort(collect(obgrp["observations"]), by=x->x[1])
            OBSNME = lowercase(OBGNME) * string(year)
            OBSVAL = obs[1]
            WEIGHT = obs[2]
            writeline(ctrl_hdnl, OBSNME, OBSVAL, WEIGHT, OBGNME)
        end
    end
    #-------------------------
    # Model command line
    #-------------------------
    tpl_fname = cfg2basename(cfg_fname) * ".tpl"
    yml_fname = cfg2basename(cfg_fname) * ".yml"
    # Line 1
    writehdr(ctrl_hdnl, "model command line")
    # Line 2
    julia_settings = pest_opts["LEAP-Macro"]["julia"]
    cmdline = [julia_settings["command"], julia_settings["script"], yml_fname, "-c", "-e"]
    if haskeyvalue(julia_settings, "resume_if_error") && julia_settings["resume_if_error"] push!(cmdline, "-r") end
    if haskeyvalue(julia_settings, "verbose_errors") && julia_settings["verbose_errors"] push!(cmdline, "-v") end
    if haskeyvalue(julia_settings, "sleep") push!(cmdline, "-s " * string(julia_settings["sleep"])) end
    datafnames = []
    for obgrp in values(pest_opts["pest"]["calibration"]["results"])
        union!(datafnames, [obgrp["filename"]])
    end
    push!(cmdline, "-d " * join(datafnames, " "))
    write(ctrl_hdnl, join(cmdline, " ") * "\r\n")
    #-------------------------
    # Model input/output
    #-------------------------
    # Line 1
    writehdr(ctrl_hdnl, "model input/output")
    # Line 2
    write(ctrl_hdnl, join([tpl_fname, yml_fname], " ") * "\r\n")
    for (ogname, ogval) in pest_opts["pest"]["calibration"]["results"]
        write(ctrl_hdnl, join([ogname * ".ins", ogval["filename"]], " ") * "\r\n")
    end
    #-------------------------
    # Prior information (empty)
    #-------------------------
    # Line 1
    writehdr(ctrl_hdnl, "prior information")

    close(ctrl_hdnl)
end

function run_pestchk(pest_opts; suppress_warnings = false)
    pestchek_path = joinpath(pest_opts["pest"]["program_path"], "pestchek.exe")
    try
        if suppress_warnings
            run(`$pestchek_path $ctrl_fname /s`)
        else
            run(`$pestchek_path $ctrl_fname`)
        end
    catch e
        exit()
    end
    return(true)
end

function run_pest(pest_opts)
    pest_path = joinpath(pest_opts["pest"]["program_path"], "pest.exe")
    try
        run(`$pest_path $ctrl_fname`)
    catch e
        exit()
    end
    return(true)
end

#--------------------------------------------------------------------------
#
# Generate PEST files
#
#--------------------------------------------------------------------------
args = parse_commandline()
pest_opts = YAML.load_file(args["pest_config_file"])

if !isfile(joinpath(pest_opts["pest"]["program_path"], "pest.exe"))
    throw(ErrorException("The PEST executable 'pest.exe' was not found in folder '" * pest_opts["pest"]["program_path"] *
                         "': check 'pest' => 'program_path' in '" * args["pest_config_file"] * "'"))
end

cfg_fname = args["config_file"]
ctrl_fname = args["control_file"]

println("Generating PEST template file...")
write_template_file(pest_opts, cfg_fname)
println("Generating PEST instruction file(s)...")
write_instruction_files(pest_opts)
println("Generating PEST control file...")
write_control_file(pest_opts, ctrl_fname, cfg_fname)
println("Checking files...")
chk = run_pestchk(pest_opts)
if chk
    println("Running PEST...")
    res = run_pest(pest_opts)
end
