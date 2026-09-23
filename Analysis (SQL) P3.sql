-- Databricks notebook source

USE CATALOG campaign_offer_analytics;
USE SCHEMA dataset;


-- COMMAND ----------



SELECT 'campaigns' AS table_name, COUNT(*) AS row_count FROM campaigns
UNION ALL
SELECT 'campaign_funnel', COUNT(*) FROM campaign_funnel
UNION ALL
SELECT 'acquired_customers', COUNT(*) FROM acquired_customers
UNION ALL
SELECT 'customer_spend_by_category', COUNT(*) FROM customer_spend_by_category
UNION ALL
SELECT 'offer_redemptions', COUNT(*) FROM offer_redemptions;



-- COMMAND ----------

SELECT * FROM campaign_funnel LIMIT 5;



-- COMMAND ----------


SELECT DISTINCT channel FROM campaigns;



-- COMMAND ----------


SELECT 
    c.channel,
    ROUND(AVG(f.cost_per_activation), 2) AS avg_cost_per_activation
FROM campaign_funnel f
JOIN campaigns c ON f.campaign_id = c.campaign_id
GROUP BY c.channel
ORDER BY avg_cost_per_activation;

-- COMMAND ----------

SELECT
    c.channel,
    SUM(f.impressions) AS total_impressions,
    SUM(f.clicks) AS total_clicks,
    SUM(f.applications) AS total_applications,
    SUM(f.approvals) AS total_approvals,
    SUM(f.activations) AS total_activations,
    ROUND(100.0 * SUM(f.clicks) / NULLIF(SUM(f.impressions), 0), 3) AS click_through_rate_pct,
    ROUND(100.0 * SUM(f.applications) / NULLIF(SUM(f.clicks), 0), 2) AS application_rate_pct,
    ROUND(100.0 * SUM(f.approvals) / NULLIF(SUM(f.applications), 0), 2) AS approval_rate_pct,
    ROUND(100.0 * SUM(f.activations) / NULLIF(SUM(f.approvals), 0), 2) AS activation_rate_pct,
    ROUND(100.0 * SUM(f.activations) / NULLIF(SUM(f.impressions), 0), 4) AS overall_conversion_pct
FROM campaign_funnel f
JOIN campaigns c ON f.campaign_id = c.campaign_id
GROUP BY c.channel
ORDER BY overall_conversion_pct DESC;

-- COMMAND ----------

WITH channel_cost AS (
    SELECT
        c.channel,
        SUM(f.budget_usd) AS total_budget,
        SUM(f.activations) AS total_activations,
        ROUND(SUM(f.budget_usd) / NULLIF(SUM(f.activations), 0), 2) AS cost_per_activation
    FROM campaign_funnel f
    JOIN campaigns c ON f.campaign_id = c.campaign_id
    GROUP BY c.channel
)
SELECT
    channel,
    total_budget,
    total_activations,
    cost_per_activation,
    RANK() OVER (ORDER BY cost_per_activation ASC) AS efficiency_rank
FROM channel_cost
ORDER BY cost_per_activation ASC;

-- COMMAND ----------

WITH monthly_activations AS (
    SELECT
        DATE_TRUNC('month', c.start_date) AS campaign_month,
        SUM(f.activations) AS total_activations
    FROM campaign_funnel f
    JOIN campaigns c ON f.campaign_id = c.campaign_id
    GROUP BY DATE_TRUNC('month', c.start_date)
)
SELECT
    campaign_month,
    total_activations,
    LAG(total_activations) OVER (ORDER BY campaign_month) AS prev_month_activations,
    ROUND(100.0 * (total_activations - LAG(total_activations) OVER (ORDER BY campaign_month))
          / NULLIF(LAG(total_activations) OVER (ORDER BY campaign_month), 0), 2) AS mom_growth_pct
FROM monthly_activations
ORDER BY campaign_month;

-- COMMAND ----------

WITH ranked_campaigns AS (
    SELECT
        c.card_product,
        c.campaign_name,
        c.channel,
        f.activations,
        DENSE_RANK() OVER (PARTITION BY c.card_product ORDER BY f.activations DESC) AS performance_rank
    FROM campaign_funnel f
    JOIN campaigns c ON f.campaign_id = c.campaign_id
)
SELECT card_product, campaign_name, channel, activations
FROM ranked_campaigns
WHERE performance_rank = 1
ORDER BY activations DESC;

-- COMMAND ----------

WITH acquired_by_offer AS (
    SELECT
        c.offer_type,
        COUNT(DISTINCT ac.customer_id) AS total_acquired
    FROM acquired_customers ac
    JOIN campaigns c ON ac.campaign_id = c.campaign_id
    GROUP BY c.offer_type
),
redeemed_by_offer AS (
    SELECT
        offer_type,
        COUNT(DISTINCT customer_id) AS total_redeemed
    FROM offer_redemptions
    GROUP BY offer_type
)
SELECT
    a.offer_type,
    a.total_acquired,
    COALESCE(r.total_redeemed, 0) AS total_redeemed,
    ROUND(100.0 * COALESCE(r.total_redeemed, 0) / a.total_acquired, 2) AS redemption_rate_pct
FROM acquired_by_offer a
LEFT JOIN redeemed_by_offer r ON a.offer_type = r.offer_type
ORDER BY redemption_rate_pct DESC;

-- COMMAND ----------

SELECT
    customer_id,
    travel,
    dining,
    grocery,
    online_shopping,
    ROUND(PERCENT_RANK() OVER (ORDER BY travel DESC), 4) AS travel_spend_percentile,
    ROUND(PERCENT_RANK() OVER (ORDER BY dining DESC), 4) AS dining_spend_percentile
FROM customer_spend_by_category
ORDER BY travel DESC
LIMIT 100;

-- COMMAND ----------

SELECT
    true_persona,
    ROUND(AVG(travel), 2) AS avg_travel,
    ROUND(AVG(dining), 2) AS avg_dining,
    ROUND(AVG(grocery), 2) AS avg_grocery,
    ROUND(AVG(online_shopping), 2) AS avg_online_shopping,
    ROUND(AVG(gas), 2) AS avg_gas,
    ROUND(AVG(entertainment), 2) AS avg_entertainment,
    COUNT(*) AS customer_count
FROM customer_spend_by_category
GROUP BY true_persona
ORDER BY customer_count DESC;

-- COMMAND ----------

WITH channel_perf AS (
    SELECT
        c.channel,
        AVG(f.activations) AS avg_activations_per_campaign
    FROM campaign_funnel f
    JOIN campaigns c ON f.campaign_id = c.campaign_id
    GROUP BY c.channel
),
overall_avg AS (
    SELECT AVG(avg_activations_per_campaign) AS overall_avg_activations
    FROM channel_perf
)
SELECT
    cp.channel,
    ROUND(cp.avg_activations_per_campaign, 1) AS avg_activations_per_campaign,
    ROUND(oa.overall_avg_activations, 1) AS overall_avg,
    ROUND(cp.avg_activations_per_campaign - oa.overall_avg_activations, 1) AS diff_from_avg,
    CASE
        WHEN cp.avg_activations_per_campaign > oa.overall_avg_activations THEN 'Above Average'
        ELSE 'Below Average'
    END AS performance_flag
FROM channel_perf cp
CROSS JOIN overall_avg oa
ORDER BY diff_from_avg DESC;

-- COMMAND ----------

SELECT
    c.card_product,
    SUM(f.budget_usd) AS total_budget,
    SUM(f.activations) AS total_activations,
    ROUND(SUM(f.budget_usd) / NULLIF(SUM(f.activations), 0), 2) AS cost_per_activation,
    SUM(r.redemption_value_usd) AS total_redemption_value
FROM campaign_funnel f
JOIN campaigns c ON f.campaign_id = c.campaign_id
LEFT JOIN acquired_customers ac ON c.campaign_id = ac.campaign_id
LEFT JOIN offer_redemptions r ON ac.customer_id = r.customer_id
GROUP BY c.card_product
ORDER BY cost_per_activation ASC;

-- COMMAND ----------

SELECT
    home_state,
    COUNT(*) AS customers_acquired,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_total
FROM acquired_customers
GROUP BY home_state
ORDER BY customers_acquired DESC;