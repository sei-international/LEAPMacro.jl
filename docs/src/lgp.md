```@meta
CurrentModule = LEAPMacro
```

# [Linear goal program](@id lgp)
For the list of variables, their symbols, and their definitions, see the [Variables](@ref variables) page.

The Macro model solves, in each year, a linear goal program (LGP) that seeks the following objectives:
1. Full utilization
2. Meeting normal final demand
3. Meeting normal export demand
4. Minimizing imports
Objectives 1-3 are expressed in terms of a gap between a target level and the modeled level. Objective 4 is expressed in terms of excess imports over base-year levels. All goal variables are scaled so that they take values between zero and one.

Specifically, the objective function is
```math
\min \underline{w}_u\sum_{i = 1}^{n_s} \underline{\sigma}^u_i\Delta u_i +
     \underline{w}_X\sum_{k = 1}^{n_p} \underline{\sigma}^K_k\Delta s_{X,k} +
     \underline{w}_F\sum_{k = 1}^{n_p} \underline{\sigma}^F_k\Delta s_{F,k} +
     \underline{w}_M\sum_{k = 1}^{n_p} \left(\psi^+_k + \psi^-_k\right).
```
!!! note "Sector and product specific weights vs. category weights"
    In the objective function, there are four "category weights", ``\underline{w}_u``, ``\underline{w}_X``, ``\underline{w}_F``, and ``\underline{w}_M``. The category weights are specified in the [configuration file](@ref config-lgp-weights).
    
    In addition, there are sector or product-specific weights for for utilization, exports, and final demand, but not for imports. The reason is that while weights are needed to capture the relative importance of certain goods in output, the export basket, and household final demand, import flexibility simply allows for demand to be met when domestic production is insufficient, a consideration that does not privilege one sector over another.
    
    The sector or product weights are given as weighted average of two possible weighting schemes: the base-year shares of the different sectors or products in output (for utilization), exports, or final demand, or equal weights. The allocations between the two possible weighting schemes are specified by the product and sector weight parameters ``\underline{\varphi}_u``, ``\underline{\varphi}_X``, and ``\underline{\varphi}_F``, which are also set in the [configuration file](@ref config-lgp-weights).

When the `report-diagnostics` parameter is set to `true` in the [configuration file](@ref config-general-settings), Macro will export the structure of the LGP for each year. The output looks something like this:
```
Min 1.7333333333333334 ugap[1] + 0.5333333333333333 ugap[2] + 0.6000000000000001 ugap[3] + ...
Subject to
 eq_util[1] : ugap[1] + u[1] == 1.0
 eq_util[2] : ugap[2] + u[2] == 1.0
 eq_util[3] : ugap[3] + u[3] == 1.0
 eq_util[4] : ugap[4] + u[4] == 1.0
...
```
Each equation is labeled, for example by `eq_util`. For reference, for each equation listed below, the label is provided along with a motivation and a mathematical expression.

## Domestic goods market equilibrium
`eq_totsupply`: Equilibrium in the domestic goods market is met when domestic supply equals total demand (the sum of final demand and demand for intermediate goods, exports, and investment goods), net of imports, and corrected by margins. This is enforced by the condition
```math
q_{s,k} = q_{d,k} - m^+_k + m^-_k + X_k + F_k + I_k - M_k
```

`eq_no_dom_prod`: If the country does not produce a particular product, `k`, then ``q_{s,k}`` must equal zero. This is enforced by the condition
```math
q_{s,k}\underline{d}_k = 0.
```

## Supply of intermediate goods
`eq_intdmd`: Intermediate goods are required for production and are given by technical coefficients (the input-output relationships). Intermediate demand is determined by
```math
q_{d,k} - \sum_{i = 1}^{n_s} \underline{D}_{ki}\overline{z}_i u_i = 0.
```

## Capacity utilization
`eq_io`: A core equation determines capacity utilization. It states that the value of domestic supply equals the value of domestic production:
```math
\sum_{k=1}^{n_p} \underline{S}_{ik} \overline{p}_{b,k}q_{s,k} - \overline{P}_g\overline{z}_i u_i = 0.
```
`eq_util`: Deviations in utilization for sector ``i`` below the target value of ``u_i = 1`` are penalized in the goal program. The deviation variable is calculated by imposing the condition
```math
u_i + \Delta u_i = 1,\quad 0 \leq u_i,\Delta u_i \leq 1.
```

## Investment goods allocation
`eq_inv_supply`: Total investment ``\overline{I}`` is supplied by a variety of sectors with shares ``\theta_k``. This is enforced by the condition
```math
I_k = \underline{\theta}_k \overline{I}.
```

## Final demand
`eq_F`: Final demand is expressed as a multiple of the normal level,
```math
F_k = s_{F,k} \overline{F}^\text{norm}_k.
```
`eq_fshare`: The multiplier satsifies
```math
s_{F,k} + \Delta s_{F,k} = 1, \quad 0\leq s_{F,k}, \Delta s_{F,k} \leq 1.
```

## Trade
`eq_X`: As with final demand, exports are expressed as a multiple of the normal level,
```math
X_k = s_{X,k} \overline{X}^\text{norm}_k.
```
`eq_xshare`: The multiplier satsifies
```math
s_{X,k} + \Delta s_{X,k} = 1, \quad 0\leq s_{X,k}, \Delta s_{X,k} \leq 1.
```

`eq_M`: Imports are given by a multiplier applied to total domestic demand, plus a possible deviation:
```math
M_k = \overline{f}_k\left(q_{d,k} + F_k + I_k\right) + \left(\psi^+_k - \psi^-_k\right) \overline{M}^\text{ref}_k.
```

## Margins
`eq_margpos`: Positive margins are a fraction of total supply (domestic plus imports),
```math
m^+_k = \underline{\chi}^+_k \left(q_{s,k} + M_k\right).
```
`eq_margneg`: They are allocated across products that correspond to the supply of those goods,
```math
m^-_k = \underline{\chi}^-_k \sum_{l = 1}^{n_p} m^+_l.
```

