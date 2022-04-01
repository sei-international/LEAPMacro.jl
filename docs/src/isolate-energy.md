```@meta
CurrentModule = LEAPMacro
```

# [Isolating the energy sector](@id isolate-energy)
The Macro model uses an approximation to a full input-output system that includes both energy and non-energy sectors.

To explain the approximation, start with the full system written in matrix form. Total output is given by a vector ``\mathbf{g}``, technical (inter-industry) coefficients by a matrix ``\mathbf{A}``, a further set of technical coefficients matching final demand to different supplying sectors ``\mathbf{S}``, combined household and government final demand ``\mathbf{F}``, investment demand ``\mathbf{I}``, exports ``\mathbf{X}``, imports ``\mathbf{M}``, and margins[^1] ``\mathbf{m}``. Separating into sub-matrices for energy (``E``) and non-energy (``N``) sectors, the system can be written
```math
\left(
    \begin{array}{c}
        \mathbf{g}_E \\
        \mathbf{g}_N
    \end{array}
\right)
=
\left(
    \begin{array}{c c}
        \mathbf{A}_{EE} & \mathbf{A}_{EN} \\
        \mathbf{A}_{NE} & \mathbf{A}_{NN}
    \end{array}
\right)
\left(
    \begin{array}{c}
        \mathbf{g}_E \\
        \mathbf{g}_N
    \end{array}
\right)
+
\left(
    \begin{array}{c c}
        \mathbf{S}_{EE} & \mathbf{0} \\
        \mathbf{0} & \mathbf{S}_{NN}
    \end{array}
\right)
\left[
    \left(
        \begin{array}{c}
            \mathbf{F}_E \\
            \mathbf{F}_N
        \end{array}
    \right)
    +
    \left(
        \begin{array}{c}
            \mathbf{0} \\
            \mathbf{I}_N
        \end{array}
    \right)
    +
    \left(
        \begin{array}{c}
            \mathbf{X}_E - \mathbf{M}_E \\
            \mathbf{X}_N - \mathbf{M}_N
        \end{array}
    \right)
    -
    \left(
        \begin{array}{c}
            \mathbf{m}_E \\
            \mathbf{m}_N
        \end{array}
    \right)
\right].
```
Investment goods are produced only by the non-energy sector, so only one non-zero vector appears in the equations above, ``\mathbf{I}_N``. However, demand can originate in either the energy or non-energy sectors. The sectoral source of demand is distinguished by superscripts,
```math
\mathbf{I}_N = \mathbf{I}^N_N + \mathbf{I}^E_N.
```

!!! note "LEAP as an input-output system"
    The full system above can be written in terms of two linked systems. The balance for the energy system is
    ```math
    \left(\mathbb{I} - \mathbf{A}_{EE}\right)\cdot\mathbf{g}_E = \mathbf{A}_{EN}\cdot\mathbf{g}_N +
        \mathbf{S}_{EE}\cdot\left(\mathbf{F}_E + \mathbf{X}_E - \mathbf{M}_E - \mathbf{m}_E\right).
    ```
    This is essentially the system that LEAP solves: it takes final demand for energy, adds it to demand for energy from non-energy economic sectors, and takes account of transfers of energy between energy production and transformation sub-sectors.

The non-energy system is
```math
\left(\mathbb{I} - \mathbf{A}_{NN}\right)\cdot\mathbf{g}_N = \mathbf{A}_{NE}\cdot\mathbf{g}_E +
    \mathbf{S}_{NN}\cdot\left(\mathbf{F}_N + \mathbf{I}_N + \mathbf{X}_N - \mathbf{M}_N - \mathbf{m}_N\right).
```
In principle this can be solved together with the LEAP calculation in an iterative manner. That would give a solution to the full input-output system. However, it raises some complications.

The term ``\mathbf{A}_{NE}\cdot\mathbf{g}_E`` is demand for non-energy goods from the energy sector. But the energy sectors in LEAP, which should appear in ``\mathbf{g}_E``, are different from the list of energy sectors in the national accounts, which appear in ``\mathbf{A}_{NE}``. That means that LEAP's energy sectors must be mapped to the national accounts through a combination of aggregation and (possible) disaggregation. That mapping would have to change every time the energy sectors in LEAP are changed.

The mapping between the non-energy sectors in the Macro model and the non-energy drivers in LEAP is less problematic. Because LEAP is an energy planning model, the energy sector is developed in detail and the structure can change with the introduction of alternative energy scenarios. Other sectors are normally treated with much less detail and are less likely to change.

Fortunately, the ``\mathbf{A}_{NE}\cdot\mathbf{g}_E`` term can often be neglected. It is ncessary only when the energy sector has a high level of demand for domestic non-energy goods and services. That is most likely when energy is a major source of output and employment. For example, an oil exporter might provide professional services and manufactured parts to the oil sector, and these inputs might be important for employment and economic output. For most countries, however, the coupling will be small, and can be neglected.

!!! note "Measuring the significance to the economy of the supply of non-energy goods and services to the energy sector"
    A measure of how significant non-energy supply to the energy sector is for the economy is calculated within the Macro model. It is reported when the flag to report diagnostics is set in the Macro configuration file: see the documentation on the [diagnostics output files](@ref model-outputs-diagnostics).

The measure of the importance of energy sector demand for non-energy products is calculated by the following algorithm. First, a Leontief inverse matrix for the full inter-industry matrix, ``\mathbf{L}^\text{full}``, is calculated,
```math
\mathbf{L}^\text{full} = \left[
    \left(
        \begin{array}{c c}
            \mathbb{I}_{EE} & \mathbf{0} \\
            \mathbf{0} & \mathbb{I}_{NN}
        \end{array}
    \right)
    -
    \left(
        \begin{array}{c c}
            \mathbf{A}_{EE} & \mathbf{A}_{EN} \\
            \mathbf{A}_{NE} & \mathbf{A}_{NN}
        \end{array}
    \right)
\right]^{-1}
```
Second, a "reduced" Leontief matrix ``\mathbf{L}^\text{red}`` is calculated, with ``\mathbf{A}_{NE}`` set to zero,
```math
\mathbf{L}^\text{red} = \left[
    \left(
        \begin{array}{c c}
            \mathbb{I}_{EE} & \mathbf{0} \\
            \mathbf{0} & \mathbb{I}_{NN}
        \end{array}
    \right)
    -
    \left(
        \begin{array}{c c}
            \mathbf{A}_{EE} & \mathbf{A}_{EN} \\
            \mathbf{0} & \mathbf{A}_{NN}
        \end{array}
    \right)
\right]^{-1}
```
Finally, the measure ``R``, is calculated as
```math
R = 1 - \frac{\sum_{i=1}^{n_s}\sum_{j=1}^{n_s} L^\text{red}_{ij}}{\sum_{i=1}^{n_s}\sum_{j=1}^{n_s} L^\text{full}_{ij}}.
```
This measure provides an order of magnitude estimate of the relative change in economic output in the non-energy sectors when ``\mathbf{A}_{NE}`` is set to zero if demand is increased by the same amount for the output of all sectors. The economic interpretation of ``R`` is that it is the relative change in total non-energy output when energy sector demand for non-energy products is neglected.

[^1]: Trade and transport margins correct for value assigned to sectors that merely convey goods. For example, it subtracts the value of trucked goods from the road transport sector (e.g., vegetables) and adds it to the corresponding goods-producing sector (e.g., agriculture). Margins sum to zero by construction.