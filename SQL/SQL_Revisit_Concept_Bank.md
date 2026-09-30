# SQL Revisit Concept Bank

Use this before fresh SQL practice.

The goal is not just to remember syntax. The goal is to identify:

> **Output grain → What is being compared? → Relationship → Pattern → SQL**

---

## 1. First / Latest Row + Condition

**Trigger words**
- first order was...
- latest transaction is...
- first login...
- latest status...

**Use**
- `ROW_NUMBER()` per entity
- filter `rn = 1`
- then apply the condition

**Avoid**
- aggregating all rows before isolating the first/latest row

**Memory rule**

> Condition applies to first/latest row → isolate that row first → then filter.

---

## 2. Full Latest Row vs Latest Value Only

**Trigger words**
- latest order date
- latest order with amount/status/etc.

**Use**
- only latest value needed → `MAX()`
- full latest row needed → `ROW_NUMBER()`

**Avoid**
- `GROUP BY + MAX()` when you need columns from the actual latest row

**Memory rule**

> Value only = aggregate. Full row = window.

---

## 3. All Tied Earliest / Latest Rows

**Trigger words**
- all rows on earliest date
- all rows on latest date
- ties must be included

**Use**
- `DENSE_RANK()` or `RANK()`

**Avoid**
- `ROW_NUMBER()` if tied rows must all be returned

**Memory rule**

> Need all tied rows → `RANK()` / `DENSE_RANK()`.

---

## 4. As-of-Date / Latest Valid Historical Row

**Trigger words**
- price as of date
- status as of date
- role as of date
- latest valid record before/on a date

**Use**
1. filter `date <= target_date`
2. rank latest row per entity with `ORDER BY date DESC`
3. keep `rn = 1`
4. left join back to all entities
5. use `COALESCE` for the default if missing

**Avoid**
- using `date = target_date`
- forgetting entities with no valid earlier record
- putting the filtered/ranked table on the left side of the `LEFT JOIN`

**Memory rule**

> As-of date = `date <= target` → latest valid row → default if none.

---

## 5. Pre-Aggregate → Rolling Window

**Trigger words**
- 7-day total
- rolling average
- daily rolling revenue
- raw table has many rows per day

**Use**
1. aggregate raw rows to the required grain first
2. then apply the rolling/window calculation

Example:

> transactions → daily total → 7-day rolling total

**Avoid**
- applying the rolling window directly on transaction-level rows when the requirement is daily-level

**Memory rule**

> First fix the grain, then apply the window.

---

## 6. Consecutive Calendar Dates

**Trigger words**
- 3 consecutive days
- next calendar day
- logged in on consecutive dates

**Use**
- `LAG(date)`
- exact `DATEDIFF(...)=1`

For 3 consecutive dates:

```sql
DATEDIFF(current_date, lag_1) = 1
AND DATEDIFF(lag_1, lag_2) = 1
```

**Avoid**
- assuming previous available row means previous calendar day

**Memory rule**

> N consecutive dates → N-1 adjacent gaps, each equal to 1.

---

## 7. Consecutive Same Values in Ordered Rows

**Trigger words**
- same number appears 3 times consecutively
- same status appears in consecutive readings
- repeated value in consecutive rows

**Use**
- order by the true sequence column
- compare the repeated values directly

Example:

```sql
num = lag_1
AND lag_1 = lag_2
```

**Avoid**
- using date-gap logic
- ordering by the value itself

**Memory rule**

> Consecutive rows → order by sequence column → compare values for equality.

---

## 8. Has All Required Items

**Trigger words**
- bought all products
- completed all required courses
- has every required item

**Use**

```sql
GROUP BY entity
HAVING COUNT(DISTINCT item) = total_required_items
```

**Avoid**
- forgetting `DISTINCT` when duplicate item rows may exist

**Memory rule**

> All required items → distinct owned count = total required count.

---

## 9. Same Entity Can Appear in Two Columns

**Trigger words**
- requester / accepter
- caller / receiver
- player1 / player2

**Use**
1. stack both sides with `UNION ALL`
2. aggregate after stacking

**Avoid**
- aggregating before the `UNION ALL`
- using `UNION` when duplicate events are real and must be preserved

**Memory rule**

> Stack both roles first → aggregate second.

---

## 10. Duplicate One Attribute + Unique Composite

**Trigger words**
- X appears more than once
- but `(Y, Z)` appears exactly once

**Use**
- separate grouped subqueries with `HAVING`
- then filter original rows using both conditions

**Avoid**
- comparing the wrong outer column to the subquery
- `COUNT(y, z)` syntax

**Memory rule**

> Check each frequency rule separately, then apply both to original rows.

---

## 11. Top N Distinct Values Within a Group

**Trigger words**
- top 3 salaries per department
- top N distinct values
- ties included

**Use**

```sql
DENSE_RANK() OVER (
    PARTITION BY group_col
    ORDER BY value DESC
)
```

**Avoid**
- `ROW_NUMBER()` when tied values must all qualify

**Memory rule**

> Top N distinct values within a group → `DENSE_RANK()`.

---

## 12. Running Total + Threshold

**Trigger words**
- cumulative weight
- cumulative spend
- last row before a threshold
- capacity limit

**Use**
- `SUM(...) OVER(ORDER BY sequence)`
- filter by threshold
- take the last valid row

**Avoid**
- `<` when the condition allows equality
- ordering by something other than the true sequence

**Memory rule**

> Running total + threshold → cumulative `SUM()` → last valid row.

---

## 13. Grouped Numerator + Global Denominator

**Trigger words**
- percentage of all users per contest
- share of total population
- group count divided by overall count

**Use**
- grouped aggregate for numerator
- scalar global total for denominator

Example:

```sql
COUNT(user_id) * 100.0 / (SELECT COUNT(*) FROM Users)
```

**Avoid**
- calculating a supposed global denominator inside the grouped query/join

**Memory rule**

> Numerator changes by group. Denominator stays global.

---

## 14. Row vs Own-Group Aggregate

**Trigger words**
- salary greater than department average
- order amount greater than customer average
- value compared with own group's average

**Use**
- window aggregate, e.g. `AVG(...) OVER(PARTITION BY group)`
- or correlated subquery

**Avoid**
- accidentally comparing against the global/company-wide average

**Memory rule**

> Row vs own group → preserve row + attach group aggregate.

---

## 15. ANY / At Least One vs ALL

**Trigger words**
- greater than any employee
- greater than at least one
- greater than all employees

**Use**
- `> ANY` / greater than at least one → effectively compare against the **minimum**
- `> ALL` → compare against the **maximum**

**Avoid**
- comparing each row against its own derived aggregate
- missing that the comparison is against a population/set

**Memory rule**

> Greater than ANY → think MIN.  
> Greater than ALL → think MAX.

---

## 16. Conditional Aggregation

**Trigger words**
- approved count
- approved amount
- category-wise totals in one output
- count only rows matching a condition

**Use**

```sql
SUM(CASE WHEN condition THEN 1 ELSE 0 END)
```

or

```sql
SUM(CASE WHEN condition THEN amount ELSE 0 END)
```

**Avoid**
- unnecessary joins
- wrong output grain
- forgetting the main `GROUP BY`

**Memory rule**

> Group once, calculate multiple conditional metrics with `CASE`.

---

# Highest-Priority Revisit Bank

These are the patterns to deliberately re-test first:

1. **As-of-date / latest valid row**
2. **ANY vs ALL / population comparison**
3. **Grouped numerator + global denominator**
4. **Full row vs aggregate value**
5. **Consecutive calendar dates vs consecutive same values**

---

# Common Mistakes to Avoid

- Choosing a familiar SQL function before understanding the requirement
- Wrong output grain
- Comparing to the wrong population
- Forgetting `DISTINCT`
- Confusing previous row with previous calendar day
- Confusing one row with all tied rows
- Calculating a global metric inside a grouped query
- Forgetting `GROUP BY` after stacking rows
- Selecting the wrong side of a `LEFT JOIN`
- Not carrying required columns through a CTE
- Using the wrong join key / column
- Mixing row-level and aggregate-level logic

---

# Mandatory Pre-SQL Checklist

Before writing SQL, answer these:

1. **What is the output grain?**
2. **What exactly is being compared or calculated?**
3. **Is the comparison against:**
   - the same row?
   - previous row?
   - previous calendar day?
   - own group?
   - another set?
   - the whole population?
4. **Do I need one row, one value, or all tied rows?**
5. **Only then choose the SQL pattern.**

---

# One-Line Master Rule

> **Understand the relationship first. Choose the SQL function second.**
