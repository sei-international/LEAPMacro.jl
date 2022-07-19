```@meta
CurrentModule = LEAPMacro
```

# [Dynamics](@id dynamics)
In between runs of the [linear goal program](@ref lgp), the [dynamic parameters](@ref dynamic-param-vars) and [intermediate variables](@ref intermed-vars) are updated.

In the equations below, a subscript ``+1`` indicates the next-year's value, and a subscript ``-1`` the previous year's value. An underline indicates an [exogenous parameter](@ref exog-param-vars), while an overline is a [dynamic parameter](@ref dynamic-param-vars).

## [Prices](@id dynamics-prices)
For an explanation of the different prices, see [Processing the supply-use table](@ref process-sut).

World prices grow at an exogenously specified inflation rate ``\underline{\pi}_{w,k}``,
```math
    \overline{p}_{w,k,+1} = \left(1 + \underline{\pi}_{w,k}\right)\overline{p}_{w,k}.
```
By default, a uniform inflation rate is applied to all traded goods, while the real price is constant, so that ``\underline{\pi}_{w,k} = \underline{\pi}_w``. However, optionally, a real price index for an individual product ``k`` can be specified: see [real price trends for selected tradeables](@ref params-optional-price-trend).

The output price level is given by
```math
    \overline{P}_{g,+1} = \left(1 + \pi_g\right)\overline{P}_g,
```
where the inflation rate ``\pi_g`` is given by the averge of the rate of increase in basic prices, weighted by domestic supply,
```math
    \pi_g = \frac{\sum_{k = 1}^{n_p} q_{s,k}\pi_{b,k}}{\sum_{k = l}^{n_p} q_{s,l}}, \quad \pi_{b,k} = \frac{p_{b,k}-p_{b,k,-1}}{p_{b,k,-1}}.
```

The GDP deflator ``\pi_\text{GDP}`` is an index that grows at the average of the rate of increase of producers' prices weighted by the value of final demand. The value of final demand for good ``k`` is
```math
    V_k = \overline{p}_{d,k,-1}\left(F_k + X_k + I_k - M_k\right).
```
The GDP inflation rate is calculated as
```math
    \pi_\text{GDP} = \frac{\sum_{k = 1}^{n_p} V_k\pi_{d,k}}{\sum_{k = l}^{n_p} V_l}, \quad \pi_{d,k} = \frac{p_{d,k}-p_{d,k,-1}}{p_{d,k,-1}}.
```

Basic prices are a weighted average of domestic and foreign prices, with the weight given by the import fraction ``f_k``, where
```math
    f_k = \frac{M_k}{q_{d,k} + F_k + I_k}.
```
Basic prices are therefore
```math
    \overline{p}_{b,k} = f_k \underline{e}\overline{p}_{w,k} + \left(1 - f_k\right)\overline{p}_{d,k}.
```
If ``f_k = 1``, meaning the country does not produce product ``k`` and all supply is from imports, then ``\overline{p}_{b,k} = \overline{p}_{w,k}``. Otherwise, domestic prices are set as a mark-up on costs, where costs are in terms of basic prices
```math
 \overline{p}_{d,k} = \sum_{i = 1}^{n_s} \underline{\mu}_i\underline{S}_{ik}
    \left[
        \overline{P}_g\left(\omega_i + \varepsilon_i\right) + \sum_{l = 1}^{n_p} \overline{p}_{b,l} \overline{D}_{li}
    \right].
```
Together these equations lead to a linear system in domestic prices,
```math
\overline{p}_{d,k} = \overline{P}_g\sum_{i = 1}^{n_s} \underline{\mu}_i\underline{S}_{ik}\left(\omega_i + \varepsilon_i\right) + \underline{e}\sum_{l = 1}^{n_p} A_{kl} f_l \overline{p}_{w,l} + \sum_{l = 1}^{n_p} A_{kl} \left(1 - f_l\right)\overline{p}_{d,l},
```
where
```math
    A_{kl} = \sum_{i = 1}^{n_s} \underline{\mu}_i\underline{S}_{ik}\overline{D}_{li}.
```
This system is solved using linear algebra.

## Imports
The normal level of imports of good ``k`` as a fraction of domestic demand (intermediate, final, and investment) is updated based on the values calculated in the last run of the [linear goal program](@ref lgp), and then adjusted based on relative changes in world and domestic prices,
```math
\overline{f}_k = f_k \left(\frac{1 + \pi_{d,k}}{1 + \underline{\pi}_{w,k}}\right)^{\underline{\phi}^\text{imp}_k}.
```

The reference import demand, which appears as a scale factor in the [linear goal program](@ref lgp), is set equal to twice the calculated volume of imports,
```math
\overline{M}^\text{ref}_k = 2 M_k.
```
The multiple of two is somewhat arbitrary, because this simply sets a scale.

## [Wages and labor productivity](@id dynamics-wages-labor-prod)
The wage share ``\omega_i`` in sector ``i`` is defined as
```math
\omega_i = \frac{\overline{W}_i}{g_i}.
```
The wage bill ``\overline{W}_i`` is by definition equal to the wage rate ``w_i`` multiplied by sectoral employment ``L_i``, while output ``g_i`` is by definition equal to real labor productivity ``\lambda_i`` muliplied by the price level of output ``\overline{P}_g`` and sectoral employment. So, the wage share can also be written as
```math
\omega_i = \frac{w_i L_i}{\overline{P}_g\lambda_i L_i} = \frac{1}{\overline{P}_g}\frac{w_i}{\lambda_i}.
```
The model does not explicitly calculate sector-specific labor productivity, employment, or wage. Instead, it calculates growth rates for each of these parameters and assumes the growth rates hold across all sectors.

Labor productivity is assumed to rise with growth, following the Kaldor-Verdoorn law. While the Kaldor-Verdoorn coefficients vary between sectors, with a higher responsiveness in industry than services, for example, data are limited. For that reason, the Macro model calculates the growth rate of economy-wide average labor productivity,
```math
\hat{\lambda} = \underline{\alpha}_\text{KV} \hat{Y} + \underline{\beta}_\text{KV}.
```
The growth rate of total employment, ``L``, is then given (using a standard approximation) by the difference in growth rates of output and productivity,
```math
\hat{L} = \hat{Y} - \hat{\lambda} = \left(1 - \underline{\alpha}_\text{KV}\right)\hat{Y} - \underline{\beta}_\text{KV}.
```

Wages are observed to rise in a tight labor market and fall otherwise. That behavior is captured in the model through a "conflict" mechanism, which views nominal wage changes as a consequence of bargaining between parties with unequal and shifting bargaining power -- employers and employees. An exogenous input to Macro is the growth rate of the working-age population, ``\hat{\underline{N}}``. The real wage is assumed to rise faster than labor productivity when employment rises faster than the working-age population, with a proportionality factor ``\underline{k}``, and fall otherwise. The nominal wage is then equal to the real wage adjustment plus an inflation "pass-through" parameter ``\underline{h}`` multiplied by the inflation rate,
```math
\hat{w} = \underline{h}\pi_\text{GDP} + \hat{\lambda}\left[1 + \underline{k}\left(\hat{L} - \hat{\underline{N}}\right)\right].
```

With the above expressions, the growth rate of the wage share can be calculated. The growth rate is assumed to be the same in each sector,
```math
\hat{\omega}_i = \hat{w} - \hat{\lambda} - \pi_g.
```

## [Intermediate demand coefficients](@id dynamics-intermed-dmd-coeff)
By default, intermediate demand coefficients are kept at their initial values: ``\overline{D}_{ki} = \underline{D}^\text{init}_{ki}``. However, optionally, they can be endogenized through a cost share-induced technological change mechanism[^1]: see [real price trends for selected tradeables](@ref params-optional-price-trend). The growth rates of the coefficients are calculated as
```math
\hat{\overline{D}}_{ki} = C_{ki} - \frac{\underline{a}\alpha_{ki}}{\sqrt{\sum_{l=1}^{n_p} \alpha^2_{li}}},
```
where the ``C_{ki}`` are constants, set such that ``\hat{\overline{D}}_{ki} = 0`` initially, ``\underline{a}`` is a rate constant, which is specified in the [configuration file](@ref config-intermed-dmd-change), and the ``\alpha_{ki}`` are cost shares, set to be compatible with the calculation of [prices for non-tradeables](@ref dynamics-prices).

[^1]: The model is a simplified application of a more general model that is presented in [_Cost Share-induced Technological Change and Kaldor’s Stylized Facts_](https://www.sei.org/publications/cost-share-induced-technological-change-kaldors-stylized-facts/) by Eric Kemp-Benedict.

## Profit rate
Profitability is reflected in the sector profit rate at full utilization ``r_i``, which is defined as profit divided by the value of capital. Gross profit per unit of output, ``\Pi_i``, is given by the value of output per unit of output less unit costs,
```math
\Pi_i = \frac{1}{g_i}\sum_{k=1}^{n_p} \underline{S}_{i,k} q_{s,k}\overline{p}_{d,k} -
        \left[\overline{P}_g\left(\omega_i + \varepsilon_i\right) +
              \sum_{k = 1}^{n_p}\overline{p}_{d,k}\underline{D}_{k,i} \right].
```

The Macro model does not track the capital stock. The calculation for the profit rate starts with the current unit price of capital goods ``p_K``, calculated as
```math
p_K = \sum_{k=1}^{n_p}\underline{\theta}_k \overline{p}_{d,k}.
```
The profit rate is then given by profits divicded by the product of the price of capital and the capital-output ratio ``\underline{v}_i``,
```math
r_i = \frac{\Pi_i}{p_K\underline{v}_i}.
```
Capital-output ratios are initialized using a procedure described below in [Demand for investment goods](@ref dynamics-inv-dmd).

## [Potential output](@id dynamics-potential-output)
Net potential output in sector ``i`` (that is, accounting for depreciation) grows at a rate ``\gamma_i``. Unless it is overridden by an [optional exogenous potential output](@ref optional-exog-param-vars), the value is determined endogenously by an investment function that responds to utilization, profitability, and borrowing costs (proxied by the central bank lending rate). The model assumes no active disinvestment, so the net growth rate is not allowed to fall below (the negative of) the depreciation rate,
```math
\gamma_i = \max\left[\gamma_{i0} + \underline{\alpha}_\text{util}\left(u_i - 1\right) +
           \underline{\alpha}_\text{profit}\left(r_i - \underline{r}^*\right) -
           \underline{\alpha}_\text{bank}\left(i_b - \underline{i}_{b0}\right),
           -\underline{\delta}_i\right].
```
The first term ``\gamma_{i0}`` is "autonomous investment". It represents long-run expectations. The other terms make up "induced investment" due to short-term changes in utilization, profits, and borrowing costs. The target value for utilization is full utilization, ``u_i = 1``, while for the bank rate it is the neutral bank rate that enters the Taylor function, ``\underline{i}_{b0}`` (see below). The target for the profit rate, ``\underline{r}^*``, is calculated by Macro during an internal calibration step to be consistent with starting values for investment and profits, using a procedure described below in [Demand for investment goods](@ref dynamics-inv-dmd).

If potential output is specified exogenously through the variable ``\underline{z}_i^\text{exog}``, then 
```math
\gamma_i = \underline{z}_{i,+1}^\text{exog}/\underline{z}_i^\text{exog} - 1.
```

Potential output grows at the calculated rate,
```math
\overline{z}_{i,+1} = \left(1 + \gamma_i\right)\overline{z}_i.
```
Autonomous investment follows adaptive expectations, with an initial value ``\gamma_{i0} = \underline{\gamma}_0``,
```math
\gamma_{i0,+1} = \gamma_{i0} + \underline{\xi}\left(\gamma_i - \gamma_{i0}\right).
```

## [Central bank lending rate](@id dynamics-taylor-rule)
The central bank lending rate is updated through a Taylor rule of the form
```math
i_b = \underline{i}_{b0} + \underline{\rho}_Y\left(\hat{Y} - \hat{Y}^*\right) + \underline{\rho}_\pi\left(\pi_\text{GDP} - \underline{\pi}^*\right).
```
In Taylor’s original paper, the coefficients were ``i_{b0} = 2\%``/year, ``\underline{\rho}_Y = \underline{\rho}_\pi = 0.5``, but they can be set by the user in the [configuration file](@ref config-taylor-rule), together with the target inflation rate ``\underline{\pi}^*`` and a permissible band for the target GDP growth rate, ``[\hat{\underline{Y}}^*_\text{min},\hat{\underline{Y}}^*_\text{max}]``.

The initial value for the target GDP growth rate is the initial value for the autonomous investment rate, ``\hat{Y}^* = \gamma_{i0}``. It then adjusts through adaptive expectations, with the same rate of adapation as for autonomous investment, while keeping within the user-specified band,
```math
\hat{Y}^* = \min\left\{\hat{\underline{Y}}^*_\text{max}, \max\left[\hat{\underline{Y}}^*_\text{min},
                       \hat{Y}^* + \underline{\xi}\left(\hat{Y} - \hat{Y}^*\right)\right]\right\}.
```

## [Demand for investment goods](@id dynamics-inv-dmd)
Total next-period demand for investment goods ``\overline{I}_{+1}`` is given by two terms: 1) the sum across sectors of current potential output multiplied by the rate of increase in potential output plus the depreciation rate, multiplied by the capital-output ratio; 2) exogenous investment ``\underline{I}_\text{exog}`` (see [optional exogenous parameters](@ref optional-exog-param-vars) and the format for the [exogenous investment demand file](@ref params-optional-exog-investment)). That is,
```math
\overline{I}_{+1} = \sum_{i=1}^{n_s} \overline{z}_i \underline{v}_i \left(\gamma_i + \underline{\delta}_i\right) + \underline{I}_{\text{exog},+1}.
```
The total is then allocated across investment goods supply shares ``\underline{\theta}_k``.

Values for sectoral capital-output ratios ``\underline{v}_i`` and the target profit rate ``\underline{r}^*`` are calculated using the equation for investment demand combined with the expression for the profit rate. Rearranging the equation for the profit rate gives
```math
\underline{v}_i = \frac{\Pi_i}{p_K r_i}.
```
The calibration is carried out by assuming that all sectors have the same profit rate, and that it is the target profit rate, ``\underline{r}^*``, so that
```math
\underline{v}_i = \frac{\Pi_i}{p_K \underline{r}^*}.
```
Substituting this expression into the equation for investment demand and solving for ``\underline{r}^*`` gives
```math
\underline{r}^* = \frac{1}{p_K\overline{I}_{+1}}\sum_{i=1}^{n_s} \Pi_i \overline{z}_i \left(\gamma_i + \underline{\delta}_i\right)
```
The calibrated value for ``\underline{r}^*`` is found by setting ``\overline{z}_i = g_i`` and ``\gamma_i = \underline{\gamma}_0``. That value is then used to calculate capital-output ratios.

## [Export demand and final demand](@id dynamics-demand-fcns)
The normal level of export demand grows with global GDP (or gross world product, GWP) to a goods-specific elasticity, modified by the relative change in domestic and world prices,
```math
\overline{X}^\text{norm}_{k,+1} = \left(1 + \underline{\gamma}^\text{world}\right)^{\underline{\eta}^\text{exp}_k} \left(\frac{1 + \underline{\pi}_{w,k}}{1 + \pi_{d,k}}\right)^{\underline{\phi}^\text{exp}_k} \overline{X}^\text{norm}_k.
```
Normal final demand grows with the real wage bill to a goods-specific elasticity. The next-period nominal wage bill in sector ``i`` is calculated using variables and parameters introduced above,
```math
\overline{W}_{i,+1} = \frac{1 + \hat{w}}{1 + \hat{\lambda}}\left(1 + \gamma_i\right)\overline{W}_i.
```
The growth in the real wage bill is given by these factors, but corrected for inflation ``\pi_g``,
```math
\gamma^\text{wage} = \frac{1}{1 + \pi_\text{GDP}}\frac{\sum_{i=1}^{n_s}\overline{W}_{i,+1}}{\sum_{j=1}^{n_s}\overline{W}_j} - 1.
```
The updated normal household demand is then given by
```math
\overline{F}^\text{norm}_{k,+1} = \left(1 + \underline{\gamma}^\text{wage}\right)^{\underline{\eta}^\text{wage}_k}\overline{F}^\text{norm}_k.
```

After the dynamic parameters have been updated, the [linear goal program](@ref lgp) is run for the subsequent year.


