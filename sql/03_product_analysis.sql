USE walmart_inventory;
GO

-- =========================================
-- PRODUCT ANALYSIS
-- =========================================

-- Top 20 Products by Units Sold
SELECT TOP 20 
    item_id,
    dept_id,
    cat_id,
    SUM(units_sold) AS total_units_sold
from dbo.sales_fact
group by 
    item_id,
    dept_id,
    cat_id
order by 
    total_units_sold desc;


-- Top 20 Products and Their Share of Total demand
SELECT top 20 
    item_id,
    dept_id,
    cat_id,
    sum(units_sold) as total_units_sold,
    round(
        sum(units_sold)*100
        / sum(sum(units_sold)) Over(),
        2
    ) as demand_share
from dbo.sales_fact
group by 
    item_id,
    dept_id,
    cat_id
order by 
    total_units_sold desc ;


-- Bottom 20 Products by Units Sold

SELECT TOP 20
    item_id,
    dept_id,
    cat_id,
    SUM(units_sold) AS total_units_sold
FROM dbo.sales_fact
GROUP BY
    item_id,
    dept_id,
    cat_id
ORDER BY
    total_units_sold ASC;


-- Product Store Coverage of Bottom 20 products

SELECT TOP 20
    item_id,
    cat_id,
    COUNT(DISTINCT store_id) AS stores_selling_product,
    SUM(units_sold) AS total_units_sold
FROM dbo.sales_fact
GROUP BY
    item_id,
    cat_id
ORDER BY
    total_units_sold ASC;

-- Product Demand Variability

SELECT TOP 20
    item_id,
    cat_id,
    ROUND(AVG(units_sold), 2) AS avg_daily_units,
    ROUND(STDEV(units_sold), 2) AS demand_std_dev
FROM dbo.sales_fact
GROUP BY
    item_id,
    cat_id
ORDER BY
    demand_std_dev DESC;


-- Product-Store Demand Variability
-- This gives us how the variability depend on store

SELECT TOP 20
    item_id,
    store_id,
    ROUND(AVG(units_sold), 2) AS avg_daily_units,
    ROUND(STDEV(units_sold), 2) AS demand_std_dev
FROM dbo.sales_fact
GROUP BY
    item_id,
    store_id
ORDER BY
    demand_std_dev DESC;


-- Product Inventory Priority Matrix
-- Approach 1 - Average Thresholds
--(initial failed classification approach)
-- even low demand products as categorised as high demand

WITH product_metrics AS
(
    SELECT
        item_id,
        cat_id,
        AVG(units_sold) AS avg_daily_units,
        STDEV(units_sold) AS demand_std_dev
    FROM dbo.sales_fact
    GROUP BY
        item_id,
        cat_id
),

thresholds AS
(
    SELECT
        AVG(avg_daily_units) AS avg_demand_threshold,
        AVG(demand_std_dev) AS avg_volatility_threshold
    FROM product_metrics
)

SELECT
    p.item_id,
    p.cat_id,
    ROUND(p.avg_daily_units, 2) AS avg_daily_units,
    ROUND(p.demand_std_dev, 2) AS demand_std_dev,

    CASE
        WHEN p.avg_daily_units >= t.avg_demand_threshold
             AND p.demand_std_dev >= t.avg_volatility_threshold
            THEN 'High Demand - High Volatility'

        WHEN p.avg_daily_units >= t.avg_demand_threshold
             AND p.demand_std_dev < t.avg_volatility_threshold
            THEN 'High Demand - Low Volatility'

        WHEN p.avg_daily_units < t.avg_demand_threshold
             AND p.demand_std_dev >= t.avg_volatility_threshold
            THEN 'Low Demand - High Volatility'

        ELSE 'Low Demand - Low Volatility'
    END AS inventory_priority

FROM product_metrics p
CROSS JOIN thresholds t

ORDER BY
    CASE
        WHEN p.avg_daily_units >= t.avg_demand_threshold
             AND p.demand_std_dev >= t.avg_volatility_threshold
            THEN 1
        WHEN p.avg_daily_units >= t.avg_demand_threshold
             AND p.demand_std_dev < t.avg_volatility_threshold
            THEN 2
        WHEN p.avg_daily_units < t.avg_demand_threshold
             AND p.demand_std_dev >= t.avg_volatility_threshold
            THEN 3
        ELSE 4
    END,
    p.avg_daily_units DESC;

-- Approach 2 - Percentile Thresholds
-- Percentile-Based Inventory Priority

WITH product_metrics AS
(
    SELECT
        item_id,
        cat_id,
        AVG(units_sold) AS avg_daily_units,
        STDEV(units_sold) AS demand_std_dev
    FROM dbo.sales_fact
    GROUP BY
        item_id,
        cat_id
),

ranked_products AS
(
    SELECT
        *,
        PERCENT_RANK() OVER (
            ORDER BY avg_daily_units
        ) AS demand_percentile,

        PERCENT_RANK() OVER (
            ORDER BY demand_std_dev
        ) AS volatility_percentile

    FROM product_metrics
)

SELECT
    item_id,
    cat_id,
    ROUND(avg_daily_units, 2) AS avg_daily_units,
    ROUND(demand_std_dev, 2) AS demand_std_dev,

    CASE
        WHEN demand_percentile >= 0.75
             AND volatility_percentile >= 0.75
            THEN 'High Demand - High Volatility'

        WHEN demand_percentile >= 0.75
             AND volatility_percentile < 0.75
            THEN 'High Demand - Low Volatility'

        WHEN demand_percentile < 0.75
             AND volatility_percentile >= 0.75
            THEN 'Low Demand - High Volatility'

        ELSE 'Low Demand - Low Volatility'
    END AS inventory_priority

FROM ranked_products

ORDER BY
    demand_percentile DESC,
    volatility_percentile DESC;

-- Approach 3 - Coefficient of Variation
-- Product Demand Coefficient of Variation

SELECT TOP 20
    item_id,
    cat_id,
    ROUND(AVG(units_sold), 2) AS avg_daily_units,
    ROUND(STDEV(units_sold), 2) AS demand_std_dev,
    ROUND(
        STDEV(units_sold) / NULLIF(AVG(units_sold), 0),
        2
    ) AS coefficient_of_variation
FROM dbo.sales_fact
GROUP BY
    item_id,
    cat_id
ORDER BY
    coefficient_of_variation DESC;


-- final Insight Approach
-- High Demand + High Relative Volatility

WITH product_metrics AS
(
    SELECT
        item_id,
        cat_id,
        AVG(units_sold) AS avg_daily_units,
        STDEV(units_sold) AS demand_std_dev
    FROM dbo.sales_fact
    GROUP BY
        item_id,
        cat_id
),

metrics_with_cv AS
(
    SELECT
        item_id,
        cat_id,
        avg_daily_units,
        demand_std_dev,
        demand_std_dev / NULLIF(avg_daily_units, 0) AS cv
    FROM product_metrics
),

ranked AS
(
    SELECT
        *,
        PERCENT_RANK() OVER (
            ORDER BY avg_daily_units
        ) AS demand_rank,
        PERCENT_RANK() OVER (
            ORDER BY cv
        ) AS cv_rank
    FROM metrics_with_cv
)

SELECT TOP 20
    item_id,
    cat_id,
    ROUND(avg_daily_units, 2) AS avg_daily_units,
    ROUND(demand_std_dev, 2) AS demand_std_dev,
    ROUND(cv, 2) AS coefficient_of_variation,
    ROUND(demand_rank * 100, 1) AS demand_percentile,
    ROUND(cv_rank * 100, 1) AS cv_percentile
FROM ranked
WHERE
    demand_rank >= 0.75
    AND cv_rank >= 0.75
ORDER BY
    demand_rank DESC,
    cv_rank DESC;

-- Approaches Tested:
--
-- Approach 1: Average-Based Classification
-- Used average demand and average volatility as thresholds.
-- The results were too broad and classified too many
-- products as high-demand/high-volatility.
--
-- Approach 2: Percentile-Based Classification
-- Used PERCENT_RANK() to compare products based on their
-- relative demand and volatility.
-- This was better than Approach 1, but the highly uneven
-- demand distribution still made the classification
-- unsuitable for the final analysis.
--
-- Approach 3: Coefficient of Variation (CV)
-- Used CV = Standard Deviation / Average Demand to measure
-- demand variability relative to normal demand.
-- This showed that CV alone can give very high values to
-- products with very low demand.
--
-- Final Approach:
-- Combine demand volume with relative variability.
-- Products are considered potential inventory-risk products
-- when they have both relatively high demand and high CV.
--
-- This final approach was selected because it considers
-- both the importance of the product and the uncertainty
-- in its demand.
--
-- =========================================================