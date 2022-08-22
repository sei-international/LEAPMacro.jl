```@meta
CurrentModule = LEAPMacro
```

# [Processing the supply-use table](@id process-sut)

## The supply and use tables

Information about [supply and use tables](@ref sut) (SUT) is provided elsewhere in this documentation. This page explains how the SUT is processed internally by Macro. The supply and use tables have the following structure:

### Supply table

|          | Total (purchase price) |    Margins     |   Taxes, etc.    |          Total (basic price)           |     Sectors      | Total (domestic production) |    Imports     |
|:---------|:----------------------:|:--------------:|:----------------:|:--------------------------------------:|:----------------:|:---------------------------:|:--------------:|
| Products |     ``\mathbf{q}``     | ``\mathbf{m}`` | ``\mathbf{T}^d`` | ``\left(\mathbf{q}-\mathbf{m}\right)`` | ``\mathbf{V}^T`` |      ``\mathbf{q}^s``       | ``\mathbf{M}`` |
| Total    |                        |                |                  |                                        | ``\mathbf{g}^T`` |                             |                |


### Use table

|          | Total (purchase price) |      Sectors       | Total (industrial demand) |    Exports     |          Final domestic demand           |  Inventory changes   |
|:---------|:----------------------:|:------------------:|:-------------------------:|:--------------:|:----------------------------------------:|:--------------------:|
| Products |     ``\mathbf{q}``     |   ``\mathbf{U}``   |     ``\mathbf{q}^d``      | ``\mathbf{X}`` | ``\left(\mathbf{F} + \mathbf{I}\right)`` | ``\Delta\mathbf{B}`` |
| Wages    |                        |  ``\mathbf{W}^T``  |                           |                |                                          |                      |
| Profits  |                        | ``\mathbf{\Pi}^T`` |                           |                |                                          |                      |
| Total    |                        |  ``\mathbf{g}^T``  |                           |                |                                          |                      |

For the remainder of this section, the notation from the [Variables](@ref variables) page is used, where an underline indicates an [exogenous parameter](@ref exog-param-vars), while an overline is a [dynamic parameter](@ref dynamic-param-vars).

## Demand coefficients and supply shares
Prices are indices equal to 1 in the initial year. Total output from sector ``i`` in the initial year (with prices set equal to 1) is calculated as
```math
g_i = \sum_{k=1}^{n_p} V_{ik}.
```
The domestic supply of product ``k`` is equal to
```math
q_{s,k} = \sum_{i=1}^{n_s} V_{ik}.
```
Initial values for demand coefficients are then calculated as
```math
\underline{D}^\text{init}_{ki} = \frac{1}{g_i}U_{ki},
```
and supply shares are calculated as
```math
\underline{S}_{ik} = \frac{1}{q_{s,k}} V_{ik}.
```

## Adjusting for stock changes and taxes
Stock changes and a tax correction are distributed over categories of demand by defining
```math
c_k \equiv \frac{\Delta B_k - T^d_k}{F_k + X_k + I_k},
```
and then transforming final demand, exports, and investment in the following way:
```math
F_k \rightarrow (1 + c_k)F_k,\; X_k \rightarrow (1 + c_k)X_k,\; I_k \rightarrow (1 + c_k)I_k.
```