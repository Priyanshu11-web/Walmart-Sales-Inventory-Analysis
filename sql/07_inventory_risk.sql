USE walmart_inventory;
GO

-- =====================================
-- STORE-PRODUCT INVENTORY RISK
-- =====================================
-- Store-Product Demand and Volatility

SELECT TOP 20
    item_id,
    store_id,
    ROUND(AVG(units_sold), 2) AS avg_daily_units,
    ROUND(STDEV(units_sold), 2) AS demand_std_dev,
    ROUND(
        STDEV(units_sold) * 1.0
        / NULLIF(AVG(units_sold), 0),
        2
    ) AS coefficient_of_variation
FROM dbo.sales_fact
GROUP BY
    item_id,
    store_id
HAVING
    AVG(units_sold) > 0
ORDER BY
    avg_daily_units DESC;


-- =========================================================
-- INVENTORY RISK RANKING
-- Tested approach - not used as final ranking
-- =========================================================

WITH store_product_metrics AS
(
    SELECT
        item_id,
        store_id,
        AVG(units_sold) AS avg_daily_units,
        STDEV(units_sold) AS demand_std_dev
    FROM dbo.sales_fact
    GROUP BY
        item_id,
        store_id
),

metrics_with_cv AS
(
    SELECT
        item_id,
        store_id,
        avg_daily_units,
        demand_std_dev,
        demand_std_dev * 1.0
            / NULLIF(avg_daily_units, 0) AS cv
    FROM store_product_metrics
),

ranked_metrics AS
(
    SELECT
        *,
        PERCENT_RANK() OVER (
            ORDER BY avg_daily_units
        ) AS demand_percentile,

        PERCENT_RANK() OVER (
            ORDER BY cv
        ) AS cv_percentile
    FROM metrics_with_cv
)

SELECT TOP 20
    item_id,
    store_id,
    ROUND(avg_daily_units, 2) AS avg_daily_units,
    ROUND(demand_std_dev, 2) AS demand_std_dev,
    ROUND(cv, 2) AS coefficient_of_variation,
    ROUND(demand_percentile * 100, 2) AS demand_percentile,
    ROUND(cv_percentile * 100, 2) AS cv_percentile,

    ROUND(
        (demand_percentile + cv_percentile) / 2.0,
        3
    ) AS inventory_risk_score

FROM ranked_metrics
ORDER BY
    inventory_risk_score DESC;

-- We tested a CV-based risk approach, but it gave too much importance to
--low-volume products. Therefore, we used demand and standard deviation
--together for the final inventory risk ranking.



-- =========================================================
-- TESTED/REJECTED STORE-PRODUCT INVENTORY RISK RANKING
-- =========================================================

WITH store_product_metrics AS
(
    SELECT
        item_id,
        store_id,
        AVG(units_sold) AS avg_daily_units,
        STDEV(units_sold) AS demand_std_dev
    FROM dbo.sales_fact
    GROUP BY
        item_id,
        store_id
)

SELECT TOP 20
    item_id,
    store_id,
    ROUND(avg_daily_units, 2) AS avg_daily_units,
    ROUND(demand_std_dev, 2) AS demand_std_dev,
    ROUND(
        demand_std_dev * 1.0
        / NULLIF(avg_daily_units, 0),
        2
    ) AS coefficient_of_variation,

    ROUND(
        avg_daily_units * demand_std_dev,
        2
    ) AS inventory_risk_score

FROM store_product_metrics

WHERE avg_daily_units > 0

ORDER BY
    inventory_risk_score DESC;



-- HIGH-DEMAND + HIGH-VOLATILITY APPROACH
USE walmart_inventory;
GO

WITH store_product_metrics AS
(
    SELECT
        item_id,
        store_id,
        AVG(CAST(units_sold AS FLOAT)) AS avg_daily_units,
        STDEV(CAST(units_sold AS FLOAT)) AS demand_std_dev
    FROM dbo.sales_fact
    GROUP BY
        item_id,
        store_id
),

overall_average AS
(
    SELECT
        AVG(avg_daily_units) AS avg_demand
    FROM store_product_metrics
),

high_demand AS
(
    SELECT
        s.*
    FROM store_product_metrics s
    CROSS JOIN overall_average o
    WHERE s.avg_daily_units > o.avg_demand
),

volatility_average AS
(
    SELECT
        AVG(demand_std_dev) AS avg_std_dev
    FROM high_demand
),

high_demand_high_volatility AS
(
    SELECT
        h.*
    FROM high_demand h
    CROSS JOIN volatility_average v
    WHERE h.demand_std_dev > v.avg_std_dev
)

SELECT TOP 15
    item_id,
    store_id,
    ROUND(avg_daily_units, 2) AS avg_daily_units,
    ROUND(demand_std_dev, 2) AS demand_std_dev
FROM high_demand_high_volatility
ORDER BY
    demand_std_dev DESC,
    avg_daily_units DESC;

-- =========================================================
-- DEMAND CONCENTRATION
-- =========================================================

-- Top Products and Their Share of Total Demand

WITH product_demand AS
(
    SELECT
        item_id,
        SUM(units_sold) AS total_units_sold
    FROM dbo.sales_fact
    GROUP BY
        item_id
),

ranked_products AS
(
    SELECT
        item_id,
        total_units_sold,
        SUM(total_units_sold) OVER () AS overall_demand,
        SUM(total_units_sold) OVER (
            ORDER BY total_units_sold DESC
            ROWS BETWEEN UNBOUNDED PRECEDING
                 AND CURRENT ROW
        ) AS cumulative_demand
    FROM product_demand
)

SELECT TOP 20
    item_id,
    total_units_sold,
    ROUND(
        total_units_sold * 100.0 / overall_demand,
        2
    ) AS demand_share_pct,
    ROUND(
        cumulative_demand * 100.0 / overall_demand,
        2
    ) AS cumulative_demand_share_pct
FROM ranked_products
ORDER BY
    total_units_sold DESC;


-- DEMAND INTERMITTENCY

SELECT TOP 20 
	item_id,
	cat_id,
	count(distinct sale_date) as selling_days,
	sum(units_sold) as total_units_sold,
	round(
		sum(units_sold) * 1.0
		/count(distinct sale_date)
		,2
		) as avg_units_per_selling_day
FROM DBO.sales_fact
where units_sold>0
group by 
	item_id,
	cat_id
order by 
	selling_days asc,
	total_units_sold desc;

--STABLE HIGH-DEMAND PRODUCTS

with product_metrics AS 
(
	SELECT
		item_id,
		round(avg(units_sold),2) as avg_daily_units,
		round(STDEV(units_sold),2) as demand_std_dev
	FROM 
		dbo.sales_fact
	GROUP BY
		item_id


)

SELECT TOP 20 
		item_id,
		avg_daily_units,
		demand_std_dev,
		round(
		demand_std_dev * 1.0
		/ NULLIF(avg_daily_units,0),
		2
		) AS coefficient_of_variation
FROM product_metrics
WHERE avg_daily_units > 10
ORDER BY 
	coefficient_of_variation ASC,
	avg_daily_units DESC;