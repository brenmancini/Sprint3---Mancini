-- -- Nivel 1
-- Ejercicio 1
CREATE SCHEMA `sprint3-analytics-bmancini.sprint3_silver`
OPTIONS (location = 'EU')

-- Ejercico 2
CREATE EXTERNAL TABLE sprint3-analytics-bmancini.sprint3_bronze.american_users_raw 
OPTIONS (
  format = 'CSV',
  uris = ['gs://bootcamp-data-analytics-public/CRM/american_users.csv']
);

CREATE EXTERNAL TABLE sprint3-analytics-bmancini.sprint3_bronze.european_users_raw
OPTIONS (
  format = 'CSV',
  uris = ['gs://bootcamp-data-analytics-public/CRM/european_users.csv']
);

CREATE EXTERNAL TABLE sprint3-analytics-bmancini.sprint3_bronze.credit_cards_raw
OPTIONS (
  format = 'CSV',
  uris = ['gs://bootcamp-data-analytics-public/CRM/credit_cards.csv']
);

CREATE EXTERNAL TABLE sprint3-analytics-bmancini.sprint3_bronze.transactions_raw
OPTIONS (
  format = 'CSV',
  uris = ['gs://bootcamp-data-analytics-public/ERP/transactions.csv'],
  field_delimiter = ';'
);

CREATE OR REPLACE EXTERNAL TABLE `sprint3-analytics-bmancini.sprint3_bronze.companies_raw`
OPTIONS (
  format = 'CSV',
  uris = ['gs://bootcamp-data-analytics-public/ERP/companies.csv']
);

SELECT * FROM `sprint3-analytics-bmancini.sprint3_bronze.companies_raw` LIMIT 3;

CREATE OR REPLACE EXTERNAL TABLE sprint3-analytics-bmancini.sprint3_bronze.companies_raw (
	company_id STRING,
    company_name STRING,
    phone STRING,
    email STRING,
    country STRING,
    website STRING
)
OPTIONS (
  format = 'CSV',
  uris = ['gs://bootcamp-data-analytics-public/ERP/companies.csv'],
  skip_leading_rows = 1
);

-- Ejercicio 4
-- a)
CREATE OR REPLACE TABLE `sprint3-analytics-bmancini.sprint3_bronze.transactions_raw_native` AS
SELECT
  *
FROM `sprint3-analytics-bmancini.sprint3_bronze.transactions_raw`;

-- b)
SELECT id FROM `sprint3-analytics-bmancini.sprint3_bronze.transactions_raw_native`;

SELECT id 
FROM `sprint3-analytics-bmancini.sprint3_bronze.transactions_raw`;

-- c)
SELECT * FROM `sprint3-analytics-bmancini.sprint3_bronze.transactions_raw_native`;
SELECT * FROM `sprint3-analytics-bmancini.sprint3_bronze.transactions_raw_native` LIMIT 10;
SELECT id FROM `sprint3-analytics-bmancini.sprint3_bronze.transactions_raw_native`;

SELECT * FROM `sprint3-analytics-bmancini.sprint3_bronze.transactions_raw` LIMIT 10;

-- Ejercicio 5
SELECT CAST(SUBSTR(fecha_string, 1, 10) AS DATE) AS fecha, SUM(amount) AS suma_monto
FROM (
	SELECT CAST(t.timestamp AS STRING) AS fecha_string, t.amount, t.declined
	FROM `sprint3-analytics-bmancini.sprint3_bronze.transactions_raw_native`) AS t
WHERE declined=0 AND SUBSTR(fecha_string, 1, 4)='2021'
GROUP BY fecha
ORDER BY suma_monto DESC
LIMIT 5;

-- Ejercicio 6
SELECT c.company_name, c.country, CAST(SUBSTR(t.fecha_string, 1, 10) AS DATE) AS fecha
FROM (
	SELECT business_id, CAST(timestamp AS STRING) AS fecha_string, amount
	FROM `sprint3-analytics-bmancini.sprint3_bronze.transactions_raw_native`) AS t
JOIN `sprint3-analytics-bmancini.sprint3_bronze.companies_raw` AS c
ON c.company_id=t.business_id
WHERE t.amount BETWEEN 100 AND 200 AND CAST(SUBSTR(T.fecha_string, 1, 10) AS DATE) IN('2015-04-29', '2018-07-20', '2024-03-13')
ORDER BY t.amount DESC;

-- -- Nivel 2
-- Ejercicio 1
CREATE OR REPLACE TABLE `sprint3-analytics-bmancini.sprint3_silver.products_clean` AS
SELECT
  id AS product_id,
  product_name AS name,
  CAST(TRIM(REPLACE(price, '$', '')) AS FLOAT64) AS price,
  colour,
  weight,
  CAST(TRIM(REPLACE(warehouse_id, 'WH-', '')) AS INT64) AS warehouse_id,
  category,
  brand,
  CAST(TRIM(REPLACE(cost, '$', '')) AS FLOAT64) AS cost,
  launch_date
FROM `sprint3-analytics-bmancini.sprint3_bronze.products_raw`;

-- Ejercicio 2
-- timestamp: Si fuera texto en un formato no estándar (por ejemplo 15/03/2021 14:23) usar SAFE.PARSE_TIMESTAMP('%d/%m/%Y %H:%M', timestamp).
CREATE OR REPLACE TABLE `sprint3-analytics-bmancini.sprint3_silver.transactions_clean` AS
SELECT
  * EXCEPT(id, amount, timestamp, lat, longitude, product_ids),
  id AS transaction_id,
  IFNULL(SAFE_CAST(amount AS FLOAT64), 0) AS amount,
  CAST(timestamp AS timestamp) AS timestamp,
  SAFE_CAST(lat AS FLOAT64) AS lat,
  SAFE_CAST(longitude AS FLOAT64) AS longitude,
  ARRAY(
    SELECT CAST(TRIM(x) AS INT64)
    FROM UNNEST(SPLIT(product_ids, ',')) AS x
  ) AS product_ids
FROM `sprint3-analytics-bmancini.sprint3_bronze.transactions_raw`;

-- Ejercicio 3
CREATE OR REPLACE TABLE `sprint3-analytics-bmancini.sprint3_silver.users_combined` AS
SELECT
  id AS user_id,
  name,
  surname,
  phone,
  email,
  birth_date,
  country,
  city,
  postal_code,
  address,
  'USA' AS origin
FROM `sprint3-analytics-bmancini.sprint3_bronze.american_users_raw`
UNION ALL
SELECT
  id AS user_id,
  name,
  surname,
  phone,
  email,
  birth_date,
  country,
  city,
  postal_code,
  address,
  'Europe' AS origin
FROM `sprint3-analytics-bmancini.sprint3_bronze.european_users_raw`;

-- Ejercicio 4
CREATE OR REPLACE TABLE `sprint3-analytics-bmancini.sprint3_silver.companies_clean` AS
SELECT *
FROM `sprint3-analytics-bmancini.sprint3_bronze.companies_raw`;

CREATE OR REPLACE TABLE `sprint3-analytics-bmancini.sprint3_silver.credit_cards_clean` AS
SELECT
  id AS credit_card_id,
  * EXCEPT (id)
FROM `sprint3-analytics-bmancini.sprint3_bronze.credit_cards_raw`;

ALTER TABLE `sprint3-analytics-bmancini.sprint3_silver.credit_cards_clean`
RENAME COLUMN credit_card_id TO card_id;

-- --Nivel 3
-- Ejercicio 1
CREATE OR REPLACE VIEW `sprint3-analytics-bmancini.sprint3_gold.v_marketing_kpis` AS
SELECT c.company_id, c.company_name, c.phone, c.country, AVG(t.amount) AS avg_amount,
  CASE
    WHEN AVG(t.amount)>260 THEN 'Premium'
    ELSE 'Standard'
  END AS client_tier
FROM `sprint3-analytics-bmancini.sprint3_silver.companies_clean` AS c
JOIN `sprint3-analytics-bmancini.sprint3_silver.transactions_clean` AS t
  ON c.company_id=t.business_id
GROUP BY c.company_id, c.company_name, c.phone, c.country;

SELECT *
FROM `sprint3-analytics-bmancini.sprint3_gold.v_marketing_kpis`
ORDER BY 
        CASE client_tier
            WHEN 'Premium' THEN 1
            ELSE 2
        END ASC,
        avg_amount DESC;

-- Ejercicio 2
CREATE OR REPLACE TABLE `sprint3-analytics-bmancini.sprint3_gold.product_sales_ranking` AS
SELECT p.product_id, p.name, p.price, p.colour, IFNULL(ventas_por_producto.total_sold, 0) AS total_sold
FROM `sprint3-analytics-bmancini.sprint3_silver.products_clean` AS p
LEFT JOIN (
  SELECT product_id, COUNT(*) AS total_sold
  FROM `sprint3-analytics-bmancini.sprint3_silver.transactions_clean`,
	  UNNEST(product_ids) AS product_id
  WHERE declined=0
  GROUP BY product_id) AS ventas_por_producto
ON p.product_id = ventas_por_producto.product_id
ORDER BY total_sold DESC;

-- Ejercicio 3
SELECT *
FROM `sprint3-analytics-bmancini.sprint3_gold.product_sales_ranking`
ORDER BY total_sold DESC;