-- =========================================
-- STORE GROWTH / DECLINE
-- measure change in annual demand for each store, 
-- not just rank stores by total sales.
-- =========================================

WITH yearly_store_sales AS
(
    SELECT
        store_id,
        YEAR(sale_date) AS sales_year,
        SUM(CAST(units_sold AS FLOAT)) AS annual_units_sold
    FROM dbo.sales_fact
    GROUP BY
        store_id,
        YEAR(sale_date)
),

store_growth AS
(
    SELECT
        store_id,
        sales_year,
        annual_units_sold,
        LAG(annual_units_sold) OVER (
            PARTITION BY store_id
            ORDER BY sales_year
        ) AS previous_year_units
    FROM yearly_store_sales
)

SELECT
    store_id,
    sales_year,
    ROUND(annual_units_sold, 0) AS annual_units_sold,
    ROUND(previous_year_units, 0) AS previous_year_units,
    ROUND(
        (annual_units_sold - previous_year_units)
        * 100.0
        / NULLIF(previous_year_units, 0),
        2
    ) AS yoy_growth_pct
FROM store_growth
WHERE previous_year_units IS NOT NULL
ORDER BY
    store_id,
    sales_year;