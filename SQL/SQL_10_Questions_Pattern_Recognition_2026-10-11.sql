-- ============================================================================
-- SQL PATTERN RECOGNITION & MISTAKE BANK — FULL-QUESTION EDITION
-- UPDATED: 2026-10-18 | MySQL 8+
-- Contains 19 documented exercises from the supplied bank.
-- NEW: Each exercise begins with a complete question statement and PATTERN TYPE.
-- PRESERVED: Original attempts, commentary, mistakes, explanations and solutions.
-- NOTE: Exercises rely on their own sample tables; run queries one at a time.
-- Some same-named tables have different schemas in different exercises.
-- ============================================================================

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
FULL PRACTICE QUESTION (READ BEFORE YOUR ATTEMPT):
Given Sales(sale_id, product_id, sale_date, amount), find each product whose largest monthly
revenue total is strictly greater than twice its average monthly revenue total. Aggregate by
product and calendar year-month (never merge the same month from different years), and
average only months with sales. Return each qualifying product_id once.
PATTERN TYPE: Multi-level aggregation / aggregate of grouped totals
-------------------------------------------------------------------------------
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
FULL PRACTICE QUESTION (READ BEFORE YOUR ATTEMPT):
Given UserEvents(event_id, user_id, event_time, event_type), return distinct user_id values
for users with at least one login event immediately followed by a purchase event. Sequence
events separately for each user by event_time, then event_id to resolve ties. A login
anywhere in the history may qualify; intervening events disqualify that particular login.
PATTERN TYPE: Event-sequence analysis / LEAD / immediate next event
-------------------------------------------------------------------------------
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
FULL PRACTICE QUESTION (READ BEFORE YOUR ATTEMPT):
Given DailyActivity(activity_date DATE, active_users INT), with exactly one record for every
consecutive calendar date, calculate the sum of active_users over the current date and six
prior calendar dates. Show only complete seven-day windows, ordered by activity_date.
active_users is a numeric daily count, not a user identifier.
PATTERN TYPE: Rolling window aggregation / explicit ROWS frame
-------------------------------------------------------------------------------
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
FULL PRACTICE QUESTION (READ BEFORE YOUR ATTEMPT):
Given Customers(customer_id, customer_name) and Orders(order_id, customer_id, order_date),
return customer_id and customer_name for customers who have never placed an order.
Customers: 101 Alice, 102 Bob, 103 Charlie, 104 David, 105 Emma. Orders belong to customers
101 (twice), 103, and 105. Expected customers: 102 Bob and 104 David.
PATTERN TYPE: Anti-join / missing matches / NOT EXISTS
-------------------------------------------------------------------------------
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
FULL PRACTICE QUESTION (READ BEFORE YOUR ATTEMPT):
Given CustomerUpdates(update_id, customer_id, email, updated_at), return exactly one row per
customer showing the most recently updated email address. Rank by updated_at descending;
when two timestamps tie, select the higher update_id. Output customer_id and email. Sample
output: 101 alice_final@mail.com; 102 bob_new@mail.com; 103 charlie@mail.com.
PATTERN TYPE: Latest record per entity / deterministic ROW_NUMBER deduplication
-------------------------------------------------------------------------------
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
FULL PRACTICE QUESTION (READ BEFORE YOUR ATTEMPT):
Given Logins(user_id, login_date), find distinct users who logged in on at least three
consecutive calendar dates. Input has at most one login per user per day. Sample dates: user
101 Oct 1,2,3,5; user 102 Oct 1,3,4; user 103 Oct 2,3,4 (all 2026). Expected user_id values:
101 and 103.
PATTERN TYPE: Consecutive calendar days / LEAD or LAG date comparisons
-------------------------------------------------------------------------------
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
FULL PRACTICE QUESTION (READ BEFORE YOUR ATTEMPT):
Given Orders(order_id, customer_id, status, amount), show every customer present in Orders
with their total_orders (all statuses), completed_orders, completed_amount, and
completion_rate as a percentage rounded to two decimals. Customers with no COMPLETED orders
must still appear; this does not require customers who have never ordered. Expected:
101=(3,2,800,66.67); 102=(2,0,0,0.00); 103=(3,2,1000,66.67).
PATTERN TYPE: Conditional aggregation / business eligibility / percentage metric
-------------------------------------------------------------------------------
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
FULL PRACTICE QUESTION (READ BEFORE YOUR ATTEMPT):
Given EmployeeSalary(employee_id, department_id, salary), return employees paid at either of
the two highest distinct salary levels within their own department, including all employees
tied at either level. Output employee_id, department_id, salary. Sample: dept 10 salaries
90000,80000,80000,70000; dept 20 salaries 95000,85000,85000,75000. Expected employee IDs:
101,102,103,105,106,107.
PATTERN TYPE: Top-N DISTINCT values with ties / DENSE_RANK
-------------------------------------------------------------------------------
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
FULL PRACTICE QUESTION (READ BEFORE YOUR ATTEMPT):
Given ProductInventory(product_id, warehouse_id) and RequiredWarehouses(warehouse_id),
return products present in EVERY required warehouse. Duplicates in inventory must not affect
the result and products may be stocked in non-required warehouses. Required warehouses:
W1,W2,W3. Sample: 101=W1,W2,W3; 102=W1,W2; 103=W1,W2,W3; 104=W3. Expected product IDs: 101
and 103.
PATTERN TYPE: Set completeness / relational division / distinct matching
-------------------------------------------------------------------------------
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
FULL PRACTICE QUESTION (READ BEFORE YOUR ATTEMPT):
Given CustomerStatusHistory(record_id, customer_id, status, effective_date), produce one row
for EVERY distinct customer occurring in the history, with the latest status effective on or
before 2026-10-10. Use highest record_id to break same-date ties. If a customer has no valid
record by that date, return status_as_of_date=unknown. Expected: 101 inactive, 102 active,
103 active, 104 unknown, 105 inactive.
PATTERN TYPE: As-of-date snapshot / filtered latest row / population-preserving join
-------------------------------------------------------------------------------
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
-- FULL PRACTICE QUESTION (READ BEFORE YOUR ATTEMPT):
-- Given Orders(order_id, product_id, order_date, revenue), return each product-year with
-- yearly_revenue and YoY growth percentage rounded to two decimals, comparing against the
-- immediately preceding CALENDAR year. Return NULL for missing previous year or zero
-- previous-year revenue. Sample: P1=2023:1500,2024:3000,2025:4500; P2=2024:800,2025:1200;
-- P3=2025:2000. Expected growth: P1=NULL,100.00,50.00; P2=NULL,50.00; P3=NULL.
-- PATTERN TYPE: Year-over-year percentage growth / year grain / LAG + calendar continuity
-- ---------------------------------------------------------------------------
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
-- FULL PRACTICE QUESTION (READ BEFORE YOUR ATTEMPT):
-- Given Payments(payment_id, merchant_id, payment_date, amount), return one row per merchant
-- and calendar month with payments: monthly_amount and MoM percentage change versus the
-- immediately preceding CALENDAR month. Missing previous month or zero previous amount =>
-- NULL; round to 2 decimals. M1 monthly totals: Nov 2025=1500, Dec 2025=1800, Jan 2026=1500;
-- M2 Nov 2025=800, Jan 2026=1200; M3 Dec 2025=500. M2 Jan 2026 growth must be NULL because
-- Dec is missing.
-- PATTERN TYPE: Month-over-month percentage growth / monthly grouping / LAG + missing-month check
-- ---------------------------------------------------------------------------
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
-- FULL PRACTICE QUESTION (READ BEFORE YOUR ATTEMPT):
-- Given UserLogins(user_id, login_date) with at most one login per user per day, return EVERY
-- maximal streak of at least two consecutive calendar login days. Output user_id,
-- streak_start, streak_end, streak_length, ordered by user and start. For user 101, dates Oct
-- 1,2,3,5,6; for 102, Oct 1,3; for 103, Oct 2,3,4,5 (2026). Expected streaks: 101 Oct1–3
-- length3; 101 Oct5–6 length2; 103 Oct2–5 length4.
-- PATTERN TYPE: Gaps and Islands / consecutive-day streak grouping
-- ---------------------------------------------------------------------------
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



-- 13/10/2026:
/*
===============================================================================
STAGE 1 | P1 CONCEPT 1 — MULTI-LEVEL AGGREGATION & GRAIN TRANSITIONS
Practice revision bank | 13–14 October 2026 | Dialect: MySQL 8+
===============================================================================
PURPOSE
- Preserve MY attempts, the specific errors I made, correct approaches, and
  reasoning behind grain changes in this Stage 1 concept only.
- Incorrect attempts are in comments. Correct queries are provided below each.
- Each correct query assumes the stated practice source table exists.

MASTER RULES
1. Raw grain = what ONE input row means, not the desired output.
2. Establish the grain of the metric BEFORE MAX/AVG/ranking it.
3. At each CTE ask: 'What does ONE row represent after this SELECT?'
4. GROUP BY identifies the keys for an aggregate row; PARTITION BY identifies
   the comparison set for window calculations. They need not be identical.
5. If the requirement says 'average of entity averages', compute one average
   per entity first, then AVG() those entity averages.
6. In an aggregate SELECT, don't project columns outside GROUP BY unless
   they're themselves aggregated (under standard SQL rules).
7. The final scalar comparison must read from the CTE at the correct grain.
8. Verify sample arithmetic and strict inequalities; don't trust a mistaken
   expected-result label.

-------------------------------------------------------------------------------
Q1 — EMPLOYEE PROJECT HOURS / HIGHEST PROJECT TOTAL VS AVG PROJECT TOTAL
FULL PRACTICE QUESTION (READ BEFORE YOUR ATTEMPT):
Given EmployeeProjects(employee_id, project_id, hours_worked), find employees whose highest
SUM of hours on any one project is strictly greater than 1.1 times their average total hours
per project. Multiple work logs can belong to the same employee-project pair. Only projects
with logs count. Sample includes employee 101 with project totals 30,30; employee 102 with
40,30; employee 103 with 15,15. Expected employee: 102. Note: 1.1x is the corrected
threshold from the original 1.5x draft.
PATTERN TYPE: Multi-stage aggregation / project totals compared to own project average
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
TABLE: EmployeeProjects(employee_id, project_id, hours_worked)
ROWS:
(101,P1,10),(101,P1,20),(101,P2,30),
(102,P1,40),(102,P2,20),(102,P2,10),
(103,P1,15),(103,P2,15)
REQUIREMENT: Employees whose highest total hours on any one project are
strictly greater than 1.1 x their average total hours per project.
NOTE: The initial prompt said 1.5x but was corrected to 1.1x BEFORE attempt
because 1.5x yields no matches. Expected result at 1.1x: 102.

MY REASONING (abridged faithfully):
Raw: one row per employee per project hour.
Intermediate: highest total hour per employee, attach average total hours.
Final: one row per qualifying employee.
Pattern: MAX/GROUP BY first, then AVG() OVER() and compare.

MY ORIGINAL SQL (preserved):
with cte as (
select employee_id , hours_worked,max(hour_worked) as highest_hour , project_id
from employeeprojects
group by employee_id , project_id
), 
with avg_hr as (
select employee_id , project_id , avg(hours_worked) over (partition by employee_id) as avg_hours,highest_hour
from cte)
select employee_id from avg_hr
where highest_hour > 1.1 * avg_hours

MISTAKES
- MAX(hours_worked) measures max *individual log*, not max project total.
- Forgot SUM(hours_worked) at employee-project grain.
- Raw hours_worked selected alongside GROUP BY without aggregation.
- Repeated WITH; multiple CTE definitions share ONE WITH separated by commas.
- Compared metrics before computing project totals.

CORRECT GRAINS:
Work-log row -> employee + project (SUM hours) -> employee (MAX/AVG project
hours) -> qualifying employee.
*/
WITH project_hours AS (
    SELECT employee_id, project_id, SUM(hours_worked) AS total_project_hours
    FROM EmployeeProjects
    GROUP BY employee_id, project_id
), employee_metrics AS (
    SELECT employee_id,
           MAX(total_project_hours) AS highest_project_hours,
           AVG(total_project_hours) AS avg_project_hours
    FROM project_hours
    GROUP BY employee_id
)
SELECT employee_id
FROM employee_metrics
WHERE highest_project_hours > 1.1 * avg_project_hours
ORDER BY employee_id;

/*
-------------------------------------------------------------------------------
Q2 — ORDER ITEMS / HIGHEST ORDER TOTAL VS AVG ORDER TOTAL
FULL PRACTICE QUESTION (READ BEFORE YOUR ATTEMPT):
Given OrderItems(order_id, customer_id, product_id, quantity, unit_price), compute each
order total by summing quantity*unit_price across line items. Return customers whose maximum
order total is STRICTLY greater than 1.5 times their average order total. Sample C1 has
orders 500,200,300; C2 has orders 400,200; C3 has order 500. Expected output is EMPTY: C1
max=500 equals (not greater than) 1.5*333.33.
PATTERN TYPE: Aggregate of order-line totals / customer MAX vs AVG order value
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
TABLE: OrderItems(order_id, customer_id, product_id, quantity, unit_price)
DATA:
(1,C1,P1,2,100),(1,C1,P2,1,300),(2,C1,P3,1,200),(3,C1,P1,3,100),
(4,C2,P2,2,200),(5,C2,P1,1,100),(5,C2,P3,1,100),(6,C3,P1,1,500)
REQUIREMENT: Customers with max total order value > 1.5 x average total
order value. STRICT inequality; correct output on given data is EMPTY.
IMPORTANT: An earlier assistant incorrectly predicted C1. C1 order totals
500, 200, 300 -> MAX=500, AVG=333.333..., 1.5*AVG=500. Not greater.

MY FIRST SQL (preserved):
with cte as (
select customer_id , order_id , (quanity * unit_price) as total_order_value
from orderitems
group by customer_id , order_id
) , avg_val as (
select customer_id , order_id , total_order_value , max(total_order_value) as highest_total_value,
avg(total_order_value) as avg_total_value 
from cte
)
select customer_id 
from avg_val
where highest_total_vale > 1.5 * avg_total_value
order by customer_id

MISTAKES FIRST ATTEMPT
- Multiplication alone calculates line value, not total order value.
- SUM(quantity * unit_price) needed per order.
- Second CTE mixed customer totals and individual order columns; omitted
  GROUP BY customer_id.
- Spelling: quanity, highest_total_vale.

MY REWRITE (preserved):
with cte as (
select customer_id , order_id , sum(quantity * unit_price) as total_ord_val
from orderitems
group by customer_id , order id
), avg_val as (
select customer_id , total_ord_val , max(total_ord_val) as highest_ord_val , avg(total_ord_val) as avg_ord_val
from cte
group by customer_id)
select customer_id
from avg_val
wher highest_ord_val > 1.5 * avg_ord_val

MISTAKES IN REWRITE
- 'order id' should be order_id; 'wher' should be WHERE.
- total_ord_val projected unaggregated in SELECT grouped only by customer.
- Logic/grain now right; SQL execution precision still needed.

CORRECT GRAINS:
Order line -> customer + order (SUM quantity*price) -> customer
(MAX and AVG of order totals) -> qualifying customer.
*/
WITH order_totals AS (
    SELECT customer_id, order_id,
           SUM(quantity * unit_price) AS total_order_value
    FROM OrderItems
    GROUP BY customer_id, order_id
), customer_metrics AS (
    SELECT customer_id,
           MAX(total_order_value) AS max_order_value,
           AVG(total_order_value) AS avg_order_value
    FROM order_totals
    GROUP BY customer_id
)
SELECT customer_id
FROM customer_metrics
WHERE max_order_value > 1.5 * avg_order_value
ORDER BY customer_id;

/*
-------------------------------------------------------------------------------
CONCEPT CHECK — WHAT DOES 'AVERAGE' WEIGHT EQUALLY?
-------------------------------------------------------------------------------
Examples discussed:
- Average across ALL orders: AVG(order_value) from ONE ROW PER ORDER.
- Average order value PER customer: GROUP BY customer_id, AVG(order_value).
- Average OF customers' order averages: AVG(customer_avg) from ONE ROW
  PER CUSTOMER, so every customer is weighted equally.

My confusion: 'For customers avg order value we directly take avg but for
across all orders we first calculate avg per order ...' — reversed.

Numerical example: C1 has orders 100,200,300; C2 has one order 900.
Average of ALL orders = (100+200+300+900)/4 = 375.
Average of CUSTOMER averages = ((100+200+300)/3 + 900)/2 = 550.
My answers: initially wrote 1500/4 = 350 (arithmetic slip); correctly
calculated customer averages and 550.

MENTAL TRIGGER: What is ONE equally weighted observation in this AVG?
If one order => order grain. If one customer => customer grain.
-------------------------------------------------------------------------------
Q3 — STORE TRANSACTIONS / STORE AVG DAILY VS AVG OF STORE AVGS
FULL PRACTICE QUESTION (READ BEFORE YOUR ATTEMPT):
Given StoreTransactions(transaction_id, store_id, transaction_date, revenue), consider only
active transaction dates. Compute each store's average DAILY revenue, then return stores
whose store-level average is greater than the equally weighted average of the stores' daily
averages. Output store_id and avg_daily_revenue rounded to 2 decimals. Sample store daily
averages: S1=300, S2=400, S3=500; benchmark=400. Expected S3,500.00.
PATTERN TYPE: Weighted-vs-unweighted average / aggregate daily then per-store then global
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
TABLE: StoreTransactions(transaction_id,store_id,transaction_date,revenue)
DATA:
(1,S1,2026-10-01,100),(2,S1,2026-10-01,200),
(3,S1,2026-10-02,300),(4,S2,2026-10-01,500),
(5,S2,2026-10-02,100),(6,S2,2026-10-02,200),
(7,S3,2026-10-01,800),(8,S3,2026-10-03,200)
REQUIREMENT: Store avg daily revenue, only active days. Return stores with
store avg daily revenue > equally-weighted avg of all stores' daily avgs.
Expected: S3 / 500.00. Store averages: S1=300,S2=400,S3=500;
overall store-average benchmark = 400.

MY ORIGINAL SQL (preserved):
-- below cte gives daily level revenue per store
with cte as (
Select store_id , transaction_date , sum(revenue) as daily_rev
from storetransactions 
group by store_id , transaction_date
),
---below cte will give avg revenue of each store 
avg_r as (select store_id , avg(daily_rev) as avg_daily_rev
from cte
group by store_id 
)
select store_id , avg_daily_rev
from avg_r where 
avg_daily_rev > (select avg(revenue) from storetransactions)

MISTAKE
- Both CTEs and all grain transitions correct FIRST TRY.
- Final subquery read raw transactions, AVG(revenue), instead of reading
  one-row-per-store avg_r CTE: AVG(avg_daily_rev) FROM avg_r.
- This is a wrong-source-grain mistake, not wrong understanding of first CTE.

CORRECT GRAINS:
Transaction -> store + active day (SUM revenue) -> store (AVG daily_rev)
-> global scalar (AVG of each store's avg) -> qualifying store.
*/
WITH store_day AS (
    SELECT store_id, transaction_date, SUM(revenue) AS daily_rev
    FROM StoreTransactions
    GROUP BY store_id, transaction_date
), store_avg AS (
    SELECT store_id, AVG(daily_rev) AS avg_daily_rev
    FROM store_day
    GROUP BY store_id
)
SELECT store_id, ROUND(avg_daily_rev, 2) AS avg_daily_revenue
FROM store_avg
WHERE avg_daily_rev > (SELECT AVG(avg_daily_rev) FROM store_avg)
ORDER BY store_id;

/*
-------------------------------------------------------------------------------
Q4 — DRIVER DELIVERIES / ADDITIONAL MASTERY CHECKPOINT
FULL PRACTICE QUESTION (READ BEFORE YOUR ATTEMPT):
Given DeliveryRecords(delivery_id, driver_id, delivery_date, earnings), calculate each
driver's average DAILY earnings over days with deliveries, then compare with the equally
weighted average of all drivers' daily averages. Output qualifying driver IDs and their
average daily earnings to two decimals. Samples: D1 average 300, D2 average 400, D3 average
500. Expected D3,500.00.
PATTERN TYPE: Multi-stage aggregation / driver daily earnings vs overall driver mean
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
TABLE: DeliveryRecords(delivery_id,driver_id,delivery_date,earnings)
DATA:
(1,D1,2026-10-01,100),(2,D1,2026-10-01,200),
(3,D1,2026-10-02,300),(4,D2,2026-10-01,500),
(5,D2,2026-10-02,100),(6,D2,2026-10-02,200),
(7,D3,2026-10-01,800),(8,D3,2026-10-03,200)
REQUIREMENT: Driver avg daily earnings > avg of all drivers' avg daily
 earnings. Only active days. Expected D3 / 500.00.

MY ORIGINAL SQL (preserved):
--- this givess daily earning per driver 
with cte as (
Select driver_id , delivery_Date ,sum(earnings) as daily_earnings
from deliveryrecords
group by driver_id , delivery_Date
),
--- this gives avg daily earning per driver
avg_ear as (
select driver_id  , avg(daily_earnings) as avg_daily_Earning
from cte
group by driver_id
)
select driver_id,avg_daily_earnings 
from avg_ear
where avg_daily_earnings > (select avg(avg_daily_earnings) from avg_ear)

ASSESSMENT
- Correct grain, two-stage aggregation, final CTE comparison, and logic.
- Small but important alias mismatch: created avg_daily_Earning (singular)
  but SELECT/WHERE use avg_daily_earnings (plural). Needs correction to run.
- Round result to 2 decimals to meet output requirement.
- Prior coaching called this 'fully executable'; that was too generous.

CORRECT GRAINS:
Delivery -> driver + active date -> driver avg daily earnings -> global
avg of driver averages -> qualifying driver.
*/
WITH daily_earnings AS (
    SELECT driver_id, delivery_date, SUM(earnings) AS daily_earnings
    FROM DeliveryRecords
    GROUP BY driver_id, delivery_date
), driver_avgs AS (
    SELECT driver_id, AVG(daily_earnings) AS avg_daily_earnings
    FROM daily_earnings
    GROUP BY driver_id
)
SELECT driver_id, ROUND(avg_daily_earnings, 2) AS avg_daily_earnings
FROM driver_avgs
WHERE avg_daily_earnings > (
    SELECT AVG(avg_daily_earnings) FROM driver_avgs
)
ORDER BY driver_id;

/*
-------------------------------------------------------------------------------
Q5 — E-COMMERCE / HIGHEST-SPENDING CUSTOMER PER CATEGORY (WITH TIES)
FULL PRACTICE QUESTION (READ BEFORE YOUR ATTEMPT):
Given OrderItems(order_id, customer_id, category, quantity, unit_price), calculate each
customer's total spend in each category across all orders. Return every customer tied for
the highest total spend WITHIN each category. Output category, customer_id, total_spent.
Sample expected Clothing C2 700 and Electronics C1 1800. This OrderItems schema is separate
from the earlier order-total exercise.
PATTERN TYPE: Multi-level aggregation plus tie-aware ranking / category competition
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
TABLE: OrderItems(order_id,customer_id,category,quantity,unit_price)
IMPORTANT: This is a SEPARATE scenario/table schema from Q2. Run each case
with its corresponding practice data, not both under one OrderItems schema.
DATA:
(1,C1,Electronics,2,500),(1,C1,Clothing,1,200),
(2,C1,Electronics,1,800),(3,C2,Electronics,1,600),
(4,C2,Clothing,3,100),(5,C2,Clothing,2,200),
(6,C3,Electronics,1,300),(7,C3,Clothing,2,150)
REQUIREMENT: Highest total spending customer in each category across all
orders; include all ties; one row per customer-category.
Expected: Clothing C2 700; Electronics C1 1800.

MY ORIGINAL SQL (preserved):
-- this gives total spend per cust per category
with cte as (
select category , customer_id , sum(quantity*unit_price) as total_spent
from orderitems
group by category , customer_id
),
--- this will give us rank per customer cat combination based on total spent 
high_Sp as (
select category , customer_id , total_spent , dense_rank () over (partition by customer_id , category order by total_spent desc) as rn
from high_sp
)
--- here we filter out for rn=1
select category , customer_id , total_spent
from high_sp
where rn=1 
order by category , customer_id

ASSESSMENT
- Core requirement, SUM(quantity*unit_price), customer-category grain,
  DENSE_RANK for ties, and rn=1 filter all identified CORRECTLY.
- Window partition mistake: PARTITION BY customer_id,category isolates
  each already-aggregated customer-category row; all ranks would be 1.
- Compare customers WITHIN a category, so PARTITION BY category only.
- CTE self-reference: high_sp reads FROM high_sp instead of FROM cte.
- 'One row per customer-category' does not conflict with multiple tied
  customers in one category: each tied customer appears once.

CORRECT GRAINS:
Line item -> customer + category (SUM spend) -> same rows ranked WITHIN
category -> rank=1 qualifying customer-category rows.

MASTER DIFFERENCE:
GROUP BY category,customer_id = one spend total per customer/category.
PARTITION BY category = which customer totals compete against each other.
*/
WITH customer_category_spend AS (
    SELECT category, customer_id,
           SUM(quantity * unit_price) AS total_spent
    FROM OrderItems
    GROUP BY category, customer_id
), category_ranking AS (
    SELECT category, customer_id, total_spent,
           DENSE_RANK() OVER (
               PARTITION BY category
               ORDER BY total_spent DESC
           ) AS spending_rank
    FROM customer_category_spend
)
SELECT category, customer_id, total_spent
FROM category_ranking
WHERE spending_rank = 1
ORDER BY category, customer_id;

/*
===============================================================================
STAGE 1 — P1 CONCEPT 1 REVIEW SUMMARY
===============================================================================
MOST RECURRENT ERROR TYPES
[A] Requirement says 'total per X' but I apply MAX/AVG to raw rows.
    FIX: SUM to X grain first; only then compare MAX/AVG of those totals.
[B] Mixing fields from different grains in aggregated SELECT.
    FIX: Only GROUP BY keys + aggregated values at that grain.
[C] Correct CTE chain, wrong source used for final global average.
    FIX: Identify which CTE has one row per equally weighted entity.
[D] Correct DENSE_RANK but over-partitioning.
    FIX: PARTITION BY the population WITHIN which items compete.
[E] SQL wiring: alias mismatch, typos, accidental self-reference.
    FIX: Check every selected column and FROM reference after each CTE.

BEFORE SUBMITTING EACH SQL QUERY:
[ ] What is each raw row?
[ ] What does each intermediate row mean after GROUP BY?
[ ] Is my measure a raw value, group total, or avg of group metrics?
[ ] Which CTE has the correct grain for my final comparison?
[ ] Who should compete in each window PARTITION BY?
[ ] Do I accidentally select non-grouped/non-aggregated columns?
[ ] Are table names, columns, and aliases EXACTLY consistent?
[ ] Does the result agree with strict inequalities and sample arithmetic?

STATUS: Concept and grain reasoning improved substantially. Continue later
with a mixed, independent first-attempt question to verify retention and
code precision; do not mark the entire P1 track mastered yet.
===============================================================================
*/


/*
14/10/2026:
AVOID NEXT TIME:
- Never GROUP BY away rows before ranking them.
- Window calculation is not the same as selecting rank 1: FILTER it.
- Trace each output column back to the CTE providing it.
- CTE aliases go in FROM/JOIN, not in "WITH cte AS" declarations.

===============================================================================
Q2 — INVALID CONSECUTIVE ORDER STATUS TRANSITIONS
FULL PRACTICE QUESTION (READ BEFORE YOUR ATTEMPT):
Given OrderStatusHistory(event_id, order_id, status, event_time), return distinct orders
with at least one INVALID immediately adjacent status transition. Only valid pairs:
created->shipped and shipped->delivered. Sequence per order by event_time, then event_id.
Ignore final events without successors and single-event orders. Sample O101
created->shipped->delivered; O102 created->delivered; O103 created->shipped; O104 shipped
only. Expected: O102.
PATTERN TYPE: Invalid adjacent state transitions / deterministic LEAD + rule exclusion
-------------------------------------------------------------------------------
===============================================================================
TABLE: OrderStatusHistory(event_id, order_id, status, event_time)

SAMPLE DATA:
 event_id | order_id | status    | event_time
 1        | O101     | created   | 2026-10-01 09:00
 2        | O101     | shipped   | 2026-10-01 11:00
 3        | O101     | delivered | 2026-10-02 15:00
 4        | O102     | created   | 2026-10-01 10:00
 5        | O102     | delivered | 2026-10-01 16:00
 6        | O103     | created   | 2026-10-02 09:00
 7        | O103     | shipped   | 2026-10-02 12:00
 8        | O104     | shipped   | 2026-10-03 10:00

REQUIREMENT:
Return distinct orders with at least one invalid consecutive status transition.
ONLY valid transitions: created -> shipped; shipped -> delivered.
Single-event orders have no transition; ignore last events without a successor.
Within an order, order by event_time ASC then event_id ASC.

EXPECTED:
 O102

YOUR ORIGINAL REASONING:
 raw grain - one row per order per status
 intermediate - umm we use lead here to check the next status directly
 final - one row per order satisfying the condition of invalid status
 pattern - we use lead here since we have to check if we have valid transition or not

YOUR ORIGINAL SQL (AS WRITTEN):

with cte as (
Select order_id ,status, lead(status) over (partition by order_id ) as next_stat
from orderstatushistory
)
select order_id from cte
where (status ='created' and next_stat!='shipped' ) or (status='shipped' and next_stat!='delivered')

WHAT WAS CORRECT:
- Chose LEAD for comparing current status with the next actual event.
- Properly kept current status and next status in the CTE.
- Correctly queried the CTE without an unnecessary GROUP BY.

MISTAKES:
1. LOGIC: Missing ORDER BY event_time, event_id inside LEAD. PARTITION BY
   identifies which order, not the order of events.
2. LOGIC: Checking only two kinds of current status does not catch other invalid
   pairs, e.g., delivered -> created.
3. LOGIC: Explicitly exclude terminal rows with no next event; NULL comparisons
   by themselves do not represent actual transitions.
4. OUTPUT: Missing DISTINCT; an order could have multiple bad transitions.

CORRECT GRAIN FLOW:
 Raw: one row per status event
 Intermediate: one row per event with its immediate next status
 Final: one row per order with >=1 invalid adjacent event pair

CORRECT APPROACH:
1. LEAD(status) partitioned by order_id in a deterministic time/event_id order.
2. Keep only actual event pairs (next_stat IS NOT NULL).
3. Exclude pairs matching either of the TWO allowed transitions.
4. Return each order once.

NOTE: The answer below assumes status values are non-NULL, as in the sample.
If nullable statuses are allowed, null-transition semantics must be defined.
*/
WITH ordered_events AS (
    SELECT
        order_id,
        status,
        LEAD(status) OVER (
            PARTITION BY order_id
            ORDER BY event_time, event_id
        ) AS next_stat
    FROM OrderStatusHistory
)
SELECT DISTINCT order_id
FROM ordered_events
WHERE next_stat IS NOT NULL
  AND NOT (
      (status = 'created' AND next_stat = 'shipped')
      OR (status = 'shipped' AND next_stat = 'delivered')
  )
ORDER BY order_id;

/*
AVOID NEXT TIME:
- Every sequence-dependent LEAD/LAG needs explicit, deterministic ordering.
- Define the valid/invalid population precisely: NOT(valid transitions) is
  safer than listing only selected invalid cases.
- Do not count the final event as a transition.
- SELECT DISTINCT when returning one entity that can have multiple bad events.

===============================================================================
CONCEPT 2 — DAILY MISTAKE BANK / PRE-SUBMISSION CHECKLIST
===============================================================================
[ ] Am I using a CTE alias inside a CTE definition? (Wrong: WITH cte x AS)
[ ] Is every referenced table and column spelled exactly as in the schema?
[ ] Are necessary columns projected from each CTE into the next?
[ ] Did I accidentally GROUP BY before applying ROW_NUMBER / LEAD / LAG?
[ ] Did I filter rn=1 if the requirement is about only the latest/first row?
[ ] Does every LEAD/LAG/ROW_NUMBER have appropriate PARTITION and ORDER BY?
[ ] Is tie-breaking deterministic when timestamps can tie?
[ ] Do I need DISTINCT in the final output?
[ ] Does the final WHERE refer to the right CTE and qualified columns?
[ ] Does the resulting grain match the required one-row-per-entity output?

NEXT SESSION: One additional P1 Concept 2 question for independent mastery.
DO NOT mark P1 Concept 2 mastered yet; current status: improving.
===============================================================================
*/

18/11/2026:
/*
===============================================================================
STAGE 1 | P1 — GRAIN, AGGREGATION, CTEs & WINDOW COMPARISONS
Practice revision bank | 18 October 2026 | Dialect: MySQL 8+
===============================================================================
PURPOSE
- Preserve MY original Day 1 SQL attempts and reasoning, then review mistakes.
- Read the FULL QUESTION and PATTERN TYPE before reviewing my attempted SQL.
- Incorrect attempts remain inside SQL comments; correct executable SQL follows.
- Each problem uses its own hypothetical table and sample records.

MASTER RULES
1. Raw grain = what one row of SOURCE data represents.
2. Calculate each metric at the required grain, not at whatever grain is handy.
3. GROUP BY collapses rows; window functions retain rows and attach metrics.
4. If a CTE aggregates rows, unaggregated original-row attributes are lost.
5. A later CTE sees only the columns selected by the previous CTE.
6. GROUP BY columns define the result grain; PARTITION BY defines peers.
7. Compare exact unrounded numbers; ROUND only in the output.
8. Verify expected outputs by calculating from sample rows.
===============================================================================
*/

/*
-------------------------------------------------------------------------------
Q1 — CUSTOMER REFUND ANALYSIS
FULL PRACTICE QUESTION (READ BEFORE YOUR ATTEMPT):
Given OrderItems(order_id, customer_id, item_id, amount, is_refunded), find
customers whose TOTAL REFUNDED ITEM AMOUNT across all orders is STRICTLY
GREATER than 20% of TOTAL PURCHASED ITEM AMOUNT. Purchased includes refunded
items. Refunded includes only records with is_refunded = 'Y'. Assume amounts
are positive. Return customer_id, total_purchased, total_refunded, refund_pct
(percentage rounded to 2 decimal places). Filter on the unrounded ratio.
PATTERN TYPE: Conditional aggregation / single customer-level GROUP BY /
              percentage threshold / retaining detail until metrics computed.
-------------------------------------------------------------------------------
TABLE: OrderItems(order_id, customer_id, item_id, amount, is_refunded)
ROWS:
(1,C1,I1,100,N),(1,C1,I2,200,Y),(2,C1,I3,300,N),
(3,C2,I4,400,Y),(3,C2,I5,100,N),(4,C2,I6,200,N),
(5,C3,I7,500,N),(5,C3,I8,200,N)
EXPECTED:
C1 | total_purchased=600 | total_refunded=200 | refund_pct=33.33
C2 | total_purchased=700 | total_refunded=400 | refund_pct=57.14
C3 does not qualify (0 refunded).

MY ORIGINAL REASONING (faithfully transcribed):
raw grain - one row per customer per order status
intermediate grain - find total purchase amount per customer and then attach
 total refund amount and refund % per customer
final grain - one row per customer satsifying the condition
requirement / logic -we do sum + group by to find total purchase per customer ,
 then we total refund per customer and the return %
pattern - sum + group by and case statement

MY ORIGINAL SQL (preserved as written):
with pur_cust as (
Select customer_id , amount , is_Refunded,sum(amount) as total_purchase
from orderitems
group by customer_id
),refund as (
select customer_id , total_purchase , sum(case when is_refunded='Y' then amount else 0 end) as total_refunded
from pur_cust
)
select customer_id , total_purchase , total_refunded,round((total_refunded / total_purchase)*100,2) as refund_pct
from pur_cust
where refund_pct > 20

MISTAKES — WHAT EXACTLY TO CORRECT
1. Raw grain is ONE ORDER ITEM, not customer/order status.
2. First CTE groups by customer_id but selects amount and is_refunded without
   aggregation. Invalid under ONLY_FULL_GROUP_BY; unreliable otherwise.
3. Collapsing items before computing refunds loses item-level is_refunded
   information. SUM(amount) and conditional SUM(...) belong together.
4. Refund CTE mixes aggregated and nonaggregated columns without GROUP BY.
5. Final SELECT incorrectly reads FROM pur_cust, which does NOT contain
   total_refunded. It should read a CTE with both measures.
6. refund_pct (SELECT alias) cannot be referenced in that same SELECT's WHERE.
7. Compare unrounded refund ratio to 20%; round only projected percentage.

CORRECT GRAINS:
Order item -> customer (purchased SUM and conditional refund SUM)
-> qualifying customer + displayed refund percentage.

MENTAL TRIGGER:
If multiple customer metrics depend on item attributes, calculate all of
those metrics BEFORE collapsing the item rows. No extra CTE is required.
*/
WITH customer_refunds AS (
    SELECT
        customer_id,
        SUM(amount) AS total_purchased,
        SUM(CASE WHEN is_refunded = 'Y' THEN amount ELSE 0 END)
            AS total_refunded
    FROM OrderItems
    GROUP BY customer_id
)
SELECT
    customer_id,
    total_purchased,
    total_refunded,
    ROUND(100.0 * total_refunded / total_purchased, 2) AS refund_pct
FROM customer_refunds
WHERE 100.0 * total_refunded / total_purchased > 20
ORDER BY customer_id;

/*
-------------------------------------------------------------------------------
Q2 — DEPARTMENT PERFORMANCE / EMPLOYEE SALES VS DEPARTMENT AVERAGE
FULL PRACTICE QUESTION (READ BEFORE YOUR ATTEMPT):
Given EmployeeSales(sale_id, employee_id, department_id, sale_amount), return
employees whose TOTAL SALES across their sales rows are STRICTLY GREATER than
the AVERAGE EMPLOYEE TOTAL SALES in their own department. Each employee is
weighted equally in the department average. Every employee belongs to one
department. Return employee_id, department_id, total_sales, dept_avg_sales
(the average displayed to two decimals).
PATTERN TYPE: Two grain levels / SUM by employee then AVG over department /
              retaining employee grain with a window function.
-------------------------------------------------------------------------------
TABLE: EmployeeSales(sale_id, employee_id, department_id, sale_amount)
ROWS:
(1,E1,D1,200),(2,E1,D1,300),(3,E2,D1,400),(4,E2,D1,100),
(5,E3,D2,600),(6,E3,D2,200),(7,E4,D2,300),(8,E4,D2,100)
EXPECTED:
E3 | D2 | total_sales=800 | dept_avg_sales=600.00
(D1 employee totals: 500,500; D2 totals: 800,400.)

MY ORIGINAL REASONING (faithfully transcribed):
raw grain - one row per employee per sale
intermediate grain - find total sale per employee and attach dept avg sale
final grain - one row per employee satisfying the condition
requirement - find the total sale per employee by sum + group by then find
 dept avg sale by avg(emp_total_Sale) group by dept apply the comparison
pattern - sum + group by and comp

MY ORIGINAL SQL (preserved as written):
with emp_sale as (
select employee_id , department_id , sum(sale_amount) as total_sales
from employeesales
group by employee_id , department_id
),
dept_Avg as (
select employee_id,total_sales , department_id ,avg(total_sales) as dept_avg_sales
from emp_sale
group by employee_id , department_id
)
select employee_id , department_id , total_sales , dept_avg_sales
from dept_avg where
total_sales > dept_avg_Sales

MISTAKES — WHAT EXACTLY TO CORRECT
1. First CTE was CORRECT: one row per employee with SUM of sales.
2. Second CTE GROUP BY employee_id, department_id made each employee its own
   group; AVG(total_sales) therefore equaled that employee's total_sales.
3. The comparison population is ALL EMPLOYEES WITHIN A DEPARTMENT, so for a
   window approach PARTITION BY department_id only.
4. If using GROUP BY department_id instead, the department result would need
   to be joined back to employee totals to preserve employee rows.
5. No need to average raw sale_amount: each employee must be weighted equally.

CORRECT GRAINS:
Sale -> employee+department (SUM sale_amount)
-> employee+department WITH department AVG attached (window preserves rows)
-> employee satisfying the threshold.

MENTAL TRIGGER:
GROUP BY chooses what ONE OUTPUT ROW represents; PARTITION BY chooses the
set of rows used to compute an attached window metric.
*/
WITH emp_sale AS (
    SELECT
        employee_id,
        department_id,
        SUM(sale_amount) AS total_sales
    FROM EmployeeSales
    GROUP BY employee_id, department_id
),
dept_avg AS (
    SELECT
        employee_id,
        department_id,
        total_sales,
        AVG(total_sales) OVER (PARTITION BY department_id)
            AS dept_avg_sales
    FROM emp_sale
)
SELECT
    employee_id,
    department_id,
    total_sales,
    ROUND(dept_avg_sales, 2) AS dept_avg_sales
FROM dept_avg
WHERE total_sales > dept_avg_sales
ORDER BY department_id, employee_id;

/*
-------------------------------------------------------------------------------
Q3 — DEPARTMENT SALARY VS DEPARTMENT AVERAGE
FULL PRACTICE QUESTION (READ BEFORE YOUR ATTEMPT):
Given Employees(employee_id, department_id, salary), return every employee
whose salary is STRICTLY GREATER than their own department's average salary.
Keep individual employee rows. Return employee_id, department_id, salary,
and dept_avg_salary rounded to 2 decimals for display only.
PATTERN TYPE: Window AVG(PARTITION BY) / attach group metric to raw rows /
              compare using full precision.
-------------------------------------------------------------------------------
TABLE: Employees(employee_id, department_id, salary)
ROWS:
(101,D1,60000),(102,D1,80000),(103,D1,100000),
(104,D2,50000),(105,D2,70000),(106,D2,90000),
(107,D3,75000),(108,D3,85000)
EXPECTED:
103 | D1 | 100000 | 80000.00
106 | D2 |  90000 | 70000.00
108 | D3 |  85000 | 80000.00

MY ORIGINAL REASONING (faithfully transcribed):
raw grain - one row per dept per employee sal
intermediate grain - find avg salary of empl dept and attach it
final grain - one row per emp satisfying the condition
requriement - finding the avg of dept and comparing
pattern - use group by and avg() over we use window function bcz we want to
 preserve employee level row but get dept avg

MY ORIGINAL SQL (preserved as written):
with cte as (
select employee_id , department_id , salary , avg(salary) over (partition by department_id) as dept_avg_sal
from employees
)
select employee_id , department_id , salary , round(dept_avg_sal,2) as dept_avg_sal
from cte
where salary > round(dept_avg_sal,2)

ASSESSMENT — CORRECT FIRST-ATTEMPT SOLUTION WITH ONE PRECISION CAUTION
1. Raw, intermediate and final grain: CORRECT.
2. Window AVG by department: CORRECT; no aggregation CTE needed.
3. CTE and final SELECT: CORRECT, and sample output matches.
4. Small improvement: WHERE salary > ROUND(dept_avg_sal, 2) may change the
   threshold for fractional averages. Compare to unrounded dept_avg_sal;
   ROUND only in final SELECT display.
5. This is NOT a failure of window-function or grain understanding.

CORRECT GRAINS:
Employee -> employee WITH department AVG attached -> qualifying employee.

MENTAL TRIGGER:
Need a group average on each detail row? AVG(...) OVER(PARTITION BY group).
Filter on original precision; only round the presentation.
*/
WITH dept_metrics AS (
    SELECT
        employee_id,
        department_id,
        salary,
        AVG(salary) OVER (PARTITION BY department_id) AS dept_avg_salary
    FROM Employees
)
SELECT
    employee_id,
    department_id,
    salary,
    ROUND(dept_avg_salary, 2) AS dept_avg_salary
FROM dept_metrics
WHERE salary > dept_avg_salary
ORDER BY department_id, employee_id;

/*
-------------------------------------------------------------------------------
Q4 — CUSTOMER SPENDING / AVG ORDER VALUE VS ALL-ORDER AVG
FULL PRACTICE QUESTION (READ BEFORE YOUR ATTEMPT):
Given OrderItems(order_id, customer_id, product_id, quantity, unit_price),
find customers whose AVERAGE ORDER VALUE is STRICTLY GREATER than the
OVERALL AVERAGE ORDER VALUE across ALL INDIVIDUAL ORDERS. Each order can
contain multiple items. Order value is SUM(quantity * unit_price) per order.
Customer average = AVG(that customer's order totals). Overall average = AVG
of EVERY order total, weighting ORDERS equally (NOT customers equally).
Return customer_id and avg_order_value rounded to 2 decimals; compare exact
unrounded amounts.
PATTERN TYPE: Multi-stage aggregation / order-item to order to customer /
              average of order totals vs global order average.
-------------------------------------------------------------------------------
TABLE: OrderItems(order_id, customer_id, product_id, quantity, unit_price)
ROWS:
(1,C1,P1,2,100),(1,C1,P2,1,300),(2,C1,P3,1,200),
(3,C2,P1,3,100),(3,C2,P2,2,200),(4,C2,P3,1,100),
(5,C3,P1,2,300),(6,C3,P2,1,200)
EXPECTED (verified from data; original prompt incorrectly omitted C3):
C2 | avg_order_value=400.00
C3 | avg_order_value=400.00
ORDER TOTALS: C1 (500,200), C2 (700,100), C3 (600,200).
GLOBAL AVG ACROSS 6 ORDERS = (500+200+700+100+600+200)/6 = 383.33.

MY ORIGINAL REASONING (faithfully transcribed):
raw grain - one row per customer order
intermediate grain - we find order value per customer then attach their avg
 order value and attach avg order value
final grain - one row per customer satisfying the condition
requriement - we find total order value per customer then thier avg order
 and then attach the avg order value and compare
pattern - we use group by , then avg then windows function

MY ORIGINAL SQL (preserved as written):
with cust_total as (
Select customer_id , (quantity * unit_price) as cust_total,avg(quantity*unit_price) over () as avg_order
from orderitems
),cust_avg as (
select customer_id , cust_total , avg_order , avg(cust_total) as avg_cust_order
from cust_total
Group by customer_id
)
select customer_id , round(avg_order,2) as avg_order_val
from cust_avg
where cust_total > avg_order_val

MISTAKES — WHAT EXACTLY TO CORRECT
1. Raw grain = ONE ORDER ITEM, not one customer/order.
2. quantity * unit_price was an ITEM LINE VALUE, not a full order total.
   First aggregate SUM(quantity * unit_price) GROUP BY customer_id, order_id.
3. AVG(quantity*unit_price) OVER () averages ITEM LINES, not ORDERS.
4. Second CTE selects cust_total and avg_order while grouping only customer_id;
   under ONLY_FULL_GROUP_BY they are invalid unaggregated projections.
5. Final WHERE compares cust_total (wrong metric) with avg_order_val
   (SELECT alias not available in same SELECT's WHERE).
6. Actual requirement: compare CUSTOMER AVG ORDER VALUE vs GLOBAL AVG of
   ALL ORDER TOTALS; the global average must read from order-grain CTE.
7. The practice prompt's original expected output was erroneous: both C2 and
   C3 qualify, not C2 alone. Do not count that mismatch against the learner.

CORRECT GRAINS:
Order item -> customer+order (SUM line values)
-> customer (AVG order totals)
-> qualifying customer relative to global AVG of all order totals.

MENTAL TRIGGER:
Before an AVG, ask: what should ONE equally weighted observation be?
An item? An order? A customer? Choose the CTE with that exact row grain.
*/
WITH order_totals AS (
    SELECT
        customer_id,
        order_id,
        SUM(quantity * unit_price) AS order_value
    FROM OrderItems
    GROUP BY customer_id, order_id
),
customer_averages AS (
    SELECT
        customer_id,
        AVG(order_value) AS avg_order_value
    FROM order_totals
    GROUP BY customer_id
)
SELECT
    customer_id,
    ROUND(avg_order_value, 2) AS avg_order_value
FROM customer_averages
WHERE avg_order_value > (SELECT AVG(order_value) FROM order_totals)
ORDER BY customer_id;

/*
===============================================================================
DAY 1 RECURRING-MISTAKE SUMMARY / BEFORE-SUBMISSION CHECKLIST
===============================================================================
[A] WRONG GRAIN: Am I averaging item rows, orders, employees, or customers?
[B] DETAIL LOST: Did I aggregate before computing every item-level condition?
[C] WRONG GROUP KEYS: Do GROUP BY keys produce the row grain I actually need?
[D] WINDOW PEERS: Is PARTITION BY the population I want to compare against?
[E] CTE WIRING: Does this CTE really expose each column I use later?
[F] RIGHT METRICS: Am I comparing avg_customer_order vs avg_ALL_orders?
[G] PRECISION: Filter on unrounded amounts; ROUND for display only.
[H] SOURCE CHECK: Independently verify expected output against sample data.

DAY 1 OUTCOME
Q1: correct conceptual technique, wrong item-to-customer SQL execution.
Q2: correct employee totals, incorrectly GROUPed department AVG by employee.
Q3: correct first attempt, with only round-before-filter precision issue.
Q4: correct metric intent, missing necessary order-grain aggregation.

NEXT: Day 1 repair checkpoints: grain identification -> debug CTE/grain errors
      -> independent short questions -> delayed retention check.
===============================================================================
*/



STAGE 1 MAESTERY : 
/*
===============================================================================
STAGE 1 | P1 CONCEPT 1 — REINFORCEMENT & MASTERY CHECK
Practice revision bank | 18 October 2026 | Dialect: MySQL 8+
===============================================================================
PURPOSE
- APPEND this section after the four original Day 1 questions.
- Preserve MY attempts, mistakes, and correct solutions from five subsequent checks.
- Original attempts are kept in comments; corrected SQL follows each block.
- Different questions may require different source-table schemas; run separately.

MASTER RULES
1. Grain is defined by what a row represents, not by what columns happen to exist.
2. SUM per day/entity first, AVG daily totals per entity second, and AVG those
   entity averages within the benchmark group third when required.
3. GROUP BY collapses rows; AVG() OVER(PARTITION BY ...) attaches a benchmark
   while preserving the input grain.
4. A new CTE is necessary whenever a metric needs a different row grain.
5. Every selected nonaggregated column in a grouped query must be a group key.
6. Filter with existing CTE columns; a SELECT alias isn't available to WHERE.
7. Apply strict comparisons to original values; ROUND only in the projection.
===============================================================================
*/

/*
-------------------------------------------------------------------------------
R1 — RESTAURANT REVENUE GREATER THAN CITY AVERAGE
FULL QUESTION: DeliveryOrders(order_id, restaurant_id, city, order_amount).
Return restaurants whose SUM(order_amount) is strictly greater than the
average of restaurant-level revenue totals in their city. Every restaurant
has equal weight. Return restaurant_id, city, total_revenue, city_avg_revenue.
DATA: (1,R1,Bengaluru,200),(2,R1,Bengaluru,400),
(3,R2,Bengaluru,500),(4,R2,Bengaluru,300),
(5,R3,Mumbai,600),(6,R3,Mumbai,200),
(7,R4,Mumbai,300),(8,R4,Mumbai,100).
EXPECTED: R2 Bengaluru 800 700.00; R3 Mumbai 800 600.00.
PATTERN TYPE: Entity SUM -> peer-group AVG window -> row filter.
MY REASONING: Raw one/order; intermediate restaurant revenue then city average;
final one qualifying restaurant; use SUM/GROUP BY and AVG OVER city.
MY ORIGINAL SQL (preserved):
with rest_rev as (
Select restaurant_id , city ,sum(order_amount) as revenue
from deliveryorders
group by restaurant_id,city
),city_Avg as (
select restaurant_id , city , revenue, avg(revenue) over (partition by city) as city_avg_rev
from rest_rev
)
select restaurant_id , city , revenue , round(city_avg_rev,2) as city_avg_rev
from city_Avg
where revenue > city_Avg_rev

ASSESSMENT: LOGIC AND QUERY CORRECT. No substantive error. The expected
output column names asked for total_revenue and city_avg_revenue; the query
used revenue and city_avg_rev, which is a presentation-name difference only.
CORRECT GRAINS: order -> restaurant+city revenue -> restaurant+city with
city benchmark -> qualifying restaurant.
AVOID: unnecessarily adding GROUP BY in the window stage.
-------------------------------------------------------------------------------
*/
WITH rest_rev AS (
    SELECT restaurant_id, city, SUM(order_amount) AS total_revenue
    FROM DeliveryOrders
    GROUP BY restaurant_id, city
), city_avg AS (
    SELECT restaurant_id, city, total_revenue,
           AVG(total_revenue) OVER (PARTITION BY city) AS city_avg_revenue
    FROM rest_rev
)
SELECT restaurant_id, city, total_revenue,
       ROUND(city_avg_revenue, 2) AS city_avg_revenue
FROM city_avg
WHERE total_revenue > city_avg_revenue
ORDER BY city, restaurant_id;

/*
-------------------------------------------------------------------------------
R2 — BANK ACCOUNTS: AVERAGE ACTIVE-DAY AMOUNT VS BRANCH AVERAGE
FULL QUESTION: BankTransactions(transaction_id,account_id,branch_id,
transaction_date,amount). Find accounts whose average DAILY transaction total
(across active days) exceeds the equally weighted average of account-level
daily averages within the same branch. Return account_id, branch_id,
avg_daily_amount, branch_avg_daily_amount; use unrounded comparisons.
DATA: (1,A1,B1,2026-10-01,100),(2,A1,B1,2026-10-01,200),
(3,A1,B1,2026-10-02,300),(4,A2,B1,2026-10-01,500),
(5,A2,B1,2026-10-02,100),(6,A3,B2,2026-10-01,400),
(7,A3,B2,2026-10-02,200),(8,A4,B2,2026-10-01,300).
EXPECTED: EMPTY (all account averages and both branch benchmarks are 300).
PATTERN TYPE: Three-grain SUM -> AVG -> AVG OVER(PARTITION BY branch).
MY REASONING: Daily total per account, average per account, then branch
average of account averages; compare account to branch.
MY ORIGINAL SQL (preserved):
with daily_amt as (
Select account_id , branch_id , transaction_date, sum(amount) as total_Daily
from banktransactions
group by  account_id , branch_id , transaction_date
),avg_daily  as (
select  account_id , branch_id , transaction_date,avg(total_daily) as avg_daily_amnt , avg(total_daily) over (partition by branch_id) as branch_avg_daily_amount
from daily_amt
)
Select  account_id , branch_id , round(avg_daily_amnt ,2) as avg_daily_amount , round(branch_avg_daily_amount,2) as branch_avg_daily_amount
from avg_daily
where avg_daily_amount > branch_Avg_daily_amount

MISTAKES:
- Raw grain initially described as account+branch; actual grain is TRANSACTION.
- AVG(total_daily) without GROUP BY account_id,branch_id mixes aggregate rows
  with nonaggregated account/date columns.
- The branch window averages daily rows, not one ACCOUNT AVERAGE per account;
  accounts with more active days would be overweighted.
- Final WHERE uses avg_daily_amount (alias from SELECT), not a source CTE
  field; MySQL can't reference it in WHERE.
CORRECT GRAINS: transaction -> account+date -> account -> account with branch
benchmark -> qualifying account.
AVOID: combining average-per-account and average-of-accounts in the same CTE.
-------------------------------------------------------------------------------
*/
WITH daily_amt AS (
    SELECT account_id, branch_id, transaction_date,
           SUM(amount) AS total_daily
    FROM BankTransactions
    GROUP BY account_id, branch_id, transaction_date
), account_avg AS (
    SELECT account_id, branch_id,
           AVG(total_daily) AS avg_daily_amount
    FROM daily_amt
    GROUP BY account_id, branch_id
), branch_avg AS (
    SELECT account_id, branch_id, avg_daily_amount,
           AVG(avg_daily_amount) OVER (PARTITION BY branch_id)
               AS branch_avg_daily_amount
    FROM account_avg
)
SELECT account_id, branch_id,
       ROUND(avg_daily_amount, 2) AS avg_daily_amount,
       ROUND(branch_avg_daily_amount, 2) AS branch_avg_daily_amount
FROM branch_avg
WHERE avg_daily_amount > branch_avg_daily_amount
ORDER BY account_id;

/*
-------------------------------------------------------------------------------
R3 — STORE DAILY REVENUE VS REGIONAL BENCHMARK
FULL QUESTION: StoreTransactions(transaction_id,store_id,region_id,
transaction_date,revenue). Multiple transactions occur per store/day.
Return stores whose average DAILY total across active days is strictly
higher than the equal-weight average of store daily averages in their region.
Return store_id, region_id, avg_daily_revenue, region_avg_daily_revenue.
DATA: (1,S1,North,2026-10-01,100),(2,S1,North,2026-10-01,200),
(3,S1,North,2026-10-02,500),(4,S2,North,2026-10-01,200),
(5,S2,North,2026-10-03,400),(6,S3,South,2026-10-01,600),
(7,S3,South,2026-10-02,200),(8,S4,South,2026-10-01,300).
EXPECTED: S1 North 400.00 350.00; S3 South 400.00 350.00.
PATTERN TYPE: Three-level SUM -> AVG -> peer-group AVG window.
MY ORIGINAL SQL (preserved):
with store_rev as (
select store_id , region_id , transaction_date , sum(revenue) as total_rev
from storetransactions
group by store_id , region_id , transaction_Date
),avg_daily_Rev as (
Select store_id , region_id , avg(total_rev) as avg_daily_rev
from store_rev
group by store_id , region_id
),region_rev as (
Select store_id , region_id ,avg_daily_rev,  avg(avg_daily_rev) over (partition by region_id) as region_avg_daily_rev
from avg_daily_rev
)
select store_id , region_id , round(avg_daily_rev,2) as avg_daily_rev , round(region_Avg_daily_rev,2) as region_avg_daily_Rev
from region_Rev
where avg_daily_Rev > region_Avg_daily_Rev

ASSESSMENT: Correct first attempt for all grain transitions, CTEs and
unrounded WHERE comparison. The requested ORDER BY region_id,store_id was
omitted (output formatting only).
CORRECT GRAINS: transaction -> store+active-date -> store average -> store
with region benchmark -> qualifying store.
MEMORY TRIGGER: one stage per distinct metric grain; preserve store rows
with AVG OVER(PARTITION BY region).
-------------------------------------------------------------------------------
*/
WITH store_rev AS (
    SELECT store_id, region_id, transaction_date,
           SUM(revenue) AS total_rev
    FROM StoreTransactions
    GROUP BY store_id, region_id, transaction_date
), avg_daily_rev AS (
    SELECT store_id, region_id, AVG(total_rev) AS avg_daily_rev
    FROM store_rev
    GROUP BY store_id, region_id
), region_rev AS (
    SELECT store_id, region_id, avg_daily_rev,
           AVG(avg_daily_rev) OVER (PARTITION BY region_id)
               AS region_avg_daily_rev
    FROM avg_daily_rev
)
SELECT store_id, region_id,
       ROUND(avg_daily_rev, 2) AS avg_daily_revenue,
       ROUND(region_avg_daily_rev, 2) AS region_avg_daily_revenue
FROM region_rev
WHERE avg_daily_rev > region_avg_daily_rev
ORDER BY region_id, store_id;

/*
-------------------------------------------------------------------------------
R4 — PAYMENTS: DEBUG AN INVALID GROUP BY
FULL QUESTION: Payments(payment_id,customer_id,payment_date,amount).
Find one row per customer with SUM(amount) as total_amount and AVG(amount)
as avg_amount. Diagnose and rewrite the invalid SQL below.
DATA: (1,C1,2026-10-01,100),(2,C1,2026-10-02,200),
(3,C1,2026-10-03,300),(4,C2,2026-10-01,400),
(5,C2,2026-10-02,200),(6,C3,2026-10-01,500).
EXPECTED: C1 600 200.00; C2 600 300.00; C3 500 500.00.
PATTERN TYPE: Single-grain GROUP BY / invalid projected columns.
INCORRECT QUERY PROVIDED FOR DEBUGGING:
SELECT customer_id, payment_date, amount,
       SUM(amount) AS total_amount, AVG(amount) AS avg_amount
FROM Payments
GROUP BY customer_id;
MY DIAGNOSIS: 'the wrong thing is we dont have payment_date, amount in group
by clause'.
MY CORRECTED SQL (preserved):
select customer_id , sum(amount) as total_amount ,
avg(amount) as avg_amount
from payments
group by customer_id

ASSESSMENT: PASSED. The correct fix is to remove payment_date and raw amount
from SELECT, NOT add them to GROUP BY (which would change the grain).
MEMORY TRIGGER: GROUP BY customer_id -> select group keys and aggregates only.
-------------------------------------------------------------------------------
*/
SELECT customer_id,
       SUM(amount) AS total_amount,
       ROUND(AVG(amount), 2) AS avg_amount
FROM Payments
GROUP BY customer_id
ORDER BY customer_id;

/*
-------------------------------------------------------------------------------
R5 — CAMPAIGN DAILY SPEND VS ADVERTISER CAMPAIGN BENCHMARK
FULL QUESTION: CampaignTransactions(transaction_id,campaign_id,advertiser_id,
transaction_date,spend). Find campaigns whose average daily spending across
active days exceeds the equal-weight average of the CAMPAIGN-level daily
averages for that advertiser. Return campaign_id, advertiser_id,
avg_daily_spend, advertiser_avg_daily_spend; compare unrounded values.
DATA: (1,C1,A1,2026-10-01,100),(2,C1,A1,2026-10-01,200),
(3,C1,A1,2026-10-02,300),(4,C2,A1,2026-10-01,200),
(5,C2,A1,2026-10-03,200),(6,C3,A2,2026-10-01,500),
(7,C3,A2,2026-10-02,300),(8,C4,A2,2026-10-01,200).
EXPECTED (corrected after original prompt error): C1 A1 300.00 250.00;
C3 A2 400.00 300.00.
PATTERN TYPE: Three-stage aggregation / final SELECT-alias filtering.
MY ORIGINAL SQL (preserved):
with daily_spend as (
select campaign_id , advertiser_id , transaction_Date, sum(spend) as daily_Spend
from campaigntransactions
group by campaign_id ,advertiser_id , transaction_date
),avg_Daily as (
Select campaign_id , advertiser_id , avg(daily_spend) as avg_daily
from daily_spend
group by campaign_id , advertiser_id
),avg_adver as (
select campaign_id , advertiser_id , avg_daily , avg(avg_daily) over (partition by advertiser_id) as adv_avg_Daily
from avg_daily
)
Select campaign_id , advertiser_id , round(avg_Daily,2) as avg_Daily_spend, round(adv_avg_Daily,2) as advertiser_avg_daily_spend
from avg_adver
where avg_Daily_spend > advertiser_avg_daily_Spend
order by advertiser_id , campaign_id

ASSESSMENT: All three grain transitions and metric logic were CORRECT.
Only issue: WHERE uses avg_Daily_spend and advertiser_avg_daily_spend,
which are aliases newly defined in the SAME SELECT. Use existing avg_daily
and adv_avg_daily from avg_adver instead. Filtering those unrounded columns
also preserves the strict comparison correctly.
CORRECT GRAINS: transaction -> campaign+active-date -> campaign average ->
campaign with advertiser benchmark -> qualifying campaign.
AVOID: comparing formatted/rounded SELECT aliases within WHERE.
-------------------------------------------------------------------------------
*/
WITH daily_spend AS (
    SELECT campaign_id, advertiser_id, transaction_date,
           SUM(spend) AS daily_spend
    FROM CampaignTransactions
    GROUP BY campaign_id, advertiser_id, transaction_date
), avg_daily AS (
    SELECT campaign_id, advertiser_id,
           AVG(daily_spend) AS avg_daily
    FROM daily_spend
    GROUP BY campaign_id, advertiser_id
), avg_adver AS (
    SELECT campaign_id, advertiser_id, avg_daily,
           AVG(avg_daily) OVER (PARTITION BY advertiser_id)
               AS adv_avg_daily
    FROM avg_daily
)
SELECT campaign_id, advertiser_id,
       ROUND(avg_daily, 2) AS avg_daily_spend,
       ROUND(adv_avg_daily, 2) AS advertiser_avg_daily_spend
FROM avg_adver
WHERE avg_daily > adv_avg_daily
ORDER BY advertiser_id, campaign_id;

/*
===============================================================================
REINFORCEMENT SUMMARY
R1 Restaurant: pass, SUM per restaurant -> city average correctly.
R2 Bank: fail, account average and branch average improperly combined.
R3 Store: pass, all three grains correct (ordering omission).
R4 Payments debug: pass, invalid non-grouped projected columns removed.
R5 Campaign: grain logic pass, SELECT-alias reference in WHERE needs care.

STATUS: Day 1 provisionally complete; delayed mixed retention still needed.
KEEP ASKING: What does ONE row mean before and after each CTE? Which CTE
contains the observations each AVG must weight equally?
===============================================================================
*/


19/10/2026 : 
/*
===============================================================================
STAGE 1 | DAY 2 — COMPLETE SQL PATTERN & MISTAKE BANK
TOPIC: LEFT JOINS, ANTI-JOINS, CONDITIONAL AGGREGATION, COUNTING GRAIN
Dialect: MySQL 8+ | Prepared from the Day 2 coaching session
===============================================================================
HOW TO REVISE:
1. Read QUESTION + SAMPLE DATA + EXPECTED OUTPUT first. Hide the SQL below.
2. State raw/intermediate/final grains, then independently write your SQL.
3. Compare with MY ORIGINAL ATTEMPT and DIAGNOSIS, then EXECUTABLE SOLUTION.
4. Source tables are independent per exercise; run each solution separately.
5. Important: errors marked as typos are NOT counted as conceptual failures.

MASTER LESSONS:
- FROM A LEFT JOIN B: all rows of A survive, even without matching B rows.
- Choose the preserved population from the QUESTION, not the fact table.
- COUNT(*) counts NULL-extended rows; COUNT(matched_id) gives zero for no match.
- COUNT(DISTINCT entity_id) counts entities, SUM(CASE ...) counts events.
- COUNT(DISTINCT reference_table.id) ignores IDs absent from valid reference set.
- SUM() can be NULL when no rows contribute; COALESCE when zero is needed.
- For valid/required categories, check matches against the reference table.
- Only columns projected by a CTE are visible to downstream SQL.
- Compare SQL aliases CHARACTER BY CHARACTER; use status values from data.
- Read business rules carefully: attempts != successful distinct shipments.
===============================================================================
*/

/*
===============================================================================
Q1 — E-COMMERCE CUSTOMERS WITH NO ORDERS (ANTI-JOIN)
SCHEMA: Customers(customer_id, customer_name)
        Orders(order_id, customer_id, order_date, amount)
Customers: (101,Alice),(102,Bob),(103,Charlie),(104,David),(105,Emma),
           (106,Frank)
Orders: (1,101,2026-10-01,500),(2,101,2026-10-03,300),
        (3,103,2026-10-02,700),(4,105,2026-10-04,200),
        (5,105,2026-10-05,400),(6,106,2026-10-06,600)
REQUIREMENT: All and only customers who have NEVER placed an order. Return
customer_id, customer_name, sorted by customer_id. PKs unique, non-null.
EXPECTED:
102 | Bob
104 | David
GRAINS: Customers=customer, Orders=order, final=unmatched customer.
PATTERN: Anti-join via LEFT JOIN + WHERE right-side PK IS NULL.

MY ORIGINAL SQL (verbatim):
select c.customer_id , c.customer_name from customers c
left join orders o on c.customer_id=o.customer_id
where o.order_id is null
group by c.customer_id , c.customer_name

DIAGNOSIS: Logic correct first attempt. GROUP BY is redundant because each
qualifying customer already has a single null-extended row. Requested ORDER BY
was omitted. No need to aggregate just to ensure uniqueness.
===============================================================================
*/
SELECT c.customer_id, c.customer_name
FROM Customers c
LEFT JOIN Orders o ON c.customer_id = o.customer_id
WHERE o.order_id IS NULL
ORDER BY c.customer_id;

/*
===============================================================================
Q2 — CUSTOMER ORDER PERFORMANCE (ALL CUSTOMERS)
SCHEMA: Customers(customer_id,customer_name)
        Orders(order_id,customer_id,status,amount)
Customers: (101,Alice),(102,Bob),(103,Charlie),(104,David),(105,Emma)
Orders: (1,101,completed,500),(2,101,cancelled,200),
        (3,101,completed,300),(4,102,cancelled,150),
        (5,102,pending,100),(6,103,completed,400),
        (7,103,completed,600),(8,105,pending,250)
REQUIREMENT: EVERY customer, total order count, completed order count,
completed order amount, percent completed out of all orders rounded to 2dp.
Zero-order customers have zeros for all metrics; sort customer_id.
EXPECTED: customer_id | name | total | completed | amount | completion_rate
101 | Alice   | 3 | 2 |  800 |  66.67
102 | Bob     | 2 | 0 |    0 |   0.00
103 | Charlie | 2 | 2 | 1000 | 100.00
104 | David   | 0 | 0 |    0 |   0.00
105 | Emma    | 1 | 0 |    0 |   0.00
GRAINS: customer / order -> grouped customer with orders -> all customers.
PATTERN: Aggregation before population-preserving LEFT JOIN, COALESCE,
NULLIF-zero-safe division, conditional SUM(CASE ...).

MY FIRST SQL (verbatim, incomplete as submitted):
with cte as (
select c.customer_id , c.customer_name ,count(*) as total_orders , sum(Case when o.status='completed' then 1 else 0 end) as completed_orders , sum(case when o.status='completed' then amount else 0 end ) as completed_amount
from customers c join orders o on
c.customer_id =o.customer_id
group by c.customer_id , c.customer_name
),zero_ord as (
Select c.customer_id , c.customer_name , coalesce(total_orders,0) as total_orders , coalesce(completed_orders,0) as completed_orders ,coalesce(completed_amount,0) as completed_amount , round(completed_orders / total_orders)*100,2) as completion_Rate from cte c2
left join customers c on
c2.customer_id = c.customer_id
group by c.customer_id , c.customer_name
order by c.customer_id

MY RETRY SQL (verbatim):
with cte as (
select c.customer_id , c.customer_name , count(*) as total_orders , sum(CASE WHEN o.status = 'completed' THEN 1 ELSE 0 END)             AS completed_orders,         SUM(CASE WHEN o.status = 'completed' THEN amount ELSE 0 END)             AS completed_amount from customers c join orders o on c.customer_id = o.customer_id
group by c.customer_id , c.customer_name
),all_cust as (
Select c.customer_id , c.customer_name , coalesce(total_orders , 0) as total_orders , coalesce(completed_amount ,0) as completed_amount , coalesce(completed_orders,0) as completed_orders
from customers c
left join cte c2 on
c.customer_id = c2.customer_id
) select customer_id , customer_name, total_orders , completed_orders , completed_amount,
coalesce(round(100.0 * compelted_orders / nullif(total_orders ,0),2),0) as completion_rate
from all_custs
order by customer_id

DIAGNOSIS: First attempt reversed second LEFT JOIN and lost zero-order
customers, malformed ROUND, CTE incomplete. Retry fixed preservation and
zero-safe division correctly; only 'compelted_orders' and 'all_custs'
are naming typos. COUNT(*) is fine IN the INNER-JOIN-only aggregate, but
COUNT(o.order_id) should be used for a direct Customers LEFT JOIN Orders.
===============================================================================
*/
WITH order_metrics AS (
    SELECT customer_id,
           COUNT(*) AS total_orders,
           SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) AS completed_orders,
           SUM(CASE WHEN status = 'completed' THEN amount ELSE 0 END) AS completed_amount
    FROM Orders
    GROUP BY customer_id
), all_customers AS (
    SELECT c.customer_id, c.customer_name,
           COALESCE(o.total_orders, 0) AS total_orders,
           COALESCE(o.completed_orders, 0) AS completed_orders,
           COALESCE(o.completed_amount, 0) AS completed_amount
    FROM Customers c
    LEFT JOIN order_metrics o ON c.customer_id = o.customer_id
)
SELECT customer_id, customer_name, total_orders, completed_orders,
       completed_amount,
       COALESCE(ROUND(100.0 * completed_orders / NULLIF(total_orders, 0), 2), 0)
           AS completion_rate
FROM all_customers
ORDER BY customer_id;

/*
===============================================================================
Q3 — EMPLOYEE MANDATORY TRAINING COMPLIANCE
SCHEMA: Employees(employee_id,employee_name,department)
        TrainingCourses(course_id,course_name)  -- ALL are mandatory
        TrainingCompletions(completion_id,employee_id,course_id)
Employees: (E1,Alice,Engineering),(E2,Bob,Engineering),
(E3,Charlie,Finance),(E4,David,Finance),(E5,Emma,HR),(E6,Frank,HR)
Courses: (C1,Data Security),(C2,Workplace Safety),(C3,Compliance)
Completions: (1,E1,C1),(2,E1,C2),(3,E1,C3),(4,E2,C1),(5,E2,C2),
(6,E3,C1),(7,E3,C2),(8,E3,C3),(9,E4,C1),(10,E6,C1),(11,E6,C3)
REQUIREMENT: Return employees missing >=1 mandatory course, including
employees with ZERO completions. Duplicates of same completion count once;
non-mandatory course IDs do not count. Return employee_id, employee_name,
completed_courses, missing_courses sorted employee_id.
EXPECTED: E2 Bob 2 1; E4 David 1 2; E5 Emma 0 3; E6 Frank 2 1.
GRAINS: employee / mandatory course / completion event -> employee ->
employee with scalar mandatory count -> noncompliant employee.
PATTERN: Preserve entities; COUNT DISTINCT matched REFERENCE IDs; attach
single-row benchmark via CROSS JOIN; missing=mandatory-completed.

MY ORIGINAL SQL (verbatim):
with cte as (
select e.employee_id , e.employee_name,count(distinct t.course_id) as completed_course , count(distinct tc.course_id) as mandatory_course from employees e
join training completions t on
e.employee_id = t.employee_id
left join trainingcompletions tc on
tc.course_id=trainingcourses.course_id
group by e.employee_id,e.employee_name)
select employee_id , employee_name , completed_course , mandatory_count - count(trainingcourses.course_id) as missing_courses
from cte
order by employee_id

MY RETRY SQL (verbatim):
with mandatory_count as (
Select count(distinct course_id) as total_courses from trainingcourses
),
all_emp as (
select e.employee_id , e.employee_name ,count(distinct tc.course_id) as completed_courses from employees e left join trainingcompletions tc on
e.employee_id=tc.employee_id
left join trainingcourses c on
tc.course_id=c.course_id
group by e.employee_id,e.employee_name
),
emp_Stat as (
select  ae.employee_id , ae.employee_name , ae.completed_courses , mc.total_courses - ae.completed_courses as missing_courses
from all_emp e cross join mandatory_count mc
)
select employee_id , employee_name , completed_courses , missing_courses
from emp_stat
where missing_courses >0 order by employee_id

DIAGNOSIS: Initial inner join lost Emma and joined invalid aliases/tables.
Retry fixed join direction, staged CTEs, formula, CROSS JOIN and filter.
Outstanding: count DISTINCT c.course_id (mandatory reference), not
 tc.course_id (completion list), and use ae consistently in FROM all_emp ae.
Important conceptual quiz eventually answered correctly: counting from
reference table excludes unmatched/invalid records.
===============================================================================
*/
WITH mandatory_count AS (
    SELECT COUNT(DISTINCT course_id) AS total_courses
    FROM TrainingCourses
), all_emp AS (
    SELECT e.employee_id, e.employee_name,
           COUNT(DISTINCT c.course_id) AS completed_courses
    FROM Employees e
    LEFT JOIN TrainingCompletions tc ON e.employee_id = tc.employee_id
    LEFT JOIN TrainingCourses c ON tc.course_id = c.course_id
    GROUP BY e.employee_id, e.employee_name
), emp_stat AS (
    SELECT ae.employee_id, ae.employee_name, ae.completed_courses,
           mc.total_courses - ae.completed_courses AS missing_courses
    FROM all_emp ae
    CROSS JOIN mandatory_count mc
)
SELECT employee_id, employee_name, completed_courses, missing_courses
FROM emp_stat
WHERE missing_courses > 0
ORDER BY employee_id;

/*
===============================================================================
Q4 — SUBSCRIPTION BILLING ANALYSIS
SCHEMA: Customers(customer_id,customer_name)
        Subscriptions(subscription_id,customer_id,plan_id)
        Payments(payment_id,subscription_id,payment_status,amount)
Customers: (C1,Alice),(C2,Bob),(C3,Charlie),(C4,David),(C5,Emma)
Subscriptions: (S1,C1,P1),(S2,C1,P2),(S3,C2,P1),(S4,C3,P3),(S5,C5,P2)
Payments: (1,S1,success,100),(2,S1,failed,100),(3,S2,success,200),
(4,S3,failed,150),(5,S3,failed,150),(6,S4,success,300),
(7,S4,success,300),(8,S5,pending,200)
REQUIREMENT: EVERY customer, distinct subscription count, number of success
payment EVENTS, success amounts sum, failed payment EVENTS; zeros for missing.
EXPECTED: C1 Alice 2 2 300 1; C2 Bob 1 0 0 2;
C3 Charlie 1 2 600 0; C4 David 0 0 0 0; C5 Emma 1 0 0 0.
GRAINS: customer / subscription / payment -> one row per customer.
PATTERN: two LEFT JOINs, COUNT DISTINCT subscription to avoid multiplication,
conditional SUM for payment EVENT metrics.

MY FINAL ORIGINAL SQL (verbatim):
with cust as (
select c.customer_id , c.customer_name , count(distinct s.subscription_id) as total_subscription , sum(case when p.payment_status='success' then 1 else 0 end) as successful_payments , sum(case when p.payment_status='success' then amount else 0 end) as successful_amount , sum(case when p.payment_status='failed' then 1 else 0 end) as failed_payments
from customers c
left join subscriptions s on
c.customer_id=s.customer_id
left join payments p on
p.subscription_id=s.subscription_id
group by c.customer_id,c.customer_name
)
select customer_id , customer_name ,total_subscriptions,successful_payments,successful_amount,failed_payment
from cust

DIAGNOSIS: All JOIN and metric logic correct. Typing/reference mismatch:
total_subscription vs total_subscriptions; failed_payments vs failed_payment.
Forgot ORDER BY customer_id. Initial submission simply stopped within CTE;
then submitted this complete version.
===============================================================================
*/
WITH cust AS (
    SELECT c.customer_id, c.customer_name,
           COUNT(DISTINCT s.subscription_id) AS total_subscriptions,
           SUM(CASE WHEN p.payment_status = 'success' THEN 1 ELSE 0 END)
               AS successful_payments,
           SUM(CASE WHEN p.payment_status = 'success' THEN p.amount ELSE 0 END)
               AS successful_amount,
           SUM(CASE WHEN p.payment_status = 'failed' THEN 1 ELSE 0 END)
               AS failed_payments
    FROM Customers c
    LEFT JOIN Subscriptions s ON c.customer_id = s.customer_id
    LEFT JOIN Payments p ON s.subscription_id = p.subscription_id
    GROUP BY c.customer_id, c.customer_name
)
SELECT customer_id, customer_name, total_subscriptions,
       successful_payments, successful_amount, failed_payments
FROM cust
ORDER BY customer_id;

/*
===============================================================================
Q5 — FINAL MASTERY: LOGISTICS DELIVERY PERFORMANCE BY HUB
SCHEMA: Hubs(hub_id,hub_name)
        Shipments(shipment_id,hub_id,shipment_date)
        DeliveryAttempts(attempt_id,shipment_id,attempt_status,delivery_cost)
Hubs: (H1,Bengaluru),(H2,Mumbai),(H3,Delhi),(H4,Pune),(H5,Hyderabad)
Shipments: (S1,H1,2026-10-01),(S2,H1,2026-10-02),(S3,H1,2026-10-03),
(S4,H2,2026-10-01),(S5,H2,2026-10-02),(S6,H3,2026-10-01),
(S7,H5,2026-10-02)
Attempts: (1,S1,failed,50),(2,S1,success,100),(3,S2,success,120),
(4,S3,failed,40),(5,S4,failed,60),(6,S4,failed,70),
(7,S5,success,150),(8,S6,success,200),(9,S7,pending,30)
REQUIREMENT: EVERY hub; distinct number of shipments; distinct shipments
having >=1 success attempt; total failed ATTEMPT records (including failures
before eventual success); sum costs of SUCCESS attempts only; zeros if none.
EXPECTED: hub | name | total_shipments | success_shipments | failed_attempts | cost
H1 | Bengaluru | 3 | 2 | 2 | 220
H2 | Mumbai    | 2 | 1 | 2 | 150
H3 | Delhi     | 1 | 1 | 0 | 200
H4 | Pune      | 0 | 0 | 0 |   0
H5 | Hyderabad | 1 | 0 | 0 |   0
GRAINS: hub / shipment / attempt -> hub (conditional DISTINCT shipment vs
ordinary COUNT of attempts). Pattern: join fanout, entity vs event counting.

MY ORIGINAL SQL (verbatim):
with cte as (
select h.hub_id , h.hub_name , count(distinct s.shipment_id) as total_shipments , sum(case when d.attempt_status='successful' then 1 else 0 end) as successful_shipements ,sum(Case when d.attempt_status='failed' then 1 else 0 end) as failed_attempts , sum(case when d.attempt_status='success' then delivery_cost else 0 end) as successful_Delivery_cost
from hubs h left join shipments s on
h.hub_id = s.hub_id
left join deliveryattempts d on
s.shipment_id=d.shipment_id
group by h.hub_id , h.hub_name
)
select hub_id , hub_name , total_shipments , successful_shipements ,failed_shipments ,successful_delivery_cost
From cte
order by hub_id

DIAGNOSIS: Joins, base preservation, distinct total shipments, failed EVENT
sum, success cost sum, GROUP BY and ordering all correct. The requirement
for successful shipments was MISREAD: count distinct successful SHIPMENTS,
not successful ATTEMPTS. Literal status is 'success', not 'successful'.
Two projected alias/reference mismatches: successful_shipements (typo),
failed_shipments vs failed_attempts. Key lesson is requirement precision,
not a failure of foundational JOIN understanding.
===============================================================================
*/
WITH hub_performance AS (
    SELECT h.hub_id, h.hub_name,
           COUNT(DISTINCT s.shipment_id) AS total_shipments,
           COUNT(DISTINCT CASE WHEN d.attempt_status = 'success'
                               THEN s.shipment_id END) AS successful_shipments,
           SUM(CASE WHEN d.attempt_status = 'failed' THEN 1 ELSE 0 END)
               AS failed_attempts,
           SUM(CASE WHEN d.attempt_status = 'success' THEN d.delivery_cost
                    ELSE 0 END) AS successful_delivery_cost
    FROM Hubs h
    LEFT JOIN Shipments s ON h.hub_id = s.hub_id
    LEFT JOIN DeliveryAttempts d ON s.shipment_id = d.shipment_id
    GROUP BY h.hub_id, h.hub_name
)
SELECT hub_id, hub_name, total_shipments, successful_shipments,
       failed_attempts, successful_delivery_cost
FROM hub_performance
ORDER BY hub_id;

/*
===============================================================================
REINFORCEMENT R1 — WAREHOUSE INVENTORY MOVEMENTS
SCHEMA: Warehouses(warehouse_id,warehouse_name)
        InventoryMovements(movement_id,warehouse_id,movement_type,quantity)
Warehouses: (W1,Bengaluru),(W2,Mumbai),(W3,Delhi),(W4,Pune),(W5,Hyderabad)
Movements: (1,W1,IN,100),(2,W1,OUT,30),(3,W1,IN,50),
(4,W2,OUT,20),(5,W2,IN,80),(6,W3,IN,200),(7,W3,OUT,60),
(8,W5,OUT,25)
REQUIREMENT: Every warehouse with movement count, IN quantity, OUT quantity,
zero when absent; sort warehouse_id.
EXPECTED: W1 Bengaluru 3 150 30; W2 Mumbai 2 80 20;
W3 Delhi 2 200 60; W4 Pune 0 0 0; W5 Hyderabad 1 0 25.
GRAINS: warehouse / movement -> warehouse.
MY ORIGINAL SQL (verbatim):
with cte as (
select w.warehouse_id , w.warehouse_name,count(i.movement_type) as total_movements, sum(case when i.movement_type='IN' then quantity else 0 end) as inward_quantity , sum(Case when i.movement_type='OUT' then quantity else 0 end) as outward_quantity
from inventorymovements i left join warehouses w on
w.warehouse_id=i.warehouse_id
)
select warehouse_id , warehouse_name , coalesce(total_movements,0) as total_movements , coalesce(inward_quantity,0) as inward_quantity,coalesce(outward_quantity,0) as outward_quantity
from cte
order by warehouse_id
DIAGNOSIS: The attempt put movements on LEFT, losing W4, omitted GROUP BY
and closing CTE parenthesis. COUNT(movement_id) is the reliable record count.
===============================================================================
*/
SELECT w.warehouse_id, w.warehouse_name,
       COUNT(i.movement_id) AS total_movements,
       SUM(CASE WHEN i.movement_type = 'IN' THEN i.quantity ELSE 0 END)
           AS inward_quantity,
       SUM(CASE WHEN i.movement_type = 'OUT' THEN i.quantity ELSE 0 END)
           AS outward_quantity
FROM Warehouses w
LEFT JOIN InventoryMovements i ON w.warehouse_id = i.warehouse_id
GROUP BY w.warehouse_id, w.warehouse_name
ORDER BY w.warehouse_id;

/*
===============================================================================
REINFORCEMENT R2 — STORES AND SALES (LEFT JOIN QUICK CHECK)
SCHEMA: Stores(store_id,store_name); Sales(sale_id,store_id,amount)
QUESTION: Every store, total sales amount and number of transactions,
including zero-sales stores with BOTH metrics zero.
EXPECTED LOGIC: No illustrative sample rows were supplied in this exercise.
MY ORIGINAL SQL (verbatim):
select s.store_id , s.store_name , sum(sl.amount) as total_sales_amount,count(sl.sale_id) as transaction_count from stores s
left join sales sl on
s.store_id = sl.store_id
group by s.store_id , s.store_name
DIAGNOSIS: Correct JOIN, COUNT and GROUP BY. SUM(sl.amount) is NULL for
zero-sales store; use COALESCE(SUM(...),0). This was a FIRST-TRY join success.
===============================================================================
*/
SELECT s.store_id, s.store_name,
       COALESCE(SUM(sl.amount), 0) AS total_sales_amount,
       COUNT(sl.sale_id) AS transaction_count
FROM Stores s
LEFT JOIN Sales sl ON s.store_id = sl.store_id
GROUP BY s.store_id, s.store_name;

/*
===============================================================================
REINFORCEMENT R3 — EMPLOYEE CERTIFICATIONS / REFERENCE-TABLE VALIDATION
SCHEMA: Employees(employee_id,employee_name)
        Certifications(certification_id,certification_name)
        EmployeeCertifications(employee_id,certification_id,completion_date)
QUESTION: Every employee, COUNT DISTINCT officially valid certifications
completed, including employees with none, excluding invalid certification IDs.
No sample rows provided. Hypothetical example: C99 in EmployeeCertifications
but not Certifications should contribute ZERO to valid certificate count.
MY ORIGINAL JOIN FRAGMENT (verbatim):
from employees e left join employeecertifications ec on
e.employee_id=ec.employee_id
left join certifications c on
ec.certification_id=c.certification_id
group by employee_id , employee_name

MY FULL SQL (verbatim):
with
cte as (
Select e.employee_id , e.employee_name , count(distinct ec.certification_id) as completed_certificates
from employees e
left join employeecertification ec on
e.employee_id=ec.employee_id
left join certifications c on
ec.certification_id = c.certification_id
group by e.employee_id, e.employee_name
)
select e.employee_id , e.employee_name , coalesce(completed_certificates,0) as completed_certificates
from cte

DIAGNOSIS: JOINs, base preservation, GROUP BY correct. COUNT(DISTINCT
 ec.certification_id) includes invalid IDs such as C99; use COUNT(DISTINCT
 c.certification_id). Outer e alias out of scope; table spelled singular in
full attempt vs schema plural. COUNT returns 0 without COALESCE.
===============================================================================
*/
SELECT e.employee_id, e.employee_name,
       COUNT(DISTINCT c.certification_id) AS completed_certifications
FROM Employees e
LEFT JOIN EmployeeCertifications ec ON e.employee_id = ec.employee_id
LEFT JOIN Certifications c ON ec.certification_id = c.certification_id
GROUP BY e.employee_id, e.employee_name;

/*
===============================================================================
REINFORCEMENT R4 — STUDENTS WITH EXAM COUNTS
SCHEMA: Students(student_id,student_name)
        ExamResults(result_id,student_id,score)
Students: (1,Alice),(2,Bob),(3,Charlie),(4,David),(5,Emma)
Results: (101,1,85),(102,1,90),(103,2,75),(104,4,88)
REQUIREMENT: Every student, count of exam results, zero if none.
EXPECTED: (1,2),(2,1),(3,0),(4,1),(5,0).
MY ORIGINAL SQL (verbatim):
select s.student_id ,count(r.result_id) as exam_count  from examresults r
left join students s on
r.student_id=s.student_id
group by s.student_id
DIAGNOSIS: Verbal reasoning said 'students go LEFT', but SQL placed ExamResults
on left, losing 3 and 5. Correct count column and grouping.
===============================================================================
*/
SELECT s.student_id, COUNT(r.result_id) AS exam_count
FROM Students s
LEFT JOIN ExamResults r ON s.student_id = r.student_id
GROUP BY s.student_id
ORDER BY s.student_id;

/*
===============================================================================
REINFORCEMENT R5 — DEPARTMENTS AND EMPLOYEES (JOIN DIRECTION MICRO-CHECK)
SCHEMA: Department(department_id); Employee(employee_id,department_id)
QUESTION: Keep every department even if it has zero employees.
MY ORIGINAL CORRECT FRAGMENT (verbatim):
from department d left join employee e on d.department_id = e.department_id
DIAGNOSIS: Correct preservation-side choice after earlier reversals.
===============================================================================
*/
SELECT d.department_id, COUNT(e.employee_id) AS employee_count
FROM Department d
LEFT JOIN Employee e ON d.department_id = e.department_id
GROUP BY d.department_id;

/*
===============================================================================
REINFORCEMENT R6 — PRODUCTS AND RETURNS (CONCEPT CHECK)
SCHEMA: Products(product_id); Returns(return_id,product_id)
QUESTION: Every product, count returns; never-returned products appear as 0.
MY ANSWER: 'the return table goes into left and we use count(return_id)
and one row represents product and no of time it was returned'
DIAGNOSIS: Correct metric/final grain, reversed join direction.
===============================================================================
*/
SELECT p.product_id, COUNT(r.return_id) AS return_count
FROM Products p
LEFT JOIN Returns r ON p.product_id = r.product_id
GROUP BY p.product_id;

/*
===============================================================================
REINFORCEMENT R7 — APPROVED PRODUCTS (CONCEPT CHECK)
SCHEMA: Orders(order_id,customer_id,product_id)
        ApprovedProducts(product_id)
QUESTION: Count distinct APPROVED products ordered per customer; unapproved
products must not count. No example rows provided in original check.
MY ANSWER (verbatim):
b bcz this will give all approved product per customer  , if we use a option it will have count of unapproed product
DIAGNOSIS: Correct distinction: COUNT(DISTINCT ap.product_id), not o.product_id.
===============================================================================
*/
SELECT o.customer_id, COUNT(DISTINCT ap.product_id) AS approved_product_count
FROM Orders o
LEFT JOIN ApprovedProducts ap ON o.product_id = ap.product_id
GROUP BY o.customer_id;

/*
===============================================================================
REINFORCEMENT R8 — RIDE VS ATTEMPT GRAIN (LATER REVISIT; NO USER ATTEMPT)
SCHEMA: Rides(ride_id,driver_id); RideAttempts(attempt_id,ride_id,status)
DATA: (R1,A1,failed),(R1,A2,completed),(R1,A3,completed),
      (R2,A4,failed),(R3,A5,completed); all three rides belong to driver D1.
QUESTION: For D1 count DISTINCT rides, DISTINCT rides with >=1 completed
attempt, and failed ATTEMPT records.
EXPECTED: 3 total rides, 2 completed rides, 2 failed attempts.
PATTERN: COUNT(DISTINCT r.ride_id), COUNT(DISTINCT CASE WHEN status='completed'
THEN r.ride_id END), SUM(CASE WHEN status='failed' THEN 1 ELSE 0 END).
This question was offered at the end of Q5, but user did not answer it;
DO NOT count it as an independently passed problem.
===============================================================================
*/
SELECT r.driver_id,
       COUNT(DISTINCT r.ride_id) AS total_rides,
       COUNT(DISTINCT CASE WHEN a.status = 'completed'
                           THEN r.ride_id END) AS completed_rides,
       SUM(CASE WHEN a.status = 'failed' THEN 1 ELSE 0 END)
           AS failed_attempts
FROM Rides r
LEFT JOIN RideAttempts a ON r.ride_id = a.ride_id
GROUP BY r.driver_id;

/*
===============================================================================
DAY 2 RETROSPECTIVE / DELAYED CHECKLIST
[PASS] Q1 anti-join (minor redundant GROUP BY)
[PASS LOGIC AFTER RETRY] Q2 conditional customer metrics and full preservation
[IMPROVED, SQL NOT FIRST-TRY CLEAN] Q3 mandatory training/reference validation
[PASS LOGIC, ALIASES TO CHECK] Q4 subscriptions/payments join fanout
[PASS STRUCTURE, MISREAD DISTINCT QUALIFIER] Q5 hub final assessment
[REINFORCED] Warehouse base table reversal, missing GROUP BY
[REINFORCED] Student and product preservation side
[REINFORCED] Store NULL SUM vs zero
[REINFORCED] Reference table's COUNT(DISTINCT) vs event table's

DON'T MEMORIZE; PRACTISE EACH QUESTION COLD:
1. What exactly does the final row represent?
2. What population must appear regardless of a match?
3. What is being counted: event, distinct entity, or distinct qualified entity?
4. Does NULL after joining signify absent match? Which ID is safe to count?
5. Are SUM/COUNT outputs zero when required? Is division protected?
6. Have I typed CTE aliases and literal statuses exactly as defined?

STATUS: DAY 2 PROVISIONALLY COMPLETE; a new mixed unseen problem later should
verify retained ability without hints. This is a REVISION BANK, not proof that
all possible hard SQL patterns are mastered.
===============================================================================
*/
