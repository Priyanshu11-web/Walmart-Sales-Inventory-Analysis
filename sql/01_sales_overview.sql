USE walmart_inventory;
GO

-- Overall Sales KPI
SELECT
    SUM(units_sold) AS total_units_sold,
    COUNT(DISTINCT sale_date) AS selling_days,
    ROUND(
        SUM(units_sold) * 1.0
        / COUNT(DISTINCT sale_date),
        2
    ) AS avg_daily_units
FROM dbo.sales_fact;




-- Yearly Sales Trend
SELECT
    YEAR(sale_date) AS sales_year,
    SUM(units_sold) AS total_units_sold,
    COUNT(DISTINCT sale_date) AS selling_days,
    ROUND(
        SUM(units_sold) * 1.0
        / COUNT(DISTINCT sale_date),
        2
    ) AS avg_daily_units
FROM dbo.sales_fact
GROUP BY YEAR(sale_date)
ORDER BY sales_year;


-- Category Performance
SELECT
    cat_id,
    SUM(units_sold) AS total_units_sold,
    ROUND(
        SUM(units_sold) * 100.0
        / SUM(SUM(units_sold)) OVER (),
        2
    ) AS sales_percentage
FROM dbo.sales_fact
GROUP BY cat_id
ORDER BY total_units_sold DESC;


