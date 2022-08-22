```@meta
CurrentModule = LEAPMacro
```
# [Installing LEAP-Macro](@id installation)

LEAP-Macro is installed via GitHub. You must first have a working [Julia](https://julialang.org/downloads/) installation on your computer. **The LEAP-Macro team has verified LEAP-Macro's compatibility with Julia 1.6; other versions of Julia may not work correctly.**

Once Julia is set up, start a Julia session and add the LEAP-Macro package (named `LEAPMacro`):

```
julia> ]

pkg> add https://github.com/sei-international/LEAPMacro.jl/releases/latest
```
This will install the latest official release of the LEAP-Macro code from GitHub. To get the latest code in development, use the following command:
```
julia> ]

pkg> add https://github.com/sei-international/LEAPMacro.jl
```

To update to the newest code after LEAP-Macro is installed, use `update`:
```
julia> ]

pkg> update LEAPMacro
```
