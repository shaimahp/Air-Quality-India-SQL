-- =====================================================================
-- Air Quality Analysis of 26 Indian Cities (2015-2020)
-- Tool    : MySQL 8.0 (MySQL Workbench)
-- Dataset : Air Quality Data in India (CPCB) - city_day.csv
--           https://www.kaggle.com/datasets/rohanrao/air-quality-data-in-india
-- Rows    : 29,531 daily records | 26 cities | 2015-01-01 to 2020-07-01
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. SETUP
-- ---------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS air_quality;
USE air_quality;

-- Columns are loaded as text first, because the CSV has many empty cells.
CREATE TABLE city_day (
    City        VARCHAR(50),
    Date        VARCHAR(20),
    PM2_5       VARCHAR(20),
    PM10        VARCHAR(20),
    NO_         VARCHAR(20),
    NO2         VARCHAR(20),
    NOx         VARCHAR(20),
    NH3         VARCHAR(20),
    CO          VARCHAR(20),
    SO2         VARCHAR(20),
    O3          VARCHAR(20),
    Benzene     VARCHAR(20),
    Toluene     VARCHAR(20),
    Xylene      VARCHAR(20),
    AQI         VARCHAR(20),
    AQI_Bucket  VARCHAR(30)
);

-- Import city_day.csv with: right-click table > Table Data Import Wizard

-- Check the import
SELECT COUNT(*) FROM city_day;                          -- expect 29531
SELECT City, COUNT(*) AS total_rows
FROM city_day
GROUP BY City
ORDER BY total_rows DESC;                               -- expect 26 cities


-- ---------------------------------------------------------------------
-- 2. DATA CLEANING
-- ---------------------------------------------------------------------
SET SQL_SAFE_UPDATES = 0;

-- 2.1 Convert empty strings to NULL
UPDATE city_day SET PM2_5 = NULL WHERE PM2_5 = '';
UPDATE city_day SET PM10 = NULL WHERE PM10 = '';
UPDATE city_day SET NO_ = NULL WHERE NO_ = '';
UPDATE city_day SET NO2 = NULL WHERE NO2 = '';
UPDATE city_day SET NOx = NULL WHERE NOx = '';
UPDATE city_day SET NH3 = NULL WHERE NH3 = '';
UPDATE city_day SET CO = NULL WHERE CO = '';
UPDATE city_day SET SO2 = NULL WHERE SO2 = '';
UPDATE city_day SET O3 = NULL WHERE O3 = '';
UPDATE city_day SET Benzene = NULL WHERE Benzene = '';
UPDATE city_day SET Toluene = NULL WHERE Toluene = '';
UPDATE city_day SET Xylene = NULL WHERE Xylene = '';
UPDATE city_day SET AQI = NULL WHERE AQI = '';
UPDATE city_day SET AQI_Bucket = NULL WHERE AQI_Bucket = '';

-- 2.2 Convert pollutant columns to numeric
ALTER TABLE city_day
  MODIFY PM2_5 DOUBLE, MODIFY PM10 DOUBLE, MODIFY NO_ DOUBLE,
  MODIFY NO2 DOUBLE, MODIFY NOx DOUBLE, MODIFY NH3 DOUBLE,
  MODIFY CO DOUBLE, MODIFY SO2 DOUBLE, MODIFY O3 DOUBLE,
  MODIFY Benzene DOUBLE, MODIFY Toluene DOUBLE, MODIFY Xylene DOUBLE,
  MODIFY AQI DOUBLE;

-- 2.3 Convert text dates to a proper DATE column
ALTER TABLE city_day ADD COLUMN Date_Clean DATE;
UPDATE city_day SET Date_Clean = STR_TO_DATE(Date, '%Y-%m-%d');

-- 2.4 Verify cleaning
SELECT MIN(Date_Clean), MAX(Date_Clean) FROM city_day;      -- 2015-01-01 to 2020-07-01
SELECT COUNT(*) - COUNT(PM10) AS pm10_nulls FROM city_day;  -- expect 11140
SELECT COUNT(*) - COUNT(AQI)  AS aqi_nulls  FROM city_day;  -- expect 4681

-- 2.5 Null count per column
SELECT COUNT(*) AS total_rows,
  COUNT(*)-COUNT(PM2_5) AS pm25_nulls, COUNT(*)-COUNT(PM10) AS pm10_nulls,
  COUNT(*)-COUNT(NO2) AS no2_nulls,   COUNT(*)-COUNT(NH3) AS nh3_nulls,
  COUNT(*)-COUNT(Xylene) AS xylene_nulls, COUNT(*)-COUNT(AQI) AS aqi_nulls
FROM city_day;

-- 2.6 Duplicate city-date rows (no rows returned = no duplicates)
SELECT City, Date_Clean, COUNT(*) FROM city_day
GROUP BY City, Date_Clean HAVING COUNT(*) > 1;


-- ---------------------------------------------------------------------
-- 3. BASIC QUERIES
-- ---------------------------------------------------------------------

-- 1. First 10 records
SELECT City, Date_Clean, PM2_5, PM10, AQI, AQI_Bucket FROM city_day LIMIT 10;

-- 2. All records for Delhi
SELECT * FROM city_day WHERE City = 'Delhi' ORDER BY Date_Clean;

-- 3. Unique cities and AQI buckets
SELECT DISTINCT City FROM city_day ORDER BY City;
SELECT DISTINCT AQI_Bucket FROM city_day WHERE AQI_Bucket IS NOT NULL;

-- 4. All "Severe" days
SELECT City, Date_Clean, AQI FROM city_day
WHERE AQI_Bucket = 'Severe' ORDER BY AQI DESC;


-- ---------------------------------------------------------------------
-- 4. AGGREGATION
-- ---------------------------------------------------------------------

-- 5. Overall averages
SELECT ROUND(AVG(PM2_5),1) AS avg_pm25, ROUND(AVG(PM10),1) AS avg_pm10,
       ROUND(AVG(AQI),1) AS avg_aqi FROM city_day;

-- 6. Days per AQI bucket in each city
SELECT City, AQI_Bucket, COUNT(*) AS days FROM city_day
WHERE AQI_Bucket IS NOT NULL
GROUP BY City, AQI_Bucket ORDER BY days DESC;

-- 7. Top 5 most polluted cities by average AQI
SELECT City, ROUND(AVG(AQI),1) AS avg_aqi FROM city_day
WHERE AQI IS NOT NULL GROUP BY City ORDER BY avg_aqi DESC LIMIT 5;

-- 8. Cities with more than 100 Severe or Very Poor days (HAVING)
SELECT City, COUNT(*) AS bad_days FROM city_day
WHERE AQI_Bucket IN ('Severe','Very Poor')
GROUP BY City HAVING COUNT(*) > 100 ORDER BY bad_days DESC;

-- 9. Average AQI per year
SELECT YEAR(Date_Clean) AS yr, ROUND(AVG(AQI),1) AS avg_aqi FROM city_day
WHERE AQI IS NOT NULL GROUP BY yr ORDER BY yr;

-- 10. Average AQI per month (seasonal pattern)
SELECT MONTH(Date_Clean) AS mth, ROUND(AVG(AQI),1) AS avg_aqi FROM city_day
WHERE AQI IS NOT NULL GROUP BY mth ORDER BY mth;


-- ---------------------------------------------------------------------
-- 5. INTERMEDIATE (SUBQUERIES AND CTEs)
-- ---------------------------------------------------------------------

-- 11. Cities with average AQI above the overall average (subquery)
SELECT City, ROUND(AVG(AQI),1) AS avg_aqi FROM city_day
WHERE AQI IS NOT NULL
GROUP BY City
HAVING AVG(AQI) > (SELECT AVG(AQI) FROM city_day)
ORDER BY avg_aqi DESC;

-- 12. Percentage of days in each AQI bucket (subquery)
SELECT AQI_Bucket, COUNT(*) AS days,
  ROUND(COUNT(*)*100 / (SELECT COUNT(*) FROM city_day WHERE AQI_Bucket IS NOT NULL),2) AS pct
FROM city_day WHERE AQI_Bucket IS NOT NULL
GROUP BY AQI_Bucket ORDER BY days DESC;

-- 13. Top 3 cities by average PM2.5 (CTE)
WITH city_pm AS (
  SELECT City, AVG(PM2_5) AS avg_pm25 FROM city_day
  WHERE PM2_5 IS NOT NULL GROUP BY City)
SELECT City, ROUND(avg_pm25,1) AS avg_pm25 FROM city_pm
ORDER BY avg_pm25 DESC LIMIT 3;

-- 14. Days when PM2.5 was more than 2x the overall average
SELECT City, Date_Clean, PM2_5 FROM city_day
WHERE PM2_5 > 2 * (SELECT AVG(PM2_5) FROM city_day)
ORDER BY PM2_5 DESC LIMIT 20;


-- ---------------------------------------------------------------------
-- 6. ADVANCED (WINDOW FUNCTIONS)
-- ---------------------------------------------------------------------

-- 15. 3-month moving average of AQI for Delhi
WITH m AS (
  SELECT DATE_FORMAT(Date_Clean,'%Y-%m') AS ym, AVG(AQI) AS a FROM city_day
  WHERE City='Delhi' AND AQI IS NOT NULL GROUP BY ym)
SELECT ym, ROUND(a,1) AS avg_aqi,
  ROUND(AVG(a) OVER (ORDER BY ym ROWS BETWEEN 2 PRECEDING AND CURRENT ROW),1) AS moving_avg_3m
FROM m;

-- 16. Month-over-month AQI change for Delhi (LAG)
WITH m AS (
  SELECT DATE_FORMAT(Date_Clean,'%Y-%m') AS ym, AVG(AQI) AS a FROM city_day
  WHERE City='Delhi' AND AQI IS NOT NULL GROUP BY ym)
SELECT ym, ROUND(a,1) AS avg_aqi,
  ROUND(a - LAG(a) OVER (ORDER BY ym),1) AS mom_change
FROM m;

-- 17. Rank cities by average AQI within each year (RANK)
WITH yearly AS (
  SELECT YEAR(Date_Clean) AS yr, City, AVG(AQI) AS avg_aqi FROM city_day
  WHERE AQI IS NOT NULL GROUP BY yr, City)
SELECT yr, City, ROUND(avg_aqi,1) AS avg_aqi,
  RANK() OVER (PARTITION BY yr ORDER BY avg_aqi DESC) AS rnk
FROM yearly ORDER BY yr, rnk;

-- 18. COVID lockdown impact: Mar-Jun 2019 vs Mar-Jun 2020
WITH lockdown AS (
  SELECT City,
    AVG(CASE WHEN YEAR(Date_Clean)=2019 THEN AQI END) AS aqi_2019,
    AVG(CASE WHEN YEAR(Date_Clean)=2020 THEN AQI END) AS aqi_2020
  FROM city_day
  WHERE MONTH(Date_Clean) BETWEEN 3 AND 6 AND YEAR(Date_Clean) IN (2019,2020)
  GROUP BY City)
SELECT City, ROUND(aqi_2019,1) AS aqi_2019, ROUND(aqi_2020,1) AS aqi_2020,
  ROUND((aqi_2020-aqi_2019)/aqi_2019*100,1) AS pct_change
FROM lockdown
WHERE aqi_2019 IS NOT NULL AND aqi_2020 IS NOT NULL
ORDER BY pct_change;

-- 19. Kerala comparison
SELECT City, COUNT(AQI) AS days_with_aqi, ROUND(AVG(AQI),1) AS avg_aqi,
       ROUND(AVG(PM2_5),1) AS avg_pm25
FROM city_day
WHERE City IN ('Kochi','Ernakulam','Thiruvananthapuram')
GROUP BY City ORDER BY avg_aqi DESC;
