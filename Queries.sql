Create Database CustomerBehav
SELECT COUNT(*) FROM customer_analytics;
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
SELECT 
    dependency_score,
    CASE 
        WHEN dependency_score = 0 THEN 'Pure Organic Loyalist (No Promo)'
        WHEN dependency_score = 1 THEN 'Low Dependency Buyer'
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
DESCRIBE customer_analytics;
SELECT 
    'Definition A (Organic/Frequency Driven)' AS loyalty_metric,
    COUNT(CASE WHEN Loyalty_Def_A = 1 THEN 1 END) AS identified_loyal_customers,
    ROUND(AVG(CASE WHEN Loyalty_Def_A = 1 THEN Total_Estimated_Spend END), 2) AS avg_lifetime_spend,
    ROUND(AVG(CASE WHEN Loyalty_Def_A = 1 THEN `Review Rating` END), 2) AS avg_customer_rating,
    ROUND(SUM(CASE WHEN Loyalty_Def_A = 1 THEN `Purchase Amount (USD)` END), 2) AS current_transaction_revenue
FROM customer_analytics
UNION ALL
SELECT 
    'Definition B (Monetary/Subscription Driven)' AS loyalty_metric,
    COUNT(CASE WHEN Loyalty_Def_B = 1 THEN 1 END) AS identified_loyal_customers,
    ROUND(AVG(CASE WHEN Loyalty_Def_B = 1 THEN Total_Estimated_Spend END), 2) AS avg_lifetime_spend,
    ROUND(AVG(CASE WHEN Loyalty_Def_B = 1 THEN `Review Rating` END), 2) AS avg_customer_rating,
    ROUND(SUM(CASE WHEN Loyalty_Def_B = 1 THEN `Purchase Amount (USD)` END), 2) AS current_transaction_revenue
FROM customer_analytics;

SELECT 
    Category,
    COUNT(`Customer ID`) AS total_orders,
    ROUND(SUM(`Purchase Amount (USD)`), 2) AS total_revenue,
    ROUND(AVG(`Previous Purchases`), 1) AS avg_customer_tenure,
    -- Entry Point Orders (New customers with <= 10 previous purchases)
    SUM(CASE WHEN `Previous Purchases` <= 10 THEN 1 ELSE 0 END) AS new_customer_orders,
    -- Retention Orders (Legacy loyal customers with > 25 previous purchases)
    SUM(CASE WHEN `Previous Purchases` > 25 THEN 1 ELSE 0 END) AS legacy_loyal_orders,
    ROUND(SUM(CASE WHEN `Previous Purchases` > 25 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS retention_power_pct
FROM customer_analytics
GROUP BY Category
ORDER BY total_revenue DESC;

SELECT 
    Location AS State,
    COUNT(`Customer ID`) AS total_orders,
    ROUND(SUM(`Purchase Amount (USD)`), 2) AS total_revenue,
    ROUND(AVG(dependency_score), 2) AS avg_state_promo_dependency,
    -- Organic Revenue % (Revenue made without promo codes)
    ROUND(SUM(CASE WHEN `Promo Code Used` = 'No' THEN `Purchase Amount (USD)` ELSE 0 END) * 100.0 / SUM(`Purchase Amount (USD)`), 2) AS organic_revenue_pct
FROM customer_analytics
GROUP BY Location
HAVING total_orders >= 10
ORDER BY organic_revenue_pct DESC, total_revenue DESC
LIMIT 10;

SELECT 
    `Shipping Type`,
    `Payment Method`,
    COUNT(`Customer ID`) AS transaction_count,
    ROUND(AVG(`Purchase Amount (USD)`), 2) AS avg_ticket_size,
    ROUND(AVG(dependency_score), 2) AS avg_promo_dependency,
    SUM(CASE WHEN `Promo Code Used` = 'Yes' THEN 1 ELSE 0 END) AS promo_orders_count
FROM customer_analytics
GROUP BY `Shipping Type`, `Payment Method`
ORDER BY transaction_count DESC
LIMIT 12;