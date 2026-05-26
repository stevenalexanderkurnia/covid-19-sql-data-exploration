# COVID-19 Data Exploration with SQL

Exploratory data analysis of global COVID-19 death and vaccination trends using SQL Server, covering infection rates, mortality, and vaccination rollout across countries and continents.


## Overview

This project analyses two datasets (COVID deaths and vaccinations) sourced from [Our World in Data](https://ourworldindata.org/covid-deaths). The analysis explores how the pandemic progressed globally, which countries were hit hardest, and how vaccination coverage evolved over time.


## Objectives

- Measure the likelihood of dying from COVID-19 by country.
- Track what percentage of each country's population was infected.
- Identify countries and continents with the highest death counts.
- Calculate rolling vaccination progress against total population.


## Dataset

The original Our World in Data dataset was split into two tables (`CovidDeaths` and `CovidVaccinations`) to demonstrate SQL JOIN operations across related datasets sharing a common `country` and `date` key.

| Table | Description |
|---|---|
| `CovidDeaths` | Country-level daily records of cases, deaths, and population |
| `CovidVaccinations` | Country-level daily records of new vaccinations administered |

**Source:** [Our World in Data – COVID-19 Dataset](https://ourworldindata.org/covid-deaths) (accessed 15/05/2026)  
**Period Covered:** 01/01/2020 – 26/04/2026  
**Key columns used:** `country`, `continent`, `date`, `population`, `total_cases`, `new_cases`, `total_deaths`, `new_deaths`, `new_vaccinations`
For simplicity, this analysis focuses on the United States. Covering multiple countries would introduce too many variables, so treating one as a baseline keeps things clear and comparable.

## Tools & Technologies

- **Database:** Microsoft SQL Server
- **Query Language:** T-SQL
- **IDE:** SQL Server Management Studio (SSMS)


## Key SQL Techniques Used

- **Aggregate functions** — `SUM()`, `MAX()` for country and continent-level summaries.
- **Window functions** — `SUM() OVER (PARTITION BY ... ORDER BY ...)` for rolling vaccination counts.
- **CTEs** — used to layer calculations on top of window function results.
- **Temp tables** — alternative approach to CTEs for multi-step calculations.
- **Views** — created for reusable output ready for visualisation tools.
- **Type casting** — `CAST()` and `CONVERT()` to handle varchar fields imported from CSV.
- **Null and zero handling** — `NULLIF()` to prevent divide-by-zero errors; `TRY_CONVERT()` for safe date parsing.
- **Data cleaning** — `ISNUMERIC()` to identify and remove malformed rows where text was stored in numeric columns.
- **Joins** — `INNER JOIN` across deaths and vaccinations tables on `country` and `date`.


## Summary of Key Findings

- The US COVID-19 death rate peaked at **6.13% in 2020** when testing was limited, dropping to ~1.2% by 2023 as treatments improved and vaccines rolled out.
- **30.29% of the US population** had a recorded infection by 2023, plateauing entirely from that point — almost certainly reflecting the end of mass testing rather than a halt in transmission.
- Small nations dominate the highest infection rate rankings — **7 of the top 10 countries have populations under 1 million**, reflecting denser social networks and more thorough relative testing.
- The **United States recorded the highest absolute death toll** at 1.24 million (nearly double Brazil's 703,928) while large nations dominate death counts and small nations dominate infection rates.
- Global new cases **peaked in 2022 at 2.7 billion** driven by the Omicron wave, with a death rate of just 0.29% reflecting the variant's lower severity.
- The US cumulative vaccination total reached **676.7 million doses by end of 2023** (approximately 1.98 doses per person) plateauing completely from 2024 onwards as mass reporting ended.


## Analysis Breakdown

### 1. Data Cleaning

Identified and removed rows where `total_cases` contained non-numeric values (a side effect of CSV import). This ensured all subsequent calculations on case counts were accurate.

The `date` column in `CovidDeaths` was imported from CSV as `varchar`, causing results to sort alphabetically by character rather than chronologically. It was also stored in `DD/MM/YYYY` format, which SQL Server cannot convert directly using `ALTER COLUMN` as it expects `MM/DD/YYYY` by default.

The fix was applied in four committed steps using `GO` batch separators.

A new `date_converted` column was added, populated using style code `103` (`DD/MM/YYYY`), the original `varchar` column dropped, and the new column renamed back to `date`. `GO` was required between each step so SQL Server fully committed each statement before the next was parsed — without it, the `UPDATE` throws an invalid column error since `date_converted` doesn't yet exist at parse time.

The same conversion was applied to `CovidVaccinations` before running the JOIN queries.


### 2. Death Percentage by Country

Calculated the likelihood of dying after contracting COVID-19 in the United States, expressed as a percentage of confirmed cases. The base query returns one row per day (spanning several years) so the first 10 rows alone show little beyond early-pandemic nulls and zeros. To surface meaningful trends, the query was restructured to aggregate by year using `GROUP BY YEAR(date_converted)`, reducing the output to one row per year.

`MAX()` is used instead of `SUM()` because `total_cases` and `total_deaths` are cumulative running totals in the dataset, not daily new figures — so the highest value within each year represents the peak recorded figure for that year. Summing them would double-count every prior day's cases.

`CAST` is applied to both columns before division since they are stored as `varchar` from the CSV import. `NULLIF` prevents a divide-by-zero error on early-pandemic rows where `total_cases = 0`.

<img width="940" height="309" alt="image" src="https://github.com/user-attachments/assets/47972cdd-6077-44ee-97c0-6a296542aa2a" />

**Key findings:** The death percentage peaked at 6.13% in 2020 during the early pandemic when testing was limited and treatment protocols were undeveloped, dropping sharply to 1.85% by 2021 as both scaled up. It has since stabilised around 1.2%. Peak cases plateauing from 2023 onwards suggests recorded infections stopped growing significantly, likely reflecting the end of mass testing rather than an actual halt in transmission.

### 3. Infection Rate vs Population

Measured what percentage of the US population had contracted COVID-19 at each point in time, using `total_cases / population`. The base query returns one row per day which shows little trend in isolation, so it was restructured to aggregate by year — same approach as the death percentage query above.

`MAX()` is used rather than `AVG()` because `total_cases` is a cumulative running total, not a daily figure. Averaging across a year would dilute the result by including earlier months where cases were still building up, understating the true infection rate. `MAX` captures the actual peak reached by end of each year, which is the more meaningful figure.

<img width="820" height="325" alt="image" src="https://github.com/user-attachments/assets/0c977881-c02c-4ab0-92c6-cbe497a1fad4" />

**Key findings:** Infection rate grew rapidly from 5.73% in 2020 to 30.29% by 2023, at which point recorded cases stopped growing entirely. This plateau almost certainly reflects the end of mass testing programs rather than an actual halt in transmission, meaning true infection rates are likely higher than what the data captures from 2023 onwards.


### 4. Countries with Highest Infection Rate

Ranked all countries by their peak recorded infection rate relative to population, using `MAX(total_cases) / population`. `MAX` is used because `total_cases` is a cumulative running total — taking the maximum gives the highest point ever reached rather than double-counting daily figures.

<img width="940" height="365" alt="image" src="https://github.com/user-attachments/assets/40606fd0-acab-4d95-9430-0cde6b217613" />

**Key findings:** The top 10 is dominated by small nations — 7 of the 10 have populations under 1 million, and the remaining 3 are under 10 million. Smaller, densely connected populations have fewer degrees of separation between individuals, meaning a single outbreak can sweep through a larger share of the population before containment measures take effect. Small nations also tend to have more robust testing relative to their population size, recording a higher proportion of actual cases than larger countries where mass testing was harder to sustain. The two outliers — South Korea (51.8M) and Austria (9.1M) — are notable for their exceptionally thorough testing and contact tracing programs, which likely captured cases that went undetected elsewhere.


### 5. Countries with Highest Death Count

Ranked all countries by total confirmed COVID-19 deaths. `MAX()` is used because `total_deaths` is a cumulative running total. Two filters are applied to exclude aggregate and regional rows that the Our World in Data dataset stores alongside country-level data: `continent IS NOT NULL` and `continent != ''`.

<img width="505" height="441" alt="image" src="https://github.com/user-attachments/assets/2f3b89df-79aa-4481-b36a-b3f467935bc9" />

**Key findings:** The United States recorded the highest death toll by a significant margin at 1.24 million — nearly double Brazil's 703,928. The top 10 is heavily weighted towards large, populous nations, which contrasts with the previous infection rate query where small nations dominated. This highlights an important distinction: small countries may record a higher percentage of their population infected, but absolute death counts naturally skew towards larger countries with bigger populations to draw from. Peru's presence at 7th is notable given its population of ~33 million — suggesting a disproportionately high death rate relative to its size compared to the other countries on this list.


### 6. Continents with Highest Death Count

Aggregated total deaths at the continent level to identify which regions were most severely affected. The same filters from the previous query are applied to exclude non-country aggregate rows. Note that this query uses `MAX(total_deaths)` grouped by continent — meaning it takes the highest single country death count within each continent rather than summing all countries together. This explains why the continent-level figures mirror the top country from each region in the previous query.

<img width="494" height="288" alt="image" src="https://github.com/user-attachments/assets/a3460256-2bcd-4e39-bb7e-34928a2b26a6" />

**Key findings:** North America leads with 1,237,889 — driven entirely by the United States figure from the previous query, confirming the `MAX` behaviour rather than a true continental sum. Africa's relatively low figure of 102,595 is worth treating with caution — it likely reflects significant underreporting due to limited testing infrastructure across much of the continent rather than genuinely lower mortality. A truer continental comparison would require `SUM` across all countries per continent, which would be a worthwhile improvement to this query.


### 7. Yearly Global Totals

Calculates worldwide new cases, new deaths, and death percentage aggregated by year. Unlike the earlier queries, this uses `SUM` rather than `MAX` because `new_cases` and `new_deaths` are daily new figures rather than cumulative running totals — summing them across a year gives the actual total recorded that year without double-counting.

`new_cases` is cast to `float` because the global yearly sum exceeds the `int` limit of ~2.1 billion. `new_deaths` stays as `int` since yearly death totals remain within range. `NULLIF` prevents a divide-by-zero error for early pandemic dates with zero new cases reported.

<img width="767" height="322" alt="image" src="https://github.com/user-attachments/assets/c0558dce-0790-4d23-a2b8-a69a2be51433" />

**Key findings:** Global new cases peaked in 2022 at 2.7 billion — driven largely by the Omicron wave — while the death percentage dropped sharply to 0.29%, reflecting the variant's lower severity. The sharp drop in new cases from 2023 onwards almost certainly reflects the widespread winding down of mass testing programs globally rather than an actual decline in transmission. The rising death percentage in 2024–2026 should be interpreted cautiously given the much smaller case base — fewer reported cases means each death carries more weight in the percentage calculation, making the figure less meaningful as a mortality indicator at low testing volumes.


### 8. Overall Global Totals

Collapses the entire dataset into a single row showing cumulative worldwide cases, deaths, and overall death percentage across the full pandemic period. Unlike the previous query which grouped by year, there is no `GROUP BY` here — every row in the dataset is summed into one grand total.

`new_cases` is cast to `float` because the global cumulative sum across all dates exceeds the `int` limit of ~2.1 billion. `new_deaths` stays as `int` since the global death total remains within range. `NULLIF` prevents a divide-by-zero error.

<img width="683" height="89" alt="image" src="https://github.com/user-attachments/assets/5cce593b-0b9f-412f-81fb-470615f40848" />

**Key findings:** Across the entire pandemic, approximately 4.83 billion cases were recorded globally with 45.2 million confirmed deaths — an overall death rate of 0.94%. This figure sits below the 2020 peak of 2.33%, reflecting how the death rate improved significantly over time as vaccines rolled out, treatments improved, and less severe variants became dominant. The 4.83 billion case figure likely includes significant double-counting of reinfections since `new_cases` counts each recorded infection event rather than unique individuals.


### 9. Total Population vs Vaccinations

Joins the `CovidDeaths` and `CovidVaccinations` tables on `country` and `date_converted` to bring together population figures and daily vaccination numbers in a single view. This sets up the foundation for the rolling vaccination calculations in the following queries.

The join uses both `country` and `date_converted` as matching keys to ensure each population figure is paired with the correct country's vaccination record on the exact same date — joining on `country` alone would produce a cartesian product multiplying every date for each country against every vaccination record.

To surface meaningful trends, the query is aggregated by year for the United States. `SUM` is used rather than `MAX` because `new_vaccinations` is a daily new figure — summing across a year gives the actual total doses administered that year without double-counting.

<img width="940" height="301" alt="image" src="https://github.com/user-attachments/assets/bd124408-576e-47a2-b4e9-c66b4fc436a4" />

**Key findings:** The US vaccination rollout peaked sharply in 2021 with over 516 million doses administered — exceeding the total population of 341 million, which is expected since many individuals received multiple doses including boosters. Doses dropped by roughly 72% in 2022 to 145 million as initial rollout completed and uptake slowed. By 2024 the dataset records zero new vaccinations, almost certainly reflecting the end of mass vaccination data reporting rather than a genuine halt in all doses being administered.


### 10. Rolling Vaccination Count

Calculates a running total of vaccinations administered in the United States, accumulated day by day using a window function. `SUM() OVER (PARTITION BY country ORDER BY date_converted)` resets the running total for each country and adds each day's new vaccinations to the previous cumulative sum.

Since the window function cannot be directly wrapped in an aggregate, a CTE is used to compute the rolling total first — then the outer query takes `MAX(RollingPeopleVaccinated)` per year to capture the peak cumulative figure reached by end of each year.

<img width="940" height="310" alt="image" src="https://github.com/user-attachments/assets/3a066e20-1b4a-460e-8416-758b26becdc6" />

**Key findings:** The cumulative vaccination count reached 676.7 million doses by end of 2023 — approximately 1.98 doses per person across a population of 341.5 million, consistent with a two-dose primary series being the dominant vaccination pattern. The rolling total plateaued completely from 2024 onwards, reflecting the end of mass vaccination data reporting. The jump from 5.7 million in 2020 to 521.8 million in 2021 captures the rapid scale-up of the rollout in the first full year vaccines were available.


### 11. Rolling Vaccination % — CTE vs Temp Table

Both queries extend the rolling vaccination calculation by adding a percentage of population vaccinated. The key technical reason for using either a CTE or temp table is the same — `(RollingPeopleVaccinated / Population) * 100` cannot be calculated in the same `SELECT` where the window function is defined, because SQL Server does not allow referencing a window function result as a column alias within the same query level. The result must first be materialised before the percentage can be computed on top of it.

Both queries produce the same result — the difference is structural. The CTE is cleaner and exists only for the duration of the query, while the temp table is a physical object that persists for the session and can be queried multiple times or inspected independently. Temp tables are preferable when the intermediate dataset is large or needs to be reused across multiple subsequent queries.

<img width="940" height="242" alt="image" src="https://github.com/user-attachments/assets/a69b4c51-c0d3-4709-88cf-cefdd30b9440" />

**Key findings:** The percentage exceeding 100% — peaking at ~198% by 2023 — is expected and reflects cumulative doses rather than unique individuals vaccinated. A figure of 198% across a population of 341.5 million implies an average of roughly 2 doses per person, consistent with a two-dose primary series being the standard vaccination protocol. The minor decimal differences between the CTE and temp table outputs are due to floating point precision handling differences between the two approaches, not a data error.


### 12. View for Visualisation

Created a `PercentPopulationVaccinated` view to store the rolling vaccination query as a reusable object, ready for direct connection to a BI tool such as Tableau or Power BI. `DROP VIEW IF EXISTS` ensures clean recreation if the view already exists from a previous run.



## How to Run

1. Download the COVID-19 dataset from [Our World in Data](https://ourworldindata.org/covid-deaths) and split into `CovidDeaths.csv` and `CovidVaccinations.csv`
2. Create a database named `CovidPortfolioProject` in SQL Server
3. Import both CSVs into their respective tables using the SSMS Import Flat File Wizard (all columns will import as `nvarchar` by default — this is expected and handled in the queries)
4. Run the data cleaning block first to convert date columns and remove malformed rows
5. Execute remaining queries in order


## Future Improvements

- Connect the `PercentPopulationVaccinated` view to a Tableau dashboard for interactive visualisation
- Replicate the analysis in Python (pandas) for a comparable portfolio piece
- Incorporate more recent data to extend the timeline
- Improve the continent-level death count query by using `SUM` across all countries per continent rather than `MAX`


## Problems Encountered

### Date Column Stored as VARCHAR

The `date` column in both tables was imported from CSV as `varchar` rather than a proper `DATE` type. This caused results to sort alphabetically by character rather than chronologically — grouping all 1st-of-month records across years before moving to the 2nd, and so on.

An `ALTER COLUMN` conversion was attempted but failed because SQL Server could not interpret the `DD/MM/YYYY` format by default, which expects `MM/DD/YYYY`. The fix was successfully applied using `CONVERT(DATE, date, 103)` with a staging column approach and `GO` batch separators, as documented in Section 1.


### sp_rename Ambiguity Error on CovidVaccinations

After successfully converting the `date` column from `varchar` to `DATE` type in `CovidVaccinations`, the final `sp_rename` step to rename `date_converted` back to `date` repeatedly threw an ambiguity error despite multiple syntax variations being attempted. The column was left as `date_converted` since all queries already reference it consistently by that name, and the data type conversion — which was the primary objective — completed successfully.
