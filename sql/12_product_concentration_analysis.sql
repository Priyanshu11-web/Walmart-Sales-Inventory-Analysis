-- =========================================
-- PRODUCT CONCENTRATION / PARETO ANALYSIS
-- How concentrated is total demand among the top-selling products?
-- =========================================

WITH product_sales AS
(
    SELECT
        item_id,
        SUM(CAST(units_sold AS FLOAT)) AS total_units_sold
    FROM dbo.sales_fact
    GROUP BY item_id
),

ranked_products AS
(
    SELECT
        item_id,
        total_units_sold,
        SUM(total_units_sold) OVER () AS overall_units,
        SUM(total_units_sold) OVER (
            ORDER BY total_units_sold DESC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS cumulative_units
    FROM product_sales
)

SELECT
    item_id,
    total_units_sold,
    ROUND(
        total_units_sold * 100.0 / overall_units,
        2
    ) AS sales_share_pct,
    ROUND(
        cumulative_units * 100.0 / overall_units,
        2
    ) AS cumulative_share_pct
FROM ranked_products
ORDER BY
    total_units_sold DESC;