USE walmart_inventory;
GO

-- =========================================
-- PRICE × DEMAND ANALYSIS
-- =========================================

-- Validate the price join before analysis

SELECT TOP 20
    s.item_id,
    s.store_id,
    s.sale_date,
    c.wm_yr_wk,
    s.units_sold,
    ROUND(p.sell_price, 2) AS sell_price
FROM dbo.sales_fact s
JOIN dbo.calendar c
    ON s.sale_date = c.date
JOIN dbo.sell_prices p
    ON s.item_id = p.item_id
    AND s.store_id = p.store_id
    AND c.wm_yr_wk = p.wm_yr_wk
WHERE s.sale_date = '2011-01-29';



-- Baseline: Average Price vs Average Weekly Demand

WITH weekly_sales AS
(
    SELECT
        s.item_id,
        s.store_id,
        c.wm_yr_wk,
        SUM(s.units_sold) AS weekly_units_sold
    FROM dbo.sales_fact s
    JOIN dbo.calendar c
        ON s.sale_date = c.date
    GROUP BY
        s.item_id,
        s.store_id,
        c.wm_yr_wk
)
SELECT TOP 20
    w.item_id,
    w.store_id,
    ROUND(AVG(p.sell_price), 2) AS avg_price,
    ROUND(AVG(w.weekly_units_sold) * 1.0, 2) AS avg_weekly_units
FROM weekly_sales w
JOIN dbo.sell_prices p
    ON w.item_id = p.item_id
    AND w.store_id = p.store_id
    AND w.wm_yr_wk = p.wm_yr_wk
GROUP BY
    w.item_id,
    w.store_id
ORDER BY
    avg_weekly_units DESC;