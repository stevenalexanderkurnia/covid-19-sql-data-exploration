# COVID-19 Data Exploration with SQL
Exploratory data analysis of global COVID-19 death and vaccination trends using SQL Server, covering infection rates, mortality, and vaccination rollout across countries and continents.


**Overview**

This project analyses two datasets — COVID deaths and vaccinations — sourced from Our World in Data. The analysis explores how the pandemic progressed globally, which countries were hit hardest, and how vaccination coverage evolved over time.


**Objectives**

- Measure the likelihood of dying from COVID-19 by country
- Track what percentage of each country's population was infected
- Identify countries and continents with the highest death counts
- Calculate rolling vaccination progress against total population


**Dataset**

The original Our World in Data dataset was split into two tables — CovidDeaths and CovidVaccinations — to demonstrate SQL JOIN operations across related datasets sharing a common country and date key.
TableDescriptionCovidDeathsCountry-level daily records of cases, deaths, and populationCovidVaccinationsCountry-level daily records of new vaccinations administered
Source: Our World in Data – COVID-19 Dataset (accessed 15/05/2026)
Period Covered: 01/01/2020 – 26/04/2026
Key columns used: country, continent, date, population, total_cases, new_cases, total_deaths, new_deaths, new_vaccinations


**Tools & Technologies**

Database: Microsoft SQL Server
Query Language: T-SQL
IDE: SQL Server Management Studio (SSMS)


**Key SQL Techniques Used**
- Aggregate functions — SUM(), MAX() for country and continent-level summaries
- Window functions — SUM() OVER (PARTITION BY ... ORDER BY ...) for rolling vaccination counts
- CTEs — used to layer calculations on top of window function results
- Temp tables — alternative approach to CTEs for multi-step calculations
- Views — created for reusable output ready for visualisation tools
- Type casting — CAST() and CONVERT() to handle varchar fields imported from CSV
- Null and zero handling — NULLIF() to prevent divide-by-zero errors; TRY_CONVERT() for safe date parsing
- Data cleaning — ISNUMERIC() to identify and remove malformed rows where text was stored in numeric columns
- Joins — INNER JOIN across deaths and vaccinations tables on country and date


Summary of Key Findings

The US COVID-19 death rate peaked at 6.13% in 2020 when testing was limited, dropping to ~1.2% by 2023 as treatments improved and vaccines rolled out
30.29% of the US population had a recorded infection by 2023, plateauing entirely from that point — almost certainly reflecting the end of mass testing rather than a halt in transmission
Small nations dominate the highest infection rate rankings — 7 of the top 10 countries have populations under 1 million, reflecting denser social networks and more thorough relative testing
The United States recorded the highest absolute death toll at 1.24 million — nearly double Brazil's 703,928 — while large nations dominate death counts and small nations dominate infection rates
Global new cases peaked in 2022 at 2.7 billion driven by the Omicron wave, with a death rate of just 0.29% reflecting the variant's lower severity
The US cumulative vaccination total reached 676.7 million doses by end of 2023 — approximately 1.98 doses per person — plateauing completely from 2024 onwards as mass reporting ended
