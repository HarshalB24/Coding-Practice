# SQL Pattern Recognition & Revision Bank

> **Use this before every SQL question:**  
> **Output grain → What is being compared/calculated? → Compared against what? → Pattern → SQL**

---

## Core Pattern Bank

| # | Pattern | Trigger words / clues | What to use | Mistakes to avoid | Status |
|---|---|---|---|---|---|
| 1 | **First / Latest Row + Condition** | “first order was…”, “latest transaction is…” | `ROW_NUMBER()` per entity → `rn = 1` → apply condition | Applying condition across all rows before isolating target row | Practice |
| 2 | **Latest Value vs Full Latest Row** | “latest date” vs “latest order with amount/status” | Value only → `MIN/MAX`; full row → `ROW_NUMBER()` | Using `MAX(date)` when columns from the actual row are needed | Practice |
| 3 | **All Tied Earliest / Latest Rows** | “all rows on earliest/latest date”, “ties included” | `RANK()` / `DENSE_RANK()` | `ROW_NUMBER()` removes ties | Practice |
| 4 | **As-of-Date / Latest Valid Row** | “price/status/role as of date X” | `date <= target` → rank `DESC` → `rn=1` → preserve all entities → `COALESCE` | `date = target`; ascending order; putting ranked table on left; `rn=1` in `WHERE` after `LEFT JOIN` | 🔴 Revisit |
| 5 | **Pre-Aggregate → Rolling Window** | “7-day total”, “daily rolling avg”, many rows/day | First aggregate to required grain → then window | Running daily window directly on transaction rows | Practice |
| 6 | **Consecutive Calendar Dates** | “3 consecutive days”, “immediately next day” | `LAG(date)` + adjacent `DATEDIFF(...)=1` | Previous available row ≠ previous calendar day | ✅ Strong |
| 7 | **Consecutive Same Values** | “same value 3 times consecutively” | Order by sequence column → `LAG(value)` → equality checks | Ordering by value; using date-gap logic | ✅ Strong |
| 8 | **Has All Required Items** | “bought all products”, “completed all courses” | `GROUP BY entity HAVING COUNT(DISTINCT item)=total_required` | Forgetting `DISTINCT` | Practice |
| 9 | **Same Entity in Two Columns** | requester/accepter, caller/receiver, player1/player2 | `UNION ALL` roles → aggregate | Aggregating before stacking; using `UNION` and losing real duplicates | Practice |
| 10 | **Duplicate X + Unique (Y,Z)** | X repeated, but composite pair unique | Separate `GROUP BY ... HAVING` checks → filter original rows | Comparing wrong columns; `COUNT(y,z)` | Practice |
| 11 | **Top N Distinct Values per Group** | “top 3 salaries per department”, ties included | `DENSE_RANK() OVER(PARTITION BY group ORDER BY value DESC)` | `ROW_NUMBER()` when ties must qualify | ✅ Strong |
| 12 | **Nth Distinct Value vs Nth Event** | “2nd highest salary” vs “2nd order” | Distinct value → `DENSE_RANK`; event position → `ROW_NUMBER` | Mixing value rank with row/event position | Practice |
| 13 | **Running Total + Threshold** | cumulative weight/spend, capacity | `SUM(...) OVER(ORDER BY sequence)` → threshold → last valid row | `<` vs `<=`; wrong sequence | Practice |
| 14 | **Grouped Numerator + Global Denominator** | “% of all users per contest” | grouped numerator ÷ scalar global denominator | Computing global denominator inside grouped join | 🔴 Revisit |
| 15 | **Row vs Own-Group Aggregate** | salary > own dept avg, order > own customer avg | Window aggregate or correlated subquery | Comparing against global average instead of own group | ✅ Strong |
| 16 | **ANY / At Least One vs ALL** | “greater than at least one”, “greater than every/all” | `> at least one` → think `MIN`; `> all` → think `MAX` | Filtering outer rows to comparison group; comparing against own derived value | 🔴 Revisit |
| 17 | **Conditional Aggregation** | approved count/amount, category metrics | `SUM(CASE WHEN ... THEN ... ELSE ... END)` + correct `GROUP BY` | Wrong grain; unnecessary joins | Practice |
| 18 | **Group Filter After Aggregation** | “at least 5 students”, “more than 3 orders” | `GROUP BY ... HAVING aggregate_condition` | Putting aggregate condition in `WHERE` | Practice |
| 19 | **Global vs Group Aggregate** | company avg vs department avg | Global → scalar/window `OVER()`; group → `PARTITION BY` / correlated subquery | Using wrong comparison population | Practice |
| 20 | **Aggregate of Aggregates / Grain Transition** | “average customer total”, “average contest percentage” | First create **one row per group**, then aggregate those grouped metrics | Averaging raw rows when question asks for average of totals/percentages | 🔴 Revisit |
| 21 | **Target Rows → Aggregate Across Selected Set** | “average first-order amount”, “average latest-order amount” | Isolate first/latest rows → then `AVG(...) OVER()` or scalar aggregate | Calculating average before filtering to target rows | 🔴 Revisit |

---

# Today's Mistake Bank — What You Are Actually Doing Wrong

| Mistake | What you are doing | Why it is wrong | What to do instead | Clear example |
|---|---|---|---|---|
| **Losing the grain between steps** | You understand the requirement but calculate the next metric from raw rows | The second metric belongs to a different grain | Write the grain after every step | `raw payments → total/customer → avg(customer totals)` |
| **Global denominator becomes group-level** | You join `Users` and count inside each contest group | That count becomes registrations for that contest, not total users | Calculate the denominator separately | `COUNT(reg.user_id) / (SELECT COUNT(*) FROM Users)` |
| **Averaging the wrong thing** | You use `AVG(amount)` when asked for average customer total / average first order | Average raw row ≠ average grouped metric | Materialize grouped metric first, then average it | `SUM(amount) per customer → AVG(total_amount)` |
| **Filtering output population instead of comparison set** | You put `department_id=20` in outer query for “greater than every employee in dept 20” | Dept 20 defines who to compare against, not necessarily who can be returned | Put comparison-set filter inside subquery | `salary > (SELECT MAX(salary) ... WHERE department_id=20)` |
| **Correct pattern, wrong `LEFT JOIN` assembly** | You put filtered/ranked rows on the left or put `rn=1` in `WHERE` | Missing-history entities disappear | Put full entity population on left and `rn=1` in `ON` | `all_products p LEFT JOIN ranked r ON ... AND r.rn=1` |
| **Aggregate before isolating target rows** | You identify first/latest rows but average before actually filtering to them | Unwanted rows enter the average | Isolate `rn=1` rows first, then aggregate | `orders → rn=1 → avg(first_order_amount)` |
| **Jumping to a familiar SQL tool too early** | You see “consecutive” and immediately think `LAG + DATEDIFF`, or “latest” and jump to `MAX()` | Similar wording can require different logic | Identify the relationship first | same value → equality; consecutive dates → `DATEDIFF`; full latest row → `ROW_NUMBER()` |
| **Mixing value / row / tied-row requirements** | You pick `MAX`, `ROW_NUMBER`, or `DENSE_RANK` before deciding output need | These solve different problems | Ask whether you need one value, one full row, or all ties | value → `MAX`; one row → `ROW_NUMBER`; all ties → `DENSE_RANK` |

---

## Today's Biggest Weakness: Grain Transition / Aggregate of Aggregates

This is the most important issue from today's practice.

### Trigger phrases
- average of customer totals
- average of contest percentages
- average first-order amount
- average latest-order amount
- average department total

### What you must think

```text
raw rows
↓
build the required group/entity-level metric
↓
one row per entity/group
↓
calculate the next aggregate
↓
compare
```

### Example 1 — Average customer total

Requirement:

> Return customers whose 2026 total payment is greater than the average total payment across customers.

Wrong:

```sql
SUM(amount) AS total_amount,
AVG(amount) AS avg_amount
```

Why wrong:

`AVG(amount)` = average individual payment row.

But requirement asks:

`AVG(customer_total)`.

Correct structure:

```sql
WITH customer_totals AS (
    SELECT customer_id, SUM(amount) AS total_amount
    FROM Payments
    WHERE YEAR(payment_date) = 2026
    GROUP BY customer_id
),
x AS (
    SELECT
        customer_id,
        total_amount,
        AVG(total_amount) OVER () AS avg_customer_total
    FROM customer_totals
)
SELECT customer_id
FROM x
WHERE total_amount > avg_customer_total;
```

Memory rule:

> **If the question says average of totals, totals must exist first.**

---

### Example 2 — Average contest percentage

Requirement:

> Contest registration percentage > average registration percentage across contests.

Think:

```text
registrations
→ one percentage per contest
→ average those percentages
→ compare each contest percentage
```

Do NOT average raw registration rows.

---

### Example 3 — Average first-order amount

Requirement:

> Customer's first order amount > average first-order amount across all customers.

Think:

```text
all orders
→ rank per customer
→ keep rn=1
→ one first-order row/customer
→ average those amounts
→ compare
```

Do NOT calculate `AVG(amount)` before `rn=1` is applied.

---

## Global Denominator vs Grouped Numerator

Trigger:

> percentage/share of **all users/customers** per group.

Think:

```text
numerator = changes per group
denominator = same global total for every group
```

Correct:

```sql
SELECT
    contest_id,
    COUNT(user_id) * 100.0 /
    (SELECT COUNT(*) FROM Users) AS percentage
FROM Register
GROUP BY contest_id;
```

Your recurring mistake:

```text
JOIN Users
→ GROUP BY contest
→ COUNT(users)
```

That count is no longer the true global denominator.

Memory rule:

> **If denominator should be identical for every group, calculate it globally.**

---

## Output Population vs Comparison Population

Always ask these separately:

1. **Who can appear in the output?**
2. **Who are they being compared against?**

Example:

> Employees whose salary is greater than every employee in department 20.

```text
Output candidates = all employees
Comparison population = department 20
```

Correct:

```sql
SELECT employee_id
FROM EmployeeSalary
WHERE salary > (
    SELECT MAX(salary)
    FROM EmployeeSalary
    WHERE department_id = 20
);
```

Do not put `department_id = 20` in the outer query unless the requirement specifically says the returned employees must also belong to department 20.

---

## As-of-Date Pattern — SQL Assembly Checklist

You are recognizing this pattern now, but the implementation is still not automatic.

Correct flow:

```text
all entities
+
historical rows where date <= target
→ rank valid history DESC
→ rn=1
→ LEFT JOIN from all entities
→ COALESCE default
```

Template:

```sql
WITH ranked AS (
    SELECT
        entity_id,
        value,
        ROW_NUMBER() OVER (
            PARTITION BY entity_id
            ORDER BY effective_date DESC
        ) AS rn
    FROM History
    WHERE effective_date <= 'TARGET_DATE'
),
all_entities AS (
    SELECT DISTINCT entity_id
    FROM History
)
SELECT
    e.entity_id,
    COALESCE(r.value, default_value) AS value
FROM all_entities e
LEFT JOIN ranked r
    ON e.entity_id = r.entity_id
   AND r.rn = 1;
```

Actively avoid:
- `effective_date = target`
- `ORDER BY effective_date ASC`
- ranked table on left side
- `WHERE rn = 1` after the `LEFT JOIN`
- forgetting `COALESCE`

---

## Quick Pattern Distinctions

| Requirement | Think |
|---|---|
| Only earliest/latest **value** | `MIN()` / `MAX()` |
| One complete earliest/latest **row** | `ROW_NUMBER()` |
| All tied earliest/latest rows | `RANK()` / `DENSE_RANK()` |
| Nth distinct value | `DENSE_RANK()` |
| Nth event/row | `ROW_NUMBER()` |
| Previous available row | `LAG()` |
| Previous calendar day | `LAG()` + `DATEDIFF = 1` |
| Same value repeated consecutively | `LAG(value)` + equality |
| Row > own group's avg | Window aggregate / correlated subquery |
| Group count ÷ entire population | Grouped numerator + scalar denominator |
| Average of customer totals | Customer totals first → average totals second |
| Average of first/latest rows | Isolate target rows first → average second |
| Greater than at least one | Think `MIN` |
| Greater than all/every | Think `MAX` |
| Entity appears in two columns | `UNION ALL` → aggregate |
| Must contain every required item | `COUNT(DISTINCT item)=total required` |
| Rolling metric from detailed rows | Fix grain first → window second |
| Historical value “as of” date | `<= target` → latest valid row |

---

## Mandatory Pre-SQL Checklist

| Step | Question |
|---|---|
| 1 | **What is the final output grain?** |
| 2 | **What exact value/metric am I calculating?** |
| 3 | **Compared against what: same row, previous row, own group, another set, or whole population?** |
| 4 | **Does the question require an intermediate grain first?** |
| 5 | **Am I averaging raw rows or an already-grouped metric?** |
| 6 | **Do I need one value, one full row, or all tied rows?** |
| 7 | **Only now: which SQL pattern/function fits?** |

---

## 5-Second Grain Check

Before coding, say the transformation out loud.

```text
Payments
→ total per customer
→ average customer total
→ qualifying customers
```

```text
Orders
→ first order per customer
→ average first-order amount
→ qualifying customers
```

```text
Registrations
→ percentage per contest
→ average contest percentage
→ qualifying contests
```

If you cannot clearly state the intermediate grain, **do not start writing SQL yet**.

---

# Master Rule

> **Do not choose the SQL function first. Identify the data grain and comparison relationship first.**
