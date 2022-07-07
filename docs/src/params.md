```@meta
CurrentModule = LEAPMacro
```

# [External parameter files](@id params)
External parameters that are specified for all products, all sectors, or over time, are supplied in three comma-separated variable (CSV) files in the `inputs` folder. The files provided with the Freedonia sample model have the names `product_parameters.csv`, `sector_parameters.csv`, and `time_series.csv`. However, the names are set in the configuration file's [general settings](@ref config-general-settings). That means that different external parameter files can be used for different scenarios.

!!! info "Comma-separated variable (CSV) files"
    CSV-formatted files are plain text files that can be viewed in a text editor. They can also be opened and modified in Excel, Google Sheets, or other spreadsheet program, which is a convenient way to edit them. 

## Product parameters
The product parameters file has the structure shown below, where ``n_p`` is the number of products. The first two columns are the product codes and product names. These should be in the same order as the products in the [supply-use tables](@ref sut).

The next two columns are numbers giving the initial elasticities for export demand (with respect to global GDP) and final demand (with respect to total wages). For details, see the page on [model dynamics](@ref dynamics-demand-fcns) and on the [configuration file](@ref config-longrun-demand-elast).

Elasticities can be estimated from historical data, although that requires knowledge of statistical methods. Otherwise, they can be drawn from reported estimates or from already existing economic models.

| `code`      | `name`       | `export_elast_demand0` | `wage_elast_demand0` |
|:------------|:-------------|-----------------------:|---------------------:|
| CODE1       | Name 1       |                   xe_1 |                 we_1 |
| CODE2       | Name 2       |                   xe_2 |                 we_2 |
| ...         | ...          |                    ... |                  ... |
| CODE``n_p`` | Name ``n_p`` |            xe_ ``n_p`` |          we_ ``n_p`` |

The corresponding [variables](@ref exog-param-vars) are:
  * `export_elast_demand0` : the initial value for ``\underline{\eta}^\text{exp}_k`` for product ``k``
  * `wage_elast_demand0` : the initial value for ``\underline{\eta}^\text{wage}_k`` for product ``k``

Here is the example from the Freedonia sample model:
![Freedonia product_parameters file](assets/images/product_parameters.png)

## Sector parameters
The structure of the sector parameters file is shown below, where ``n_s`` is the number of sectors. It contains only a single parameter for each sector, the depreciation rate. Where available, this can be calculated from national statistics. Otherwise, the `delta` parameter reported for the whole economy in the [Penn World Table](https://www.rug.nl/ggdc/productivity/pwt/) can be applied to each sector.

| `code`      | `name`       | `depr_rate` |
|:------------|:-------------|------------:|
| CODE1       | Name 1       |        dr_1 |
| CODE2       | Name 2       |        dr_2 |
| ...         | ...          |         ... |
| CODE``n_s`` | Name ``n_s`` | dr_ ``n_s`` |

The corresponding [variable](@ref exog-param-vars) is:
  * `depr_rate` : ``\underline{\delta}_i`` for sector ``i``

Here is the example from the Freedonia sample model:
![Freedonia sector_parameters file](assets/images/sector_parameters.png)

## Time series
The structure of the time series file is shown below. It contains several parameters: the world growth rate, the world inflation rate, the growth rate of the working-age population, the exchange rate, and parameters for the [labor productivity calculation](@ref dynamics-wages-labor-prod).

Scenarios for the world economic growth rate can be drawn from other studies, such as the [Shared Socioeconomic Pathways (SSP) database](https://tntcat.iiasa.ac.at/SspDb/dsd?Action=htmlpage&page=about). The working age growth rate can be calculated from national projections or the [UN Population Prospects database](https://population.un.org/wpp/Download/Standard/Population/).

Other parameters have less well-established sources of estimates. The labor productivity parameters (the Kaldor-Verdoorn parameters `KV_coeff` and `KV_intercept`) might well be assumed constant, possibly estimated from historical data or drawn from studies such as [Estimating Kaldor-Verdoorn’s law across countries in different stages of development](https://www.anpec.org.br/encontro/2014/submissao/files_I/i9-0ed7d252394aed6039f6af0e4ed51fc6.pdf) by Guilherme Magacho. Assumptions regarding the world inflation rate and the exchange rate can be based on historical patterns, other modeling studies, or consultation with experts.

| `year` | `world_gr` | `world_infl_rate` | `working_age_gr` | `exchange_rate` | `KV_coeff` | `KV_intercept` |
|-------:|-----------:|------------------:|-----------------:|----------------:|-----------:|---------------:|
|    y_1 |      wgr_1 |             wir_1 |           wagr_1 |            xr_1 |      kvc_1 |          kvi_1 |
|    y_2 |      wgr_2 |             wir_2 |           wagr_2 |            xr_2 |      kvc_2 |          kvi_2 |
|    ... |        ... |               ... |              ... |             ... |        ... |            ... |
|  y_*N* |    wgr_*N* |           wir_*N* |         wagr_*N* |          xr_*N* |    kvc_*N* |        kvi_*N* |

The corresponding [variables](@ref exog-param-vars) are:
  * `world_gr` : ``\underline{\gamma}^\text{world}``
  * `world_infl_rate` : ``\underline{\pi}_{w,k}`` for sector ``k`` (but assumed to be the same for all products)
  * `working_age_gr` : ``\underline{\hat{N}}``
  * `exchange_rate` : ``\underline{e}``
  * `KV_coeff` : ``\underline{\alpha}_\text{KV}``
  * `KV_intercept` : ``\underline{\beta}_\text{KV}``

Here is the example from the Freedonia sample model:
![Freedonia time_series file](assets/images/time_series.png)

## [Optional input files](@id params-optional-input-files)
In the [configuration file general settings](@ref config-general-settings), it is possible to specify any or all of three optional input files for: investment demand; potential output; and maximum capacity utilization.

### Investment demand
The Macro model calculates investment for non-energy sectors based on expected demand and profitability: see the explanation of [potential output](@ref dynamics-potential-output) in the Technical Details. However, for public infrastructure investment -- which is driven by policy goals, rather than private profitability, and where the capital stock is not associated with a particular sector -- investment must be specified exogenously. (When externally specified investment *is* associated with a particular sector, it is better to specify potential output: see below.)

The investment demand parameter file has the following structure:

| `year` | `addl_investment` |
|-------:|------------------:|
|    y_1 |             inv_1 |
|    y_2 |             inv_2 |
|    ... |               ... |

Note that not all years need to be included. For example, if there is investment expenditure in 2025, but not in 2026, then the year 2026 does not have to be included in the file. The values are in "real" monetary terms, and are used directly by Macro, so the units should be the same as those for the supply and use tables.

### Potential output
In the Macro model, potential output is determined by investment: see [potential output](@ref dynamics-potential-output) in the Technical Details. In some cases, it is best to override this behavior. For example, output from agriculture might be determined by an external crop model, or the output from the mining sector might be constrained by the availability of the ore. In other cases, the production level might be set as a policy target or through a sector-specific planning document. In these cases, potential output can be specified for specific sectors, and Macro will calculate investment.

The potential output parameter file has the following structure:

| `year` |       `sec_1` |       `sec_2` | ... |
|-------:|--------------:|--------------:|----:|
|    y_1 |   potout_s1y1 |   potout_s2y1 | ... |
|    y_2 |   potout_s1y2 |   potout_s2y2 | ... |
|    ... |           ... |           ... | ... |
|  y_*N* | potout_s1y*N* | potout_s2y*N* | ... |

The sequence of values is converted internally into an index. For this reason, **values must be specified for all years**. However, **values should be specified only for sectors with exogenous potential output**. Other sectors, where Macro simulates the change in potential output, should not appear in this file.

### Maximum capacity utilization
Capacity utilization in the Macro model is determined in each time step by solving a [linear goal program](@ref lgp). By default, maximum capacity utilization is equal to 1.0. However, in some cases, capacity utilization might be constrained. For example, during a disease outbreak, some service sector activities may be limited, and during a drought, manufacturing plants that rely on cooling or process water might have to curtail production. In these cases, a maximum level of capacity utilization less than one can be specified exogenously.

The maximum capacity utilization file has the following structure:

| `year` |     `sec_1` |     `sec_2` | ... |
|-------:|------------:|------------:|----:|
|    y_1 |   umax_s1y1 |   umax_s2y1 | ... |
|    y_2 |   umax_s1y2 |             | ... |
|    y_3 |   umax_s1y3 |   umax_s2y3 | ... |
|    ... |         ... |         ... | ... |
|  y_*N* | umax_s1y*N* | umax_s2y*N* | ... |

In the file, all years must be listed. However, values do not have to specified for all years. As indicated in the table for sector 2 and year 2 (cell `y_2`,`sec_2`), if capacity utilization is unconstrained in some year, the maximum level can be omitted, and Macro will set it equal to 1.0.
