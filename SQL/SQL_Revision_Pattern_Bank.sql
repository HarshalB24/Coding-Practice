-- ==================================================================================================
-- SQL INTERVIEW PATTERN BANK v2 | EXAMPLE-DRIVEN STUDY EDITION | 2026-11-22
-- MySQL 8+; examples are independent: create/load their stated tables before executing.
-- PURPOSE: Learn to RECOGNIZE, REASON and SOLVE; NOT just memorize pattern names.
-- 30 patterns, with 1-2 fully solved examples each; full attempts remain in SQL_Question_Archive.sql.
-- Provenance: "SOURCE" identifies archived practice where applicable. Other examples are teaching cases
-- written for this revision guide, not claims of independent student completion.
-- Status: these examples are study material, NOT evidence that the pattern is mastered.
-- For each: hide SOLUTION; state raw/intermediate/final grain; write query; compare expected output.
-- ==================================================================================================

-- CONTENTS
-- P01 | GRAIN TRANSITIONS / AGGREGATE OF AGGREGATES (2 solved examples)
-- P02 | FIRST SUCCESSFUL MONTH / NEW VS REPEAT REVENUE (2 solved examples)
-- P03 | CONDITIONAL AGGREGATION (1 solved example)
-- P04 | PRESERVE BASE POPULATION WITH LEFT JOIN (1 solved example)
-- P05 | ANTI-JOIN / MISSING ROWS (1 solved example)
-- P06 | JOIN FANOUT / MULTIPLE FACT TABLES (2 solved examples)
-- P07 | LATEST ELIGIBLE ROW AS-OF A DATE (2 solved examples)
-- P08 | LATEST WHOLE ROW VS MAX VALUE (1 solved example)
-- P09 | TOP-N DISTINCT VALUES / TIES (2 solved examples)
-- P10 | IMMEDIATE PREVIOUS / NEXT EVENT (2 solved examples)
-- P11 | LATEST VS PRIOR HISTORY AVERAGE (1 solved example)
-- P12 | CALENDAR-ADJACENT MONTH / MRR MOVEMENT (2 solved examples)
-- P13 | RUNNING TOTALS / ROLLING WINDOWS (1 solved example)
-- P14 | GAPS AND ISLANDS / CONSECUTIVE DAYS (2 solved examples)
-- P15 | RELATIONAL DIVISION / ALL REQUIRED (1 solved example)
-- P16 | GROUP BENCHMARK VS GLOBAL BENCHMARK (1 solved example)
-- P17 | GROUP NUMERATOR / GLOBAL DENOMINATOR (1 solved example)
-- P18 | MONTH-OVER-MONTH / YEAR-OVER-YEAR GROWTH (1 solved example)
-- P19 | WHERE VS HAVING / FILTER STAGE (1 solved example)
-- P20 | NULL SEMANTICS / PREVIOUS NON-NULL (2 solved examples)
-- P21 | RECURSIVE CTE / HIERARCHY (1 solved example)
-- P22 | STRING PARSING / PERMUTATIONS / COMBINATIONS (3 solved examples)
-- P23 | PIVOT / UNPIVOT (2 solved examples)
-- P24 | MEDIAN / PERCENTILES (1 solved example)
-- P25 | SESSIONIZATION / INACTIVITY GAPS (2 solved examples)
-- P26 | DEDUPLICATION / KEEP LATEST (1 solved example)
-- P27 | EVENT ROLES / UNION ALL (1 solved example)
-- P28 | ANY VS ALL COMPARISONS (1 solved example)
-- P29 | COHORT RETENTION (1 solved example)
-- P30 | SQL IMPLEMENTATION / DEBUGGING CHECKLIST (1 solved example)

-- ==================================================================================================
-- P01 | GRAIN TRANSITIONS / AGGREGATE OF AGGREGATES
-- ==================================================================================================
/*
RECOGNITION CLUES: average of monthly totals; customer average daily spend
GRAIN MAP: transaction -> entity/month -> entity
SOLUTION METHOD: Aggregate at the business grain first; only then apply MAX/AVG or another aggregate.
COMMON MISTAKE: AVG(raw amount) is not AVG(monthly total).
RELATED PRACTICE: CORE Q01; Stage1 Day1
WORKED MINI-WALKTHROUGH: First build one row per product-month. Only THEN compare each product maximum month with the average of its monthly totals.
*/

/* --- SOLVED EXAMPLE P01.1 | Product with a peak month above twice its average month ---
QUESTION: Find products where MAX(monthly revenue) > 2 * AVG(monthly revenue), considering months with sales.
SCHEMA: Sales(product_id, sale_date, amount)
SAMPLE INPUT: A: Jan 10, Feb 10, Mar 100; B: Jan 200, Feb 250, Mar 220
EXPECTED OUTPUT: A only: monthly 10,10,100; avg 40; max100 > 80. B max250 <= 2*223.33.
STEP 1 - GRAIN: transaction -> entity/month -> entity
STEP 2 - PLAN: Aggregate at the business grain first; only then apply MAX/AVG or another aggregate.
STEP 3 - WHY IT WORKS: Raw sales -> product-month totals -> one row/product comparison.
EDGE CASE / CHECK: A three-month example makes the condition possible; months without sales are excluded unless explicitly required.
HIDE SQL BELOW AND ATTEMPT INDEPENDENTLY BEFORE REVISING.
*/
WITH monthly AS (
    SELECT product_id, DATE_FORMAT(sale_date,'%Y-%m') AS ym,
           SUM(amount) AS month_revenue
    FROM Sales
    GROUP BY product_id, DATE_FORMAT(sale_date,'%Y-%m')
)
SELECT product_id
FROM monthly
GROUP BY product_id
HAVING MAX(month_revenue) > 2 * AVG(month_revenue);

/* --- SOLVED EXAMPLE P01.2 | Average order value per customer vs global average ---
QUESTION: Return customers whose average order total exceeds the average total across all orders.
SCHEMA: OrderItems(order_id, customer_id, amount)
SAMPLE INPUT: O1 C1 100; O1 C1 200; O2 C1 400; O3 C2 600
EXPECTED OUTPUT: C2 only; order totals 300,400,600; global average 433.33; C2 average 600
STEP 1 - GRAIN: transaction -> entity/month -> entity
STEP 2 - PLAN: Aggregate at the business grain first; only then apply MAX/AVG or another aggregate.
STEP 3 - WHY IT WORKS: Order-item -> order -> customer average; global denominator uses orders, not items.
EDGE CASE / CHECK: Do not calculate AVG(amount) directly from OrderItems.
HIDE SQL BELOW AND ATTEMPT INDEPENDENTLY BEFORE REVISING.
*/
WITH orders AS (
 SELECT order_id, customer_id, SUM(amount) AS order_total
 FROM OrderItems GROUP BY order_id,customer_id
), customer_avg AS (
 SELECT customer_id, AVG(order_total) AS avg_order
 FROM orders GROUP BY customer_id
)
SELECT customer_id, avg_order
FROM customer_avg
WHERE avg_order > (SELECT AVG(order_total) FROM orders);

-- END P01

-- ==================================================================================================
-- P02 | FIRST SUCCESSFUL MONTH / NEW VS REPEAT REVENUE
-- ==================================================================================================
/*
RECOGNITION CLUES: new customers; returning revenue; first-ever successful month
GRAIN MAP: order -> customer first month -> order -> month
SOLUTION METHOD: Filter successful orders; attach first month using MIN window or grouped CTE; classify and sum.
COMMON MISTAKE: Do not group customer+month when computing FIRST month; exclude cancellations first.
RELATED PRACTICE: Namastekart 2026-11-22; corrected, not mastered
WORKED MINI-WALKTHROUGH: Example: customer 101 has Jan100 + Jan200 + Feb250. firsts(101)=Jan; after join both January orders are NEW and February is REPEAT. Customer 102 cancelled January: firsts(102)=February.
*/

/* --- SOLVED EXAMPLE P02.1 | Namastekart new and repeat revenue — GROUP BY + JOIN ---
QUESTION: For each delivered-order month, sum revenue from customers in first successful month vs later months; repeat percentage.
SCHEMA: orders(order_id, customer_id, order_date, amount, status)
SAMPLE INPUT: 1 101 Jan05 100 Delivered; 2 101 Jan20 200 Delivered; 3 102 Jan10 150 Cancelled; 4 103 Jan15 300 Delivered; 5 101 Feb05 250 Delivered; 6 102 Feb10 400 Delivered; 7 103 Feb12 100 Delivered; 8 102 Feb20 200 Delivered; 9 101 Mar03 150 Delivered; 10 104 Mar08 500 Delivered; 11 102 Mar12 300 Delivered
EXPECTED OUTPUT: 2024-01: new 600 repeat 0 0.00%; 2024-02: new 600 repeat 350 36.84%; 2024-03: new 500 repeat 450 47.37%
STEP 1 - GRAIN: order -> customer first month -> order -> month
STEP 2 - PLAN: Filter successful orders; attach first month using MIN window or grouped CTE; classify and sum.
STEP 3 - WHY IT WORKS: Firsts is exactly one row per customer; join attaches first month to EACH delivered order; final grouping is month.
EDGE CASE / CHECK: Customer 102 had cancelled January order; February is still NEW. Zero monthly total yields NULL percentage unless COALESCE requested.
HIDE SQL BELOW AND ATTEMPT INDEPENDENTLY BEFORE REVISING.
*/
WITH delivered AS (
 SELECT order_id,customer_id,amount,
        DATE_FORMAT(order_date,'%Y-%m') AS order_month
 FROM orders WHERE status='Delivered'
), firsts AS (
 SELECT customer_id, MIN(order_month) AS first_month
 FROM delivered GROUP BY customer_id
)
SELECT d.order_month,
 SUM(CASE WHEN d.order_month=f.first_month THEN d.amount ELSE 0 END) AS new_revenue,
 SUM(CASE WHEN d.order_month>f.first_month THEN d.amount ELSE 0 END) AS repeat_revenue,
 ROUND(100.0*SUM(CASE WHEN d.order_month>f.first_month THEN d.amount ELSE 0 END)
       /NULLIF(SUM(d.amount),0),2) AS repeat_pct
FROM delivered d JOIN firsts f ON d.customer_id=f.customer_id
GROUP BY d.order_month ORDER BY d.order_month;

/* --- SOLVED EXAMPLE P02.2 | Same problem — window alternative ---
QUESTION: Solve Namastekart without a customer-level GROUP BY and join.
SCHEMA: orders(order_id,customer_id,order_date,amount,status)
SAMPLE INPUT: Same as prior example
EXPECTED OUTPUT: Same three monthly rows as prior example
STEP 1 - GRAIN: order -> customer first month -> order -> month
STEP 2 - PLAN: Filter successful orders; attach first month using MIN window or grouped CTE; classify and sum.
STEP 3 - WHY IT WORKS: Window MIN retains every delivered-order row; grouping happens only in final SELECT.
EDGE CASE / CHECK: A window calculation does not collapse rows; GROUP BY does.
HIDE SQL BELOW AND ATTEMPT INDEPENDENTLY BEFORE REVISING.
*/
WITH enriched AS (
 SELECT customer_id,amount,
        DATE_FORMAT(order_date,'%Y-%m') AS order_month,
        MIN(DATE_FORMAT(order_date,'%Y-%m')) OVER(PARTITION BY customer_id) AS first_month
 FROM orders WHERE status='Delivered'
)
SELECT order_month,
 SUM(CASE WHEN order_month=first_month THEN amount ELSE 0 END) AS new_revenue,
 SUM(CASE WHEN order_month>first_month THEN amount ELSE 0 END) AS repeat_revenue,
 ROUND(100.0*SUM(CASE WHEN order_month>first_month THEN amount ELSE 0 END)
       /NULLIF(SUM(amount),0),2) AS repeat_pct
FROM enriched GROUP BY order_month ORDER BY order_month;

-- END P02

-- ==================================================================================================
-- P03 | CONDITIONAL AGGREGATION
-- ==================================================================================================
/*
RECOGNITION CLUES: sum by status; multiple KPI columns in one row
GRAIN MAP: event -> reporting group
SOLUTION METHOD: SUM(CASE WHEN ... THEN amount ELSE 0 END), COUNT(CASE WHEN ... THEN 1 END).
COMMON MISTAKE: END must be inside SUM; COUNT(*) differs from COUNT(child_id).
RELATED PRACTICE: Stage1 Day1/Day2
*/

/* --- SOLVED EXAMPLE P03.1 | Monthly delivered and cancelled amounts ---
QUESTION: Return monthly delivered revenue and number of cancelled orders.
SCHEMA: orders(order_id,order_date,amount,status)
SAMPLE INPUT: Jan 1 Delivered 100; Jan 2 Cancelled 40; Jan 3 Delivered 200; Feb 4 Cancelled 60
EXPECTED OUTPUT: Jan delivered 300 cancelled_count 1; Feb delivered 0 cancelled_count 1
STEP 1 - GRAIN: event -> reporting group
STEP 2 - PLAN: SUM(CASE WHEN ... THEN amount ELSE 0 END), COUNT(CASE WHEN ... THEN 1 END).
STEP 3 - WHY IT WORKS: Each CASE classifies one raw order; SUM combines into month.
EDGE CASE / CHECK: COUNT(CASE WHEN condition THEN 1 END) is another valid conditional count.
HIDE SQL BELOW AND ATTEMPT INDEPENDENTLY BEFORE REVISING.
*/
SELECT DATE_FORMAT(order_date,'%Y-%m') AS ym,
 SUM(CASE WHEN status='Delivered' THEN amount ELSE 0 END) AS delivered_revenue,
 SUM(CASE WHEN status='Cancelled' THEN 1 ELSE 0 END) AS cancelled_count
FROM orders
GROUP BY DATE_FORMAT(order_date,'%Y-%m')
ORDER BY ym;

-- END P03

-- ==================================================================================================
-- P04 | PRESERVE BASE POPULATION WITH LEFT JOIN
-- ==================================================================================================
/*
RECOGNITION CLUES: all customers including those with zero orders
GRAIN MAP: customer -> customer (with optional facts)
SOLUTION METHOD: Start from mandatory base; LEFT JOIN; count right-side PK; keep right-side filters in ON.
COMMON MISTAKE: WHERE right.status=... removes unmatched customers.
RELATED PRACTICE: Stage1 Day2 Q1/Q2; Day3 address
*/

/* --- SOLVED EXAMPLE P04.1 | All customers including zero delivered orders ---
QUESTION: Return each customer and delivered order count, including customers with none.
SCHEMA: customers(customer_id); orders(order_id,customer_id,status)
SAMPLE INPUT: customers: 1,2,3; orders: (10,1,Delivered),(11,1,Cancelled),(12,2,Delivered)
EXPECTED OUTPUT: 1->1; 2->1; 3->0
STEP 1 - GRAIN: customer -> customer (with optional facts)
STEP 2 - PLAN: Start from mandatory base; LEFT JOIN; count right-side PK; keep right-side filters in ON.
STEP 3 - WHY IT WORKS: Filter in ON preserves the unmatched base row.
EDGE CASE / CHECK: COUNT(*) would count customer 3 as 1, because LEFT JOIN emits one NULL-extended row.
HIDE SQL BELOW AND ATTEMPT INDEPENDENTLY BEFORE REVISING.
*/
SELECT c.customer_id,COUNT(o.order_id) AS delivered_count
FROM customers c
LEFT JOIN orders o ON o.customer_id=c.customer_id AND o.status='Delivered'
GROUP BY c.customer_id ORDER BY c.customer_id;

-- END P04

-- ==================================================================================================
-- P05 | ANTI-JOIN / MISSING ROWS
-- ==================================================================================================
/*
RECOGNITION CLUES: never ordered; paid in 2023 not 2024
GRAIN MAP: customer -> customer
SOLUTION METHOD: NOT EXISTS correlated by customer and date; or LEFT JOIN + IS NULL.
COMMON MISTAKE: NOT IN can return no rows if subquery includes NULL.
RELATED PRACTICE: CORE Q04; Stage1 Day2
*/

/* --- SOLVED EXAMPLE P05.1 | Customers with no delivered orders ---
QUESTION: Return customers who have never had a Delivered order.
SCHEMA: customers(customer_id); orders(order_id,customer_id,status)
SAMPLE INPUT: customers:1,2,3; orders:(10,1,Delivered),(11,2,Cancelled)
EXPECTED OUTPUT: 2,3
STEP 1 - GRAIN: customer -> customer
STEP 2 - PLAN: NOT EXISTS correlated by customer and date; or LEFT JOIN + IS NULL.
STEP 3 - WHY IT WORKS: Test existence of qualifying child rows; cancellation is not a qualifying delivered order.
EDGE CASE / CHECK: Prefer NOT EXISTS when child customer_id might be NULL.
HIDE SQL BELOW AND ATTEMPT INDEPENDENTLY BEFORE REVISING.
*/
SELECT c.customer_id
FROM customers c
WHERE NOT EXISTS (
 SELECT 1 FROM orders o
 WHERE o.customer_id=c.customer_id AND o.status='Delivered'
)
ORDER BY c.customer_id;

-- END P05

-- ==================================================================================================
-- P06 | JOIN FANOUT / MULTIPLE FACT TABLES
-- ==================================================================================================
/*
RECOGNITION CLUES: subscriptions and payments; one-to-many joins
GRAIN MAP: subscription -> subscription metrics + payment metrics -> customer
SOLUTION METHOD: Pre-aggregate each fact before joining, or establish uniqueness of join keys.
COMMON MISTAKE: Joining two child tables multiplies rows and revenue.
RELATED PRACTICE: Stage1 Day2; Namastekart attempted fanout
WORKED MINI-WALKTHROUGH: Two payments joined to three tickets produces SIX joined rows. Each payment appears three times; pre-aggregate each side to one row/customer first.
*/

/* --- SOLVED EXAMPLE P06.1 | Payments and tickets per customer ---
QUESTION: Report each customer payment total and ticket count.
SCHEMA: payments(payment_id,customer_id,amount); tickets(ticket_id,customer_id)
SAMPLE INPUT: payments:(1,A,100),(2,A,200); tickets:(10,A),(11,A),(12,A)
EXPECTED OUTPUT: A payment_total=300 ticket_count=3
STEP 1 - GRAIN: subscription -> subscription metrics + payment metrics -> customer
STEP 2 - PLAN: Pre-aggregate each fact before joining, or establish uniqueness of join keys.
STEP 3 - WHY IT WORKS: Each side is unique by customer before join; no 2x3 multiplication.
EDGE CASE / CHECK: Bad raw join gives payment_total=900 and six ticket rows.
HIDE SQL BELOW AND ATTEMPT INDEPENDENTLY BEFORE REVISING.
*/
WITH p AS (
 SELECT customer_id,SUM(amount) AS payment_total
 FROM payments GROUP BY customer_id
), t AS (
 SELECT customer_id,COUNT(*) AS ticket_count
 FROM tickets GROUP BY customer_id
)
SELECT p.customer_id,p.payment_total,COALESCE(t.ticket_count,0) AS ticket_count
FROM p LEFT JOIN t ON p.customer_id=t.customer_id;

/* --- SOLVED EXAMPLE P06.2 | Validate right-side key uniqueness before joining ---
QUESTION: Find customer keys with more than one row in a supposedly one-row/customer first_month table.
SCHEMA: first_month(customer_id,first_month)
SAMPLE INPUT: (1,2024-01),(1,2024-02),(2,2024-02)
EXPECTED OUTPUT: 1 has 2 rows; must repair before joining to orders
STEP 1 - GRAIN: subscription -> subscription metrics + payment metrics -> customer
STEP 2 - PLAN: Pre-aggregate each fact before joining, or establish uniqueness of join keys.
STEP 3 - WHY IT WORKS: This is a diagnostic query; expected output should be empty when key uniqueness holds.
EDGE CASE / CHECK: A DISTINCT on the final result cannot reliably repair multiplied SUMs.
HIDE SQL BELOW AND ATTEMPT INDEPENDENTLY BEFORE REVISING.
*/
SELECT customer_id,COUNT(*) AS rows_per_customer
FROM first_month
GROUP BY customer_id
HAVING COUNT(*)>1;

-- END P06

-- ==================================================================================================
-- P07 | LATEST ELIGIBLE ROW AS-OF A DATE
-- ==================================================================================================
/*
RECOGNITION CLUES: latest approved price; most recent valid address
GRAIN MAP: history row -> eligible ranked row -> entity
SOLUTION METHOD: Filter validity and cutoff BEFORE ROW_NUMBER; rank by business date DESC, ID DESC.
COMMON MISTAKE: Ranking before eligibility or filtering rn=1 in WHERE after LEFT JOIN drops customers.
RELATED PRACTICE: Stage1 Day3 Q2/R2
WORKED MINI-WALKTHROUGH: C1 eligible history is Mumbai Jan10 and Pune Mar15; May Delhi is beyond cutoff and invalid. Rank eligible rows: Pune rn=1; C3 has no eligible row but survives LEFT JOIN.
*/

/* --- SOLVED EXAMPLE P07.1 | Latest valid address by cutoff, preserve all customers ---
QUESTION: For every customer in address history, return latest valid city by 2026-04-30; NULL if none.
SCHEMA: addresses(address_id,customer_id,city,updated_at,is_valid)
SAMPLE INPUT: 1 C1 Mumbai Jan10 Y; 2 C1 Pune Mar15 Y; 3 C1 Delhi May20 N; 4 C2 Bengaluru Feb01 Y; 5 C2 Chennai Jun10 Y; 6 C3 Hyderabad Jan05 N
EXPECTED OUTPUT: C1 Pune; C2 Bengaluru; C3 NULL
STEP 1 - GRAIN: history row -> eligible ranked row -> entity
STEP 2 - PLAN: Filter validity and cutoff BEFORE ROW_NUMBER; rank by business date DESC, ID DESC.
STEP 3 - WHY IT WORKS: Eligible rows ranked first; all original customers preserved from base.
EDGE CASE / CHECK: Tie-break by unique address_id; do not put r.rn=1 in WHERE.
HIDE SQL BELOW AND ATTEMPT INDEPENDENTLY BEFORE REVISING.
*/
WITH base AS (
 SELECT DISTINCT customer_id FROM addresses
), ranked AS (
 SELECT customer_id,city,updated_at,
        ROW_NUMBER() OVER(PARTITION BY customer_id
          ORDER BY updated_at DESC,address_id DESC) AS rn
 FROM addresses
 WHERE is_valid='Y' AND updated_at<='2026-04-30'
)
SELECT b.customer_id,r.city,r.updated_at
FROM base b LEFT JOIN ranked r
 ON b.customer_id=r.customer_id AND r.rn=1
ORDER BY b.customer_id;

/* --- SOLVED EXAMPLE P07.2 | Latest approved product price ---
QUESTION: Return most recent approved price effective on or before 2024-02-15 per product.
SCHEMA: prices(price_id,product_id,effective_date,price,status)
SAMPLE INPUT: (1,A,Jan01,100,Approved),(2,A,Feb01,120,Pending),(3,A,Feb10,110,Approved),(4,B,Mar01,90,Approved)
EXPECTED OUTPUT: A 110; B absent (no eligible price)
STEP 1 - GRAIN: history row -> eligible ranked row -> entity
STEP 2 - PLAN: Filter validity and cutoff BEFORE ROW_NUMBER; rank by business date DESC, ID DESC.
STEP 3 - WHY IT WORKS: Filter before ranking so pending later price cannot displace approved earlier price.
EDGE CASE / CHECK: To include all products with NULL prices, start from a separate products base and LEFT JOIN.
HIDE SQL BELOW AND ATTEMPT INDEPENDENTLY BEFORE REVISING.
*/
WITH ranked AS (
 SELECT product_id,price,
        ROW_NUMBER() OVER(PARTITION BY product_id
           ORDER BY effective_date DESC,price_id DESC) AS rn
 FROM prices
 WHERE status='Approved' AND effective_date<='2024-02-15'
)
SELECT product_id,price FROM ranked WHERE rn=1;

-- END P07

-- ==================================================================================================
-- P08 | LATEST WHOLE ROW VS MAX VALUE
-- ==================================================================================================
/*
RECOGNITION CLUES: latest event with its status; latest record
GRAIN MAP: event -> entity latest event
SOLUTION METHOD: ROW_NUMBER for whole latest row; MAX(date) only when you need the scalar date.
COMMON MISTAKE: Selecting status beside MAX(date) without grouping is invalid/unsafe.
RELATED PRACTICE: CORE Q05; Day3
*/

/* --- SOLVED EXAMPLE P08.1 | Latest order status per customer ---
QUESTION: Return the status of each customer's latest order, breaking date ties by order_id.
SCHEMA: orders(order_id,customer_id,order_date,status)
SAMPLE INPUT: (1,A,Jan01,Delivered),(2,A,Jan10,Cancelled),(3,B,Jan04,Delivered)
EXPECTED OUTPUT: A Cancelled; B Delivered
STEP 1 - GRAIN: event -> entity latest event
STEP 2 - PLAN: ROW_NUMBER for whole latest row; MAX(date) only when you need the scalar date.
STEP 3 - WHY IT WORKS: Ranking selects the complete latest row; MAX(order_date) alone cannot select status.
EDGE CASE / CHECK: Two orders on same date require deterministic order_id tie-break.
HIDE SQL BELOW AND ATTEMPT INDEPENDENTLY BEFORE REVISING.
*/
WITH ranked AS (
 SELECT customer_id,status,order_date,
 ROW_NUMBER() OVER(PARTITION BY customer_id
 ORDER BY order_date DESC,order_id DESC) AS rn
 FROM orders
)
SELECT customer_id,status,order_date
FROM ranked WHERE rn=1 ORDER BY customer_id;

-- END P08

-- ==================================================================================================
-- P09 | TOP-N DISTINCT VALUES / TIES
-- ==================================================================================================
/*
RECOGNITION CLUES: top 2 distinct salaries; rank including ties
GRAIN MAP: transaction -> entity totals -> ranked entities
SOLUTION METHOD: DENSE_RANK after aggregating metric; filter rank in outer SELECT.
COMMON MISTAKE: ROW_NUMBER loses ties; RANK skips rank values; rank raw transactions is wrong.
RELATED PRACTICE: Stage1 Day3 Q1
WORKED MINI-WALKTHROUGH: North totals: E1=800, E2=800, E3=600. DENSE_RANK assigns 1,1,2; filtering <=2 keeps all three reps.
*/

/* --- SOLVED EXAMPLE P09.1 | Top two distinct sales totals per region ---
QUESTION: Include all reps whose region total is among the top 2 distinct values.
SCHEMA: sales(rep,region,amount)
SAMPLE INPUT: N:A 500+300; N:B 800; N:C 600; S:D 600; S:E 600; S:F 300
EXPECTED OUTPUT: N A800 rank1,B800 rank1,C600 rank2; S D600 rank1,E600 rank1,F300 rank2
STEP 1 - GRAIN: transaction -> entity totals -> ranked entities
STEP 2 - PLAN: DENSE_RANK after aggregating metric; filter rank in outer SELECT.
STEP 3 - WHY IT WORKS: Aggregate first, then rank by group.
EDGE CASE / CHECK: If top 2 ROWS rather than distinct values, ROW_NUMBER might be appropriate.
HIDE SQL BELOW AND ATTEMPT INDEPENDENTLY BEFORE REVISING.
*/
WITH totals AS (
 SELECT region,rep,SUM(amount) AS total_sales
 FROM sales GROUP BY region,rep
), ranked AS (
 SELECT *,DENSE_RANK() OVER(PARTITION BY region
 ORDER BY total_sales DESC) AS sales_rank
 FROM totals
)
SELECT region,rep,total_sales,sales_rank
FROM ranked WHERE sales_rank<=2
ORDER BY region,sales_rank,rep;

/* --- SOLVED EXAMPLE P09.2 | Second-highest DISTINCT salary per department ---
QUESTION: Return employees earning the second distinct highest salary in their department.
SCHEMA: employees(emp_id,dept,salary)
SAMPLE INPUT: A: E1 100,E2 90,E3 90,E4 80; B:E5 70,E6 60
EXPECTED OUTPUT: A E2,E3; B E6
STEP 1 - GRAIN: transaction -> entity totals -> ranked entities
STEP 2 - PLAN: DENSE_RANK after aggregating metric; filter rank in outer SELECT.
STEP 3 - WHY IT WORKS: DENSE_RANK gives both tied 90 employees rank 2.
EDGE CASE / CHECK: A department with one distinct salary returns no row.
HIDE SQL BELOW AND ATTEMPT INDEPENDENTLY BEFORE REVISING.
*/
WITH ranked AS (
 SELECT emp_id,dept,salary,
 DENSE_RANK() OVER(PARTITION BY dept ORDER BY salary DESC) AS dr
 FROM employees
)
SELECT dept,emp_id,salary FROM ranked WHERE dr=2
ORDER BY dept,emp_id;

-- END P09

-- ==================================================================================================
-- P10 | IMMEDIATE PREVIOUS / NEXT EVENT
-- ==================================================================================================
/*
RECOGNITION CLUES: immediately after login; compare with previous transaction
GRAIN MAP: event -> event enriched with adjacent event
SOLUTION METHOD: LAG/LEAD partition by entity and order by time, stable ID.
COMMON MISTAKE: Do not restrict to rn=1 when ANY qualifying sequence can count.
RELATED PRACTICE: CORE Q02; Stage1 Day3 Q3
*/

/* --- SOLVED EXAMPLE P10.1 | Login immediately followed by purchase ---
QUESTION: Return users with any login whose immediately next event is purchase.
SCHEMA: events(event_id,user_id,event_time,event_type)
SAMPLE INPUT: U1 login 09:00, view 09:01, purchase 09:02; U2 login 10:00,purchase 10:02
EXPECTED OUTPUT: U2 only
STEP 1 - GRAIN: event -> event enriched with adjacent event
STEP 2 - PLAN: LAG/LEAD partition by entity and order by time, stable ID.
STEP 3 - WHY IT WORKS: LEAD returns the immediate next event type on each current row.
EDGE CASE / CHECK: Intervening view disqualifies U1 login; multiple qualifying logins still return one user.
HIDE SQL BELOW AND ATTEMPT INDEPENDENTLY BEFORE REVISING.
*/
WITH seq AS (
 SELECT user_id,event_type,
 LEAD(event_type) OVER(PARTITION BY user_id
 ORDER BY event_time,event_id) AS next_type
 FROM events
)
SELECT DISTINCT user_id FROM seq
WHERE event_type='login' AND next_type='purchase';

/* --- SOLVED EXAMPLE P10.2 | Transaction > 1.5 times immediate previous ---
QUESTION: Return transactions exceeding 1.5x immediately previous transaction for same customer.
SCHEMA: transactions(txn_id,customer_id,txn_date,amount)
SAMPLE INPUT: A: 1 Jan01 100; 2 Jan02 160; 3 Jan03 170; B: 4 Jan01 50
EXPECTED OUTPUT: A txn 2 only
STEP 1 - GRAIN: event -> event enriched with adjacent event
STEP 2 - PLAN: LAG/LEAD partition by entity and order by time, stable ID.
STEP 3 - WHY IT WORKS: LAG previous is the immediately preceding event, not previous month.
EDGE CASE / CHECK: First event has NULL previous amount and cannot qualify.
HIDE SQL BELOW AND ATTEMPT INDEPENDENTLY BEFORE REVISING.
*/
WITH seq AS (
 SELECT txn_id,customer_id,amount,
 LAG(amount) OVER(PARTITION BY customer_id ORDER BY txn_date,txn_id) AS prev_amount
 FROM transactions
)
SELECT txn_id,customer_id,amount,prev_amount
FROM seq WHERE amount>1.5*prev_amount;

-- END P10

-- ==================================================================================================
-- P11 | LATEST VS PRIOR HISTORY AVERAGE
-- ==================================================================================================
/*
RECOGNITION CLUES: latest amount > 1.5x all earlier average
GRAIN MAP: event -> entity latest + prior summary
SOLUTION METHOD: Exclude latest from historical average; use ROW_NUMBER and conditional grouped AVG or explicit frame.
COMMON MISTAKE: Averaging current event into history changes threshold.
RELATED PRACTICE: Stage1 Day3 Q4/R4
*/

/* --- SOLVED EXAMPLE P11.1 | Latest salary exceeds prior average by 50% ---
QUESTION: Return employees whose latest salary > 1.5x average of all their earlier salaries.
SCHEMA: salary_history(record_id,emp_id,effective_date,salary)
SAMPLE INPUT: A:100,120,200 chronological; B:100,110 chronological
EXPECTED OUTPUT: A only; prior avg110, latest200>165
STEP 1 - GRAIN: event -> entity latest + prior summary
STEP 2 - PLAN: Exclude latest from historical average; use ROW_NUMBER and conditional grouped AVG or explicit frame.
STEP 3 - WHY IT WORKS: Rank newest first, then exclude rn=1 from AVG of history.
EDGE CASE / CHECK: One-record employees have NULL older_avg and do not qualify.
HIDE SQL BELOW AND ATTEMPT INDEPENDENTLY BEFORE REVISING.
*/
WITH ranked AS (
 SELECT emp_id,salary,
 ROW_NUMBER() OVER(PARTITION BY emp_id ORDER BY effective_date DESC,record_id DESC) AS rn
 FROM salary_history
), summary AS (
 SELECT emp_id,
 MAX(CASE WHEN rn=1 THEN salary END) AS latest_salary,
 AVG(CASE WHEN rn>1 THEN salary END) AS older_avg
 FROM ranked GROUP BY emp_id
)
SELECT emp_id,latest_salary,older_avg FROM summary
WHERE latest_salary>1.5*older_avg;

-- END P11

-- ==================================================================================================
-- P12 | CALENDAR-ADJACENT MONTH / MRR MOVEMENT
-- ==================================================================================================
/*
RECOGNITION CLUES: reactivation; previous CALENDAR month; expansion
GRAIN MAP: customer-month -> customer-month enriched -> month
SOLUTION METHOD: Self-join to DATE_SUB(cur.month, INTERVAL 1 MONTH); find first-ever month separately.
COMMON MISTAKE: LAG gets previous AVAILABLE payment, which may be months earlier.
RELATED PRACTICE: Prime Plus 2026-11-22 (pending independent attempt)
WORKED MINI-WALKTHROUGH: A paid January and March but not February: March previous-calendar payment is NULL, not January. B paid February and March: March previous amount is February amount.
*/

/* --- SOLVED EXAMPLE P12.1 | Previous calendar month payment vs previous available payment ---
QUESTION: Show each payment and amount paid in immediately previous calendar month, or NULL.
SCHEMA: plus_payments(customer_id,payment_month,amount)
SAMPLE INPUT: A Jan 100, Mar 130; B Feb 80, Mar 90
EXPECTED OUTPUT: A Jan NULL, A Mar NULL, B Feb NULL, B Mar 80
STEP 1 - GRAIN: customer-month -> customer-month enriched -> month
STEP 2 - PLAN: Self-join to DATE_SUB(cur.month, INTERVAL 1 MONTH); find first-ever month separately.
STEP 3 - WHY IT WORKS: A March has prior AVAILABLE January but not previous CALENDAR February.
EDGE CASE / CHECK: Use first-ever month separately to distinguish new from reactivation.
HIDE SQL BELOW AND ATTEMPT INDEPENDENTLY BEFORE REVISING.
*/
SELECT cur.customer_id,cur.payment_month,cur.amount,
 prev.amount AS prev_calendar_amount
FROM plus_payments cur
LEFT JOIN plus_payments prev
 ON prev.customer_id=cur.customer_id
 AND prev.payment_month=DATE_SUB(cur.payment_month,INTERVAL 1 MONTH)
ORDER BY cur.customer_id,cur.payment_month;

/* --- SOLVED EXAMPLE P12.2 | Monthly expansion and contraction (related variation) ---
QUESTION: For each paid month, report only expansion and contraction among customers who also paid in the immediately preceding calendar month.
SCHEMA: plus_payments(customer_id,payment_month,amount), PK(customer_id,payment_month)
SAMPLE INPUT: A Jan100,Feb130,Apr120; B Feb80,Mar70; C Mar50
EXPECTED OUTPUT: Jan expansion0 contraction0; Feb expansion30 contraction0; Mar expansion0 contraction10; Apr expansion0 contraction0
STEP 1 - GRAIN: customer-month -> customer-month enriched -> month
STEP 2 - PLAN: Self-join to DATE_SUB(cur.month, INTERVAL 1 MONTH); find first-ever month separately.
STEP 3 - WHY IT WORKS: Only customers with an adjacent prior-calendar-month payment can contribute to expansion or contraction.
EDGE CASE / CHECK: The FULL Prime Plus question remains unsolved in the Question Archive; do not look up its complete solution before independent attempt.
HIDE SQL BELOW AND ATTEMPT INDEPENDENTLY BEFORE REVISING.
*/
SELECT cur.payment_month,
 SUM(CASE WHEN prev.amount IS NOT NULL AND cur.amount>prev.amount
          THEN cur.amount-prev.amount ELSE 0 END) AS expansion_mrr,
 SUM(CASE WHEN prev.amount IS NOT NULL AND cur.amount<prev.amount
          THEN prev.amount-cur.amount ELSE 0 END) AS contraction_mrr
FROM plus_payments cur
LEFT JOIN plus_payments prev
 ON prev.customer_id=cur.customer_id
 AND prev.payment_month=DATE_SUB(cur.payment_month,INTERVAL 1 MONTH)
GROUP BY cur.payment_month ORDER BY cur.payment_month;

-- END P12

-- ==================================================================================================
-- P13 | RUNNING TOTALS / ROLLING WINDOWS
-- ==================================================================================================
/*
RECOGNITION CLUES: cumulative; last seven days
GRAIN MAP: raw -> daily totals -> daily windows
SOLUTION METHOD: Pre-aggregate at one row per day, then explicit ROWS frame; require contiguous dates for calendar-day meaning.
COMMON MISTAKE: Seven rows != seven calendar days if dates are missing.
RELATED PRACTICE: CORE Q03
*/

/* --- SOLVED EXAMPLE P13.1 | Three-day rolling revenue on complete daily calendar ---
QUESTION: Return 3-day sum of revenue; only complete 3-day windows.
SCHEMA: daily(day,revenue), one row per calendar day
SAMPLE INPUT: Jan01 10; Jan02 20; Jan03 30; Jan04 40
EXPECTED OUTPUT: Jan03 60; Jan04 90
STEP 1 - GRAIN: raw -> daily totals -> daily windows
STEP 2 - PLAN: Pre-aggregate at one row per day, then explicit ROWS frame; require contiguous dates for calendar-day meaning.
STEP 3 - WHY IT WORKS: The input guarantees consecutive daily rows, so three rows equal three calendar days.
EDGE CASE / CHECK: Without contiguous days, build a date spine before ROWS.
HIDE SQL BELOW AND ATTEMPT INDEPENDENTLY BEFORE REVISING.
*/
WITH w AS (
 SELECT day,
 SUM(revenue) OVER(ORDER BY day ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS roll3,
 COUNT(*) OVER(ORDER BY day ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS n
 FROM daily
)
SELECT day,roll3 FROM w WHERE n=3 ORDER BY day;

-- END P13

-- ==================================================================================================
-- P14 | GAPS AND ISLANDS / CONSECUTIVE DAYS
-- ==================================================================================================
/*
RECOGNITION CLUES: 3+ consecutive login days; longest streak
GRAIN MAP: event -> unique user-day -> island -> user
SOLUTION METHOD: Deduplicate days, ROW_NUMBER over dates, subtract rank days to obtain constant island key.
COMMON MISTAKE: Multiple events on same day break row-number offset unless deduped.
RELATED PRACTICE: CORE Q06; discussed longest streak
WORKED MINI-WALKTHROUGH: After DISTINCT user/date, ROW_NUMBER is 1,2,3 for Jan1,Jan2,Jan3. date minus rn days is the same island key for all three.
*/

/* --- SOLVED EXAMPLE P14.1 | Users with at least three consecutive login days ---
QUESTION: Find users with streak of 3 or more distinct calendar days.
SCHEMA: logins(user_id,login_date)
SAMPLE INPUT: A Jan01,Jan01,Jan02,Jan03,Jan06; B Jan01,Jan03
EXPECTED OUTPUT: A only (Jan01-Jan03)
STEP 1 - GRAIN: event -> unique user-day -> island -> user
STEP 2 - PLAN: Deduplicate days, ROW_NUMBER over dates, subtract rank days to obtain constant island key.
STEP 3 - WHY IT WORKS: For consecutive dates, date minus increasing row number is constant.
EDGE CASE / CHECK: Dedup first; ensure login_date is DATE not timestamp.
HIDE SQL BELOW AND ATTEMPT INDEPENDENTLY BEFORE REVISING.
*/
WITH days AS (
 SELECT DISTINCT user_id,login_date FROM logins
), seq AS (
 SELECT user_id,login_date,
 ROW_NUMBER() OVER(PARTITION BY user_id ORDER BY login_date) AS rn
 FROM days
), islands AS (
 SELECT user_id,DATE_SUB(login_date,INTERVAL rn DAY) AS island_key,
 COUNT(*) AS streak_len
 FROM seq GROUP BY user_id,DATE_SUB(login_date,INTERVAL rn DAY)
)
SELECT DISTINCT user_id FROM islands WHERE streak_len>=3;

/* --- SOLVED EXAMPLE P14.2 | Longest consecutive streak per user ---
QUESTION: Return each user and maximum number of consecutive login days.
SCHEMA: logins(user_id,login_date)
SAMPLE INPUT: A Jan01,Jan02,Jan05,Jan06,Jan07; B Jan10
EXPECTED OUTPUT: A 3; B 1
STEP 1 - GRAIN: event -> unique user-day -> island -> user
STEP 2 - PLAN: Deduplicate days, ROW_NUMBER over dates, subtract rank days to obtain constant island key.
STEP 3 - WHY IT WORKS: First identify every island, then take max length per user.
EDGE CASE / CHECK: Do not count gaps as days.
HIDE SQL BELOW AND ATTEMPT INDEPENDENTLY BEFORE REVISING.
*/
WITH days AS (
 SELECT DISTINCT user_id,login_date FROM logins
), seq AS (
 SELECT user_id,login_date,
 ROW_NUMBER() OVER(PARTITION BY user_id ORDER BY login_date) AS rn
 FROM days
), runs AS (
 SELECT user_id,DATE_SUB(login_date,INTERVAL rn DAY) AS grp,
 COUNT(*) AS len FROM seq
 GROUP BY user_id,DATE_SUB(login_date,INTERVAL rn DAY)
)
SELECT user_id,MAX(len) AS longest_streak
FROM runs GROUP BY user_id ORDER BY user_id;

-- END P14

-- ==================================================================================================
-- P15 | RELATIONAL DIVISION / ALL REQUIRED
-- ==================================================================================================
/*
RECOGNITION CLUES: completed every mandatory course; visited all locations
GRAIN MAP: employee-course -> employee
SOLUTION METHOD: Compare distinct qualifying completed requirements with count of required items; or double NOT EXISTS.
COMMON MISTAKE: Optional courses do not count; duplicates should not inflate count.
RELATED PRACTICE: CORE Q09; Stage1 Day2 Q3
*/

/* --- SOLVED EXAMPLE P15.1 | Employees who completed every mandatory course ---
QUESTION: Return employees who completed all required courses.
SCHEMA: employees(emp_id); courses(course_id,mandatory); completions(emp_id,course_id)
SAMPLE INPUT: required C1,C2; A C1,C2; B C1; C C1,C2,C2
EXPECTED OUTPUT: A,C
STEP 1 - GRAIN: employee-course -> employee
STEP 2 - PLAN: Compare distinct qualifying completed requirements with count of required items; or double NOT EXISTS.
STEP 3 - WHY IT WORKS: Double NOT EXISTS means there is no required course missing for employee.
EDGE CASE / CHECK: Also handles zero mandatory courses: everyone qualifies (vacuous truth).
HIDE SQL BELOW AND ATTEMPT INDEPENDENTLY BEFORE REVISING.
*/
SELECT e.emp_id
FROM employees e
WHERE NOT EXISTS (
 SELECT 1 FROM courses c
 WHERE c.mandatory=1 AND NOT EXISTS (
   SELECT 1 FROM completions x
   WHERE x.emp_id=e.emp_id AND x.course_id=c.course_id
 )
)
ORDER BY e.emp_id;

-- END P15

-- ==================================================================================================
-- P16 | GROUP BENCHMARK VS GLOBAL BENCHMARK
-- ==================================================================================================
/*
RECOGNITION CLUES: salary above dept average; sales above branch average
GRAIN MAP: employee -> employee enriched with group avg
SOLUTION METHOD: AVG(metric) OVER(PARTITION BY group), then filter in outer query.
COMMON MISTAKE: Window function cannot be directly used in WHERE at same SELECT level.
RELATED PRACTICE: Stage1 Day1 Q2/Q3
*/

/* --- SOLVED EXAMPLE P16.1 | Employees earning above their department average ---
QUESTION: Return employee and salary where salary exceeds department average.
SCHEMA: employees(emp_id,dept,salary)
SAMPLE INPUT: A E1 100,E2 200; B E3 50,E4 50
EXPECTED OUTPUT: E2 only (dept A average 150)
STEP 1 - GRAIN: employee -> employee enriched with group avg
STEP 2 - PLAN: AVG(metric) OVER(PARTITION BY group), then filter in outer query.
STEP 3 - WHY IT WORKS: Window avg adds department benchmark without collapsing employee rows.
EDGE CASE / CHECK: Compare full precision, not rounded display values.
HIDE SQL BELOW AND ATTEMPT INDEPENDENTLY BEFORE REVISING.
*/
WITH w AS (
 SELECT emp_id,dept,salary,
 AVG(salary) OVER(PARTITION BY dept) AS dept_avg
 FROM employees
)
SELECT emp_id,dept,salary FROM w
WHERE salary>dept_avg;

-- END P16

-- ==================================================================================================
-- P17 | GROUP NUMERATOR / GLOBAL DENOMINATOR
-- ==================================================================================================
/*
RECOGNITION CLUES: percentage of all users by country
GRAIN MAP: event -> country + global population
SOLUTION METHOD: Compute global denominator separately and CROSS JOIN or scalar subquery.
COMMON MISTAKE: Dividing by each country count gives 100% for every row.
RELATED PRACTICE: SQL_Pattern_Revision_Bank_Updated.md
*/

/* --- SOLVED EXAMPLE P17.1 | Country share of all customers ---
QUESTION: Return each country count and percentage of all customers.
SCHEMA: customers(customer_id,country)
SAMPLE INPUT: A,A,A,B,B
EXPECTED OUTPUT: A 3 60.00; B 2 40.00
STEP 1 - GRAIN: event -> country + global population
STEP 2 - PLAN: Compute global denominator separately and CROSS JOIN or scalar subquery.
STEP 3 - WHY IT WORKS: Country grain numerator divided by global grain denominator.
EDGE CASE / CHECK: COUNT(DISTINCT customer_id) if duplicate customer rows possible.
HIDE SQL BELOW AND ATTEMPT INDEPENDENTLY BEFORE REVISING.
*/
WITH by_country AS (
 SELECT country,COUNT(*) AS n FROM customers GROUP BY country
), total AS (
 SELECT COUNT(*) AS all_n FROM customers
)
SELECT b.country,b.n,
 ROUND(100.0*b.n/NULLIF(t.all_n,0),2) AS pct
FROM by_country b CROSS JOIN total t
ORDER BY b.country;

-- END P17

-- ==================================================================================================
-- P18 | MONTH-OVER-MONTH / YEAR-OVER-YEAR GROWTH
-- ==================================================================================================
/*
RECOGNITION CLUES: MoM growth; revenue change
GRAIN MAP: order -> month -> month with prior
SOLUTION METHOD: Aggregate to month then LAG; validate actual adjacency when calendar continuity matters.
COMMON MISTAKE: LAG may jump over a missing month; percentage denominator could be zero.
RELATED PRACTICE: CORE monthly growth
*/

/* --- SOLVED EXAMPLE P18.1 | Monthly revenue growth percentage ---
QUESTION: Return monthly revenue and percent change from previous available month.
SCHEMA: payments(payment_date,amount)
SAMPLE INPUT: Jan 100, Jan 50, Feb 200, Mar 100
EXPECTED OUTPUT: Jan 150 NULL; Feb 200 33.33%; Mar 100 -50.00%
STEP 1 - GRAIN: order -> month -> month with prior
STEP 2 - PLAN: Aggregate to month then LAG; validate actual adjacency when calendar continuity matters.
STEP 3 - WHY IT WORKS: LAG compares monthly totals after grouping, not individual payment rows.
EDGE CASE / CHECK: If previous CALENDAR month is required, use calendar spine/self-join, not plain LAG.
HIDE SQL BELOW AND ATTEMPT INDEPENDENTLY BEFORE REVISING.
*/
WITH monthly AS (
 SELECT DATE_FORMAT(payment_date,'%Y-%m') AS ym,
 SUM(amount) AS revenue
 FROM payments GROUP BY DATE_FORMAT(payment_date,'%Y-%m')
), w AS (
 SELECT ym,revenue,LAG(revenue) OVER(ORDER BY ym) AS prev_revenue
 FROM monthly
)
SELECT ym,revenue,
 ROUND(100.0*(revenue-prev_revenue)/NULLIF(prev_revenue,0),2) AS mom_pct
FROM w ORDER BY ym;

-- END P18

-- ==================================================================================================
-- P19 | WHERE VS HAVING / FILTER STAGE
-- ==================================================================================================
/*
RECOGNITION CLUES: groups with > N; revenue > threshold
GRAIN MAP: row -> group
SOLUTION METHOD: WHERE filters input rows; HAVING filters aggregate groups.
COMMON MISTAKE: SUM(amount) cannot be used in WHERE at same level.
RELATED PRACTICE: CORE Q01; Stage1 Day1
*/

/* --- SOLVED EXAMPLE P19.1 | Customers with delivered spend above 300 ---
QUESTION: Return customers whose total delivered amount >300.
SCHEMA: orders(customer_id,status,amount)
SAMPLE INPUT: A Delivered 200,Delivered 150,Cancelled 500; B Delivered 100
EXPECTED OUTPUT: A only, delivered total 350
STEP 1 - GRAIN: row -> group
STEP 2 - PLAN: WHERE filters input rows; HAVING filters aggregate groups.
STEP 3 - WHY IT WORKS: WHERE removes cancelled rows before SUM; HAVING tests aggregated spend.
EDGE CASE / CHECK: Moving status to HAVING is not equivalent when group has mixed statuses.
HIDE SQL BELOW AND ATTEMPT INDEPENDENTLY BEFORE REVISING.
*/
SELECT customer_id,SUM(amount) AS delivered_spend
FROM orders
WHERE status='Delivered'
GROUP BY customer_id
HAVING SUM(amount)>300;

-- END P19

-- ==================================================================================================
-- P20 | NULL SEMANTICS / PREVIOUS NON-NULL
-- ==================================================================================================
/*
RECOGNITION CLUES: previous non-null; forward-fill; NOT IN trap
GRAIN MAP: ordered row -> ordered row
SOLUTION METHOD: Define strict previous vs inclusive forward-fill; correlated ordered lookup; use NOT EXISTS for anti-join.
COMMON MISTAKE: LAG returns previous ROW even if NULL; NOT IN with NULL can make predicate UNKNOWN.
RELATED PRACTICE: Mentor NULL question explained, not mastered
WORKED MINI-WALKTHROUGH: For [1,2,NULL,3,NULL], strict previous non-NULL is [NULL,1,2,2,3]; inclusive forward-fill is [1,2,2,3,3]. Only < versus <= changes.
*/

/* --- SOLVED EXAMPLE P20.1 | Strict previous non-NULL value ---
QUESTION: For ordered rows 1,2,NULL,3,NULL return the most recent non-NULL value strictly BEFORE current row.
SCHEMA: events(event_id,id_value)
SAMPLE INPUT: (1,1),(2,2),(3,NULL),(4,3),(5,NULL)
EXPECTED OUTPUT: event 1 NULL; 2 1; 3 2; 4 2; 5 3
STEP 1 - GRAIN: ordered row -> ordered row
STEP 2 - PLAN: Define strict previous vs inclusive forward-fill; correlated ordered lookup; use NOT EXISTS for anti-join.
STEP 3 - WHY IT WORKS: Strict < excludes current value, even when non-NULL.
EDGE CASE / CHECK: Requires a deterministic ordering key; event_id here is the order.
HIDE SQL BELOW AND ATTEMPT INDEPENDENTLY BEFORE REVISING.
*/
SELECT e.event_id,e.id_value,
 (SELECT p.id_value FROM events p
  WHERE p.event_id<e.event_id AND p.id_value IS NOT NULL
  ORDER BY p.event_id DESC LIMIT 1) AS previous_non_null
FROM events e ORDER BY e.event_id;

/* --- SOLVED EXAMPLE P20.2 | Forward-fill NULL values (inclusive) ---
QUESTION: Return current value if non-NULL, otherwise most recent preceding non-NULL.
SCHEMA: events(event_id,id_value)
SAMPLE INPUT: (1,1),(2,2),(3,NULL),(4,3),(5,NULL)
EXPECTED OUTPUT: 1,2,2,3,3
STEP 1 - GRAIN: ordered row -> ordered row
STEP 2 - PLAN: Define strict previous vs inclusive forward-fill; correlated ordered lookup; use NOT EXISTS for anti-join.
STEP 3 - WHY IT WORKS: Inclusive <= is the sole logical difference from previous-non-NULL query.
EDGE CASE / CHECK: Leading NULLs remain NULL if no earlier value exists.
HIDE SQL BELOW AND ATTEMPT INDEPENDENTLY BEFORE REVISING.
*/
SELECT e.event_id,e.id_value,
 (SELECT p.id_value FROM events p
  WHERE p.event_id<=e.event_id AND p.id_value IS NOT NULL
  ORDER BY p.event_id DESC LIMIT 1) AS filled_value
FROM events e ORDER BY e.event_id;

-- END P20

-- ==================================================================================================
-- P21 | RECURSIVE CTE / HIERARCHY
-- ==================================================================================================
/*
RECOGNITION CLUES: all indirect reports; recursive sequence
GRAIN MAP: anchor rows -> recursive descendants
SOLUTION METHOD: Anchor + UNION ALL recursive member; stop when no new children.
COMMON MISTAKE: Cycle detection needed if data can contain loops.
RELATED PRACTICE: FAANG checklist; not independently attempted
*/

/* --- SOLVED EXAMPLE P21.1 | All reports under manager 1 ---
QUESTION: Return all direct and indirect reports of manager 1 with depth.
SCHEMA: employees(emp_id,manager_id)
SAMPLE INPUT: (1,NULL),(2,1),(3,1),(4,2),(5,4)
EXPECTED OUTPUT: 2 depth1,3 depth1,4 depth2,5 depth3
STEP 1 - GRAIN: anchor rows -> recursive descendants
STEP 2 - PLAN: Anchor + UNION ALL recursive member; stop when no new children.
STEP 3 - WHY IT WORKS: Anchor starts direct reports; recursive member finds reports of each previous report.
EDGE CASE / CHECK: Assumes acyclic reporting hierarchy; handle cycles for production data.
HIDE SQL BELOW AND ATTEMPT INDEPENDENTLY BEFORE REVISING.
*/
WITH RECURSIVE tree AS (
 SELECT emp_id,manager_id,1 AS depth
 FROM employees WHERE manager_id=1
 UNION ALL
 SELECT e.emp_id,e.manager_id,t.depth+1
 FROM employees e JOIN tree t ON e.manager_id=t.emp_id
)
SELECT emp_id,depth FROM tree ORDER BY depth,emp_id;

-- END P21

-- ==================================================================================================
-- P22 | STRING PARSING / PERMUTATIONS / COMBINATIONS
-- ==================================================================================================
/*
RECOGNITION CLUES: email domain; all strings from letters
GRAIN MAP: character/string -> parsed token or recursive path
SOLUTION METHOD: Use SUBSTRING_INDEX for domain; recursive indices for combinations, used-position state for permutations.
COMMON MISTAKE: Combinations ignore order, permutations consider order; repeated letters may duplicate outputs.
RELATED PRACTICE: Mentor string question discussed, not mastered
WORKED MINI-WALKTHROUGH: ABC combinations include AB but not BA; full permutations include BOTH ABC and ACB. Increasing positions enforce combinations; used-position bitmask enforces permutations.
*/

/* --- SOLVED EXAMPLE P22.1 | Extract email domains ---
QUESTION: Return domain part after @ for each valid email.
SCHEMA: users(user_id,email)
SAMPLE INPUT: 1 a@gmail.com; 2 b@company.org
EXPECTED OUTPUT: 1 gmail.com; 2 company.org
STEP 1 - GRAIN: character/string -> parsed token or recursive path
STEP 2 - PLAN: Use SUBSTRING_INDEX for domain; recursive indices for combinations, used-position state for permutations.
STEP 3 - WHY IT WORKS: Split on @ and take last component.
EDGE CASE / CHECK: For strict validation, LIKE alone is insufficient; define invalid-email rules.
HIDE SQL BELOW AND ATTEMPT INDEPENDENTLY BEFORE REVISING.
*/
SELECT user_id,SUBSTRING_INDEX(email,'@',-1) AS domain
FROM users
WHERE email LIKE '%@%';

/* --- SOLVED EXAMPLE P22.2 | All non-empty combinations of ABC ---
QUESTION: Generate all combinations of distinct character positions from ABC; order does not matter.
SCHEMA: input(name) containing (ABC)
SAMPLE INPUT: ABC
EXPECTED OUTPUT: A,B,C,AB,AC,BC,ABC
STEP 1 - GRAIN: character/string -> parsed token or recursive path
STEP 2 - PLAN: Use SUBSTRING_INDEX for domain; recursive indices for combinations, used-position state for permutations.
STEP 3 - WHY IT WORKS: Seed one-letter combinations at every position; recurse only to strictly larger positions so AB and BA are not both generated.
EDGE CASE / CHECK: Repeated letters can produce duplicate strings, so DISTINCT is intentional; combinations use positions, not unique letter values.
HIDE SQL BELOW AND ATTEMPT INDEPENDENTLY BEFORE REVISING.
*/
WITH RECURSIVE positions AS (
 SELECT name,1 AS pos FROM input
 UNION ALL
 SELECT name,pos+1 FROM positions WHERE pos<CHAR_LENGTH(name)
), combos AS (
 SELECT name,pos AS last_pos,CAST(SUBSTRING(name,pos,1) AS CHAR(255)) AS s
 FROM positions
 UNION ALL
 SELECT c.name,p.pos,CONCAT(c.s,SUBSTRING(c.name,p.pos,1))
 FROM combos c JOIN positions p
   ON p.name=c.name AND p.pos>c.last_pos
)
SELECT s FROM (SELECT DISTINCT s FROM combos) AS unique_combos
ORDER BY CHAR_LENGTH(s),s;

/* --- SOLVED EXAMPLE P22.3 | Full-length permutations of ABC ---
QUESTION: Generate every full-length permutation of the characters in ABC (order matters).
SCHEMA: input(name) containing (ABC)
SAMPLE INPUT: ABC
EXPECTED OUTPUT: ABC,ACB,BAC,BCA,CAB,CBA
STEP 1 - GRAIN: character/string -> parsed token or recursive path
STEP 2 - PLAN: Use SUBSTRING_INDEX for domain; recursive indices for combinations, used-position state for permutations.
STEP 3 - WHY IT WORKS: Seed each position as a one-letter path; recurse by appending only positions not yet used. Full length gives permutations.
EDGE CASE / CHECK: For repeated letters, DISTINCT removes duplicate strings; bitmask implementation is for short strings (up to 63 positions).
HIDE SQL BELOW AND ATTEMPT INDEPENDENTLY BEFORE REVISING.
*/
WITH RECURSIVE positions AS (
 SELECT name,1 AS pos FROM input
 UNION ALL
 SELECT name,pos+1 FROM positions WHERE pos<CHAR_LENGTH(name)
), perms AS (
 SELECT name,CAST(SUBSTRING(name,pos,1) AS CHAR(255)) AS s,
        CAST(1 AS UNSIGNED) << (pos-1) AS used_mask
 FROM positions
 UNION ALL
 SELECT p.name,CONCAT(p.s,SUBSTRING(p.name,x.pos,1)),
        p.used_mask | (CAST(1 AS UNSIGNED) << (x.pos-1))
 FROM perms p JOIN positions x
   ON x.name=p.name AND (p.used_mask & (CAST(1 AS UNSIGNED) << (x.pos-1)))=0
)
SELECT DISTINCT s FROM perms WHERE CHAR_LENGTH(s)=CHAR_LENGTH(name)
ORDER BY s;

-- END P22

-- ==================================================================================================
-- P23 | PIVOT / UNPIVOT
-- ==================================================================================================
/*
RECOGNITION CLUES: turn categories into columns; columns into rows
GRAIN MAP: row categories -> grouped wide columns; wide -> normalized rows
SOLUTION METHOD: Conditional SUM pivot; UNION ALL unpivot in MySQL.
COMMON MISTAKE: Fixed categories need fixed SQL columns; dynamic pivot requires generated SQL.
RELATED PRACTICE: FAANG checklist; not started
*/

/* --- SOLVED EXAMPLE P23.1 | Pivot sales by quarter ---
QUESTION: Return one row per store with Q1 and Q2 revenue.
SCHEMA: sales(store,quarter,amount)
SAMPLE INPUT: A Q1 100,A Q2 200,B Q1 50
EXPECTED OUTPUT: A 100 200; B 50 0
STEP 1 - GRAIN: row categories -> grouped wide columns; wide -> normalized rows
STEP 2 - PLAN: Conditional SUM pivot; UNION ALL unpivot in MySQL.
STEP 3 - WHY IT WORKS: Conditional sums turn values into separate output columns.
EDGE CASE / CHECK: Unknown quarters need dynamic SQL or long-format output.
HIDE SQL BELOW AND ATTEMPT INDEPENDENTLY BEFORE REVISING.
*/
SELECT store,
 SUM(CASE WHEN quarter='Q1' THEN amount ELSE 0 END) AS q1,
 SUM(CASE WHEN quarter='Q2' THEN amount ELSE 0 END) AS q2
FROM sales GROUP BY store ORDER BY store;

/* --- SOLVED EXAMPLE P23.2 | Unpivot two monthly columns ---
QUESTION: Convert monthly wide revenue into store/month/amount rows.
SCHEMA: wide_sales(store,jan,feb)
SAMPLE INPUT: A 100 200; B 50 60
EXPECTED OUTPUT: A Jan100,A Feb200,B Jan50,B Feb60
STEP 1 - GRAIN: row categories -> grouped wide columns; wide -> normalized rows
STEP 2 - PLAN: Conditional SUM pivot; UNION ALL unpivot in MySQL.
STEP 3 - WHY IT WORKS: UNION ALL stacks column values as rows without removing duplicates.
EDGE CASE / CHECK: If null values should be omitted, filter each branch.
HIDE SQL BELOW AND ATTEMPT INDEPENDENTLY BEFORE REVISING.
*/
SELECT store,'Jan' AS month_name,jan AS amount FROM wide_sales
UNION ALL
SELECT store,'Feb',feb FROM wide_sales;

-- END P23

-- ==================================================================================================
-- P24 | MEDIAN / PERCENTILES
-- ==================================================================================================
/*
RECOGNITION CLUES: median salary; P90 latency
GRAIN MAP: value -> ranked value -> one statistic
SOLUTION METHOD: For median use ROW_NUMBER and COUNT; for percentiles define nearest-rank vs interpolation.
COMMON MISTAKE: AVG is not median; PERCENTILE_CONT not available in all MySQL versions.
RELATED PRACTICE: FAANG checklist; not started
*/

/* --- SOLVED EXAMPLE P24.1 | Median salary per department (MySQL 8) ---
QUESTION: Return median salary for each department; average two middle values when even.
SCHEMA: employees(dept,salary)
SAMPLE INPUT: A 10,20,30; B 10,20,30,40
EXPECTED OUTPUT: A 20; B 25
STEP 1 - GRAIN: value -> ranked value -> one statistic
STEP 2 - PLAN: For median use ROW_NUMBER and COUNT; for percentiles define nearest-rank vs interpolation.
STEP 3 - WHY IT WORKS: Middle row(s) selected; AVG returns middle value or average of two.
EDGE CASE / CHECK: P90/P99 require explicit percentile definition (nearest rank vs continuous interpolation).
HIDE SQL BELOW AND ATTEMPT INDEPENDENTLY BEFORE REVISING.
*/
WITH ranked AS (
 SELECT dept,salary,
 ROW_NUMBER() OVER(PARTITION BY dept ORDER BY salary) AS rn,
 COUNT(*) OVER(PARTITION BY dept) AS cnt
 FROM employees
)
SELECT dept,AVG(salary) AS median_salary
FROM ranked
WHERE rn IN (FLOOR((cnt+1)/2),FLOOR((cnt+2)/2))
GROUP BY dept ORDER BY dept;

-- END P24

-- ==================================================================================================
-- P25 | SESSIONIZATION / INACTIVITY GAPS
-- ==================================================================================================
/*
RECOGNITION CLUES: new session after >30 min inactivity
GRAIN MAP: event -> gap/flag -> session ID -> session
SOLUTION METHOD: LAG timestamp; flag first event and gap > threshold; cumulative SUM flags.
COMMON MISTAKE: Boundary exactly 30 minutes must follow wording; order ties deterministically.
RELATED PRACTICE: FAANG checklist; not started
WORKED MINI-WALKTHROUGH: A 09:00 -> 09:20 gap20: same session. 09:20 -> 10:00 gap40: new session. 10:00 -> 10:15 gap15: same session.
*/

/* --- SOLVED EXAMPLE P25.1 | Assign sessions after >30 minute inactivity ---
QUESTION: A new session starts when gap from previous event is strictly greater than 30 minutes.
SCHEMA: events(event_id,user_id,event_time)
SAMPLE INPUT: A 09:00,09:20,10:00,10:15; B 08:00
EXPECTED OUTPUT: A session IDs 1,1,2,2; B 1
STEP 1 - GRAIN: event -> gap/flag -> session ID -> session
STEP 2 - PLAN: LAG timestamp; flag first event and gap > threshold; cumulative SUM flags.
STEP 3 - WHY IT WORKS: Cumulative number of starts labels each user session.
EDGE CASE / CHECK: TIMESTAMPDIFF(MINUTE,...) truncates seconds; for exact threshold use TIMESTAMPDIFF(SECOND,prev_time,event_time)>1800.
HIDE SQL BELOW AND ATTEMPT INDEPENDENTLY BEFORE REVISING.
*/
WITH gaps AS (
 SELECT event_id,user_id,event_time,
 LAG(event_time) OVER(PARTITION BY user_id
 ORDER BY event_time,event_id) AS prev_time
 FROM events
), flags AS (
 SELECT *,CASE WHEN prev_time IS NULL OR
 TIMESTAMPDIFF(SECOND,prev_time,event_time)>1800
 THEN 1 ELSE 0 END AS new_session
 FROM gaps
)
SELECT event_id,user_id,event_time,
 SUM(new_session) OVER(PARTITION BY user_id
 ORDER BY event_time,event_id ROWS UNBOUNDED PRECEDING) AS session_id
FROM flags ORDER BY user_id,event_time,event_id;

/* --- SOLVED EXAMPLE P25.2 | Session metrics ---
QUESTION: After assigning session_id, calculate start/end and event count per session.
SCHEMA: sessionized(user_id,session_id,event_time)
SAMPLE INPUT: A S1 09:00,09:20; A S2 10:00,10:15
EXPECTED OUTPUT: A S1 start09:00 end09:20 count2; A S2 start10:00 end10:15 count2
STEP 1 - GRAIN: event -> gap/flag -> session ID -> session
STEP 2 - PLAN: LAG timestamp; flag first event and gap > threshold; cumulative SUM flags.
STEP 3 - WHY IT WORKS: Aggregate by both user and session ID (session IDs restart per user).
EDGE CASE / CHECK: Do not group by session_id alone across all users.
HIDE SQL BELOW AND ATTEMPT INDEPENDENTLY BEFORE REVISING.
*/
SELECT user_id,session_id,
 MIN(event_time) AS session_start,
 MAX(event_time) AS session_end,
 COUNT(*) AS event_count
FROM sessionized
GROUP BY user_id,session_id
ORDER BY user_id,session_id;

-- END P25

-- ==================================================================================================
-- P26 | DEDUPLICATION / KEEP LATEST
-- ==================================================================================================
/*
RECOGNITION CLUES: latest per key; delete duplicate records
GRAIN MAP: row -> natural key ranked -> one retained row
SOLUTION METHOD: ROW_NUMBER PARTITION BY business key ORDER BY updated_at DESC,id DESC.
COMMON MISTAKE: Deleting all duplicate rows or ignoring tie-breaker.
RELATED PRACTICE: CORE Q05; Stage1 Day3
*/

/* --- SOLVED EXAMPLE P26.1 | Keep latest row per email ---
QUESTION: Select one latest row for each email.
SCHEMA: users(id,email,updated_at)
SAMPLE INPUT: 1 a@x Jan01;2 a@x Feb01;3 b@x Jan01
EXPECTED OUTPUT: id 2 and id 3
STEP 1 - GRAIN: row -> natural key ranked -> one retained row
STEP 2 - PLAN: ROW_NUMBER PARTITION BY business key ORDER BY updated_at DESC,id DESC.
STEP 3 - WHY IT WORKS: Business key email defines duplicates; recency and ID determine winner.
EDGE CASE / CHECK: For DELETE, identify losing IDs and verify in SELECT before deletion.
HIDE SQL BELOW AND ATTEMPT INDEPENDENTLY BEFORE REVISING.
*/
WITH ranked AS (
 SELECT *,ROW_NUMBER() OVER(PARTITION BY email
 ORDER BY updated_at DESC,id DESC) AS rn
 FROM users
)
SELECT id,email,updated_at FROM ranked WHERE rn=1;

-- END P26

-- ==================================================================================================
-- P27 | EVENT ROLES / UNION ALL
-- ==================================================================================================
/*
RECOGNITION CLUES: sender and receiver totals; both sides of transaction
GRAIN MAP: transaction -> participant-role rows -> participant
SOLUTION METHOD: UNION ALL normalizes sender and receiver to common user_id column.
COMMON MISTAKE: UNION removes legitimate duplicate role events; sign amounts if net balance requested.
RELATED PRACTICE: SQL_Pattern_Revision_Bank_Updated.md
*/

/* --- SOLVED EXAMPLE P27.1 | Total transaction participation per user ---
QUESTION: Count every transaction in which a user was sender or receiver.
SCHEMA: transfers(id,sender,receiver)
SAMPLE INPUT: 1 A B; 2 A C; 3 B C
EXPECTED OUTPUT: A 2; B 2; C 2
STEP 1 - GRAIN: transaction -> participant-role rows -> participant
STEP 2 - PLAN: UNION ALL normalizes sender and receiver to common user_id column.
STEP 3 - WHY IT WORKS: Each transfer creates one row for each role; aggregate normalized participants.
EDGE CASE / CHECK: Self-transfer creates two participations; define whether that should count once.
HIDE SQL BELOW AND ATTEMPT INDEPENDENTLY BEFORE REVISING.
*/
WITH participants AS (
 SELECT id,sender AS user_id FROM transfers
 UNION ALL
 SELECT id,receiver AS user_id FROM transfers
)
SELECT user_id,COUNT(*) AS participations
FROM participants GROUP BY user_id ORDER BY user_id;

-- END P27

-- ==================================================================================================
-- P28 | ANY VS ALL COMPARISONS
-- ==================================================================================================
/*
RECOGNITION CLUES: greater than any in group; greater than all
GRAIN MAP: employee -> employee threshold
SOLUTION METHOD: ANY > MIN(reference), ALL > MAX(reference) for non-empty non-NULL comparison sets.
COMMON MISTAKE: Empty sets and NULLs have special SQL semantics; do not blindly replace quantified subqueries.
RELATED PRACTICE: SQL_Pattern_Revision_Bank_Updated.md
*/

/* --- SOLVED EXAMPLE P28.1 | Salary greater than ALL salaries in Sales ---
QUESTION: Return employees whose salary exceeds every salary in Sales.
SCHEMA: employees(emp_id,dept,salary)
SAMPLE INPUT: E1 Sales 50,E2 Sales 70,E3 Tech 80,E4 Tech 60
EXPECTED OUTPUT: E3 only
STEP 1 - GRAIN: employee -> employee threshold
STEP 2 - PLAN: ANY > MIN(reference), ALL > MAX(reference) for non-empty non-NULL comparison sets.
STEP 3 - WHY IT WORKS: ALL compares against each salary in reference group; 80 > 50 and 70.
EDGE CASE / CHECK: For empty Sales set, > ALL(empty) is true; > MAX(empty) would be UNKNOWN, so not equivalent.
HIDE SQL BELOW AND ATTEMPT INDEPENDENTLY BEFORE REVISING.
*/
SELECT e.emp_id
FROM employees e
WHERE e.salary > ALL (
 SELECT s.salary FROM employees s WHERE s.dept='Sales'
);

-- END P28

-- ==================================================================================================
-- P29 | COHORT RETENTION
-- ==================================================================================================
/*
RECOGNITION CLUES: month 0 signup; month 1 retention
GRAIN MAP: event -> user/month distinct -> cohort/month offset
SOLUTION METHOD: Find first activity month; join distinct user active months; count users at each offset.
COMMON MISTAKE: Do not count raw events; one user with five events counts once.
RELATED PRACTICE: FAANG checklist; not started
*/

/* --- SOLVED EXAMPLE P29.1 | Month-1 retention by first active month ---
QUESTION: For each signup cohort, return cohort size and number active exactly next calendar month.
SCHEMA: activity(user_id,activity_month) first day of month
SAMPLE INPUT: A Jan,Feb; B Jan,Jan; C Feb,Mar
EXPECTED OUTPUT: Jan cohort size2 retained1; Feb cohort size1 retained1
STEP 1 - GRAIN: event -> user/month distinct -> cohort/month offset
STEP 2 - PLAN: Find first activity month; join distinct user active months; count users at each offset.
STEP 3 - WHY IT WORKS: Distinct user-month prevents double-counting; date arithmetic enforces next calendar month.
EDGE CASE / CHECK: Use successful activity only if business definition requires it.
HIDE SQL BELOW AND ATTEMPT INDEPENDENTLY BEFORE REVISING.
*/
WITH months AS (
 SELECT DISTINCT user_id,activity_month FROM activity
), firsts AS (
 SELECT user_id,MIN(activity_month) AS cohort_month
 FROM months GROUP BY user_id
), sizes AS (
 SELECT cohort_month,COUNT(*) AS cohort_size
 FROM firsts GROUP BY cohort_month
), retained AS (
 SELECT f.cohort_month,COUNT(*) AS retained_users
 FROM firsts f JOIN months m ON m.user_id=f.user_id
 AND m.activity_month=DATE_ADD(f.cohort_month,INTERVAL 1 MONTH)
 GROUP BY f.cohort_month
)
SELECT s.cohort_month,s.cohort_size,
 COALESCE(r.retained_users,0) AS retained_users
FROM sizes s LEFT JOIN retained r ON s.cohort_month=r.cohort_month
ORDER BY s.cohort_month;

-- END P29

-- ==================================================================================================
-- P30 | SQL IMPLEMENTATION / DEBUGGING CHECKLIST
-- ==================================================================================================
/*
RECOGNITION CLUES: idea correct but query fails
GRAIN MAP: all query stages
SOLUTION METHOD: Trace CTE columns and aliases; validate each GROUP BY; close CASE END; test sample and ties.
COMMON MISTAKE: Wrong alias, malformed DATE_FORMAT, CASE END outside SUM, ! =.
RELATED PRACTICE: Namastekart 2026-11-22
*/

/* --- SOLVED EXAMPLE P30.1 | Debug a flawed new/repeat query ---
QUESTION: The query below has alias, date grain and CASE syntax errors. Produce correct monthly repeat revenue.
SCHEMA: orders(order_id,customer_id,order_date,amount,status)
SAMPLE INPUT: A Jan 100,A Feb 150,B Feb 200
EXPECTED OUTPUT: Jan repeat0; Feb repeat150
STEP 1 - GRAIN: all query stages
STEP 2 - PLAN: Trace CTE columns and aliases; validate each GROUP BY; close CASE END; test sample and ties.
STEP 3 - WHY IT WORKS: Confirm: ym and first_ym both YYYY-MM; alias valid; CASE END inside SUM; grouping month only.
EDGE CASE / CHECK: Check output for first-month multiple orders, cancelled earlier order, zero revenue.
HIDE SQL BELOW AND ATTEMPT INDEPENDENTLY BEFORE REVISING.
*/
WITH valid AS (
 SELECT customer_id,amount,
 DATE_FORMAT(order_date,'%Y-%m') AS ym,
 MIN(DATE_FORMAT(order_date,'%Y-%m')) OVER(PARTITION BY customer_id) AS first_ym
 FROM orders WHERE status='Delivered'
)
SELECT ym,
 SUM(CASE WHEN ym>first_ym THEN amount ELSE 0 END) AS repeat_revenue
FROM valid GROUP BY ym ORDER BY ym;

-- END P30

-- ==================================================================================================
-- REVISION RULE: a read example = STUDIED, not MASTERED. Only a new unseen, timed solve proves mastery.
-- Archive full attempts in SQL_Question_Archive.sql; record retests/scores in SQL_Interview_Progress_Tracker.xlsx.
-- ==================================================================================================
