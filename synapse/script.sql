-- 1. Create External Data Source
CREATE EXTERNAL DATA SOURCE fdadls_datasource
WITH (
    LOCATION = 'abfss://star-schema@fdadls.dfs.core.windows.net/'
);

-- 2. Create External File Format
CREATE EXTERNAL FILE FORMAT parquet_format
WITH (
    FORMAT_TYPE = PARQUET
);

CREATE EXTERNAL TABLE dim_customer (
    CustomerID INT,
    RecentLoginGapDays INT
)
WITH (
    LOCATION = 'dim_customer/',
    DATA_SOURCE = fdadls_datasource,
    FILE_FORMAT = parquet_format
);

CREATE EXTERNAL TABLE dim_merchant (
    MerchantID INT,
    Category VARCHAR
)
WITH (
    LOCATION = 'dim_merchant/',
    DATA_SOURCE = fdadls_datasource,
    FILE_FORMAT = parquet_format
);

CREATE EXTERNAL TABLE dim_time (
    TransactionTimestamp DATETIME,
    TransactionDate DATE,
    Hour INT
)
WITH (
    LOCATION = 'dim_time/',
    DATA_SOURCE = fdadls_datasource,
    FILE_FORMAT = parquet_format
);

CREATE EXTERNAL TABLE fact_transactions (
    TransactionID INT,
    CustomerID INT,
    MerchantID INT,
    TransactionAmount FLOAT,
    HourOfTransaction INT,
    IsHighAmount INT,
    AnomalyScore FLOAT,
    FraudIndicator INT,
    TransactionTimestamp DATETIME
)
WITH (
    LOCATION = 'fact_transactions/',
    DATA_SOURCE = fdadls_datasource,
    FILE_FORMAT = parquet_format
);

-- 1. Top 10 Customers with Highest Total Transaction Amounts

SELECT TOP 10
    dc.CustomerID,
    SUM(ft.TransactionAmount) AS TotalSpent
FROM fact_transactions ft
JOIN dim_customer dc ON ft.CustomerID = dc.CustomerID
GROUP BY dc.CustomerID
ORDER BY TotalSpent DESC;



-- 2. Daily Fraud Count Trend

SELECT 
    CONVERT(DATE, ft.TransactionTimestamp) AS TransactionDate,
    COUNT(*) AS FraudCount
FROM fact_transactions ft
WHERE ft.FraudIndicator = 1
GROUP BY CONVERT(DATE, ft.TransactionTimestamp)
ORDER BY TransactionDate;


-- 3. Fraud Rate by Merchant Category

SELECT 
    dm.Category,
    CAST(COUNT(CASE WHEN ft.FraudIndicator = 1 THEN 1 END) AS FLOAT) / COUNT(*) AS FraudRate
FROM fact_transactions ft
JOIN dim_merchant dm ON ft.MerchantID = dm.MerchantID
GROUP BY dm.Category
ORDER BY FraudRate DESC;



-- 4. Hourly Fraud Distribution

SELECT 
    HourOfTransaction,
    COUNT(*) AS TotalTransactions,
    SUM(CASE WHEN FraudIndicator = 1 THEN 1 ELSE 0 END) AS FraudCount
FROM fact_transactions
GROUP BY HourOfTransaction
ORDER BY HourOfTransaction;



-- 5. Fraud Rate by Login Gap

SELECT 
    dc.RecentLoginGapDays,
    COUNT(*) AS TotalUsers,
    SUM(CASE WHEN ft.FraudIndicator = 1 THEN 1 ELSE 0 END) AS FraudCases,
    CAST(SUM(CASE WHEN ft.FraudIndicator = 1 THEN 1 ELSE 0 END) AS FLOAT) / COUNT(*) AS FraudRate
FROM fact_transactions ft
JOIN dim_customer dc ON ft.CustomerID = dc.CustomerID
GROUP BY dc.RecentLoginGapDays
ORDER BY dc.RecentLoginGapDays;


