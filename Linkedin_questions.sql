
-- DROP TABLE IF EXISTS ingestion_raw;
-- DROP TABLE IF EXISTS transactions;
-- DROP TABLE IF EXISTS logins;
-- DROP TABLE IF EXISTS products;
-- DROP TABLE IF EXISTS users;
-- DROP TABLE IF EXISTS events_log;
-- DROP TABLE IF EXISTS customer_scd;

-- CREATE TABLE users (
--     user_id      INT PRIMARY KEY,
--     username     VARCHAR(50),
--     region       VARCHAR(50),
--     signup_date  DATE,
--     is_premium   TINYINT DEFAULT 0,
--     premium_date DATE NULL
-- );

-- CREATE TABLE logins (
--     login_id  INT PRIMARY KEY AUTO_INCREMENT,
--     user_id   INT,
--     login_ts  DATETIME,
--     FOREIGN KEY (user_id) REFERENCES users(user_id)
-- );

-- CREATE TABLE products (
--     product_id   INT PRIMARY KEY,
--     product_name VARCHAR(50),
--     category     VARCHAR(50),
--     cost         DECIMAL(10,2),
--     price        DECIMAL(10,2)
-- );

-- CREATE TABLE transactions (
--     transaction_id INT PRIMARY KEY AUTO_INCREMENT,
--     user_id        INT NULL,        -- nullable on purpose (bad FK cases)
--     product_id     INT NULL,        -- nullable on purpose (bad FK cases)
--     amount         DECIMAL(10,2),
--     txn_ts         DATETIME
-- );

-- -- Raw ingestion landing table (contains exact-duplicate rows to detect)
-- CREATE TABLE ingestion_raw (
--     row_id      INT PRIMARY KEY AUTO_INCREMENT,
--     user_id     INT,
--     product_id  INT,
--     amount      DECIMAL(10,2),
--     txn_ts      DATETIME,
--     load_month  DATE          -- used for the "current month partition" delete demo
-- );

-- -- Hourly event log with deliberate gaps
-- CREATE TABLE events_log (
--     event_id  INT PRIMARY KEY AUTO_INCREMENT,
--     event_ts  DATETIME
-- );

-- -- SCD Type 2 style dimension (simulating what Delta Lake would store as history)
-- CREATE TABLE customer_scd (
--     scd_id      INT PRIMARY KEY AUTO_INCREMENT,
--     customer_id INT,
--     name        VARCHAR(50),
--     address     VARCHAR(100),
--     tier        VARCHAR(20),
--     valid_from  DATE,
--     valid_to    DATE NULL,        -- NULL = current row
--     is_current  TINYINT
-- );

-- -- ---------------------------------------------------------------------
-- -- 1. SEED DATA
-- -- ---------------------------------------------------------------------
-- INSERT INTO users (user_id, username, region, signup_date, is_premium, premium_date) VALUES
-- (1,'alice','US','2026-01-01',1,'2026-01-05'),
-- (2,'bob','US','2026-01-03',0,NULL),
-- (3,'carol','EU','2026-01-10',1,'2026-01-25'),
-- (4,'dave','EU','2026-02-01',0,NULL),
-- (5,'eve','APAC','2026-02-05',1,'2026-02-06'),
-- (6,'frank','APAC','2026-02-10',0,NULL),
-- (7,'grace','US','2026-03-01',1,'2026-04-01'),
-- (8,'heidi','EU','2026-03-15',0,NULL);

-- INSERT INTO logins (user_id, login_ts) VALUES
-- (1,'2026-07-01 09:00:00'),(1,'2026-07-01 20:00:00'),(1,'2026-07-02 09:15:00'),
-- (2,'2026-07-01 10:00:00'),(2,'2026-07-03 11:00:00'),
-- (3,'2026-07-01 08:00:00'),(3,'2026-07-02 08:30:00'),(3,'2026-07-03 08:45:00'),
-- (3,'2026-07-04 09:00:00'),(3,'2026-07-08 09:00:00'),(3,'2026-07-09 09:00:00'),(3,'2026-07-10 09:00:00'),
-- (4,'2026-07-02 12:00:00'),
-- (5,'2026-07-01 07:00:00'),(5,'2026-07-01 23:30:00'), -- 23:30 = outside business hours flag later
-- (6,'2026-07-05 14:00:00'),
-- (7,'2026-07-01 06:00:00'),(7,'2026-07-02 06:10:00'),(7,'2026-07-03 06:05:00'),
-- (7,'2026-07-08 06:00:00'),(7,'2026-07-09 06:00:00'),(7,'2026-07-10 06:00:00');

-- INSERT INTO products (product_id, product_name, category, cost, price) VALUES
-- (101,'Wireless Mouse','Electronics',5.00,20.00),
-- (102,'Mechanical Keyboard','Electronics',30.00,80.00),
-- (103,'Yoga Mat','Fitness',8.00,25.00),
-- (104,'Protein Powder','Fitness',12.00,35.00),
-- (105,'Desk Lamp','Home',6.00,18.00),
-- (106,'Office Chair','Home',50.00,150.00);

-- INSERT INTO transactions (user_id, product_id, amount, txn_ts) VALUES
-- (1,101,20.00,'2026-07-01 10:05:00'),
-- (1,102,80.00,'2026-07-02 11:00:00'),
-- (1,102,80.00,'2026-07-02 11:30:00'),   -- same product twice same day
-- (1,103,25.00,'2026-07-05 02:00:00'),   -- outside business hours (2am)
-- (2,101,20.00,'2026-07-01 12:00:00'),
-- (2,105,18.00,'2026-07-04 13:00:00'),
-- (3,104,35.00,'2026-01-11 09:00:00'),   -- carol's first purchase, day after signup
-- (3,104,35.00,'2026-02-11 09:00:00'),
-- (3,106,150.00,'2026-06-01 09:00:00'),
-- (3,106,150.00,'2026-06-15 09:00:00'),
-- (4,103,25.00,'2026-02-02 09:00:00'),
-- (5,102,80.00,'2026-02-06 10:00:00'),
-- (5,102,80.00,'2026-02-06 10:20:00'),   -- same product twice same day
-- (6,105,18.00,'2026-02-11 21:30:00'),   -- outside business hours (9:30pm)
-- (7,101,20.00,'2026-03-02 07:00:00'),
-- (7,104,35.00,'2026-04-01 07:00:00'),
-- (NULL,101,20.00,'2026-05-01 09:00:00'),   -- orphan: no user
-- (8,NULL,40.00,'2026-05-02 09:00:00');     -- orphan: no product

-- -- Ingestion table: mostly a copy of transactions, with exact-duplicate rows injected
-- INSERT INTO ingestion_raw (user_id, product_id, amount, txn_ts, load_month)
-- SELECT user_id, product_id, amount, txn_ts, DATE_FORMAT(txn_ts, '%Y-%m-01')
-- FROM transactions WHERE user_id IS NOT NULL AND product_id IS NOT NULL;

-- -- duplicate a few rows on purpose (simulating a re-run ingestion job)
-- INSERT INTO ingestion_raw (user_id, product_id, amount, txn_ts, load_month)
-- SELECT user_id, product_id, amount, txn_ts, load_month
-- FROM ingestion_raw WHERE row_id IN (1,2,5);

-- -- Hourly event log for 2026-07-01, with 03:00, 04:00, 09:00 missing on purpose
-- INSERT INTO events_log (event_ts) VALUES
-- ('2026-07-01 00:00:00'),('2026-07-01 01:00:00'),('2026-07-01 02:00:00'),
-- ('2026-07-01 05:00:00'),('2026-07-01 06:00:00'),('2026-07-01 07:00:00'),
-- ('2026-07-01 08:00:00'),('2026-07-01 10:00:00'),('2026-07-01 11:00:00'),
-- ('2026-07-01 12:00:00'),('2026-07-01 13:00:00'),('2026-07-01 14:00:00'),
-- ('2026-07-01 15:00:00'),('2026-07-01 16:00:00'),('2026-07-01 17:00:00'),
-- ('2026-07-01 18:00:00'),('2026-07-01 19:00:00'),('2026-07-01 20:00:00'),
-- ('2026-07-01 21:00:00'),('2026-07-01 22:00:00'),('2026-07-01 23:00:00');

-- -- SCD2 history: customer 501 changed address (Jan->Mar) then tier (Mar->current)
-- INSERT INTO customer_scd (customer_id, name, address, tier, valid_from, valid_to, is_current) VALUES
-- (501,'Nilesh','Hyderabad-Old','Silver','2026-01-01','2026-03-01',0),
-- (501,'Nilesh','Hyderabad-New','Silver','2026-03-01','2026-06-01',0),
-- (501,'Nilesh','Hyderabad-New','Gold','2026-06-01',NULL,1),
-- (502,'Priya','Pune','Silver','2026-01-01',NULL,1);

-- -- Monthly sales rollup for the "3 months declining" question (derived from products+txns is too sparse,
-- -- so a small explicit table is used for a clean, testable pattern)
-- DROP TABLE IF EXISTS monthly_sales;
-- CREATE TABLE monthly_sales (
--     product_id  INT,
--     sale_month  DATE,
--     revenue     DECIMAL(10,2)
-- );
-- INSERT INTO monthly_sales VALUES
-- (101,'2026-03-01',500),(101,'2026-04-01',400),(101,'2026-05-01',300),(101,'2026-06-01',250), -- declining
-- (102,'2026-03-01',300),(102,'2026-04-01',350),(102,'2026-05-01',500),(102,'2026-06-01',600), -- growing
-- (103,'2026-03-01',200),(103,'2026-04-01',180),(103,'2026-05-01',150),(103,'2026-06-01',170); -- mixed

-- -- Small lookup table for the broadcast-join example
-- DROP TABLE IF EXISTS region_lookup;
-- CREATE TABLE region_lookup (
--     region      VARCHAR(50) PRIMARY KEY,
--     region_mgr  VARCHAR(50)
-- );
-- INSERT INTO region_lookup VALUES ('US','Sam'),('EU','Lena'),('APAC','Wei');


-- =====================================================================
-- 2. QUERIES
-- =====================================================================

-- ---------------------------------------------------------------------
-- Q1. Daily count of active users (logged in at least once)
-- ---------------------------------------------------------------------
SELECT date(login_ts) as loging_date,count(distinct login_id ) FROM logins
Group by date(login_ts) order by count(distinct login_id )  desc;

-- ---------------------------------------------------------------------
-- Q2. ⁠ ⁠Find the 2nd highest transaction per user without using LIMIT or TOP
-- ------------------------------------------------------------------------------------------------------------------------------------------

with cte as (
SELECT *,dense_rank() over(partition by user_id order by amount desc ) as dense_rank_amount FROM transactions) 


select distinct user_id,amount FROM cte 
where  dense_rank_amount=2;

-- the expression 1 = (SELECT COUNT(DISTINCT t2.amount) ...) is checking this rule:"Find me a transaction where there is exactly one unique transaction amount larger than it."
-- The Good: It works on almost any relational database in existence, even ancient versions of SQL that don't support modern window components.
-- The Bad: It is a correlated subquery. For every single row in your transactions table, the system has to run an entirely separate scan of the table. On large datasets, this will heavily slow down performance.
SELECT t1.user_id, t1.amount AS second_highest_amount
FROM transactions t1
WHERE t1.user_id IS NOT NULL
  AND 1 = (
      SELECT COUNT(DISTINCT t2.amount)
      FROM transactions t2
      WHERE t2.user_id = t1.user_id
        AND t2.amount > t1.amount
  );
 
-- ---------------------------------------------------------------------
-- Q3. ⁠⁠ ⁠Identify data gaps in time-series event logs (eg, missing hourly records)
-- ---------------------------------------------------------------------
-- SELECT TIMESTAMP('2026-07-01 00:00:00') AS hour_slot
--     UNION ALL
--     SELECT hour_slot + INTERVAL 1 HOUR
--     FROM hours
--     WHERE hour_slot < '2026-07-01 23:00:00'

WIth RECURSIVE  hours as (
SELECT Timestamp('2026-07-01 00:00:00') as hour_slot
UNION ALL
SELECT hour_slot+interval 1 hour
from hours
where hour_slot<'2026-07-01 23:00:00'
) 


SELECT * FROM hours as a
left join events_log as b on a.hour_slot=b.event_ts 
where b.event_ts is null;

 
-- ---------------------------------------------------------------------
-- Q4. ⁠⁠⁠ ⁠Fetch the first purchase date per user and calculate days since then
-- ---------------------------------------------------------------------
WIth first_purchase_date as (
SELECT user_ID,min(date(txn_ts)) as first_purchase_date FROM transactions
 where user_ID is not null
Group by user_ID)

SELECT a.user_ID,b.first_purchase_date, max(datediff(txn_ts,first_purchase_date)) FROM transactions as a
left join first_purchase_date as b on a.user_ID=b.user_ID
where a.user_ID is not null
GROUP BY a.user_ID,b.first_purchase_date
;
SELECT user_id,
       MIN(txn_ts) AS first_purchase_ts,
       DATEDIFF(CURDATE(), DATE(MIN(txn_ts))) AS days_since_first_purchase
FROM transactions
WHERE user_id IS NOT NULL
GROUP BY user_id;
-- ---------------------------------------------------------------------
-- Q5.⁠ ⁠Detect schema changes in SCD Type 2 tables using Delta Lake
-- ---------------------------------------------------------------------
use learning200;
select * FROM customer_scd;
WITH CTE AS (
select *,lead(address) over(partition by customer_id order by valid_from) as next_add,lead(tier) over(partition by customer_id order by valid_from) as next_tier,lead(valid_FROM) over(partition by customer_id order by valid_from ) as change_on
 from customer_scd)
 
 SELECT * FROM CTE 
 where next_add is not null and (next_add <> address or next_tier<>tier );
 

 -- ---------------------------------------------------------------------
-- Q6.⁠ ⁠ ⁠Join product and transaction tables and filter out null foreign keys safely
-- ---------------------------------------------------------------------
SELECT t.transaction_id, t.user_id, p.product_name, t.amount, t.txn_ts
FROM transactions t
INNER JOIN products p ON p.product_id = t.product_id
WHERE t.user_id IS NOT NULL
  AND t.product_id IS NOT NULL;
  
  
  
  
 -- ---------------------------------------------------------------------
-- Q7.⁠ ⁠ ⁠Users who upgraded to premium within 7 days of signup
-- ---------------------------------------------------------------------
SELECT * fROM users
where datediff(premium_date,signup_date)>=7;




 -- ---------------------------------------------------------------------
-- Q8.⁠ ⁠ ⁠⁠ ⁠Calculate cumulative distinct product purchases per customer
-- ---------------------------------------------------------------------


with CTE as (
SELECT User_id,product_id,min(txn_ts) as first_broght FROM Transactions
where User_id is not null and product_id is not null
Group by User_id,product_id)

select *,count(first_broght) over(partition by user_id order by first_broght  rows between unbounded preceding and current row) FROM cte
;








WITH data AS (
    SELECT 1 AS t, 1 AS a
    UNION ALL
    SELECT 2, 5
    UNION ALL
    SELECT 3, 3
    UNION ALL
    SELECT 4, 5
    UNION ALL
    SELECT 5, 4
    UNION ALL
    SELECT 6, 11
)


SELECT *,sum(a) over(order by t rows between unbounded preceding and current row ) FROM data;


 -- ---------------------------------------------------------------------
-- Q9.⁠ ⁠ ⁠⁠ ⁠ ⁠Retrieve customers who spent above average in their region
-- ---------------------------------------------------------------------
use learning200;

WITH customer_spend AS (
    SELECT
        u.user_id,
        u.username,
        u.region,
        SUM(t.amount) AS total_spent
    FROM users u
    JOIN transactions t
        ON t.user_id = u.user_id
    GROUP BY
        u.user_id,
        u.username,
        u.region
),
spend_with_avg AS (
    SELECT
        *,
        AVG(total_spent) OVER (
            PARTITION BY region
        ) AS region_avg_spent
    FROM customer_spend
)
SELECT *
FROM spend_with_avg
WHERE total_spent > region_avg_spent;

SELECT user_id, product_id, amount, txn_ts, load_month, COUNT(*) AS dup_count
FROM ingestion_raw
GROUP BY user_id, product_id, amount, txn_ts, load_month
HAVING COUNT(*) > 1;
  -- ---------------------------------------------------------------------
-- Q10.⁠ ⁠ ⁠⁠Row-level version (keep the surrogate key so you can DELETE the extras):
-- ---------------------------------------------------------------------
-- 
WITH ranked AS (
    SELECT row_id,
           ROW_NUMBER() OVER (
               PARTITION BY user_id, product_id, amount, txn_ts, load_month
               ORDER BY row_id
           ) AS rn
    FROM ingestion_raw
)
SELECT row_id FROM ranked WHERE rn > 1;   -- these row_ids are the extra duplicates
  
-- ---------------------------------------------------------------------
-- Q12. Products with declining sales 3 months in a row
-- ---------------------------------------------------------------------
SELECT * FROM (
SELECT product_id, sale_month, revenue,
           LAG(revenue,1) OVER (PARTITION BY product_id ORDER BY sale_month) AS rev_1mo_ago,
           LAG(revenue,2) OVER (PARTITION BY product_id ORDER BY sale_month) AS rev_2mo_ago
    FROM monthly_sales
) as t
where rev_2mo_ago is not null
and rev_1mo_ago<rev_2mo_ago
and revenue<rev_1mo_ago;


SELECT product_id, sale_month, revenue,
           LAG(revenue,1) OVER (PARTITION BY product_id ORDER BY sale_month) AS rev_1mo_ago,
           LAG(revenue,2) OVER (PARTITION BY product_id ORDER BY sale_month) AS rev_2mo_ago
    FROM monthly_sales;
   
   
use learning200;
-- ---------------------------------------------------------------------
-- Q13. ⁠ ⁠Get users with at least 3 logins per week over last 2 months
-- ---------------------------------------------------------------------
with
user_information as (
select l.*,week(login_ts)as weeklogin FROM logins as l
left join users as a on a.user_id=l.user_id)

SELECT user_id,weeklogin,month(login_ts),count(*)
FROM
user_information
where TIMESTAMPDIFF(MONTH, login_ts, (CURRENT_DATE()+ interval 1 month))=1 
Group by user_id,weeklogin,month(login_ts)
having  count(*)>=3
;


    SELECT
    l.user_id,
    YEARWEEK(l.login_ts, 3) AS login_year_week,
    MIN(DATE(l.login_ts)) AS week_first_login_date,
    MAX(DATE(l.login_ts)) AS week_last_login_date,
    COUNT(*) AS login_count
FROM logins AS l
WHERE l.login_ts >= CURRENT_DATE() - INTERVAL 2 MONTH
  AND l.login_ts <  CURRENT_DATE() + INTERVAL 1 DAY
GROUP BY
    l.user_id,
    YEARWEEK(l.login_ts, 3)
HAVING COUNT(*) >= 3
ORDER BY
    l.user_id,
    login_year_week;
    
    
    
    

use learning200;
-- ---------------------------------------------------------------------
-- Q14. ⁠ ⁠ ⁠ ⁠Fetch users who purchased same product multiple times in one day
-- ---------------------------------------------------------------------   
SELECT user_id,date(txn_ts),count(*) FROM transactions as t
left join products as p on t.product_id=p.product_id
Group by user_id,date(txn_ts)
having count(*) >1;
-- ---------------------------------------------------------------------
-- Q15. ⁠ ⁠ ⁠ ⁠ ⁠Detect and delete late-arriving data for current month partitions
-- ---------------------------------------------------------------------   
-- need to ingest more data

SELECT * FROM ingestion_raw
WHERE load_month = DATE_FORMAT(CURRENT_DATE(), '%Y-%m-01')
  AND txn_ts < DATE_FORMAT(CURRENT_DATE(), '%Y-%m-01');
  
  
  
  -- ---------------------------------------------------------------------
-- Q16. ⁠ ⁠ ⁠ ⁠ ⁠Detect and delete late-arriving data for current month partitions
-- ---------------------------------------------------------------------   
-- need to ingest more data

SELECT * FROM ingestion_raw
WHERE load_month = DATE_FORMAT(CURRENT_DATE(), '%Y-%m-01')
  AND txn_ts < DATE_FORMAT(CURRENT_DATE(), '%Y-%m-01');
  
  
  
  
  -- ---------------------------------------------------------------------
-- Q17. ⁠ ⁠ ⁠ ⁠ ⁠⁠ ⁠Get top 5 products by profit margin across all categories
-- ---------------------------------------------------------------------   
SELECT *,Round((cost*price) /100,2) as Profit_margin_pers FROM products;

  
  -- ---------------------------------------------------------------------
-- Q19. ⁠⁠ ⁠Flag transactions happening outside business hours
-- ---------------------------------------------------------------------   
SELECT  * ,case when  ( date_format(txn_ts,"&r") > '07:30:00 PM'
or   date_format(txn_ts,"&r") < '09:30:00 AM') then "outside_office_hours"
else "within+_office_hours" end as "trasaction timeing"
FROM Transactions
where date_format(txn_ts,"&r") > '07:30:00 PM'
or   date_format(txn_ts,"&r") < '09:30:00 AM';
 