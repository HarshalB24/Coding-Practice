/*
================================================================================
 SQL INTERVIEW PATTERN RECOGNITION | 10-QUESTION PRACTICE REVIEW
 Date of practice: 2026-10-10 / 2026-10-11
 Target: Product-company Data Engineering interviews
 Dialect: MySQL 8.0+ (window functions, DATE_FORMAT, DATEDIFF)

 PURPOSE
 - Compare YOUR reasoning/SQL with a robust solution.
 - Record the exact issue and the mistake to avoid next time.
 - Revision file for a Git repository; no real client data or names.

 HOW TO USE
 1. Read the question and YOUR ATTEMPT (commented out).
 2. Predict/fix the mistake before looking at the corrected SQL.
 3. Verify output grain, base population, ordering, NULLs and tie rules.
 4. Correct solutions below are runnable SELECTs when example tables exist.
    Each question is an independent exercise; schemas are specified in comments.

 SOURCE FIDELITY
 - Q4-Q10 attempts are transcribed from the practice chat (formatting adjusted).
 - Q1 full original attempt is available from the session recap.
 - Q2/Q3 full verbatim SQL is not available in the retained session context.
   Only confirmed fragments/decisions are recorded; no invented full attempts.
 - Q8's >= instead of <= was identified by the learner as a typing slip.

 INDEX
 Q01 Aggregate of aggregates / multiple grain levels
 Q02 LEAD: immediate next event
 Q03 7-day rolling window / ROWS frames
 Q04 Anti-join / missing customers
 Q05 Latest record / tie-breaking
 Q06 3 consecutive calendar days
 Q07 Conditional aggregation / zero completed vs zero orders
 Q08 Top N distinct salaries / DENSE_RANK
 Q09 Every required warehouse / relational division
 Q10 As-of-date snapshot / preserve customers
================================================================================
*/

/* =============================================================================
 Q01 | MULTI-LEVEL AGGREGATION — MONTHLY TOTALS VS THEIR AVERAGE
 -----------------------------------------------------------------------------
 Schema: Sales(sale_id, product_id, sale_date, amount)
 Requirement: Return products whose MAXIMUM monthly total sales amount is greater
 than TWICE their AVERAGE monthly total. Average considers months WITH sales only.
 A month is YEAR+MONTH, not just calendar month number.
 Output: product_id (one row per qualifying product).

 YOUR REASONING
 - Raw: one row per sale.
 - Intermediate: monthly revenue per product.
 - Final: one row per product meeting the comparison.
 - Recognized GROUP BY / MAX / AVG; no window needed.

 YOUR ORIGINAL ATTEMPT (commented out; intentionally incorrect)
 -----------------------------------------------------------------------------
 WITH cte AS (
     SELECT product_id,
            MONTH(sale_date) AS mnth,
            SUM(amount) monthly_revenue,
            AVG(amount) avg_monthly
     FROM Sales
     GROUP BY product_id, MONTH(sale_date)
 )
 SELECT product_id FROM cte
 WHERE MAX(monthly_revenue) > 2*avg_monthly
 GROUP BY product_id;
 -----------------------------------------------------------------------------
 WHY IT FAILED
 1. MONTH(sale_date) mixes, e.g., Jan 2025 and Jan 2026.
 2. AVG(amount) averages individual sales rows, NOT monthly totals.
 3. MAX() cannot be used in WHERE at this grouping stage: use HAVING.
 4. Need two grain transitions: sale -> product/year-month -> product.

 AVOID: applying an aggregate to raw rows when the question asks for an
        aggregate of group totals.
 CHECK: 'average monthly revenue' means AVG(monthly_revenue), not AVG(amount).
*/
WITH monthly_sales AS (
    SELECT
        product_id,
        DATE_FORMAT(sale_date, '%Y-%m') AS sale_month,
        SUM(amount) AS monthly_revenue
    FROM Sales
    GROUP BY product_id, DATE_FORMAT(sale_date, '%Y-%m')
)
SELECT product_id
FROM monthly_sales
GROUP BY product_id
HAVING MAX(monthly_revenue) > 2 * AVG(monthly_revenue);


/* =============================================================================
 Q02 | LEAD — LOGIN IMMEDIATELY FOLLOWED BY PURCHASE
 -----------------------------------------------------------------------------
 Schema: UserEvents(event_id, user_id, event_time, event_type)
 Requirement: Find distinct users for whom ANY login is IMMEDIATELY followed by
 a purchase in their event sequence. Sort by event_time, then event_id.
 Output: user_id.

 YOUR CONFIRMED APPROACH/FRAGMENTS (full original SQL not available)
 - Chose LEAD(event_type), which IS the correct function.
 - Also added ROW_NUMBER() and filtered rn = 1 (incorrect restriction).
 - Included invalid comparison:
       CASE WHEN event_type + INTERVAL 1 = 'purchase' ...
 - Missed the correct outer predicate comparing CURRENT login to NEXT purchase.

 WHY IT FAILED
 1. rn = 1 tests only the first event, but ANY login can qualify.
 2. LEAD(event_type) returns next EVENT TYPE on the current row; it does not
    mean adding an interval or offset to the text value event_type.
 3. Compare current event_type and next_event after computing the window.
 4. DISTINCT prevents repeating a user with multiple qualifying sequences.

 AVOID: choosing rn=1 simply because ROW_NUMBER is available.
 TRIGGER: 'immediately followed by' => compare current row to LEAD(next row).
*/
WITH sequenced_events AS (
    SELECT
        user_id,
        event_type,
        LEAD(event_type) OVER (
            PARTITION BY user_id
            ORDER BY event_time, event_id
        ) AS next_event
    FROM UserEvents
)
SELECT DISTINCT user_id
FROM sequenced_events
WHERE event_type = 'login'
  AND next_event = 'purchase';


/* =============================================================================
 Q03 | COMPLETE 7-DAY ROLLING SUM
 -----------------------------------------------------------------------------
 Schema: DailyActivity(activity_date DATE, active_users INT)
 IMPORTANT DATA CONTRACT: exactly ONE ROW for EVERY calendar day; consecutive
 dates without gaps. active_users is a numeric daily COUNT, NOT a user_id.
 Requirement: Return activity_date and total active_users across the CURRENT day
 plus SIX previous calendar days. Include ONLY complete seven-day windows.
 Output: activity_date, rolling_7day_users.

 YOUR CONFIRMED APPROACH/FRAGMENTS (full original SQL not available)
 - Treated numeric active_users as if it were a user identifier.
 - Used LEAD(activity_date) partitioned by active_users.
 - Tried attaching a ROWS BETWEEN window frame to LEAD().
 - Considered rn >= 7, which IS useful, but the SUM window was missing.

 FAIRNESS NOTE
 The original exercise was presented without sample rows; the learner rightly
 pointed out that active_users could be misread. This is NOT a clean assessment
 of conceptual understanding. The corrected data contract is stated above.

 WHY IT FAILED
 1. Need SUM(active_users), not LEAD(activity_date).
 2. Window SUM OVER(ORDER BY date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW).
 3. rn >= 7 removes incomplete windows at the start.
 4. ROWS counts ROWS, not calendar days in general. It represents seven days
    here ONLY because the input has one row per consecutive date.

 AVOID: assuming a 7-ROW frame equals seven calendar DAYS with missing dates.
 TRIGGER: 'rolling sum' => SUM(...) OVER(...ROWS BETWEEN...).
*/
WITH rolling_activity AS (
    SELECT
        activity_date,
        SUM(active_users) OVER (
            ORDER BY activity_date
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ) AS rolling_7day_users,
        ROW_NUMBER() OVER (ORDER BY activity_date) AS rn
    FROM DailyActivity
)
SELECT activity_date, rolling_7day_users
FROM rolling_activity
WHERE rn >= 7
ORDER BY activity_date;


/* =============================================================================
 Q04 | ANTI-JOIN — CUSTOMERS WHO NEVER ORDERED
 -----------------------------------------------------------------------------
 Customers(customer_id, customer_name)
 Orders(order_id, customer_id, order_date)
 Sample: Customers 101 Alice; 102 Bob; 103 Charlie; 104 David; 105 Emma.
         Orders (1,101), (2,101), (3,103), (4,105).
 Requirement: customers with NO order. Output: customer_id, customer_name.
 Expected: (102, Bob), (104, David).

 YOUR ORIGINAL ATTEMPT #1 (commented out)
 SELECT c.customer_id, c.customer_name FROM customer c
 LEFT JOIN orders o ON c.customer_id = o.customer_id
 WHERE o.order_id IS NULL OR o.order_id = '';

 YOUR ORIGINAL ATTEMPT #2 (commented out; incorrect)
 SELECT customer_id, customer_name FROM customer
 WHERE customer_id NOT IN (
     SELECT * FROM orders GROUP BY customer_id
 );

 ASSESSMENT
 - Correctly recognized LEFT JOIN + IS NULL.
 - Raw grains should be stated separately: Customers=1/customer; Orders=1/order.
 - No GROUP BY needed for the LEFT JOIN anti-join.
 - order_id = '' is unnecessary (and order_id may be numeric).
 - NOT IN subquery must return ONE COLUMN; SELECT * is invalid here.
 - NOT IN can fail unintuitively when the subquery contains NULL customer_id.

 AVOID: GROUP BY without aggregation, SELECT * inside a one-column IN subquery.
 TRIGGER: 'never placed' => missing right-hand match, NOT EXISTS or anti-join.
*/
SELECT c.customer_id, c.customer_name
FROM Customers c
LEFT JOIN Orders o
    ON o.customer_id = c.customer_id
WHERE o.order_id IS NULL;

-- Q04 alternative (NULL-safe even if Orders.customer_id contains NULL):
SELECT c.customer_id, c.customer_name
FROM Customers c
WHERE NOT EXISTS (
    SELECT 1
    FROM Orders o
    WHERE o.customer_id = c.customer_id
);


/* =============================================================================
 Q05 | LATEST CUSTOMER EMAIL / DETERMINISTIC DEDUPLICATION
 -----------------------------------------------------------------------------
 CustomerUpdates(update_id, customer_id, email, updated_at)
 Samples: (1,101,alice_old@mail.com,2026-10-01 10:00)
          (2,102,bob@mail.com,2026-10-01 11:00)
          (3,101,alice_new@mail.com,2026-10-03 09:00)
          (4,103,charlie@mail.com,2026-10-02 14:00)
          (5,102,bob_new@mail.com,2026-10-04 08:00)
          (6,101,alice_final@mail.com,2026-10-05 16:00)
 Requirement: one latest email per customer; on timestamp tie take MAX update_id.
 Expected: (101,alice_final@mail.com), (102,bob_new@mail.com),
           (103,charlie@mail.com).

 YOUR ORIGINAL ATTEMPT
 WITH cte AS (
   SELECT customer_id, email,
       ROW_NUMBER() OVER (
          PARTITION BY customer_id ORDER BY updated_at, update_id DESC
       ) AS rn
   FROM customerupdates
 )
 SELECT customer_id, email FROM cte WHERE rn=1;

 WHY IT FAILED
 - ORDER BY updated_at (default ASC) puts OLDEST date first.
 - Tie breaker DESC was correct, but the primary timestamp also needs DESC.
 - Grain and ROW_NUMBER() selection were already correct.

 AVOID: trusting DESC on the second sort key to make the first key descending.
 TRIGGER: 'latest' => effective timestamp DESC + deterministic tie-breaker DESC.
*/
WITH ranked_updates AS (
    SELECT
        customer_id,
        email,
        ROW_NUMBER() OVER (
            PARTITION BY customer_id
            ORDER BY updated_at DESC, update_id DESC
        ) AS rn
    FROM CustomerUpdates
)
SELECT customer_id, email
FROM ranked_updates
WHERE rn = 1;


/* =============================================================================
 Q06 | AT LEAST THREE CONSECUTIVE CALENDAR LOGIN DAYS
 -----------------------------------------------------------------------------
 Logins(user_id, login_date)
 Samples: 101: Oct 1,2,3,5; 102: Oct 1,3,4; 103: Oct 2,3,4 (2026).
 One row maximum per user/day.
 Requirement: users with AT LEAST 3 consecutive calendar login days.
 Expected: 101,103.

 YOUR ORIGINAL ATTEMPT
 WITH cte AS (
   SELECT user_id,
          LEAD(login_Date,1) OVER
              (PARTITION BY user_id ORDER BY login_date) AS lead_1,
          LEAD(login_Date,2) OVER
              (PARTITION BY user_id ORDER BY login_date) AS lead_2
   FROM logins
 )
 SELECT user_id FROM cte
 WHERE DATEDIFF(login_date,lead_1)=1
   AND DATEDIFF(lead_1,lead_2)=1;

 WHY IT FAILED
 - login_date used in outer WHERE was not selected inside CTE.
 - MySQL DATEDIFF(later,earlier)=+1; reversed operands give -1.
 - A user may have multiple 3-day streaks; add DISTINCT to final user_id.
 - Choosing LEAD (instead of LAG) was VALID; this is not a pattern mistake.

 AVOID: forgetting to carry columns through CTEs; reversing date subtraction.
 TRIGGER: LEAD -> DATEDIFF(next,current); LAG -> DATEDIFF(current,previous).
*/
WITH next_two_logins AS (
    SELECT
        user_id,
        login_date,
        LEAD(login_date, 1) OVER (
            PARTITION BY user_id ORDER BY login_date
        ) AS lead_1,
        LEAD(login_date, 2) OVER (
            PARTITION BY user_id ORDER BY login_date
        ) AS lead_2
    FROM Logins
)
SELECT DISTINCT user_id
FROM next_two_logins
WHERE DATEDIFF(lead_1, login_date) = 1
  AND DATEDIFF(lead_2, lead_1) = 1;

-- Q06 equally valid LAG alternative:
WITH previous_two_logins AS (
    SELECT
        user_id,
        login_date,
        LAG(login_date, 1) OVER (
            PARTITION BY user_id ORDER BY login_date
        ) AS prev_1,
        LAG(login_date, 2) OVER (
            PARTITION BY user_id ORDER BY login_date
        ) AS prev_2
    FROM Logins
)
SELECT DISTINCT user_id
FROM previous_two_logins
WHERE DATEDIFF(login_date, prev_1) = 1
  AND DATEDIFF(prev_1, prev_2) = 1;


/* =============================================================================
 Q07 | CONDITIONAL AGGREGATION — ZERO COMPLETED VS ZERO ORDERS
 -----------------------------------------------------------------------------
 Orders(order_id, customer_id, status, amount)
 Samples: (1,101,completed,500), (2,101,cancelled,200),
          (3,101,completed,300), (4,102,cancelled,150),
          (5,102,pending,100), (6,103,completed,400),
          (7,103,completed,600), (8,103,cancelled,100).
 Requirement: per customer total_orders, completed_orders, completed_amount,
 completion_rate as a percentage rounded to 2 decimals. Include customers WITH
 ORDERS but with ZERO COMPLETED orders. Does NOT require missing customers.
 Expected: 101 -> 3,2,800,66.67; 102 -> 2,0,0,0.00;
           103 -> 3,2,1000,66.67.

 YOUR ORIGINAL ATTEMPT (commented out; intentionally malformed)
 WITH cte c AS (
    SELECT customer_id,
           COUNT(order_id) AS total_orders,
           SUM(CASE WHEN status='completed THEN 1 ELSE 0 END)
               AS completed_orders,
           SUM(CASE WHEN status='completed' THEN amount ELSE 0 END)
               AS completed_amount
    FROM orders
    GROUP BY customer_id
 )
 SELECT customer_id, total_orders, completed_orders, completed_amount,
        ROUND(completed_orders/total_orders),2) AS completion_rate
 FROM cte
 JOIN cte2 c2 ON c.customer_id=c2.customer_id;

 WHY IT FAILED
 - Misinterpreted 'zero COMPLETED orders' as 'zero orders of ANY status'.
 - All customers in this exercise appear in Orders; no master-table join needed.
 - WITH cte c AS is invalid; missing quote in 'completed'; missing CTE2.
 - ROUND parentheses incorrect; forgot x100 for percentage.
 - Conditional SUM approach itself was RIGHT.

 AVOID: solving a bigger/different population than requirement specifies.
 TRIGGER: zero qualifying orders != customer entirely absent from Orders.
*/
SELECT
    customer_id,
    COUNT(*) AS total_orders,
    SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END)
        AS completed_orders,
    SUM(CASE WHEN status = 'completed' THEN amount ELSE 0 END)
        AS completed_amount,
    ROUND(
        100.0 * SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END)
        / COUNT(*),
        2
    ) AS completion_rate
FROM Orders
GROUP BY customer_id;

/* Q07 BONUS — IF question explicitly says ALL customers, even zero TOTAL orders:
   Requires separate Customers(customer_id,...). Non-null order_id counts orders,
   NULLIF protects zero denominator, COALESCE maps NULL percentage to 0. */
SELECT
    c.customer_id,
    COUNT(o.order_id) AS total_orders,
    SUM(CASE WHEN o.status = 'completed' THEN 1 ELSE 0 END)
        AS completed_orders,
    SUM(CASE WHEN o.status = 'completed' THEN o.amount ELSE 0 END)
        AS completed_amount,
    COALESCE(
        ROUND(
            100.0 * SUM(CASE WHEN o.status = 'completed' THEN 1 ELSE 0 END)
            / NULLIF(COUNT(o.order_id), 0),
            2
        ),
        0
    ) AS completion_rate
FROM Customers c
LEFT JOIN Orders o
    ON o.customer_id = c.customer_id
GROUP BY c.customer_id;


/* =============================================================================
 Q08 | TOP 2 DISTINCT SALARY LEVELS WITH TIES
 -----------------------------------------------------------------------------
 EmployeeSalary(employee_id, department_id, salary)
 Samples: dept10 (101,90000), (102,80000), (103,80000), (104,70000);
          dept20 (105,95000), (106,85000), (107,85000), (108,75000).
 Requirement: employees earning a top 2 DISTINCT salary within THEIR dept;
 keep ALL ties. Expected ids: 101,102,103,105,106,107.

 YOUR ORIGINAL ATTEMPT
 WITH cte AS (
   SELECT employee_id, department_id, salary,
          DENSE_RANK() OVER
              (PARTITION BY department_id ORDER BY salary DESC) AS rn
   FROM employeesalary
 )
 SELECT employee_id, department_id, salary FROM cte WHERE rn>=2;

 LEARNER CLARIFICATION: >= instead of <= was a TYPING SLIP; pattern is correct.
 WHY THE FILTER WOULD FAIL IF RUN AS WRITTEN
 - rn >= 2 excludes highest salary (rank 1) and includes rank 3+.
 - DENSE_RANK is correct: RANK can skip levels after ties; ROW_NUMBER splits ties.

 AVOID: overcounting this as a conceptual mistake; verify final inequality.
 TRIGGER: top N levels + ties => DENSE_RANK <= N after DESC ordering.
*/
WITH salary_levels AS (
    SELECT
        employee_id,
        department_id,
        salary,
        DENSE_RANK() OVER (
            PARTITION BY department_id
            ORDER BY salary DESC
        ) AS salary_rank
    FROM EmployeeSalary
)
SELECT employee_id, department_id, salary
FROM salary_levels
WHERE salary_rank <= 2;


/* =============================================================================
 Q09 | EVERY REQUIRED WAREHOUSE — SET COMPLETENESS
 -----------------------------------------------------------------------------
 ProductInventory(product_id, warehouse_id)
 Samples: 101-W1,W2,W3; 102-W1,W2; 103-W1,W2,W3; 104-W3.
 RequiredWarehouses(warehouse_id): W1, W2, W3.
 Requirement: return products present in EVERY required warehouse. Duplicate
 inventory records must not change result. Expected: 101,103.

 YOUR ORIGINAL ATTEMPT #1
 SELECT DISTINCT product_id FROM productinventory
 WHERE warehouse_id EXISTS IN (
   SELECT warehouse_id FROM reqiuredwarehouses
 );

 YOUR ORIGINAL ATTEMPT #2
 SELECT product_id, COUNT(warehouse_id) FROM productinventory
 GROUP BY product_id
 HAVING COUNT(DISTINCT warehouse_id) =
        (SELECT COUNT(*) FROM requiredwarehosue);

 WHY IT FAILED / EDGE CASE
 - EXISTS IN is invalid syntax: use IN or EXISTS separately.
 - Membership in ONE required warehouse is not membership in EVERY warehouse.
 - Attempt #2 works for sample if inventory ONLY has required warehouses.
 - Edge case: product in W1,W2,W4 would count as 3, but misses required W3.
 - Need to JOIN/FILTER to required set BEFORE counting distinct matched IDs.
 - Grouped count in SELECT is not needed if expected output is just product_id.

 ASSUMPTION: RequiredWarehouses is nonempty and identifies a set of unique IDs;
 COUNT(DISTINCT ...) also protects from duplicate required rows.
 AVOID: comparing size of arbitrary set A to size of required set B without
        FIRST ensuring A contains only elements from B.
 TRIGGER: 'all required items' => matched DISTINCT count equals required count.
*/
SELECT p.product_id
FROM ProductInventory p
JOIN RequiredWarehouses r
    ON r.warehouse_id = p.warehouse_id
GROUP BY p.product_id
HAVING COUNT(DISTINCT p.warehouse_id) = (
    SELECT COUNT(DISTINCT warehouse_id)
    FROM RequiredWarehouses
);

-- Q09 alternate double NOT EXISTS: no required warehouse may be missing.
SELECT DISTINCT p.product_id
FROM ProductInventory p
WHERE NOT EXISTS (
    SELECT 1
    FROM RequiredWarehouses r
    WHERE NOT EXISTS (
        SELECT 1
        FROM ProductInventory p2
        WHERE p2.product_id = p.product_id
          AND p2.warehouse_id = r.warehouse_id
    )
);


/* =============================================================================
 Q10 | AS-OF-DATE CUSTOMER STATUS — LATEST VALID RECORD PER CUSTOMER
 -----------------------------------------------------------------------------
 CustomerStatusHistory(record_id, customer_id, status, effective_date)
 Samples: (1,101,active,2026-09-01), (2,101,inactive,2026-10-05),
          (3,102,active,2026-09-15), (4,102,suspended,2026-10-15),
          (5,103,inactive,2026-08-20), (6,103,active,2026-10-01),
          (7,104,active,2026-10-20), (8,105,inactive,2026-09-25).
 Snapshot date: 2026-10-10.
 Requirement: one row per customer from HISTORY; latest status effective <= date.
 If no valid historical record, return 'unknown'. Ties: highest record_id.
 Expected: 101 inactive; 102 active; 103 active; 104 unknown; 105 inactive.

 YOUR ORIGINAL ATTEMPT (original naming/aliases preserved)
 WITH cte AS (
   SELECT record_id, customer_id, status, effective_date,
          ROW_NUMBER() OVER (
              PARTITION BY customer_id ORDER BY effective_date DESC
          ) AS rn
   FROM customerstatushistory
   WHERE effective_Date <= '2026-10-10'
 ),
 all_Cust AS (
   SELECT customer_id, status
   FROM customerstatushistory
 )
 SELECT customer_id, COALESCE(status,'unknown') FROM all_cust
 LEFT JOIN cte ON
   c.customer_id = all_cust.customer_id AND cte.rn = 1;

 WHY IT FAILED
 1. Base all_Cust projects status, producing duplicate rows per customer.
    It must be SELECT DISTINCT customer_id.
 2. ROW_NUMBER order needs record_id DESC as explicit tie-breaker.
 3. Alias c.customer_id is referenced but alias c is never defined.
 4. customer_id/status are ambiguous between joined tables; use aliases.
 5. COALESCE must use ranked status (r.status), not raw all-cust status.
 6. Filtering date BEFORE ranking was RIGHT, and rn = 1 in JOIN ON was RIGHT.
    Putting r.rn=1 in WHERE would drop 'unknown' customers.

 AVOID: projecting non-key attributes into the all-entity base population;
        WHERE filters that silently turn LEFT JOIN into INNER-like behavior.
 TRIGGER: 'as of date' => filter valid records -> rank latest -> LEFT JOIN onto
          ALL distinct entity IDs -> COALESCE missing status.
*/
WITH ranked_status AS (
    SELECT
        customer_id,
        status,
        ROW_NUMBER() OVER (
            PARTITION BY customer_id
            ORDER BY effective_date DESC, record_id DESC
        ) AS rn
    FROM CustomerStatusHistory
    WHERE effective_date <= '2026-10-10'
),
all_customers AS (
    SELECT DISTINCT customer_id
    FROM CustomerStatusHistory
)
SELECT
    c.customer_id,
    COALESCE(r.status, 'unknown') AS status_as_of_date
FROM all_customers c
LEFT JOIN ranked_status r
    ON r.customer_id = c.customer_id
   AND r.rn = 1
ORDER BY c.customer_id;


/* =============================================================================
 FINAL REVISION CHECKLIST — READ BEFORE SUBMITTING ANY INTERVIEW QUERY
 -----------------------------------------------------------------------------
 [ ] 1. RAW GRAIN: Identify each source table separately.
 [ ] 2. FINAL POPULATION: Which IDs must appear, including missing transactions?
 [ ] 3. GRAIN TRANSITIONS: Do I need to aggregate once, or aggregate totals again?
 [ ] 4. WINDOW: Does function produce previous/next/rank/running total?
 [ ] 5. ORDER: ASC vs DESC; deterministic tie-breaker specified?
 [ ] 6. FILTER: Row-level WHERE vs grouped HAVING vs join ON condition?
 [ ] 7. PROJECTION: Does each CTE output every column later referenced?
 [ ] 8. ALIASES: Every table alias defined; joined columns fully qualified?
 [ ] 9. DUPLICATES: DISTINCT vs GROUP BY vs ROW_NUMBER; intended output grain?
 [ ]10. NULLs: NOT IN, LEFT JOIN, COUNT(*), zero denominator, COALESCE?
 [ ]11. CALENDAR: DATE vs YEAR-MONTH; missing dates; ROWS vs actual day window?
 [ ]12. SETS: Are matching items filtered to the REQUIRED set before counting?
 [ ]13. BUSINESS RULE: zero COMPLETED orders != zero TOTAL orders.
 [ ]14. RESULT: Check a positive case, negative case, tie and missing-record case.

 MOST IMPORTANT REPEATABLE THOUGHT PROCESS
 RAW GRAIN -> INTERMEDIATE GRAIN(S) -> FINAL GRAIN
 -> EXACT POPULATION / BUSINESS RULE -> PATTERN -> SQL -> EDGE-CASE CHECK

 NEXT PRACTICE (5 TARGETED REINFORCEMENT QUESTIONS)
 1. LEAD/LAG: next-event condition
 2. Rolling window: ROWS and complete windows
 3. Aggregate of aggregates: grain transition
 4. As-of-date snapshot: preserve all entities
 5. All-required-items: relational division
 Then practice a genuinely NEW set of product-company DE interview scenarios.
================================================================================
*/


-- ============================================================================
-- SQL INTERVIEW PRACTICE — ORIGINAL ATTEMPTS, CORRECTIONS & MISTAKE NOTES
-- Session: 2026-10-13 | Dialect: MySQL 8+
-- Topics: YoY Growth, MoM Growth, Gaps & Islands
-- ============================================================================
-- PURPOSE: Preserve my actual attempts and compare against working solutions.
-- Original attempts are quoted verbatim as SQL comments (including typos).
-- Corrected queries are below each attempt and are runnable when source tables
-- exist. Each section can be run separately; CTE names are local to each query.
-- ============================================================================

-- ###########################################################################
-- Q1: YEAR-OVER-YEAR REVENUE GROWTH
-- ###########################################################################
-- INPUT: Orders(order_id, product_id, order_date, revenue)
-- REQUIREMENT: For each product and year with orders, show yearly revenue and
-- YoY % growth versus the IMMEDIATELY PRECEDING CALENDAR YEAR. Missing year or
-- previous revenue 0 -> NULL. Round percentage to 2 decimals.
-- EXPECTED ROWS:
-- P1 2023 1500 NULL
-- P1 2024 3000 100.00
-- P1 2025 4500 50.00
-- P2 2024  800 NULL
-- P2 2025 1200 50.00
-- P3 2025 2000 NULL
--
-- MY ORIGINAL REASONING:
-- Raw: one row per product revenue [should be one row per ORDER].
-- Intermediate: yearly revenue + previous year's revenue [good].
-- Final: one row per product per year with yearly revenue and YoY % [good].
-- Pattern: SUM window + LAG, instead of GROUP BY [wrong order of operations].
--
-- MY ORIGINAL SQL (VERBATIM, COMMENTED OUT):
-- with cte as (
-- select product_id , year , sum(revenue) over (partition by product_id) as yearly_revenue
-- from orders
-- ),prev_year_rev as (
-- Select product_id , year ,yearly_revenue,lag(yearly_revenue,1)  over (partition by product_id order by year) as prev_year_rev
-- from cte
-- )
-- Select product_id,year,yearly_revenue,round(yearly_revenue/prev_year_rev),2) as yoy_growth_pct
-- from prev_year_rev
-- order by product_id , year
--
-- MISTAKES / WHAT TO AVOID:
-- 1. 'year' was not a source column; derive YEAR(order_date).
-- 2. SUM(revenue) OVER(PARTITION BY product_id) repeats ALL-YEARS total on
--    each order row; it does not produce ONE PRODUCT-YEAR ROW.
-- 3. Applying LAG at order grain compares orders, not aggregated years.
-- 4. YoY growth != current/previous. Correct: (current - previous)/previous*100.
-- 5. LAG moves to previous AVAILABLE year; if 2024 is absent, it may return
--    2023 when the current row is 2025. Validate the year gap.
-- 6. ROUND(expression, 2) must contain the precision inside the parentheses.
-- 7. Avoid division by zero using NULLIF or a CASE condition.
--
-- CORRECT GRAIN: order -> product+year -> product+year with prior-year values
-- -> product+year with growth %.
-- MEMORY TRIGGER: GROUP BY yearly grain -> LAG (year and revenue) ->
--                check exact calendar year -> growth formula.

WITH yearly_sales AS (
    SELECT
        product_id,
        YEAR(order_date) AS sales_year,
        SUM(revenue) AS yearly_revenue
    FROM Orders
    GROUP BY product_id, YEAR(order_date)
),
previous_year AS (
    SELECT
        product_id,
        sales_year,
        yearly_revenue,
        LAG(sales_year) OVER (
            PARTITION BY product_id ORDER BY sales_year
        ) AS prev_year,
        LAG(yearly_revenue) OVER (
            PARTITION BY product_id ORDER BY sales_year
        ) AS prev_year_revenue
    FROM yearly_sales
)
SELECT
    product_id,
    sales_year AS year,
    yearly_revenue,
    CASE
        WHEN prev_year = sales_year - 1 AND prev_year_revenue <> 0
        THEN ROUND(100.0 * (yearly_revenue - prev_year_revenue)
                   / prev_year_revenue, 2)
        ELSE NULL
    END AS yoy_growth_pct
FROM previous_year
ORDER BY product_id, sales_year;


-- ###########################################################################
-- Q2: MONTH-OVER-MONTH PAYMENT GROWTH
-- ###########################################################################
-- INPUT: Payments(payment_id, merchant_id, payment_date, amount)
-- REQUIREMENT: For every merchant-month containing payments, report total
-- payments and % change versus the IMMEDIATELY PRECEDING CALENDAR MONTH.
-- Missing previous calendar month / previous amount 0 -> NULL.
-- EXPECTED ROWS:
-- M1 2025-11 1500 NULL
-- M1 2025-12 1800 20.00
-- M1 2026-01 1500 -16.67
-- M2 2025-11  800 NULL
-- M2 2026-01 1200 NULL  -- Dec absent, even though LAG sees Nov
-- M3 2025-12  500 NULL
--
-- MY ORIGINAL REASONING:
-- Raw: one row per merchant per payment [correct].
-- Intermediate: monthly total then previous monthly value [correct].
-- Final: said 'one row per merchant'; should be MERCHANT + MONTH.
-- Pattern: aggregate -> LAG(prev month and total) -> MoM growth [correct].
--
-- MY ORIGINAL SQL (VERBATIM, COMMENTED OUT):
-- with cte as (
-- Select merchant_id , sum(monthly_amount) as total_monthly , date_format(paymnet_date,'%Y-%m') as payment_month
-- from payments
-- group by merchant_id , date_format(paymnet_date,'%Y-%m')
-- ) , cte2 as (
-- select merchant_id , total_monthly , lag(payment_month) over (partition by merchant_id order by payment_month) as prev_month,lag(total_monthly) over (partition by merchant_id order by paymnet_month) as prev_month_total
-- from cte
-- )
-- select merchant_id , total_monthly , payment_month , case when prev_month=payment_month -1 and prev_month_total <> 0
-- then round(100 * (total_monthly - prev_month_total) / prev_month_total,2) else null end as Mom_grwoth
-- from cte2
--
-- MISTAKES / WHAT TO AVOID:
-- 1. Input has amount, NOT monthly_amount; aggregate SUM(amount).
-- 2. Column typo 'paymnet_date' -> payment_date.
-- 3. CTE2 did NOT select payment_month, so the final SELECT cannot read it.
-- 4. 'paymnet_month' typo in second LAG's ORDER BY.
-- 5. payment_month - 1 is NOT valid calendar arithmetic on a YYYY-MM string.
--    In particular, 2026-01 must compare to 2025-12, not 2026-00.
-- 6. LAG sees previous RECORDED month; compare its date to the actual previous
--    calendar month to reject gaps (M2 Nov -> Jan).
-- 7. Final grain is merchant + month, never just merchant.
--
-- CORRECT GRAIN: payment -> merchant+calendar-month -> merchant+month with
-- previous recorded month/amount -> merchant+month with MoM %.
-- MEMORY TRIGGER: Monthly GROUP BY -> LAG -> DATE_SUB one calendar month ->
--                growth formula; carry every needed column across CTEs.

WITH monthly_payments AS (
    SELECT
        merchant_id,
        CAST(DATE_FORMAT(payment_date, '%Y-%m-01') AS DATE) AS month_start,
        SUM(amount) AS monthly_amount
    FROM Payments
    GROUP BY merchant_id, CAST(DATE_FORMAT(payment_date, '%Y-%m-01') AS DATE)
),
previous_month AS (
    SELECT
        merchant_id,
        month_start,
        monthly_amount,
        LAG(month_start) OVER (
            PARTITION BY merchant_id ORDER BY month_start
        ) AS prev_month_start,
        LAG(monthly_amount) OVER (
            PARTITION BY merchant_id ORDER BY month_start
        ) AS prev_monthly_amount
    FROM monthly_payments
)
SELECT
    merchant_id,
    DATE_FORMAT(month_start, '%Y-%m') AS payment_month,
    monthly_amount,
    CASE
        WHEN prev_month_start = DATE_SUB(month_start, INTERVAL 1 MONTH)
             AND prev_monthly_amount <> 0
        THEN ROUND(100.0 * (monthly_amount - prev_monthly_amount)
                   / prev_monthly_amount, 2)
        ELSE NULL
    END AS mom_change_pct
FROM previous_month
ORDER BY merchant_id, month_start;


-- ###########################################################################
-- Q3: GAPS & ISLANDS — ALL MAXIMAL CONSECUTIVE-DAY LOGIN STREAKS
-- ###########################################################################
-- INPUT: UserLogins(user_id, login_date)
-- ASSUMPTION: At most one login row per user per calendar date.
-- REQUIREMENT: Every maximal run of >=2 consecutive days for each user;
-- output user_id, streak_start, streak_end, streak_length.
-- EXPECTED ROWS:
-- 101 2026-10-01 2026-10-03 3
-- 101 2026-10-05 2026-10-06 2
-- 103 2026-10-02 2026-10-05 4
--
-- MY ORIGINAL REASONING / ATTEMPT (NO SQL WAS WRITTEN):
-- 'raw grain - one row per use per login date'
-- 'intermediate grain - we find the streak and then attach the streak length per user'
-- 'final grain - one row per user per streak length satisfhying the condition of atleast 2 consecutive login'
-- 'pattern - we use the lag first to find the users with atleast 2 consecutive login and then count the streak length and we also need to use the case statement to find the start and end date for each streak'
-- 'i m not sure how to solve this question logic wise also and syntax wise also i mean maybe we give a rank / rowwn umber where if we have atleast 2 login we then count it and then take the date not sure'
--
-- NO ORIGINAL SQL EXISTS FOR Q3: do not fabricate an attempted query.
--
-- CONCEPTUAL GAP:
-- LAG() can detect whether a date follows the previous date, but to return
-- every separate MAXIMAL streak, records must be assigned an ISLAND KEY.
-- Finding 'does a user have consecutive days?' is not the same as grouping
-- every streak into its own group with start, end and length.
--
-- CORRECT GRAIN: user+login_date -> user+date with ROW_NUMBER ->
-- user+date with island key -> ONE ROW PER user+island -> filter length>=2.
--
-- WHY DATE - ROW_NUMBER WORKS:
-- For a user with Oct 1,2,3,5,6, the row numbers are 1,2,3,4,5.
-- Date minus rn days -> Sep 30, Sep 30, Sep 30, Oct 1, Oct 1.
-- Consecutive dates share the same resulting anchor date.
--
-- COMMON PITFALLS:
-- * GROUP BY both user_id and island key; identical anchors across users
--   must not merge separate users' streaks.
-- * Keep the single-day islands while GROUPing, then filter with HAVING.
-- * Deduplicate user/date FIRST if the source allows several logins/day.
-- * One missing calendar day always breaks a streak.
--
-- MY QUICK CHECK RESULT:
-- Input dates Oct 1,2,5,6,7,10 -> THREE islands of lengths 2,3,1;
-- only TWO qualify when HAVING COUNT(*) >= 2.
-- MEMORY TRIGGER: ROW_NUMBER by user/date -> date minus rn days = island ID
--                -> GROUP BY user+island -> MIN/MAX/COUNT -> HAVING.

WITH numbered_logins AS (
    SELECT
        user_id,
        login_date,
        ROW_NUMBER() OVER (
            PARTITION BY user_id ORDER BY login_date
        ) AS rn
    FROM UserLogins
),
islands AS (
    SELECT
        user_id,
        login_date,
        DATE_SUB(login_date, INTERVAL rn DAY) AS island_key
    FROM numbered_logins
)
SELECT
    user_id,
    MIN(login_date) AS streak_start,
    MAX(login_date) AS streak_end,
    COUNT(*) AS streak_length
FROM islands
GROUP BY user_id, island_key
HAVING COUNT(*) >= 2
ORDER BY user_id, streak_start;


-- ###########################################################################
-- RECURRING CHECKLIST BEFORE SUBMITTING SQL
-- ###########################################################################
-- [ ] Raw grain matches source (order/payment/login), not an assumed group.
-- [ ] Every intermediate grain is explicitly identified and implemented.
-- [ ] Aggregate to correct product-year / merchant-month BEFORE doing LAG.
-- [ ] LAG refers to a prior available ROW; validate time continuity if asked.
-- [ ] Carry columns forward through EACH CTE (e.g., payment_month).
-- [ ] Use source column names exactly; validate typos.
-- [ ] Growth % = 100 * (current - previous) / previous, guard zero/NULL.
-- [ ] For streak groups, build an ISLAND identifier before GROUP BY.
-- [ ] Final grain, filters, expected ordering and output aliases all match.
--
-- NEXT SESSION: Q4 Sessionization and Q5 Funnel Analysis are NOT covered here.
