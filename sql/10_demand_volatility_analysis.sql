-- =========================================
-- DEMAND VOLATILITY BY STORE
-- =========================================

WITH daily_store_demand AS
(
    SELECT
        store_id,
        sale_date,
        SUM(CAST(units_sold AS FLOAT)) AS daily_units
    FROM dbo.sales_fact
    GROUP BY
        store_id,
        sale_date
),

store_stats AS
(
    SELECT
        store_id,
        AVG(daily_units) AS avg_daily_demand,
        STDEV(daily_units) AS demand_std_dev
    FROM daily_store_demand
    GROUP BY
        store_id
)

SELECT
    store_id,
    ROUND(avg_daily_demand, 2) AS avg_daily_demand,
    ROUND(demand_std_dev, 2) AS demand_std_dev,
    ROUND(
        demand_std_dev / NULLIF(avg_daily_demand, 0),
        3
    ) AS coefficient_of_variation
FROM store_stats
ORDER BY
    coefficient_of_variation DESC;