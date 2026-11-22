# Week 1 – SQL Foundations

## Concepts Covered

- Logical Query Execution Order
- WHERE vs HAVING
- COUNT()
- GROUP BY
- HAVING
- CASE
- NULL Handling
- Output Grain
- Aggregate Functions
- Conditional Aggregation
- SQL Debugging
- Query Simplicity

---

## Reference Queries

### Basic Filtering

```sql
SELECT order_id,
       customer_id,
       amount
FROM orders
WHERE status = 'COMPLETED'
  AND amount > 1000
ORDER BY amount DESC;
```

### Aggregation

```sql
SELECT customer_id,
       COUNT(*) AS total_orders,
       SUM(amount) AS total_spend
FROM orders
WHERE status = 'COMPLETED'
GROUP BY customer_id
HAVING COUNT(*) >= 3;
```

### CASE

```sql
SELECT order_id,
       amount,
       CASE
           WHEN amount >= 5000 THEN 'High'
           WHEN amount >= 1000 THEN 'Medium'
           ELSE 'Low'
       END AS order_category
FROM orders;
```

### NULL Handling

```sql
SELECT customer_id,
       customer_name,
       COALESCE(city,'Unknown') AS city
FROM customers;
```

### Conditional Aggregation

```sql
SELECT customer_id,
       SUM(CASE WHEN status='COMPLETED' THEN 1 ELSE 0 END) AS completed_orders,
       SUM(CASE WHEN status='CANCELLED' THEN 1 ELSE 0 END) AS cancelled_orders
FROM orders
GROUP BY customer_id;
```

---

# Mistakes Identified (Rounds 1 & 2)

### ❌ NULL Semantics

Mistakes:

- Compared NULL using `=` / `<>`
- Expected NULL rows in comparison results
- Used `'Null'` instead of SQL `NULL`

Revision:

- Use `IS NULL`
- Use `IS NOT NULL`
- Use `COALESCE()`
- `NULL = NULL` is **not TRUE**

---

### ❌ WHERE vs HAVING

Mistakes:

```sql
WHERE SUM(...)
```

```sql
WHERE COUNT(...)
```

Revision:

- `WHERE` → filters rows
- `HAVING` → filters groups

---

### ❌ Conditional Aggregation

Mistake:

```sql
COUNT(CASE ... ELSE 0 END)
```

Revision:

```sql
SUM(CASE ... THEN 1 ELSE 0 END)
```

or

```sql
COUNT(CASE WHEN ... THEN 1 END)
```

---

### ❌ Query Minimalism

Recurring mistakes:

- Unnecessary joins
- Unnecessary `GROUP BY`
- Aggregating when not required

Revision:

> Ask: **"What is the simplest query that satisfies the requirement?"**

---

### ⚠️ Output Grain

Always state before writing SQL:

> **One row per ________.**

---

## Quick Revision

### Logical Order

```text
FROM
→ WHERE
→ GROUP BY
→ HAVING
→ SELECT
→ ORDER BY
```

### COUNT()

| Function | Counts |
|----------|--------|
| COUNT(*) | All rows |
| COUNT(column) | Non-NULL values |
| COUNT(DISTINCT column) | Unique non-NULL values |

### Remember

- `WHERE` filters rows
- `HAVING` filters groups
- `CASE` executes top-down
- `COUNT(column)` ignores NULL
- Aggregate functions belong in `HAVING`
- Always identify the output grain before writing SQL