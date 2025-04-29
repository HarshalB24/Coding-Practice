/*
===============================================
SQL Problem:  Income Tax Returns
===============================================

-- File:        late_or_missed_returns.sql
-- Description: Identify users who either filed their income tax returns late 
--              or completely skipped filing for certain financial years.
-- 
-- Definitions:
--   - A return is considered **late** if return_file_date > file_due_date
--   - A return is considered **missed** if there is no return entry for a user 
--     for a given financial year.
-- 
-- Output: List of users with financial year and a comment indicating 
--         'late return' or 'missed'
-- 
-- Sorting: Ascending order of financial year
-- ============================================================================

-- Table: income_tax_dates
-- +-----------------+------------+
-- | COLUMN_NAME     | DATA_TYPE  |
-- +-----------------+------------+
-- | financial_year  | varchar(4) |
-- | file_start_date | date       |
-- | file_due_date   | date       |
-- +-----------------+------------+

-- Table: users
-- +------------------+------------+
-- | COLUMN_NAME      | DATA_TYPE  |
-- +------------------+------------+
-- | user_id          | int        |
-- | financial_year   | varchar(4) |
-- | return_file_date | date       |
-- +------------------+------------+

*/


WITH all_user_years AS (
    -- Step 1: Create a combination of each user and all financial years
    SELECT 
        u.user_id, 
        i.financial_year, 
        i.file_due_date
    FROM 
        (SELECT DISTINCT user_id FROM users) u
    CROSS JOIN 
        income_tax_dates i
),
user_returns AS (
    -- Step 2: Join the user return data (if any) with user-financial year pairs
    SELECT 
        a.user_id,
        a.financial_year,
        u.return_file_date,
        a.file_due_date
    FROM 
        all_user_years a
    LEFT JOIN 
        users u 
        ON a.user_id = u.user_id AND a.financial_year = u.financial_year
)
-- Step 3: Identify late returns and missed filings
SELECT 
    user_id,
    financial_year,
    CASE 
        WHEN return_file_date IS NULL THEN 'missed'
        WHEN return_file_date > file_due_date THEN 'late return'
    END AS comment
FROM 
    user_returns
WHERE 
    return_file_date IS NULL 
    OR return_file_date > file_due_date
ORDER BY 
    financial_year ASC;

----
-- Second Method
--for each user we have to find whether they have filed the return late or did not file it at all...
--the challenge is if we do inner join on both tables then we dont have data in users table for user 1 and so we will miss that.
--so we need to get the combination of all user id and financial year first ....

with cte as (
select u.user_id,itd.financial_year,file_due_date from users u
cross join income_tax_dates itd 
group by u.user_id,itd.financial_year,file_due_date
  )
select cte.user_id,cte.financial_year,
case when 
users.return_file_date is null then 'missed'
else 
'late return'
end as comment
from cte
left join users on cte.user_id=users.user_id 
and cte.financial_year=users.financial_year
where users.return_file_date is null 
or return_file_date > file_due_date
order by cte.financial_year

/*
===============================================
SQL Problem:   Software vs Data Analytics Engineers
===============================================
-- File:        employee_role_counts.sql
-- Description: Retrieve counts of Software Engineers, Data Professionals, 
--              and Managers from the Employees table.
--
-- Role Identification Rules:
--   1. Software Engineers   : JobTitle starts with "Software"
--   2. Data Professionals   : JobTitle starts with "Data"
--   3. Managers             : JobTitle contains "Manager"
--
-- Output: One row with 3 columns: software_engineers, data_professionals, managers
-- ============================================================================

-- Table: Employees
-- +-------------+-------------+
-- | COLUMN_NAME | DATA_TYPE   |
-- +-------------+-------------+
-- | EmployeeID  | int         |
-- | Name        | varchar(20) |
-- | JoinDate    | date        |
-- | JobTitle    | varchar(20) |
-- +-------------+-------------+

*/

SELECT
    COUNT(CASE WHEN JobTitle LIKE 'Software%' THEN 1 END) AS software_engineers,
    COUNT(CASE WHEN JobTitle LIKE 'Data%' THEN 1 END) AS data_professionals,
    COUNT(CASE WHEN JobTitle LIKE '%Manager%' THEN 1 END) AS managers
FROM 
    Employees;


-- Second Method of first creating the job groups and then counting it and pivoting them into columns
--Step 1 : create Job bins

with Job_bins as (   --Step 1 : create Job bins
select * , case when jobtitle like 'Software%' then 'Software_Engineers'
when jobtitle like 'Data%' then 'Data Professionals'
when jobtitle like '%Manager%' then 'Managers'
end as Job_titles
from employees 
),
employee_count as (  -- step 2 get the count per title
    select job_titles,count(*) as cnt
    from job_bins
    group by job_titles
)
select  -- step 3 pivot the titles into columns
sum(case when job_titles='Software_Engineers' then cnt end ) as Software_Engineers,
sum(case when job_titles='Data Professionals' then cnt end ) as Data_Professionals,
sum(case when job_titles='Managers' then cnt end ) as Managers
from employee_count;

/*
===============================================
SQL Problem:    Highly Paid Employees
===============================================

-- File:        employees_above_adjusted_avg.sql
-- Description: Retrieve a list of employees whose salary is greater than the
--              company average salary, excluding the salaries from their own
--              department in the average calculation.
--
-- Table: employee
-- +-------------+-------------+
-- | COLUMN_NAME | DATA_TYPE   |
-- +-------------+-------------+
-- | emp_id      | int         |
-- | salary      | int         |
-- | department  | varchar(15) |
-- +-------------+-------------+
--
-- Output: emp_id, salary, department
-- Sort: Ascending order by emp_id
-- ============================================================================
*/
SELECT 
    e1.emp_id,
    e1.salary,
    e1.department
FROM 
    employee e1
WHERE 
    e1.salary > (
        SELECT 
            AVG(e2.salary)
        FROM 
            employee e2
        WHERE 
            e2.department <> e1.department
    )

/*
===============================================
SQL Problem:    Warikoo 20-6-20
===============================================

-- File:        affordable_phones_by_user.sql
-- Description: List phones each user can afford based on the 20-6-20 rule:
--              1. User must have enough savings for a 20% down payment.
--              2. Remaining cost (80%) to be paid in no-cost 6-month EMI.
--              3. EMI should not exceed 20% of the user's monthly salary.
--
-- Tables:
-- users
-- +----------------+-------------+
-- | COLUMN_NAME    | DATA_TYPE   |
-- +----------------+-------------+
-- | user_name      | varchar(10) |
-- | monthly_salary | int         |
-- | savings        | int         |
-- +----------------+-------------+
--
-- phones
-- +-------------+-------------+
-- | COLUMN_NAME | DATA_TYPE   |
-- +-------------+-------------+
-- | cost        | int         |
-- | phone_name  | varchar(15) |
-- +-------------+-------------+
--
-- Output: user_name, phones (comma-separated list of phone_name)
-- Sorted by: user_name (ascending)
-- ============================================================================
*/

select user_name,group_concat(phone_name) as phones
from users cross join phones
where savings >= cost*0.2 and monthly_salary*0.2 >=cost*0.8/6
group by user_name
order by user_name

/*
===============================================
SQL Problem:    Average Order Value
===============================================

## 📝 Problem Statement

Write an SQL query to determine **the transaction date with the lowest average order value (AOV)** among all dates recorded in the `transactions` table.

Display:
- The `transaction_date`
- The corresponding **AOV** (rounded to 2 decimal places)
- The **difference** between the AOV for that date and the **highest AOV** for any day in the dataset (rounded to 2 decimal places)

---

## 📚 Table: `transactions`

| COLUMN_NAME         | DATA_TYPE     |
|---------------------|---------------|
| order_id            | int           |
| transaction_amount  | decimal(5,2)  |
| transaction_date    | date          |
| user_id             | int           |

---

## 🎯 Requirements
- Find the **date** with the **lowest AOV**.
- Find the **highest AOV** across all dates.
- Show both the **lowest AOV** and the **difference** between the **lowest AOV** and the **highest AOV**.
- Round all decimal outputs to **2 decimal places**.

---
*/

---Solution:

with minimum_value  as (
select transaction_date,round(avg(transaction_amount),2) as minimum_aov from transactions 
group by transaction_date
order by round(avg(transaction_amount),2) asc
limit 1),
maximum_value as (
select transaction_date,round(avg(transaction_amount),2) as highest_aov from transactions 
group by transaction_date
order by round(avg(transaction_amount),2) desc
limit 1)
select min_value.transaction_date,min_value.minimum_aov,(highest_aov-minimum_aov) as diff from minimum_value min_value
cross join
maximum_value maximum_val

----Alternate :
with cte as (
select transaction_date, avg(transaction_amount) as aov
 from transactions
 group by transaction_date
)
, cte1 as (
select *
,row_number() over(order by aov) as rn
,max(aov) over() as highest_aov
from cte 
)
select transaction_date,round(aov,2) as aov,round(highest_aov-aov,2) as diff_from_highest_aov
from cte1
where rn=1;



/*
===============================================
SQL Problem: Employee vs Manager Salary and Joining Date Challenge

===============================================

## 📝 Problem Statement

You are given a table containing **employee details**.

Write an SQL query to find **details of employees** who:
- Have a **salary greater** than their **manager's salary**, and
- **Joined the company after** their **manager**.

### Output Columns:
- `emp_name`
- `salary`
- `joining_date`
- `manager_salary`
- `manager_joining_date`

Sort the output by **employee name** in ascending order.

> 📢 **Note**:  
> The `manager_id` in the `employee` table refers to the `emp_id` from the same table (self-reference).

---

## 📚 Table: `employee`

| COLUMN_NAME  | DATA_TYPE    |
|--------------|--------------|
| emp_id       | int          |
| emp_name     | varchar(10)  |
| joining_date | date         |
| salary       | int          |
| manager_id   | int          |


## 📤 Expected Output

| emp_name | salary | joining_date | manager_salary | manager_joining_date |
|----------|--------|--------------|----------------|----------------------|
| Charlie  | 80000  | 2022-05-20    | 70000          | 2022-01-10           |


*/
Solution :
select e.emp_name,e.salary,e.joining_date,m.salary,m.joining_date from employee e 
inner join employee m on m.emp_id=e.manager_id
where e.salary > m.salary and e.joining_date > m.joining_date
order by e.emp_name


/*
===============================================
SQL Problem: Cancellation vs Return

===============================================
An order is considered cancelled if it is cancelled before delivery (i.e., cancel_date is not null, and delivery_date is null). If an order is cancelled, no delivery will take place.
An order is considered a return if it is cancelled after it has already been delivered (i.e., cancel_date is not null, and cancel_date > delivery_date).

Metrics to Calculate:
Cancel Rate = (Number of orders cancelled / Number of orders placed but not returned) * 100
Return Rate = (Number of orders returned / Number of orders placed but not cancelled) * 100

Write an SQL query to calculate the cancellation rate and return rate for each month (based on the order_date).Round the rates to 2 decimal places. Sort the output by year and month in increasing order.
 

Table: orders 
+---------------+-----------+
| COLUMN_NAME   | DATA_TYPE |
+---------------+-----------+
| order_id      | int       |
| order_date    | date      |
| customer_id   | int       |
| delivery_date | date      |
| cancel_date   | date      |
+---------------+-----------+
*/

with cte as (
  select * ,
case when delivery_Date is not null and cancel_date is not null then 1 else 0 end as return_flag,
case when delivery_date is null and cancel_date is not null then 1 else 0 end as cancel_flag
from orders
)
select year(order_Date) as order_year,month(order_date) as order_month
,round(sum(cancel_flag)*100 / (count(*) - sum(return_flag)),2) as cancel_Rate
,round(sum(return_flag)*100 / (count(*) - sum(cancel_flag)),2) as return_rate
from cte
group by 
year(order_Date) ,month(order_date) 



