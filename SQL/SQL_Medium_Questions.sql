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
