-- 1. DATA CLEANING
-- Preview CovidDeaths table
SELECT *
FROM CovidPortfolioProject..CovidDeaths
ORDER BY 3, 4

-- Convert date column from varchar to DATE type in CovidDeaths
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

-- Preview CovidVaccinations table
SELECT *
FROM CovidPortfolioProject..CovidVaccinations
ORDER BY 3, 4

-- Remove aggregate and regional rows from CovidVaccinations
DELETE FROM CovidPortfolioProject..CovidVaccinations
WHERE country LIKE '%World excl%'
OR country LIKE '%World%'
OR country LIKE '%income%'
OR continent = ''
OR continent IS NULL

-- Convert date column from varchar to DATE type in CovidVaccinations
IF COL_LENGTH('CovidVaccinations', 'date_converted') IS NOT NULL
BEGIN
    ALTER TABLE CovidPortfolioProject..CovidVaccinations
    DROP COLUMN date_converted;
END
GO

ALTER TABLE CovidPortfolioProject..CovidVaccinations
ADD date_converted DATE;
GO

UPDATE CovidPortfolioProject..CovidVaccinations
SET date_converted = CONVERT(DATE, date, 103);
GO

ALTER TABLE CovidPortfolioProject..CovidVaccinations
DROP COLUMN date;
GO

EXEC sp_rename 'dbo.CovidVaccinations.date_converted', 'date', 'COLUMN';
GO

-- Verify CovidVaccinations columns after conversion
SELECT COLUMN_NAME 
FROM CovidPortfolioProject.INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'CovidVaccinations'
ORDER BY ORDINAL_POSITION

-- Remove rows where total_cases contains non-numeric values
SELECT * FROM CovidPortfolioProject..CovidDeaths
WHERE ISNUMERIC(total_cases) = 0 
AND total_cases IS NOT NULL
AND total_cases != ''
DELETE FROM CovidPortfolioProject..CovidDeaths
WHERE ISNUMERIC(total_cases) = 0 
AND total_cases IS NOT NULL
AND total_cases != ''

-- 2. DEATH PERCENTAGE BY COUNTRY
SELECT country, date_converted, total_cases, total_deaths, 
       (CAST(total_deaths AS FLOAT) / NULLIF(CAST(total_cases AS FLOAT), 0)) * 100 AS DeathPercentage
FROM CovidPortfolioProject..CovidDeaths
WHERE country LIKE '%states%'
ORDER BY 1, 2
SELECT country, YEAR(date_converted) AS year, 
       MAX(CAST(total_cases AS FLOAT)) AS peak_cases,
       MAX(CAST(total_deaths AS FLOAT)) AS peak_deaths,
       MAX((CAST(total_deaths AS FLOAT) / NULLIF(CAST(total_cases AS FLOAT), 0)) * 100) AS PeakDeathPercentage
FROM CovidPortfolioProject..CovidDeaths
WHERE country = 'United States'
GROUP BY country, YEAR(date_converted)
ORDER BY year

-- 3. INFECTION RATE VS POPULATION
SELECT country, date_converted, population, total_cases, 
       (CAST(total_cases AS FLOAT) / NULLIF(CAST(population AS FLOAT), 0)) * 100 AS InfectionPercentage
FROM CovidPortfolioProject..CovidDeaths
WHERE country LIKE '%states%'
ORDER BY 1, 2
SELECT country, YEAR(date_converted) AS year,
       MAX(CAST(total_cases AS FLOAT)) AS peak_cases,
       MAX((CAST(total_cases AS FLOAT) / NULLIF(CAST(population AS FLOAT), 0)) * 100) AS PeakInfectionPercentage
FROM CovidPortfolioProject..CovidDeaths
WHERE country = 'United States'
GROUP BY country, YEAR(date_converted)
ORDER BY year

-- 4. COUNTRIES WITH HIGHEST INFECTION RATE VS POPULATION
SELECT country, population, MAX(total_cases) AS HighestInfectionCount, 
       MAX(CAST(total_cases AS FLOAT) / NULLIF(CAST(population AS FLOAT), 0)) * 100 AS PercentPopulationInfected
FROM CovidPortfolioProject..CovidDeaths
GROUP BY country, population
ORDER BY PercentPopulationInfected DESC

-- 5. COUNTRIES WITH HIGHEST DEATH COUNT PER POPULATION
SELECT country, MAX(CAST(total_deaths AS INT)) AS TotalDeathCount 
FROM CovidPortfolioProject..CovidDeaths
WHERE continent IS NOT NULL 
AND continent != ''
GROUP BY country
ORDER BY TotalDeathCount DESC

-- 6. CONTINENTS WITH HIGHEST DEATH COUNT PER POPULATION
SELECT continent, MAX(CAST(total_deaths AS INT)) AS TotalDeathCount 
FROM CovidPortfolioProject..CovidDeaths
WHERE continent IS NOT NULL AND continent != ''
GROUP BY continent
ORDER BY TotalDeathCount DESC

-- 7. YEARLY GLOBAL TOTALS
SELECT YEAR(date_converted) AS year,
    SUM(CAST(new_cases AS FLOAT)) AS total_cases, 
    SUM(CAST(new_deaths AS INT)) AS total_deaths,
    SUM(CAST(new_deaths AS INT)) / NULLIF(SUM(CAST(new_cases AS FLOAT)), 0) * 100 AS DeathPercentage
FROM CovidPortfolioProject..CovidDeaths
WHERE continent IS NOT NULL
GROUP BY YEAR(date_converted)
ORDER BY year

-- 8. OVERALL GLOBAL TOTALS
SELECT 
    SUM(CAST(new_cases AS FLOAT)) AS total_cases, 
    SUM(CAST(new_deaths AS INT)) AS total_deaths, 
    SUM(CAST(new_deaths AS INT)) / NULLIF(SUM(CAST(new_cases AS FLOAT)), 0) * 100 AS DeathPercentage
FROM CovidPortfolioProject..CovidDeaths
WHERE continent IS NOT NULL
ORDER BY 1, 2

-- 9. TOTAL POPULATION VS VACCINATIONS
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

-- 10. ROLLING VACCINATION COUNT (WINDOW FUNCTION)
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

-- ROLLING VACCINATION % — CTE VS TEMP TABLE
-- CTE approach
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

-- Temp table approach
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

-- 12: VIEW FOR VISUALISATION
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
