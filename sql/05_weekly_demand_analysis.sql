USE walmart_inventory;
GO

-- =========================================================
-- WEEKLY DEMAND ANALYSIS
-- =========================================================

-- Day-of-Week Demand Pattern

SELECT
    c.wday,
    c.weekday,
    SUM(s.units_sold) AS total_units_sold,
    ROUND(
        SUM(s.units_sold)*1.0
        / COUNT(DISTINCT s.sale_date),
        2
    ) AS avg_daily_units
FROM dbo.sales_fact s
JOIN dbo.calendar c
    ON s.sale_date = c.date
GROUP BY
    c.wday,
    c.weekday
ORDER BY
    c.wday;


-- Weekly Demand by Category

SELECT
    c.wday,
    c.weekday,
    s.cat_id,
    SUM(s.units_sold) AS total_units_sold,
    ROUND(
        SUM(s.units_sold) * 1.0
        / COUNT(DISTINCT s.sale_date),
        2
    ) AS avg_daily_units
FROM dbo.sales_fact s
JOIN dbo.calendar c
    ON s.sale_date = c.date
GROUP BY
    c.wday,
    c.weekday,
    s.cat_id
ORDER BY
    s.cat_id,
    c.wday;


-- Weekly Demand by Store

SELECT
    c.wday,
    c.weekday,
    s.store_id,
    SUM(s.units_sold) AS total_units_sold,
    ROUND(
        SUM(s.units_sold) * 1.0
        / COUNT(DISTINCT s.sale_date),
        2
    ) AS avg_daily_units
FROM dbo.sales_fact s
JOIN dbo.calendar c
    ON s.sale_date = c.date
GROUP BY
    c.wday,
    c.weekday,
    s.store_id
ORDER BY
    s.store_id,
    c.wday;




-- Weekend Demand Uplift by Store

WITH daily_store_demand AS
(
    SELECT
        s.store_id,
        s.sale_date,
        c.weekday,
        SUM(s.units_sold) AS daily_units_sold
    FROM dbo.sales_fact s
    JOIN dbo.calendar c
        ON s.sale_date = c.date
    GROUP BY
        s.store_id,
        s.sale_date,
        c.weekday
),

store_weekend_metrics AS
(
    SELECT
        store_id,

        AVG(
            CASE
                WHEN weekday IN ('Saturday', 'Sunday')
                THEN daily_units_sold * 1.0
            END
        ) AS weekend_avg,

        AVG(
            CASE
                WHEN weekday NOT IN ('Saturday', 'Sunday')
                THEN daily_units_sold * 1.0
            END
        ) AS weekday_avg

    FROM daily_store_demand
    GROUP BY
        store_id
)

SELECT
    store_id,
    ROUND(weekday_avg, 2) AS weekday_avg_daily_units,
    ROUND(weekend_avg, 2) AS weekend_avg_daily_units,
    ROUND(
        (weekend_avg - weekday_avg)
        * 100.0
        / NULLIF(weekday_avg, 0),
        2
    ) AS weekend_uplift_pct
FROM store_weekend_metrics
ORDER BY
    weekend_uplift_pct DESC;