# COVID-19 Data Exploration with SQL

Exploratory data analysis of global COVID-19 death and vaccination trends using SQL Server, covering infection rates, mortality, and vaccination rollout across countries and continents.

---

## Overview

This project analyses two datasets — COVID deaths and vaccinations — sourced from [Our World in Data](https://ourworldindata.org/covid-deaths). The analysis explores how the pandemic progressed globally, which countries were hit hardest, and how vaccination coverage evolved over time.

---

## Objectives

- Measure the likelihood of dying from COVID-19 by country
- Track what percentage of each country's population was infected
- Identify countries and continents with the highest death counts
- Calculate rolling vaccination progress against total population

---

## Dataset

The original Our World in Data dataset was split into two tables — `CovidDeaths` and `CovidVaccinations` — to demonstrate SQL JOIN operations across related datasets sharing a common `country` and `date` key.

| Table | Description |
|---|---|
| `CovidDeaths` | Country-level daily records of cases, deaths, and population |
| `CovidVaccinations` | Country-level daily records of new vaccinations administered |

**Source:** [Our World in Data – COVID-19 Dataset](https://ourworldindata.org/covid-deaths) (accessed 15/05/2026)  
**Period Covered:** 01/01/2020 – 26/04/2026  
**Key columns used:** `country`, `continent`, `date`, `population`, `total_cases`, `new_cases`, `total_deaths`, `new_deaths`, `new_vaccinations`

---

## Tools & Technologies

- **Database:** Microsoft SQL Server
- **Query Language:** T-SQL
- **IDE:** SQL Server Management Studio (SSMS)

---

## Key SQL Techniques Used

- **Aggregate functions** — `SUM()`, `MAX()` for country and continent-level summaries
- **Window functions** — `SUM() OVER (PARTITION BY ... ORDER BY ...)` for rolling vaccination counts
- **CTEs** — used to layer calculations on top of window function results
- **Temp tables** — alternative approach to CTEs for multi-step calculations
- **Views** — created for reusable output ready for visualisation tools
- **Type casting** — `CAST()` and `CONVERT()` to handle varchar fields imported from CSV
- **Null and zero handling** — `NULLIF()` to prevent divide-by-zero errors; `TRY_CONVERT()` for safe date parsing
- **Data cleaning** — `ISNUMERIC()` to identify and remove malformed rows where text was stored in numeric columns
- **Joins** — `INNER JOIN` across deaths and vaccinations tables on `country` and `date`

---

## Summary of Key Findings

- The US COVID-19 death rate peaked at **6.13% in 2020** when testing was limited, dropping to ~1.2% by 2023 as treatments improved and vaccines rolled out
- **30.29% of the US population** had a recorded infection by 2023, plateauing entirely from that point — almost certainly reflecting the end of mass testing rather than a halt in transmission
- Small nations dominate the highest infection rate rankings — **7 of the top 10 countries have populations under 1 million**, reflecting denser social networks and more thorough relative testing
- The **United States recorded the highest absolute death toll** at 1.24 million — nearly double Brazil's 703,928 — while large nations dominate death counts and small nations dominate infection rates
- Global new cases **peaked in 2022 at 2.7 billion** driven by the Omicron wave, with a death rate of just 0.29% reflecting the variant's lower severity
- The US cumulative vaccination total reached **676.7 million doses by end of 2023** — approximately 1.98 doses per person — plateauing completely from 2024 onwards as mass reporting ended

---

## Analysis Breakdown

### 1. Data Cleaning

Identified and removed rows where `total_cases` contained non-numeric values (a side effect of CSV import). This ensured all subsequent calculations on case counts were accurate.

The `date` column in `CovidDeaths` was imported from CSV as `varchar`, causing results to sort alphabetically by character rather than chronologically. It was also stored in `DD/MM/YYYY` format, which SQL Server cannot convert directly using `ALTER COLUMN` as it expects `MM/DD/YYYY` by default.

The fix was applied in four committed steps using `GO` batch separators:

```sql
ALTER TABLE CovidPortfolioProject..CovidDeaths
ADD date_converted DATE;
GO

UPDATE CovidPortfolioProject..CovidDeaths
SET date_converted = CONVERT(DATE, date, 103);
GO

ALTER TABLE CovidPortfolioProject..CovidDeaths
DROP COLUMN date;
GO

EXEC sp_rename 'CovidDeaths.date_converted', 'date', 'COLUMN';
GO
```

A new `date_converted` column was added, populated using style code `103` (`DD/MM/YYYY`), the original `varchar` column dropped, and the new column renamed back to `date`. `GO` was required between each step so SQL Server fully committed each statement before the next was parsed — without it, the `UPDATE` throws an invalid column error since `date_converted` doesn't yet exist at parse time.

The same conversion was applied to `CovidVaccinations` before running the JOIN queries.

---

### 2. Death Percentage by Country

Calculated the likelihood of dying after contracting COVID-19 in the United States, expressed as a percentage of confirmed cases. The base query returns one row per day — spanning several years — so the first 10 rows alone show little beyond early-pandemic nulls and zeros. To surface meaningful trends, the query was restructured to aggregate by year using `GROUP BY YEAR(date_converted)`, reducing the output to one row per year.

`MAX()` is used instead of `SUM()` because `total_cases` and `total_deaths` are cumulative running totals in the dataset, not daily new figures — so the highest value within each year represents the peak recorded figure for that year. Summing them would double-count every prior day's cases.

`CAST` is applied to both columns before division since they are stored as `varchar` from the CSV import. `NULLIF` prevents a divide-by-zero error on early-pandemic rows where `total_cases = 0`.

```sql
SELECT country, YEAR(date_converted) AS year, 
       MAX(CAST(total_cases AS FLOAT)) AS peak_cases,
       MAX(CAST(total_deaths AS FLOAT)) AS peak_deaths,
       MAX((CAST(total_deaths AS FLOAT) / NULLIF(CAST(total_cases AS FLOAT), 0)) * 100) AS PeakDeathPercentage
FROM CovidPortfolioProject..CovidDeaths
WHERE country = 'United States'
GROUP BY country, YEAR(date_converted)
ORDER BY year
```

| Year | Peak Cases | Peak Deaths | Peak Death % |
|------|-----------|-------------|--------------|
| 2020 | 19,577,585 | 352,004 | 6.13% |
| 2021 | 53,534,286 | 819,055 | 1.85% |
| 2022 | 99,411,696 | 1,082,456 | 1.52% |
| 2023 | 103,436,829 | 1,164,497 | 1.13% |
| 2024 | 103,436,829 | 1,212,901 | 1.17% |
| 2025 | 103,436,829 | 1,233,250 | 1.19% |
| 2026 | 103,436,829 | 1,237,889 | 1.20% |

**Key findings:** The death percentage peaked at 6.13% in 2020 during the early pandemic when testing was limited and treatment protocols were undeveloped, dropping sharply to 1.85% by 2021 as both scaled up. It has since stabilised around 1.2%. Peak cases plateauing from 2023 onwards suggests recorded infections stopped growing significantly, likely reflecting the end of mass testing rather than an actual halt in transmission.

---

### 3. Infection Rate vs Population

Measured what percentage of the US population had contracted COVID-19 at each point in time, using `total_cases / population`. The base query returns one row per day which shows little trend in isolation, so it was restructured to aggregate by year — same approach as the death percentage query above.

`MAX()` is used rather than `AVG()` because `total_cases` is a cumulative running total, not a daily figure. Averaging across a year would dilute the result by including earlier months where cases were still building up, understating the true infection rate. `MAX` captures the actual peak reached by end of each year, which is the more meaningful figure.

```sql
SELECT country, YEAR(date_converted) AS year,
       MAX(CAST(total_cases AS FLOAT)) AS peak_cases,
       MAX((CAST(total_cases AS FLOAT) / NULLIF(CAST(population AS FLOAT), 0)) * 100) AS PeakInfectionPercentage
FROM CovidPortfolioProject..CovidDeaths
WHERE country = 'United States'
GROUP BY country, YEAR(date_converted)
ORDER BY year
```

| Year | Peak Cases | Peak Infection % |
|------|-----------|-----------------|
| 2020 | 19,577,585 | 5.73% |
| 2021 | 53,534,286 | 15.67% |
| 2022 | 99,411,696 | 29.11% |
| 2023 | 103,436,829 | 30.29% |
| 2024 | 103,436,829 | 30.29% |
| 2025 | 103,436,829 | 30.29% |
| 2026 | 103,436,829 | 30.29% |

**Key findings:** Infection rate grew rapidly from 5.73% in 2020 to 30.29% by 2023, at which point recorded cases stopped growing entirely. This plateau almost certainly reflects the end of mass testing programs rather than an actual halt in transmission, meaning true infection rates are likely higher than what the data captures from 2023 onwards.

---

### 4. Countries with Highest Infection Rate

Ranked all countries by their peak recorded infection rate relative to population, using `MAX(total_cases) / population`. `MAX` is used because `total_cases` is a cumulative running total — taking the maximum gives the highest point ever reached rather than double-counting daily figures.

```sql
SELECT country, population, MAX(total_cases) AS HighestInfectionCount, 
       MAX(CAST(total_cases AS FLOAT) / NULLIF(CAST(population AS FLOAT), 0)) * 100 AS PercentPopulationInfected
FROM CovidPortfolioProject..CovidDeaths
GROUP BY country, population
ORDER BY PercentPopulationInfected DESC
```

| Country | Population | Highest Infection Count | % Population Infected |
|---------|-----------|------------------------|----------------------|
| Brunei | 455,374 | 9,828 | 76.98% |
| San Marino | 34,113 | 9,900 | 74.42% |
| Austria | 9,064,678 | 989,928 | 67.12% |
| South Korea | 51,782,515 | 99,839 | 66.76% |
| Martinique | 349,462 | 99,753 | 65.92% |
| Slovenia | 2,115,231 | 997,973 | 64.62% |
| Jersey | 103,493 | 9,995 | 64.15% |
| Faroe Islands | 54,039 | 998 | 64.14% |
| Luxembourg | 653,315 | 9,664 | 61.48% |
| Andorra | 79,722 | 9,972 | 60.23% |

**Key findings:** The top 10 is dominated by small nations — 7 of the 10 have populations under 1 million, and the remaining 3 are under 10 million. Smaller, densely connected populations have fewer degrees of separation between individuals, meaning a single outbreak can sweep through a larger share of the population before containment measures take effect. Small nations also tend to have more robust testing relative to their population size, recording a higher proportion of actual cases than larger countries where mass testing was harder to sustain. The two outliers — South Korea (51.8M) and Austria (9.1M) — are notable for their exceptionally thorough testing and contact tracing programs, which likely captured cases that went undetected elsewhere.

---

### 5. Countries with Highest Death Count

Ranked all countries by total confirmed COVID-19 deaths. `MAX()` is used because `total_deaths` is a cumulative running total. Two filters are applied to exclude aggregate and regional rows that the Our World in Data dataset stores alongside country-level data: `continent IS NOT NULL` and `continent != ''`.

```sql
SELECT country, MAX(CAST(total_deaths AS INT)) AS TotalDeathCount 
FROM CovidPortfolioProject..CovidDeaths
WHERE continent IS NOT NULL 
AND continent != ''
GROUP BY country
ORDER BY TotalDeathCount DESC
```

| Country | Total Death Count |
|---------|-----------------|
| United States | 1,237,889 |
| Brazil | 703,928 |
| India | 533,849 |
| Russia | 404,290 |
| Mexico | 335,105 |
| United Kingdom | 232,112 |
| Peru | 221,071 |
| Italy | 198,523 |
| Germany | 174,979 |
| France | 168,207 |

**Key findings:** The United States recorded the highest death toll by a significant margin at 1.24 million — nearly double Brazil's 703,928. The top 10 is heavily weighted towards large, populous nations, which contrasts with the previous infection rate query where small nations dominated. This highlights an important distinction: small countries may record a higher percentage of their population infected, but absolute death counts naturally skew towards larger countries with bigger populations to draw from. Peru's presence at 7th is notable given its population of ~33 million — suggesting a disproportionately high death rate relative to its size compared to the other countries on this list.

---

### 6. Continents with Highest Death Count

Aggregated total deaths at the continent level to identify which regions were most severely affected. The same filters from the previous query are applied to exclude non-country aggregate rows. Note that this query uses `MAX(total_deaths)` grouped by continent — meaning it takes the highest single country death count within each continent rather than summing all countries together. This explains why the continent-level figures mirror the top country from each region in the previous query.

```sql
SELECT continent, MAX(CAST(total_deaths AS INT)) AS TotalDeathCount 
FROM CovidPortfolioProject..CovidDeaths
WHERE continent IS NOT NULL AND continent != ''
GROUP BY continent
ORDER BY TotalDeathCount DESC
```

| Continent | Total Death Count |
|-----------|-----------------|
| North America | 1,237,889 |
| South America | 703,928 |
| Asia | 533,849 |
| Europe | 404,290 |
| Africa | 102,595 |
| Oceania | 25,236 |

**Key findings:** North America leads with 1,237,889 — driven entirely by the United States figure from the previous query, confirming the `MAX` behaviour rather than a true continental sum. Africa's relatively low figure of 102,595 is worth treating with caution — it likely reflects significant underreporting due to limited testing infrastructure across much of the continent rather than genuinely lower mortality. A truer continental comparison would require `SUM` across all countries per continent, which would be a worthwhile improvement to this query.

---

### 7. Yearly Global Totals

Calculates worldwide new cases, new deaths, and death percentage aggregated by year. Unlike the earlier queries, this uses `SUM` rather than `MAX` because `new_cases` and `new_deaths` are daily new figures rather than cumulative running totals — summing them across a year gives the actual total recorded that year without double-counting.

`new_cases` is cast to `float` because the global yearly sum exceeds the `int` limit of ~2.1 billion. `new_deaths` stays as `int` since yearly death totals remain within range. `NULLIF` prevents a divide-by-zero error for early pandemic dates with zero new cases reported.

```sql
SELECT YEAR(date_converted) AS year,
    SUM(CAST(new_cases AS FLOAT)) AS total_cases, 
    SUM(CAST(new_deaths AS INT)) AS total_deaths,
    SUM(CAST(new_deaths AS INT)) / NULLIF(SUM(CAST(new_cases AS FLOAT)), 0) * 100 AS DeathPercentage
FROM CovidPortfolioProject..CovidDeaths
WHERE continent IS NOT NULL
GROUP BY YEAR(date_converted)
ORDER BY year
```

| Year | Total Cases | Total Deaths | Death % |
|------|------------|--------------|---------|
| 2020 | 529,060,154 | 12,327,424 | 2.33% |
| 2021 | 1,320,298,956 | 22,660,459 | 1.72% |
| 2022 | 2,695,746,014 | 7,888,727 | 0.29% |
| 2023 | 250,636,658 | 1,730,142 | 0.69% |
| 2024 | 22,459,208 | 425,077 | 1.89% |
| 2025 | 11,090,276 | 158,170 | 1.43% |
| 2026 | 945,997 | 33,707 | 3.56% |

**Key findings:** Global new cases peaked in 2022 at 2.7 billion — driven largely by the Omicron wave — while the death percentage dropped sharply to 0.29%, reflecting the variant's lower severity. The sharp drop in new cases from 2023 onwards almost certainly reflects the widespread winding down of mass testing programs globally rather than an actual decline in transmission. The rising death percentage in 2024–2026 should be interpreted cautiously given the much smaller case base — fewer reported cases means each death carries more weight in the percentage calculation, making the figure less meaningful as a mortality indicator at low testing volumes.

---

### 8. Overall Global Totals

Collapses the entire dataset into a single row showing cumulative worldwide cases, deaths, and overall death percentage across the full pandemic period. Unlike the previous query which grouped by year, there is no `GROUP BY` here — every row in the dataset is summed into one grand total.

`new_cases` is cast to `float` because the global cumulative sum across all dates exceeds the `int` limit of ~2.1 billion. `new_deaths` stays as `int` since the global death total remains within range. `NULLIF` prevents a divide-by-zero error.

```sql
SELECT 
    SUM(CAST(new_cases AS FLOAT)) AS total_cases, 
    SUM(CAST(new_deaths AS INT)) AS total_deaths, 
    SUM(CAST(new_deaths AS INT)) / NULLIF(SUM(CAST(new_cases AS FLOAT)), 0) * 100 AS DeathPercentage
FROM CovidPortfolioProject..CovidDeaths
WHERE continent IS NOT NULL
ORDER BY 1, 2
```

| Total Cases | Total Deaths | Death % |
|------------|--------------|---------|
| 4,830,237,263 | 45,223,706 | 0.94% |

**Key findings:** Across the entire pandemic, approximately 4.83 billion cases were recorded globally with 45.2 million confirmed deaths — an overall death rate of 0.94%. This figure sits below the 2020 peak of 2.33%, reflecting how the death rate improved significantly over time as vaccines rolled out, treatments improved, and less severe variants became dominant. The 4.83 billion case figure likely includes significant double-counting of reinfections since `new_cases` counts each recorded infection event rather than unique individuals.

---

### 9. Total Population vs Vaccinations

Joins the `CovidDeaths` and `CovidVaccinations` tables on `country` and `date_converted` to bring together population figures and daily vaccination numbers in a single view. This sets up the foundation for the rolling vaccination calculations in the following queries.

The join uses both `country` and `date_converted` as matching keys to ensure each population figure is paired with the correct country's vaccination record on the exact same date — joining on `country` alone would produce a cartesian product multiplying every date for each country against every vaccination record.

To surface meaningful trends, the query is aggregated by year for the United States. `SUM` is used rather than `MAX` because `new_vaccinations` is a daily new figure — summing across a year gives the actual total doses administered that year without double-counting.

```sql
SELECT dea.continent, dea.country, YEAR(dea.date_converted) AS year,
    dea.population,
    SUM(CAST(vac.new_vaccinations AS FLOAT)) AS total_vaccinations_that_year
FROM CovidPortfolioProject..CovidDeaths dea
JOIN CovidPortfolioProject..CovidVaccinations vac
    ON dea.country = vac.country
    AND dea.date_converted = vac.date_converted
WHERE dea.continent IS NOT NULL
AND dea.continent != ''
AND dea.country = 'United States'
GROUP BY dea.continent, dea.country, YEAR(dea.date_converted), dea.population
ORDER BY year
```

| Continent | Country | Year | Population | Total Vaccinations That Year |
|-----------|---------|------|------------|----------------------------|
| North America | United States | 2020 | 341,534,041 | 5,670,692 |
| North America | United States | 2021 | 341,534,041 | 516,085,759 |
| North America | United States | 2022 | 341,534,041 | 145,143,337 |
| North America | United States | 2023 | 341,534,041 | 9,776,541 |
| North America | United States | 2024 | 341,534,041 | 0 |
| North America | United States | 2025 | 341,534,041 | 0 |
| North America | United States | 2026 | 341,534,041 | 0 |

**Key findings:** The US vaccination rollout peaked sharply in 2021 with over 516 million doses administered — exceeding the total population of 341 million, which is expected since many individuals received multiple doses including boosters. Doses dropped by roughly 72% in 2022 to 145 million as initial rollout completed and uptake slowed. By 2024 the dataset records zero new vaccinations, almost certainly reflecting the end of mass vaccination data reporting rather than a genuine halt in all doses being administered.

---

### 10. Rolling Vaccination Count

Calculates a running total of vaccinations administered in the United States, accumulated day by day using a window function. `SUM() OVER (PARTITION BY country ORDER BY date_converted)` resets the running total for each country and adds each day's new vaccinations to the previous cumulative sum.

Since the window function cannot be directly wrapped in an aggregate, a CTE is used to compute the rolling total first — then the outer query takes `MAX(RollingPeopleVaccinated)` per year to capture the peak cumulative figure reached by end of each year.

```sql
WITH RollingVac AS (
    SELECT dea.continent, dea.country, dea.date_converted, dea.population,
        SUM(CONVERT(FLOAT, vac.new_vaccinations)) OVER (PARTITION BY dea.country ORDER BY dea.country, dea.date_converted) AS RollingPeopleVaccinated
    FROM CovidPortfolioProject..CovidDeaths dea
    JOIN CovidPortfolioProject..CovidVaccinations vac
        ON dea.country = vac.country
        AND dea.date_converted = vac.date_converted
    WHERE dea.continent IS NOT NULL
    AND dea.continent != ''
    AND dea.country = 'United States'
)
SELECT continent, country, YEAR(date_converted) AS year, population,
    MAX(RollingPeopleVaccinated) AS PeakRollingVaccinated
FROM RollingVac
GROUP BY continent, country, YEAR(date_converted), population
ORDER BY year
```

| Continent | Country | Year | Population | Peak Rolling Vaccinated |
|-----------|---------|------|------------|------------------------|
| North America | United States | 2020 | 341,534,041 | 5,670,692 |
| North America | United States | 2021 | 341,534,041 | 521,756,451 |
| North America | United States | 2022 | 341,534,041 | 666,899,788 |
| North America | United States | 2023 | 341,534,041 | 676,676,329 |
| North America | United States | 2024 | 341,534,041 | 676,676,329 |
| North America | United States | 2025 | 341,534,041 | 676,676,329 |
| North America | United States | 2026 | 341,534,041 | 676,676,329 |

**Key findings:** The cumulative vaccination count reached 676.7 million doses by end of 2023 — approximately 1.98 doses per person across a population of 341.5 million, consistent with a two-dose primary series being the dominant vaccination pattern. The rolling total plateaued completely from 2024 onwards, reflecting the end of mass vaccination data reporting. The jump from 5.7 million in 2020 to 521.8 million in 2021 captures the rapid scale-up of the rollout in the first full year vaccines were available.

---

### 11. Rolling Vaccination % — CTE vs Temp Table

Both queries extend the rolling vaccination calculation by adding a percentage of population vaccinated. The key technical reason for using either a CTE or temp table is the same — `(RollingPeopleVaccinated / Population) * 100` cannot be calculated in the same `SELECT` where the window function is defined, because SQL Server does not allow referencing a window function result as a column alias within the same query level. The result must first be materialised before the percentage can be computed on top of it.

Both queries produce the same result — the difference is structural. The CTE is cleaner and exists only for the duration of the query, while the temp table is a physical object that persists for the session and can be queried multiple times or inspected independently. Temp tables are preferable when the intermediate dataset is large or needs to be reused across multiple subsequent queries.

**CTE approach:**

```sql
WITH PopvsVac (Continent, Country, Date_converted, Population, New_Vaccinations, RollingPeopleVaccinated)
AS
(
    SELECT dea.continent, dea.country, dea.date_converted, dea.population, vac.new_vaccinations,
        SUM(CONVERT(FLOAT, vac.new_vaccinations)) OVER (PARTITION BY dea.country ORDER BY dea.country, dea.date_converted) AS RollingPeopleVaccinated
    FROM CovidPortfolioProject..CovidDeaths dea
    JOIN CovidPortfolioProject..CovidVaccinations vac
        ON dea.country = vac.country
        AND dea.date_converted = vac.date_converted
    WHERE dea.continent IS NOT NULL
    AND dea.continent != ''
    AND dea.country = 'United States'
)
SELECT Continent, Country, YEAR(Date_converted) AS year, Population,
    MAX(RollingPeopleVaccinated) AS PeakRollingVaccinated,
    MAX((RollingPeopleVaccinated / NULLIF(Population, 0)) * 100) AS PeakPercentVaccinated
FROM PopvsVac
GROUP BY Continent, Country, YEAR(Date_converted), Population
ORDER BY year
```

**Temp table approach:**

```sql
DROP TABLE IF EXISTS #PercentPopulationVaccinated
CREATE TABLE #PercentPopulationVaccinated
(
    Continent NVARCHAR(255),
    Country NVARCHAR(255),
    Date_converted DATETIME,
    Population NUMERIC,
    New_vaccinations NUMERIC,
    RollingPeopleVaccinated NUMERIC
)
INSERT INTO #PercentPopulationVaccinated
SELECT dea.continent, dea.country, 
    TRY_CONVERT(DATETIME, dea.date_converted),
    CAST(dea.population AS FLOAT),
    CAST(vac.new_vaccinations AS FLOAT),
    SUM(CONVERT(FLOAT, vac.new_vaccinations)) OVER (PARTITION BY dea.country ORDER BY dea.country, dea.date_converted) AS RollingPeopleVaccinated
FROM CovidPortfolioProject..CovidDeaths dea
JOIN CovidPortfolioProject..CovidVaccinations vac
    ON dea.country = vac.country
    AND dea.date_converted = vac.date_converted
WHERE dea.country = 'United States'

SELECT Continent, Country, YEAR(Date_converted) AS year, Population,
    MAX(RollingPeopleVaccinated) AS PeakRollingVaccinated,
    MAX((RollingPeopleVaccinated / NULLIF(Population, 0)) * 100) AS PeakPercentVaccinated
FROM #PercentPopulationVaccinated
GROUP BY Continent, Country, YEAR(Date_converted), Population
ORDER BY year
```

| Continent | Country | Year | Population | Peak Rolling Vaccinated | Peak % Vaccinated |
|-----------|---------|------|------------|------------------------|-------------------|
| North America | United States | 2020 | 341,534,041 | 5,670,692 | 1.66% |
| North America | United States | 2021 | 341,534,041 | 521,756,451 | 152.77% |
| North America | United States | 2022 | 341,534,041 | 666,899,788 | 195.27% |
| North America | United States | 2023 | 341,534,041 | 676,676,329 | 198.13% |
| North America | United States | 2024 | 341,534,041 | 676,676,329 | 198.13% |
| North America | United States | 2025 | 341,534,041 | 676,676,329 | 198.13% |
| North America | United States | 2026 | 341,534,041 | 676,676,329 | 198.13% |

**Key findings:** The percentage exceeding 100% — peaking at ~198% by 2023 — is expected and reflects cumulative doses rather than unique individuals vaccinated. A figure of 198% across a population of 341.5 million implies an average of roughly 2 doses per person, consistent with a two-dose primary series being the standard vaccination protocol. The minor decimal differences between the CTE and temp table outputs are due to floating point precision handling differences between the two approaches, not a data error.

---

### 12. View for Visualisation

Created a `PercentPopulationVaccinated` view to store the rolling vaccination query as a reusable object, ready for direct connection to a BI tool such as Tableau or Power BI. `DROP VIEW IF EXISTS` ensures clean recreation if the view already exists from a previous run.

```sql
DROP VIEW IF EXISTS PercentPopulationVaccinated;
GO

CREATE VIEW PercentPopulationVaccinated AS
SELECT dea.continent, dea.country, dea.date_converted, dea.population, vac.new_vaccinations,
    SUM(CONVERT(FLOAT, vac.new_vaccinations)) OVER (PARTITION BY dea.country ORDER BY dea.country, dea.date_converted) AS RollingPeopleVaccinated
FROM CovidPortfolioProject..CovidDeaths dea
JOIN CovidPortfolioProject..CovidVaccinations vac
    ON dea.country = vac.country
    AND dea.date_converted = vac.date_converted
WHERE dea.continent IS NOT NULL
AND dea.continent != ''
GO
```

---

## How to Run

1. Download the COVID-19 dataset from [Our World in Data](https://ourworldindata.org/covid-deaths) and split into `CovidDeaths.csv` and `CovidVaccinations.csv`
2. Create a database named `CovidPortfolioProject` in SQL Server
3. Import both CSVs into their respective tables using the SSMS Import Flat File Wizard (all columns will import as `nvarchar` by default — this is expected and handled in the queries)
4. Run the data cleaning block first to convert date columns and remove malformed rows
5. Execute remaining queries in order

---

## Future Improvements

- Connect the `PercentPopulationVaccinated` view to a Tableau dashboard for interactive visualisation
- Replicate the analysis in Python (pandas) for a comparable portfolio piece
- Incorporate more recent data to extend the timeline
- Improve the continent-level death count query by using `SUM` across all countries per continent rather than `MAX`

---

## Problems Encountered

### Date Column Stored as VARCHAR

The `date` column in both tables was imported from CSV as `varchar` rather than a proper `DATE` type. This caused results to sort alphabetically by character rather than chronologically — grouping all 1st-of-month records across years before moving to the 2nd, and so on.

An `ALTER COLUMN` conversion was attempted but failed because SQL Server could not interpret the `DD/MM/YYYY` format by default, which expects `MM/DD/YYYY`. The fix was successfully applied using `CONVERT(DATE, date, 103)` with a staging column approach and `GO` batch separators, as documented in Section 1.

---

### sp_rename Ambiguity Error on CovidVaccinations

After successfully converting the `date` column from `varchar` to `DATE` type in `CovidVaccinations`, the final `sp_rename` step to rename `date_converted` back to `date` repeatedly threw an ambiguity error despite multiple syntax variations being attempted. The column was left as `date_converted` since all queries already reference it consistently by that name, and the data type conversion — which was the primary objective — completed successfully.
