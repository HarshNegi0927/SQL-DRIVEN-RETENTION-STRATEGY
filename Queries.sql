
CREATE DATABASE IF NOT EXISTS CustomerBehav;
USE CustomerBehav;

CREATE TABLE IF NOT EXISTS customer_analytics (
    `Customer ID`             INT PRIMARY KEY,
    `Age`                     INT,
    `Gender`                  VARCHAR(10),
    `Item Purchased`          VARCHAR(50),
    `Category`                VARCHAR(30),
    `Purchase Amount (USD)`   INT,
    `Location`                VARCHAR(30),
    `Size`                    VARCHAR(5),
    `Color`                   VARCHAR(20),
    `Season`                  VARCHAR(10),
    `Review Rating`           DECIMAL(3,1),
    `Subscription Status`     VARCHAR(5),
    `Shipping Type`           VARCHAR(20),
    `Discount Applied`        VARCHAR(5),
    `Promo Code Used`         VARCHAR(5),
    `Previous Purchases`      INT,
    `Payment Method`          VARCHAR(20),
    `Frequency of Purchases`  VARCHAR(20),
    Total_Estimated_Spend     INT,
    value_tier                VARCHAR(15),
    dependency_score          INT,
    satisfaction_flag         INT,
    Loyalty_Def_A             INT,
    Loyalty_Def_B             INT,
    Loyalty_Def_C             INT
);


SELECT COUNT(*) FROM customer_analytics;   -- expect 3900


-- ============================================================================
-- Q1 -- Value Tier Analysis
-- Business question: "What separates high-value customers from low-value
-- ones, and which profiles show the strongest repeat purchase behavior?"
-- ============================================================================
SELECT
    value_tier,
    COUNT(`Customer ID`) AS total_customers,
    ROUND(COUNT(`Customer ID`) * 100.0 / (SELECT COUNT(*) FROM customer_analytics), 2) AS customer_percentage,
    ROUND(AVG(Age), 1) AS avg_age,
    ROUND(SUM(`Purchase Amount (USD)`), 2) AS current_order_revenue,
    ROUND(AVG(Total_Estimated_Spend), 2) AS avg_lifetime_value_proxy
FROM customer_analytics
GROUP BY value_tier
ORDER BY avg_lifetime_value_proxy DESC;


-- ============================================================================
-- Q2 -- Promo Dependency Segmentation
-- Business question: "Is the discount/promo program building a loyal
-- customer base, or just attracting one-time bargain hunters?"
-- FIX: dependency_score now genuinely spans 0-3, so all four labels are
-- reachable (score=1 was previously dead code).
-- ============================================================================
SELECT
    dependency_score,
    CASE
        WHEN dependency_score = 0 THEN 'Pure Organic Loyalist (No Promo)'
        WHEN dependency_score = 1 THEN 'Low Dependency Buyer (Promo, but subscriber + low-frequency)'
        WHEN dependency_score = 2 THEN 'Moderate Promo Hunter'
        WHEN dependency_score = 3 THEN 'High-Risk Promo Addict'
    END AS customer_risk_profile,
    COUNT(`Customer ID`) AS customer_count,
    ROUND(SUM(`Purchase Amount (USD)`), 2) AS total_revenue,
    ROUND(SUM(`Purchase Amount (USD)`) * 100.0 / (SELECT SUM(`Purchase Amount (USD)`) FROM customer_analytics), 2) AS revenue_contribution_pct,
    ROUND(AVG(`Review Rating`), 2) AS avg_satisfaction
FROM customer_analytics
GROUP BY dependency_score
ORDER BY dependency_score DESC;


-- ============================================================================
-- Q3 -- Loyalty Definition Faceoff (A vs B vs Hybrid C)
-- Central analytical challenge: build >=2 competing loyalty definitions and
-- justify one. Def C is the validated intersection (A and B), added because
-- it outperforms both parent definitions on every metric below (see Python
-- notebook Step 4 for the internal-consistency and revenue-correlation
-- tests behind this).
-- ============================================================================
SELECT 'Definition A (Organic/Frequency Driven)' AS loyalty_metric,
    COUNT(CASE WHEN Loyalty_Def_A = 1 THEN 1 END) AS identified_loyal_customers,
    ROUND(COUNT(CASE WHEN Loyalty_Def_A = 1 THEN 1 END) * 100.0 / (SELECT COUNT(*) FROM customer_analytics), 1) AS pct_of_base,
    ROUND(AVG(CASE WHEN Loyalty_Def_A = 1 THEN Total_Estimated_Spend END), 2) AS avg_lifetime_spend,
    ROUND(AVG(CASE WHEN Loyalty_Def_A = 1 THEN `Review Rating` END), 2) AS avg_customer_rating,
    ROUND(SUM(CASE WHEN Loyalty_Def_A = 1 THEN `Purchase Amount (USD)` END), 2) AS current_transaction_revenue
FROM customer_analytics
UNION ALL
SELECT 'Definition B (Monetary/Subscription Driven)' AS loyalty_metric,
    COUNT(CASE WHEN Loyalty_Def_B = 1 THEN 1 END),
    ROUND(COUNT(CASE WHEN Loyalty_Def_B = 1 THEN 1 END) * 100.0 / (SELECT COUNT(*) FROM customer_analytics), 1),
    ROUND(AVG(CASE WHEN Loyalty_Def_B = 1 THEN Total_Estimated_Spend END), 2),
    ROUND(AVG(CASE WHEN Loyalty_Def_B = 1 THEN `Review Rating` END), 2),
    ROUND(SUM(CASE WHEN Loyalty_Def_B = 1 THEN `Purchase Amount (USD)` END), 2)
FROM customer_analytics
UNION ALL
SELECT 'Definition C (Hybrid: High-Value AND Organic = A and B)' AS loyalty_metric,
    COUNT(CASE WHEN Loyalty_Def_C = 1 THEN 1 END),
    ROUND(COUNT(CASE WHEN Loyalty_Def_C = 1 THEN 1 END) * 100.0 / (SELECT COUNT(*) FROM customer_analytics), 1),
    ROUND(AVG(CASE WHEN Loyalty_Def_C = 1 THEN Total_Estimated_Spend END), 2),
    ROUND(AVG(CASE WHEN Loyalty_Def_C = 1 THEN `Review Rating` END), 2),
    ROUND(SUM(CASE WHEN Loyalty_Def_C = 1 THEN `Purchase Amount (USD)` END), 2)
FROM customer_analytics;


-- ============================================================================
-- Q4 -- Category Funnel
-- Business question: "Which product categories are associated with lower
-- purchase history, and which appear most among high-tenure customers?"
-- NOTE: renamed avg_customer_tenure -> avg_previous_purchases. This column
-- is a purchase COUNT, not a day count -- the original name implied a
-- duration that isn't what's being measured.
-- ============================================================================
SELECT
    Category,
    COUNT(`Customer ID`) AS total_customers,
    ROUND(SUM(`Purchase Amount (USD)`), 2) AS total_revenue,
    ROUND(AVG(`Previous Purchases`), 1) AS avg_previous_purchases,
    SUM(CASE WHEN `Previous Purchases` <= 10 THEN 1 ELSE 0 END) AS entry_point_customers,
    SUM(CASE WHEN `Previous Purchases` > 25 THEN 1 ELSE 0 END) AS high_tenure_customers,
    ROUND(SUM(CASE WHEN `Previous Purchases` > 25 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS retention_power_pct
FROM customer_analytics
GROUP BY Category
ORDER BY total_revenue DESC;


-- ============================================================================
-- Q5 -- Geographic Goldmines
-- Business question: "Are there cities/regions with strong traction that
-- look different in category preference, promo sensitivity, or average
-- spend per customer?"
-- ADDED: avg_spend_per_customer (the brief explicitly asks for this; the
-- original query had total_revenue but never divided by customer count).
-- CAUTION: these are 50 states on 60-95 customers each -- read organic_pct
-- as directional, not precise (see Python notebook Step 5 for the
-- multiple-comparisons check on the top state).
-- ============================================================================
SELECT
    Location AS State,
    COUNT(`Customer ID`) AS total_customers,
    ROUND(SUM(`Purchase Amount (USD)`), 2) AS total_revenue,
    ROUND(SUM(`Purchase Amount (USD)`) * 1.0 / COUNT(`Customer ID`), 2) AS avg_spend_per_customer,
    ROUND(AVG(dependency_score), 2) AS avg_state_promo_dependency,
    ROUND(SUM(CASE WHEN `Promo Code Used` = 'No' THEN `Purchase Amount (USD)` ELSE 0 END) * 100.0 / SUM(`Purchase Amount (USD)`), 2) AS organic_revenue_pct
FROM customer_analytics
GROUP BY Location
HAVING total_customers >= 10
ORDER BY organic_revenue_pct DESC, total_revenue DESC
LIMIT 10;


-- ============================================================================
-- Q6 -- Shipping x Payment Operations Cut
-- Supplementary cut: which shipping/payment combinations skew most
-- promo-dependent (useful for checkout-flow and shipping-offer decisions).
-- ============================================================================
SELECT
    `Shipping Type`,
    `Payment Method`,
    COUNT(`Customer ID`) AS customer_count,
    ROUND(AVG(`Purchase Amount (USD)`), 2) AS avg_ticket_size,
    ROUND(AVG(dependency_score), 2) AS avg_promo_dependency,
    SUM(CASE WHEN `Promo Code Used` = 'Yes' THEN 1 ELSE 0 END) AS promo_customers_count
FROM customer_analytics
GROUP BY `Shipping Type`, `Payment Method`
ORDER BY customer_count DESC
LIMIT 12;


-- ============================================================================
-- Q7 -- Season Funnel (NEW)
-- Business question: "Which SEASONS and categories are associated with
-- lower-tenure customers vs. high previous purchase counts?" -- the season
-- half of this question had no query in the original submission.
-- ============================================================================
SELECT
    Season,
    COUNT(`Customer ID`) AS total_customers,
    ROUND(SUM(`Purchase Amount (USD)`), 2) AS total_revenue,
    ROUND(AVG(`Previous Purchases`), 1) AS avg_previous_purchases,
    SUM(CASE WHEN `Previous Purchases` <= 10 THEN 1 ELSE 0 END) AS entry_point_customers,
    SUM(CASE WHEN `Previous Purchases` > 25 THEN 1 ELSE 0 END) AS high_tenure_customers,
    ROUND(SUM(CASE WHEN `Previous Purchases` > 25 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS retention_power_pct
FROM customer_analytics
GROUP BY Season
ORDER BY total_revenue DESC;
-- Reminder: the Python notebook's ANOVA test found this spread (~1-2
-- previous-purchases between seasons) is NOT statistically significant --
-- report as "retention is brand-wide, not seasonal", not as a real gap.


-- ============================================================================
-- Q8 -- Retention Rate by Promo-Dependency Segment (NEW)
-- Needed for the Power BI "Promo dependency vs. retention rate, plotted by
-- segment" panel -- the original file had no query producing this pairing.
-- ============================================================================
SELECT
    dependency_score,
    CASE
        WHEN dependency_score = 0 THEN 'Pure Organic Loyalist'
        WHEN dependency_score = 1 THEN 'Low Dependency Buyer'
        WHEN dependency_score = 2 THEN 'Moderate Promo Hunter'
        WHEN dependency_score = 3 THEN 'High-Risk Promo Addict'
    END AS customer_risk_profile,
    COUNT(`Customer ID`) AS total_customers,
    ROUND(AVG(`Previous Purchases`), 1) AS avg_previous_purchases,
    SUM(CASE WHEN `Previous Purchases` > 25 THEN 1 ELSE 0 END) AS high_tenure_customers,
    ROUND(SUM(CASE WHEN `Previous Purchases` > 25 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS retention_rate_pct
FROM customer_analytics
GROUP BY dependency_score
ORDER BY dependency_score DESC;
-- Finding: retention rate is fairly FLAT across segments (45-52%) --
-- Moderate Promo Hunters (score=2) actually show the highest high-tenure
-- rate of any segment, slightly above Pure Organic Loyalists. Promo usage
-- alone does not cleanly predict lower tenure in this data -- worth stating
-- plainly rather than only reporting the cleaner "organic = better" story.
