USE walmart_inventory;
GO

-- =========================================
-- STORE ANALYSIS
-- =========================================

-- Store × Category Performance

SELECT
    store_id,
    cat_id,
    SUM(units_sold) AS total_units_sold,
    ROUND(
        SUM(units_sold) * 100.0
        / SUM(SUM(units_sold)) OVER (PARTITION BY store_id),
        2
    ) AS category_share
FROM dbo.sales_fact
GROUP BY
    store_id,
    cat_id
ORDER BY
    store_id,
    total_units_sold DESC;


    -- Average Daily Demand by Store

SELECT
    store_id,
    SUM(units_sold) AS total_units_sold,
    COUNT(DISTINCT sale_date) AS selling_days,
    ROUND(
        SUM(units_sold) * 1.0
        / COUNT(DISTINCT sale_date),
        2
    ) AS avg_daily_units
FROM dbo.sales_fact
GROUP BY store_id
ORDER BY avg_daily_units DESC;


-- Store Yearly Demand Trend

SELECT
    store_id,
    YEAR(sale_date) AS sales_year,
    SUM(units_sold) AS total_units_sold,
    ROUND(
        SUM(units_sold) * 1.0
        / COUNT(DISTINCT sale_date),
        2
    ) AS avg_daily_units
FROM dbo.sales_fact
GROUP BY
    store_id,
    YEAR(sale_date)
ORDER BY
    store_id,
    sales_year;