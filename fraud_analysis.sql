-- Create Table
DROP TABLE IF EXISTS transaction_fraud_data;

CREATE TABLE transaction_fraud_data (
    transaction_id INT PRIMARY KEY,
    user_id INT,
    amount NUMERIC,
    transaction_type VARCHAR(50),
    merchant_category VARCHAR(50),
    country VARCHAR(10),
    hour INT,
    device_risk_score NUMERIC,
    ip_risk_score NUMERIC,
    is_fraud INT    
);

-- Create New Risk Column
ALTER TABLE transaction_fraud_data 
ADD COLUMN total_risk_score NUMERIC(5, 4);

-- Clean Data and Calculate Total Risk
UPDATE transaction_fraud_data
SET 
    amount = ROUND(amount, 2),
    device_risk_score = ROUND(device_risk_score, 4),
    ip_risk_score = ROUND(ip_risk_score, 4),
    total_risk_score = ROUND((device_risk_score + ip_risk_score) / 2, 4);


--Analysis Queries

-- Query 1: Overall Fraud Rate and Totals
SELECT 
    COUNT(*) AS total_transactions,
    SUM(is_fraud) AS total_fraud_cases,
    ROUND((SUM(is_fraud)::NUMERIC / COUNT(*)) * 100, 2) AS fraud_percentage,
    ROUND(AVG(amount), 2) AS avg_clean_amount,
    ROUND(AVG(CASE WHEN is_fraud = 1 THEN amount END), 2) AS avg_fraud_amount
FROM transaction_fraud_data;

-- Query 2: Fraud Rates by Transaction Type
SELECT 
    transaction_type,
    COUNT(*) AS total_count,
    SUM(is_fraud) AS fraud_count,
    ROUND((SUM(is_fraud)::NUMERIC / COUNT(*)) * 100, 2) AS fraud_rate
FROM transaction_fraud_data
GROUP BY transaction_type
ORDER BY fraud_rate DESC;

-- Query 3: High Value Late Night Anomaly Detection
SELECT 
    transaction_id,
    user_id,
    amount,
    transaction_type,
    hour,
    total_risk_score
FROM transaction_fraud_data
WHERE hour IN (23, 0, 1, 2, 3, 4, 5) 
  AND amount > 1000
ORDER BY amount DESC;

-- Query 4: High Device and IP Risk Anomalies
SELECT 
    transaction_id,
    user_id,
    amount,
    device_risk_score,
    ip_risk_score,
    total_risk_score
FROM transaction_fraud_data
WHERE device_risk_score > 0.75 
  AND ip_risk_score > 0.75
ORDER BY total_risk_score DESC;

-- Query 5: Create Risk Tiers for Users
SELECT 
    user_id,
    COUNT(*) AS transaction_count,
    ROUND(SUM(amount), 2) AS total_spend,
    SUM(is_fraud) AS actual_fraud_hits,
    CASE 
        WHEN SUM(is_fraud) > 0 THEN 'BLACKLIST'
        WHEN MAX(total_risk_score) >= 0.75 THEN 'HIGH RISK'
        WHEN MAX(total_risk_score) BETWEEN 0.40 AND 0.74 THEN 'MEDIUM RISK'
        ELSE 'LOW RISK'
    END AS risk_classification
FROM transaction_fraud_data
GROUP BY user_id
ORDER BY actual_fraud_hits DESC;

-- Query 6: Find Spending Spikes Using Window Functions
SELECT 
    transaction_id,
    user_id,
    amount,
    merchant_category,
    ROUND(AVG(amount) OVER(PARTITION BY user_id), 2) AS user_average_spend,
    ROUND(amount - AVG(amount) OVER(PARTITION BY user_id), 2) AS spend_deviation,
    is_fraud
FROM transaction_fraud_data
WHERE amount > 500
ORDER BY spend_deviation DESC;