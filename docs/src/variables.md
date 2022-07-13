
```@meta
CurrentModule = LEAPMacro
```

# [Variables](@id variables)
The Macro model contains three types of variables:
  * The [goal program variables](@ref lgp-vars) are solved in each time step (equal to one year) using a [linear goal program](@ref lgp).
  * The [dynamic parameters](@ref dynamic-param-vars) appear as parameters the goal program, but are updated between runs. They are shown with an overline to make them easier to identify in the equations.
  * As the dynamic parameters are calculated, additional [intermediate variables](@ref intermed-vars) are introduced to simplify the equations.
In addition to model variables, there are [exogenous parameters](@ref exog-param-vars), which might or might not change over time. They are shown with an underline to make them easier to identify in the equations. Some "exogenous" parameters, such as the target profit rate ``\underline{r}^*``, are in fact calculated from a combination of initial values and exogenous parameters, but are then held fixed.

Variables and parameters are labeled with the following dimensions:

| Symbol       | Definition                                          | 
|:-------------| :---------------------------------------------------|
| ``n_s``      | Number of sectors                                   |
| ``n_p``      | Number of products                                  |
| ``i``, ``j`` | Sector indices, taking values from ``1\ldots n_s``  |
| ``k``, ``l`` | Product indices, taking values from ``1\ldots n_p`` |

## [Goal program variables](@id lgp-vars)
| Symbol             | Definition                                                                                                                     |
|:-------------------|:-------------------------------------------------------------------------------------------------------------------------------|
| ``u_i``            | Capacity utilization in sector ``i``                                                                                           |
| ``\Delta u_i``     | Gap between full and realized utilization in sector ``i``                                                                      |
| ``s_{X,k}``        | Exports relative to the normal level for product ``k``                                                                         |
| ``\Delta s_{X,k}`` | Gap between normal and realized exports as a share for product ``k``                                                           |
| ``s_{F,k}``        | Final demand (household and government combined) relative to the normal level for product ``k``                                |
| ``\Delta s_{F,k}`` | Gap between normal and realized final demand as a share for product ``k``                                                      |
| ``\psi^\pm_k``     | Import excess ``(+)`` or deficit ``(-)`` relative to the normal level as a multiplier on the reference level for product ``k`` |
| ``X_k``            | Exports of product ``k``                                                                                                       |
| ``F_k``            | Final demand for product ``k``                                                                                                 |
| ``I_k``            | Investment demand for product ``k``                                                                                            |
| ``M_k``            | Imports of product ``k``                                                                                                       |
| ``q_{s,k}``        | Domestic production of product ``k``                                                                                           |
| ``q_{d,k}``        | Intermediate demand for product ``k``                                                                                          |
| ``m^\pm_k``        | Positive ``(+)`` and negative ``(-)`` margins for product ``k``                                                                |

## [Dynamic parameters](@id dynamic-param-vars)
| Symbol                         | Definition                                                                                                   |
|:-------------------------------|:-------------------------------------------------------------------------------------------------------------|
| ``\overline{z}_i``             | Potential output for sector ``i``                                                                            |
| ``\overline{W}_i``             | Nominal wage bill in sector ``i``                                                                            |
| ``\overline{p}_{b,k}``         | Basic price for product ``k`` as an index relative to the initial year                                       |
| ``\overline{P}_g``             | Price level of output as an index relative to the initial year                                               |
| ``\overline{I}``               | Demand for investment goods                                                                                  |
| ``\overline{X}^\text{norm}_k`` | Normal level of export demand for product ``k``                                                              |
| ``\overline{F}^\text{norm}_k`` | Normal level of final demand for product ``k``                                                               |
| ``\overline{M}^\text{ref}_k``  | Reference level of imports for product ``k``                                                                 |
| ``\overline{f}_k``             | Normal level of imports of good ``k`` as a fraction of domestic demand (intermediate, final, and investment) |
| ``\overline{p}_{d,k}``         | Producer price for product ``k`` as an index relative to the initial year                                    |
| ``\overline{p}_{w,k}``         | World price index for product ``k``                                                                          |
| ``\overline{D}_{ki}``          | Intermediate demand for product ``k`` per unit of output from sector ``i``                                   |

## [Intermediate variables](@id intermed-vars)
| Symbol                 | Definition                                                                                    |
|:-----------------------|:----------------------------------------------------------------------------------------------|
| ``g_i``                | Total output from sector ``i``                                                                |
| ``\hat{Y}``            | Real GDP growth rate                                                                          |
| ``\pi_\text{GDP}``     | Inflation rate for the GDP price level                                                        |
| ``\pi_{b,k}``          | Basic price inflation rate for product ``k``                                                  |
| ``\pi_{d,k}``          | Producer price inflation rate for product ``k``                                               |
| ``V_k``                | Value of total final demand (household, government, exports,and investment) for product ``k`` |
| ``\hat{L}``            | Growth rate of employment                                                                     |
| ``\hat{w}``            | Growth rate of the nominal wage                                                               |
| ``\hat{\lambda}``      | Growth rate of labor productivity                                                             |
| ``\omega_i``           | Wage share in sector ``i``                                                                    |
| ``\gamma_i``           | Rate of net investment demand in sector ``i``                                                 |
| ``\gamma_{i0}``        | The autonomous (smoothed) component of the rate of net investment demand in sector ``i``      |
| ``i_b``                | Central bank interest rate                                                                    |
| ``r_i``                | Gross rate of profit in sector ``i``                                                          |
| ``\Pi_i``              | Gross profits in sector ``i``                                                                 |
| ``\gamma^\text{wage}`` | Growth rate of the total wage bill                                                            |

## [Exogenous parameters](@id exog-param-vars)
| Symbol                               | Definition                                                                                                                          |
|:-------------------------------------|:------------------------------------------------------------------------------------------------------------------------------------|
| ``\underline{w}_u``                  | In the [linear goal program](@ref lgp), the category weight penalizing low utilization                                              |
| ``\underline{w}_F``                  | In the [linear goal program](@ref lgp), the category weight penalizing departure from normal final demand                           |
| ``\underline{w}_X``                  | In the [linear goal program](@ref lgp), the category weight penalizing departure from normal exports                                |
| ``\underline{w}_M``                  | In the [linear goal program](@ref lgp), the category weight penalizing imports over domestic supply                                 |
| ``\underline{\sigma}^u_i``           | Sector weight for utilization for sector ``i``                                                                                      |
| ``\underline{\sigma}^X_k``           | Product weight for exports for product ``k``                                                                                        |
| ``\underline{\sigma}^F_k``           | Product weight for final consumption demand for product ``k``                                                                       |
| ``\underline{\varphi}_u``            | For utilization sector weights, weight of value share vs. constant share                                                            |
| ``\underline{\varphi}_F``            | For final demand sector weights, weight of value share vs. constant share                                                           |
| ``\underline{\varphi}_X``            | For export sector weights, weight of value share vs. constant share                                                                 |
| ``\underline{S}_{ik}``               | Sector ``i``'s share of domestic production of product ``k``                                                                        |
| ``\underline{D}^\text{init}_{ki}``   | Initial value for intermediate demand for product ``k`` per unit of output from sector ``i``                                         |
| ``\underline{d}_k``                  | Equal to ``\underline{d}_k = 1`` if the country does _not_ produce product ``k`` and  ``\underline{d}_k = 0`` if it does produce it |
| ``\underline{e}``                    | Exchange rate                                                                                                                       |
| ``\underline{\pi}_{w,k}``            | Inflation rate for the world price of product ``k`` (currently the same across all products)                                        |
| ``\underline{\tau}_{d,k}``           | Tax rate on domestic supply of product ``k``                                                                                        |
| ``\underline{\mu}_i``                | Profit margin in sector ``i`` over total costs                                                                                      |
| ``\underline{\alpha}_\text{KV}``     | Kaldor-Verdoorn law coefficient                                                                                                     |
| ``\underline{\beta}_\text{KV}``      | Kaldor-Verdoorn law intercept                                                                                                       |
| ``\underline{h}``                    | Inflation pass-through from the price of goods to the increase in the nominal wage                                                  |
| ``\underline{k}``                    | Response of the real wage to labor supply constraints                                                                               |
| ``\underline{\hat{N}}``              | Growth rate of the working-age population                                                                                           |
| ``\underline{\chi}^\pm_k``           | Allocation coefficients for positive ``(+)`` and negative ``(-)`` margins for product ``k``                                         |
| ``\underline{\xi}``                  | Rate of adjustment of autonomous demand to realized growth rate                                                                     |
| ``\underline{i}_{b0}``               | Central bank interest rate when GDP growth and inflation are at their targets                                                       |
| ``\underline{\rho}_Y``               | Taylor coefficient on the GDP growth rate                                                                                           |
| ``\underline{\rho}_\pi``             | Taylor coefficient on the inflation rate                                                                                            |
| ``\hat{\underline{Y}}^*_\text{min}`` | Taylor rule minimum target growth rate                                                                                              |
| ``\hat{\underline{Y}}^*_\text{max}`` | Taylor rule maximum target growth rate                                                                                              |
| ``\underline{\pi}^*``                | Taylor rule target inflation rate                                                                                                   |
| ``\underline{\gamma}_0``             | Initial autonomous investment rate in the investment function                                                                       |
| ``\underline{\alpha}_\text{util}``   | Change in induced investment from a change in utilization (utilization investment sensitivity)                                      |
| ``\underline{\alpha}_\text{profit}`` | Change in induced investment from a change in profit rate (profit rate investment sensitivity)                                      |
| ``\underline{\alpha}_\text{bank}``   | Change in induced investment from a change in borrowing costs (interest rate investment sensitivity)                                |
| ``\underline{r}^*``                  | Target rate of gross profit (in the investment function)                                                                            |
| ``\underline{\delta}_i``             | Depreciation rate for sector ``i``                                                                                                  |
| ``\underline{v}_i``                  | Capital-output ratio in sector ``i``                                                                                                |
| ``\underline{\theta}_k``             | Share of product ``k`` in the total supply of investment goods                                                                      |
| ``\underline{\gamma}^\text{world}``  | Growth rate of world GDP (also termed gross world product, GWP)                                                                     |
| ``\underline{\eta}^\text{exp}_k``    | Elasticity of normal export demand for product ``k`` with respect to a change in GWP                                                |
| ``\underline{\eta}^\text{wage}_k``   | Elasticity of normal final demand for product ``k`` with respect to a change in the wage bill                                       |

The following are [optional exogenous parameters](@id optional-exog-param-vars):

| Symbol                          | Definition                                                                                                                                                                          |
|:--------------------------------|:------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| ``\underline{I}_\text{exog}``   | Exogenous investment, not associated with a sector (default is 0.0)                                                                                                                 |
| ``\underline{z}_i^\text{exog}`` | Exogenously specified potential output (default is that Macro calculates potential output)                                                                                          |
| ``\underline{u}_i^\text{max}``  | In the [linear goal program](@ref lgp), the maximum capacity utilization (default is 1.0)                                                                                           |
| ``\underline{A}``               | Rate constant for endogenous intermediate demand coefficients (default is ``\overline{D}_{ki} = \underline{D}^\text{init}_{ki}``) |
