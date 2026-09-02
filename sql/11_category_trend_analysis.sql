USE walmart_inventory;
GO

-- =========================================
-- CATEGORY TREND OVER TIME
--Did each category's share of total demand change over the years?
-- =========================================

SELECT
    YEAR(sale_date) AS sales_year,
    cat_id,
    SUM(units_sold) AS total_units_sold,
    ROUND(
        SUM(CAST(units_sold AS FLOAT)) * 100.0
        / SUM(SUM(CAST(units_sold AS FLOAT)))
            OVER (PARTITION BY YEAR(sale_date)),
        2
    ) AS category_share
FROM dbo.sales_fact
GROUP BY
    YEAR(sale_date),
    cat_id
ORDER BY
    sales_year,
    total_units_sold DESC;