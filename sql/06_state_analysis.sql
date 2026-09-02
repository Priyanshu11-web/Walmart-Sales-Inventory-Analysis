USE walmart_inventory;
GO

-- =========================================================
-- STATE-LEVEL DEMAND ANALYSIS
-- =========================================================

-- Total Demand and Average Daily Demand by State

SELECT
    state_id,
    SUM(units_sold) AS total_units_sold,
    ROUND(
        SUM(units_sold) * 1.0
        / COUNT(DISTINCT sale_date),
        2
    ) AS avg_daily_units
FROM dbo.sales_fact
GROUP BY
    state_id
ORDER BY
    total_units_sold DESC;