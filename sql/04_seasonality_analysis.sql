USE walmart_inventory;
GO

-- =========================================================
-- SEASONALITY ANALYSIS
-- =========================================================

-- Monthly Demand Pattern

SELECT
    YEAR(sale_date) AS sales_year,
    MONTH(sale_date) AS sales_month,
    SUM(units_sold) AS total_units_sold,
    ROUND(
        sum(units_sold) /COUNT(DISTINCT sale_date),
        2
    ) AS avg_daily_units
FROM dbo.sales_fact
GROUP BY
    YEAR(sale_date),
    MONTH(sale_date)
ORDER BY
    sales_year,
    sales_month;



-- Monthly Seasonal Index

WITH monthly_demand AS
(
    SELECT
        YEAR(sale_date) AS sales_year,
        MONTH(sale_date) AS sales_month,
        SUM(units_sold) * 1.0
            / COUNT(DISTINCT sale_date) AS avg_daily_units
    FROM dbo.sales_fact
    GROUP BY
        YEAR(sale_date),
        MONTH(sale_date)
),

month_average AS
(
    SELECT
        sales_month,
        AVG(avg_daily_units) AS monthly_avg_demand
    FROM monthly_demand
    GROUP BY
        sales_month
),

overall_average AS
(
    SELECT
        AVG(avg_daily_units) AS overall_avg_demand
    FROM monthly_demand
)

SELECT
    m.sales_month,
    ROUND(m.monthly_avg_demand, 2) AS avg_daily_units,
    ROUND(
        m.monthly_avg_demand
        / o.overall_avg_demand,
        3
    ) AS seasonal_index
FROM month_average m
CROSS JOIN overall_average o
ORDER BY
    m.sales_month;


