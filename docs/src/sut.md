```@meta
CurrentModule = LEAPMacro
```

# [Supply-use table](@id sut)
Supply and use tables (or "supply-use tables" for short) are part of national economic accounts.

The **supply table** records the total value of payments for goods and services sold by businesses within the country, together with imports. To those "basic" values are added taxes net of subsidies, as well as an adjustment for trade and transport margins.

The margins correct for goods, such as agricultural produce, whose sales are recorded in, say, wholesale trade or commercial transport. Entries in the margins columns of the supply table subtract the value of payments from wholesale and commercial transport and add the value to the corresponding product -- in this example, agricultural produce.

The **use table** records sales of goods and services to businesses -- termed intermediate use -- as well as sales to households and the government -- final domestic use -- and to export markets. Sales are also recorded for investment goods, such as buildings and machinery, including the cost of construction and installation. Sometimes investment is reported separately for business, households, and the government.

Total sales by businesses, net of intermediate payments, is "value added". In the use table, value added is allocated to payments to so-called "factors of production", in particular the wages and salaries of employees and the businesses' profit, together with associated taxes and social payments. The total of value added across all sectors is GDP.[^1]

[^1]: Specifically, it is GDP at market prices. Subtracting taxes on production activities and adding subsidies (so-called "indirect" taxes such as registration fees, rather than direct taxes and subsidies on products) gives GDP at factor cost.

!!! tip "Social accounting matrices from the International Food Policy Research Institute"
    Unlike GDP, which is updated at least each year, and sometimes more frequently, supply-use tables are calculated infrequently. In some countries the national statistical office may not report supply-use tables at all. If none is available, then the Macro model cannot be applied. However, by now a large number of countries do have at least one set of supply-use tables, either explicitly labeled as supply and use tables or as part of a social accounting matrix (SAM).
    
    The International Food Policy Research Institute (IFPRI) has been assisting countries with constructing SAMs. They make the datasets and documentation available on the [IFPRI Dataverse](https://dataverse.harvard.edu/dataverse/IFPRI?q=&fq2=seriesName_s%3A%22Social+Accounting+Matrix+%28SAM%29%22&fq0=subtreePaths%3A%22%2F99%22&fq1=dvObjectType%3A%28dataverses+OR+datasets%29&types=dataverses%3Adatasets&sort=dateSort&order=).

      * For more information on supply-use tables, see [_Handbook on Supply and Use Tables and Input-Output Tables with Extensions and Applications_](https://unstats.un.org/unsd/nationalaccount/docs/SUT_IOT_HB_Final_Cover.pdf) from UN Statistics
      * For more information on SAMs, see [_Social accounting matrices and multiplier analysis: An introduction with exercises_](https://www.ifpri.org/publication/social-accounting-matrices-and-multiplier-analysis) from the International Food Policy Research Institute.

## Format of the supply-use table
The supply-use table is the most flexible of the Macro model input files. That is because supply-use tables vary widely in their level of detail and layout. However, Macro does have some restrictions, so some processing is normally required:
  * All of the tables must be in a single comma-separated variable (CSV) file;
  * The tables and columns must be oriented in a specific direction;
  * To be summed together, groups of columns must be next to each other.

!!! info "Aggregate products that are close substitutes"
    Because of the Macro model logic, it is best if the table is not too disaggregated. Specifically, different products should not be close substitutes for one another. For example, if crops are represented, then "cereals" might be a useful category, but reporting different cereal grains as separate products -- such as rice, wheat, maize, and sorghum -- could be problematic if they are readily substituted in diets. If one of those grains were very unlikely to be substituted for the others, such as rice, then "rice" and "other cereals" could be a reasonable level of aggregation.

Many supply-use tables or social accounting matrices are provided as Excel files (or STATA, SPSS, or other format). What is more, sometimes the supply table will be on one worksheet tab and the use table on another. For the Macro model to use them, they must be placed into a single CSV file.

!!! info "Comma-separated variable (CSV) files"
    CSV-formatted files are plain text files that can be viewed in a text editor. They can also be opened and modified in Excel, Google Sheets, or other spreadsheet program, which is a convenient way to edit them. Here is a portion of the supply-use table for the Freedonia example model, opened in Excel:

    ![Freedonia supply-use table](assets/images/Freedonia_SUT.png)

## Linking the supply-use table to Macro
The link between the supply-use table file and the Macro model is specified in the [configuration file](@ref config-sut). The relevant block in the configuration file specifies the range in the CSV file for two matrices -- the supply table and the use table -- with products labeling the rows and sectors labeling the columns.

In addition to the matrices there are columns (with entries for each product) and rows (with entries for each sector). Macro does not require all of the columns and rows in the table to be identified -- it uses a subset of them. Furthermore, it will sum up adjacent columns and rows. For example, in Macro, "final demand" includes household and government expenditure. There may be many households listed, particularly in a social accounting matrix.

See the Freedonia sample model for an example: instructions for downloading the sample model are on the [quick start](@ref quick-start) page.

!!! info "Terminology for supply-use tables"
    There are standard short-hand terms used in economic modeling that are named more descriptively in most supply-use tables or social accounting matrices. For example, "investment" is usually reported as "gross fixed capital formation" (GFCF), to distinguish it from net fixed capital formation (net of depreciation) and additions to inventories. Here is a partial list:

    | Term in the Macro model | Other terms you might see                               |
    |:------------------------|:--------------------------------------------------------|
    | sectors                 | industries, activities                                  |
    | products                | commodities, goods and services                         |
    | wages                   | wages and other compensation, labor (as a factor)       |
    | profits                 | gross operating surplus, surplus, capital (as a factor) |
    | investment              | gross fixed capital formation, GFCF                     |
    | stock changes           | changes in inventories                                  |
