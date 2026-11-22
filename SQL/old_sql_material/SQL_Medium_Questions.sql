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


/*
===============================================
SQL Problem: Return Orders Customer Feedback
===============================================
Namastekart, an e-commerce company, has observed a notable surge in return orders recently. They suspect that a specific group of customers may be responsible for a significant portion of these returns. To address this issue, their initial goal is to identify customers who have returned more than 50% of their orders. This way, they can proactively reach out to these customers to gather feedback.

Write an SQL to find list of customers along with their return percent (Round to 2 decimal places), display the output in ascending order of customer name.

Table: orders (primary key : order_id)
+---------------+-------------+
| COLUMN_NAME   | DATA_TYPE   |
+---------------+-------------+
| customer_name | varchar(10) |
| order_date    | date        |
| order_id      | int         |
| sales         | int         |
+---------------+-------------+

Table: returns (primary key : order_id)
+-------------+-----------+
| COLUMN_NAME | DATA_TYPE |
+-------------+-----------+
| order_id    | int       |
| return_date | date      |
+-------------+-----------+
*/
Solution:

select customer_name,round(count(r.order_id)*100/count(*),2) as return_count from orders o
left join returns r on 
o.order_id=r.order_id
group by customer_name
having count(r.order_id) > count(*) * 0.5
order by customer_name

/*
===============================================
SQL Problem: LinkedIn Top Voice
===============================================
LinkedIn is a professional social networking app. They want to give top voice badge to their best creators to encourage them to create more quality content. A creator qualifies for the badge if he/she satisfies following criteria.

 

1- Creator should have more than 50k followers.
2- Creator should have more than 100k impressions on the posts that they published in the month of Dec-2023.
3- Creator should have published atleast 3 posts in Dec-2023.

 

Write a SQL to get the list of top voice creators name along with no of posts and impressions by them in the month of Dec-2023.

 

Table: creators(primary key : creator_id)
+--------------+-------------+
| COLUMN_NAME  | DATA_TYPE   |
+--------------+-------------+
| creator_id   | int         |
| creator_name | varchar(20) |
| followers    | int         |
+--------------+-------------+
Table: posts(primary key : post_id)
+--------------+------------+
| COLUMN_NAME  | DATA_TYPE  |
+--------------+------------+
| creator_id   | int        |
| post_id      | varchar(3) |
| publish_date | date       |
| impressions  | int        |
+--------------+------------+

*/
sOLUTION :
select c.creator_name,count(post_id) as no_posts,sum(impressions) as total_impressions
from creators c
inner join posts p on 
c.creator_id=p.creator_id
where month(publish_date)=12 and followers > 50000
group by c.creator_name
having no_posts >=3 and total_impressions > 100000



/*
===============================================
SQL Problem: Premium Customers
===============================================
An e-commerce company want to start special reward program for their premium customers.  The customers who have placed a greater number of orders than the average number of orders placed by customers are considered as premium customers.

Write an SQL to find the list of premium customers along with the number of orders placed by each of them, display the results in highest to lowest no of orders.

Table: orders (primary key : order_id)
+---------------+-------------+
| COLUMN_NAME   | DATA_TYPE   |
+---------------+-------------+
| order_id      | int         |
| order_date    | date        |
| customer_name | varchar(20) |
| sales         | int         |
+---------------+-------------+
*/

Solution:
select customer_name,count(*) as total_orders
from orders
group by customer_name
having count(*) > (select count(*)/count(distinct customer_name) as avg_orders from orders)
order by total_orders desc

/*
===============================================
SQL Problem: AirBnB Top Listings
===============================================
Suppose you are a data analyst working for a travel company that offers vacation rentals similar to Airbnb. Your company wants to identify the top hosts with the highest average ratings for their listings. This information will be used to recognize exceptional hosts and potentially offer them incentives to continue providing outstanding service.

 

Your task is to write an SQL query to find the top 2 hosts with the highest average ratings for their listings. However, you should only consider hosts who have at least 2 listings, as hosts with fewer listings may not be representative.

Display output in descending order of average ratings and round the average ratings to 2 decimal places.

 

Table: listings
+----------------+---------------+
| COLUMN_NAME    | DATA_TYPE     |
+----------------+---------------+
| host_id        | int           |
| listing_id     | int           |
| minimum_nights | int           |
| neighborhood   | varchar(20)   |
| price          | decimal(10,2) |
| room_type      | varchar(20)   |
+----------------+---------------+
*/

Solution:
with cte as (
select host_id,listing_id , count(*) over (partition by host_id) as no_of_listing from listings  --we do partition by to keep both listing id and count of listing id
)  -- if we do this without partition by then the anser will be wrong
select cte.host_id,no_of_listing,round(avg(r.rating),2) as avg_ratings from cte 
inner join reviews r on 
r.listing_id=cte.listing_id
where no_of_listing >=2
group by cte.host_id,cte.no_of_listing
order by avg_ratings desc
limit 2


/*
===============================================
SQL Problem: Best Employee Award
===============================================
TCS wants to award employees based on number of projects completed by each individual each month.  Write an SQL to find best employee for each month along with number of projects completed by him/her in that month, display the output in descending order of number of completed projects.

Table: projects
+-------------------------+-------------+
| COLUMN_NAME             | DATA_TYPE   |
+-------------------------+-------------+
| project_id              | int         |
| employee_name           | varchar(10) |
| project_completion_date | date        |
+-------------------------+-------------+
*/

Solution:

with cte as (select employee_name,date_format(project_completion_Date,'%Y%m') AS yearmonth ,count(*) as no_of_projects from projects 
group by employee_name,date_format(project_completion_Date,'%Y%m') 
)
select employee_name,no_of_projects,yearmonth from (
select *
, row_number () over (partition by yearmonth order by no_of_projects desc ) as rn from cte ) A
where rn=1
order by no_of_projects desc

====
Alternate :
with cte_projects_completed as (
select employee_name, DATE_FORMAT(project_completion_date,'%Y%m') as year_month_combo,
count(project_completion_date) as no_of_completed_projects
from projects
where project_completion_date is not null
group by employee_name,DATE_FORMAT(project_completion_date,'%Y%m') )
select employee_name,no_of_completed_projects,year_month_combo as yearmonth from (
select employee_name,year_month_combo,no_of_completed_projects, rank() over(partition by year_month_combo order by no_of_completed_projects desc) as rn
from cte_projects_completed) a
where rn=1
ORDER BY no_of_completed_projects DESC;


/*
===============================================
SQL Problem: Workaholics Employees -- HARD 
===============================================
Write a query to find workaholics employees.  Workaholics employees are those who satisfy at least one of the given criterions:

 

1- Worked for more than 8 hours a day for at least 3 days in a week. 
2- worked for more than 10 hours a day for at least 2 days in a week. 
You are given the login and logout timings of all the employees for a given week. Write a SQL to find all the workaholic employees along with the criterion that they are satisfying (1,2 or both), display it in the order of increasing employee id

 

Table: employees
+-------------+-----------+
| COLUMN_NAME | DATA_TYPE |
+-------------+-----------+
| emp_id      | int       |
| login       | datetime  |
| logout      | datetime  |
+-------------+-----------+
*/

Solution :
with cte as (
select emp_id,count(*) as days_8
, count(case when datediff(minute,login,logout)/60.0 > 10 then 1 end )as days_10 
from employees
where datediff(minute,login,logout)/60.0 > 8
group by emp_id
 )
 select emp_id,
 case when days_8 >=3 and days_10 >=2 then 'both'
 when days_10>=2 then '2'
 else '1' end as criteria
 from cte 

ALTERNATE :
=====================

with logged_hours as (
select *,TIMESTAMPDIFF(second, login, logout)/3600.0,case when TIMESTAMPDIFF(second, login, logout) / 3600.0  > 10 then '10+'
when TIMESTAMPDIFF(second, login, logout) / 3600.0  > 8 then '8+'
else '8-' end as time_window
from employees)
 , time_window as (
 select emp_id , count(*) as days_8
, sum(case when time_window='10+' then 1 else 0 end ) as days_10
 from logged_hours
where time_window in ('10+','8+')
 group by emp_id)
 select emp_id, case when days_8 >=3 and days_10>=2 then 'both'
 when days_8 >=3 then '1'
 else '2' end as criterian
 from time_window
  where days_8>=3 or days_10>=2 
ORDER BY emp_id ASC;


/*
===============================================
SQL Problem: Business Expansion
===============================================
Amazon is expanding their pharmacy business to new cities every year. You are given a table of business operations where you have information about cities where Amazon is doing operations along with the business date information.

Write a SQL to find year wise number of new cities added to the business, display the output in increasing order of year.

 

Table: business_operations
+---------------+-----------+
| COLUMN_NAME   | DATA_TYPE |
+---------------+-----------+
| business_date | date      |
| city_id       | int       |
+---------------+-----------+

*/
Solution :
with cte as (
    select city_id,year(min(business_date)) as yr
from business_operations
group by city_id
)
select yr,count(*) from cte
group by yr
order by yr

/*

===============================================
SQL Problem: 18 - Hero Products
===============================================
Flipkart an ecommerce company wants to find out its top most selling product by quantity in each category. 
In case of a tie when quantities sold are same for more than 1 product, then we need to give preference to the product with higher sales value.
Display category and product in output with category in ascending order.

Table: orders
+-------------+-------------+
| COLUMN_NAME | DATA_TYPE   |
+-------------+-------------+
| category    | varchar(10) |
| order_id    | int         |
| product_id  | varchar(20) |
| quantity    | int         |
| unit_price  | int         |
+-------------+-------------+

Hints :
1- total sales will be unit_price*quantity
2- aggregate the sales at category and product level and then rank them based on quantity and total sales

Expected Output
+-----------+---------------+
| category  | product_id    |
+-----------+---------------+
| Footwear  | floaters-3421 |
| Furniture | Table-3421    |
+-----------+---------------+
*/



/*===============================================
SQL Problem: Account Balance 
===============================================

You are given a list of users and their opening account balance along with the transactions done by them. Write a SQL to calculate their account balance at the end of all the transactions. Please note that users can do transactions among themselves as well, display the output in ascending order of the final balance.

 
Table: users
+-----------------+-------------+
| COLUMN_NAME     | DATA_TYPE   |
+-----------------+-------------+
| user_id         | int         |
| username        | varchar(10) |
| opening_balance | int         |
+-----------------+-------------+

Table: transactions
+-------------+-----------+
| COLUMN_NAME | DATA_TYPE |
+-------------+-----------+
| id          | int       |
| from_userid | int       |
| to_userid   | int       |
| amount      | int       |
+-------------+---------


Hints

1- flatter the data using union for from user id and to user id in same column
2- negate the amount for "from user id" select

Expected Output
+----------+---------------+
| username | final_balance |
+----------+---------------+
| Ankit    |          2000 |
| Amit     |          2800 |
| Agam     |          7500 |
| Rahul    |         10200 |
+----------+---------------+
/*

===============================================
SQL Problem: 18 - boAt Lifestyle Marketing
===============================================

boAt Lifestyle is focusing on influencer marketing to build and scale their brand. They want to partner with power creators for their upcoming campaigns. 
The creators should satisfy below conditions to qualify:

1- They should have 100k+ followers on at least 2 social media platforms and
2- They should have at least 50k+ views on their latest YouTube video.
Write an SQL to get creator id and name satisfying above conditions.

Table: creators
+-------------+-------------+
| COLUMN_NAME | DATA_TYPE   |
+-------------+-------------+
| id          | int         |
| name        | varchar(10) |
| followers   | int         |
| platform    | varchar(10) |
+-------------+-------------+
Table: youtube_videos
+--------------+-----------+
| COLUMN_NAME  | DATA_TYPE |
+--------------+-----------+
| id           | int       |
| creator_id   | int       |
| publish_date | date      |
| views        | int       |
+--------------+-----------+

Hint:
1- in first cte filter creators who have 100k followers on at least 2 platforms
2- then find latest video for all of them using row number
3- combine the above 2 ctes


+------+-------+
| id   | name  |
+------+-------+
|  102 | Dhruv |
|  104 | Neha  |
|  105 | Amit  |
+------+-------+


===============================================
SQL Problem: 18 - Dynamic Pricing
===============================================

You are given a products table where a new row is inserted every time the price of a product changes. Additionally, there is a transaction table containing details such as order_date and product_id for each order.
Write an SQL query to calculate the total sales value for each product, considering the cost of the product at the time of the order date, display the output in ascending order of the product_id.

Table: products
+-------------+-----------+
| COLUMN_NAME | DATA_TYPE |
+-------------+-----------+
| product_id  | int       |
| price       | int       |
| price_date  | date      |
+-------------+-----------+
Table: orders 
+-------------+-----------+
| COLUMN_NAME | DATA_TYPE |
+-------------+-----------+
| order_id    | int       |
| order_date  | date      |
| product_id  | int       |
+-------------+-----------+


Hints
1- use lag function to get date range for each product and price 
2- do a range join using between on order date and price range

Expected Output
+------------+-------------+
| product_id | total_sales |
+------------+-------------+
|        100 |         510 |
|        101 |        4700 |
+------------+-------------+
/*

===============================================
SQL Problem: 18 - Airbnb Business
===============================================

You are planning to list a property on Airbnb. To maximize profits, you need to analyze the Airbnb data for the month of January 2023 to determine the best room type for each location. The best room type is based on the maximum average occupancy during the given month.
Write an SQL query to find the best room type for each location based on the average occupancy days. Order the results in descending order of average occupancy days, rounded to 2 decimal places.

 
Table: listings
+----------------+---------------+
| COLUMN_NAME    | DATA_TYPE     |
+----------------+---------------+
| listing_id     | int           |
| host_id        | int           |
| location       | varchar(20)   |
| room_type      | varchar(20)   |
| price          | decimal(10,2) |
| minimum_nights | int           |
+----------------+---------------+
Table: bookings
+---------------+-----------+
| COLUMN_NAME   | DATA_TYPE |
+---------------+-----------+
| booking_id    | int       |
| checkin_date  | date      |
| checkout_date | date      |
| listing_id    | int       |
+---------------+-----------+


Hints
1- first find total number of book days for each listing
2- then find the average book days at location level 

Expected Output
+----------+-----------------+---------------+
| location | room_type       | avg_book_days |
+----------+-----------------+---------------+
| Midtown  | Private room    |          7.00 |
| Downtown | Entire home/apt |          6.33 |
+----------+-----------------+---------------+


===============================================
SQL Problem: Spotify Popular Tracks
===============================================

Suppose you are a data analyst working for Spotify (a music streaming service company) . Your company is interested in analyzing user engagement with playlists and wants to identify the most popular tracks among all the playlists.
Write an SQL query to find the top 2 most popular tracks based on number of playlists they are part of. 
Your query should return the top 2 track ID along with total number of playlist they are part of , sorted by the same and  track id in descending order , Please consider only those playlists which were played by at least 2 distinct users.

Table: playlists
+---------------+--------------+
| COLUMN_NAME   | DATA_TYPE    |
+---------------+--------------+
| playlist_id   | int          |
| playlist_name | varchar(15) |
+---------------+--------------+
Table: playlist_tracks
+-------------+-----------+
| COLUMN_NAME | DATA_TYPE |
+-------------+-----------+
| playlist_id | int       |
| track_id    | int       |
+-------------+-----------+
Table: playlist_plays
+-------------+------------+
| COLUMN_NAME | DATA_TYPE  |
+-------------+------------+
| playlist_id | int        |
| user_id     | varchar(2) |
+-------------+------------

Hints
1- create a cte which filters playlist which are played at least by 2 users
2- join the cte and other 2 tables together

Expected Output
+----------+----------------+
| track_id | no_of_playlist |
+----------+----------------+
|      104 |              4 |
|      101 |              3 |
+----------+----------------+
/*

/*
===============================================
SQL Problem: 40 – Uber Driver Ratings
===============================================

Question
Your Submissions
Solution
Discussion
Medium - 20 Points
Suppose you are a data analyst working for ride-sharing platform Uber. Uber is interested in analyzing the performance of drivers based on their ratings and wants to categorize them into different performance tiers. 

Write an SQL query to categorize drivers equally into three performance tiers (Top, Middle, and Bottom) based on their average ratings. Drivers with the highest average ratings should be placed in the top tier, drivers with ratings below the top tier but above the bottom tier should be placed in the middle tier, and drivers with the lowest average ratings should be placed in the bottom tier. Sort the output in decreasing order of average rating.

 

Table : driver_ratings
+-------------+--------------+
| COLUMN_NAME | DATA_TYPE    |
+-------------+--------------+
| driver_id   | int          |
| avg_rating  | decimal(3,2) |
+-------------+--------------+

1- use ntile function
documentation: https://dev.mysql.com/doc/refman/8.4/en/window-function-descriptions.html#function_ntile

+-----------+------------+------------------+
| driver_id | avg_rating | performance_tier |
+-----------+------------+------------------+
|         7 |       4.90 | Top              |
|         1 |       4.80 | Top              |
|         5 |       4.70 | Top              |
|        12 |       4.60 | Top              |
|         2 |       4.50 | Middle           |
|         9 |       4.40 | Middle           |
|         4 |       4.20 | Middle           |
|        11 |       4.10 | Middle           |
|         3 |       3.90 | Bottom           |
|         8 |       3.80 | Bottom           |
|         6 |       3.60 | Bottom           |
|        10 |       3.50 | Bottom           |
+-----------+------------+------------------+

/*


/*
===============================================
SQL Problem:Excess/insufficient Inventory
===============================================

Suppose you are a data analyst working for Flipkart. Your task is to identify excess and insufficient inventory at various Flipkart warehouses in terms of no of units and cost.  
Excess inventory is when inventory levels are greater than inventory targets else its insufficient inventory.
Write an SQL to derive excess/insufficient Inventory volume and value in cost for each location as well as at overall company level, display the results in ascending order of location id.

 

Table: inventory
+------------------+-----------+
| COLUMN_NAME      | DATA_TYPE |
+------------------+-----------+
| inventory_level  | int       |
| inventory_target | int       |
| location_id      | int       |
| product_id       | int       |
+------------------+-----------+
Table: products
+-------------+--------------+
| COLUMN_NAME | DATA_TYPE    |
+-------------+--------------+
| product_id  | int          |
| unit_cost   | decimal(5,2) |
+-------------+--------------+

Hints
1- first calculate excess/insufficient  at location level
2- then union and aggregate above output to get at overall level

Expected Output
+-------------+-------------------------+---------------------------+
| location_id | excess_insufficient_qty | excess_insufficient_value |
+-------------+-------------------------+---------------------------+
| 1           |                      25 |                   1347.50 |
| 2           |                     -25 |                  -1420.00 |
| 3           |                      20 |                   1180.00 |
| 4           |                     -12 |                   -600.00 |
| Overall     |                       8 |                    507.50 |
+-------------+-------------------------+---------------------------+
/*

/*
===============================================
SQL Problem: Zomato Membership
===============================================

Zomato is planning to offer a premium membership to customers who have placed multiple orders in a single day.
Your task is to write a SQL to find those customers who have placed multiple orders in a single day at least once , 
total order value generate by those customers and order value generated only by those orders, display the results in ascending order of total order value.

 

Table: orders (primary key : order_id)
+---------------+-------------+
| COLUMN_NAME   | DATA_TYPE   |
+---------------+-------------+
| customer_name | varchar(20) |
| order_date    | datetime    |
| order_id      | int         |
| order_value   | int         |
+---------------+-------------+

Hint:
1- first find customer and order date combination where customer placed multiple orders in a day
2- use above cte as filter for customers as well as well as  for join 

Expected Output
+---------------+-------------------+-------------+
| customer_name | total_order_value | order_value |
+---------------+-------------------+-------------+
| Mudit         |               780 |         550 |
| Rahul         |              1300 |        1150 |
+---------------+-------------------+-------------+
*/


/*
===============================================
SQL Problem: Employees Inside Office (Part 1)
===============================================

A company record its employee's movement In and Out of office in a table. Please note below points about the data:
1- First entry for each employee is “in”
2- Every “in” is succeeded by an “out”
3- Employee can work across days
Write a SQL to find the number of employees inside the Office at “2019-04-01 19:05:00".


Table: employee_record
+-------------+------------+
| COLUMN_NAME | DATA_TYPE  |
+-------------+------------+
| emp_id      | int        |
| action      | varchar(3) |
| created_at  | datetime   |
+-------------+------------+

1- use lead to get the out time for each in
2- keep only in entries now. 

Expected Output
+------------------+
| no_of_emp_inside |
+------------------+
|                3 |
+------------------+
/*

------------------------------------------------- DA Interview Question--------------
1. Products
product_id  product_name  category        price
1        Laptop        Electronics        1000.00
2        Phone         Electronics        800.00
3        Chair          Furniture         150.00
4        Desk           Furniture         300.00
 
2. Sales
sale_id product_id  sale_date  quantity
101        1        2023-01-10        5
102        2        2023-01-15        3
103        3        2023-02-20        10
104        4        2023-02-25        7
105        1        2023-03-05        2
106        3        2023-03-15        8
107        2        2023-03-20        4
108        4        2023-03-25        6
 
Calculate the total revenue generated for each product category. Include the category and total_revenue. 
--> total revenue = price * quantity
with cte as (
select p.category,sum(p.price * s.quantity) as total_rev
from products p
left join sales s on p.product_id=s.product_id  -- here using left join means all categories with products will appear even if they dont have any sales
group by category
)
select category,total_rev
from cte

# better to use inner join and without cte
select p.category,coaelsce(sum(p.price*s.quantity)) as total_rev
from products p
join sales s on p.product_id=s.product_id
group by category

Top-Selling Products
Identify the top 3 products by total quantity sold. Include the product_name, category, and total_quantity_sold.

=========> 

select product_name ,category sum(quantity) as total_quantity
from products p
left join sales s on p.product_id=s.product_id
group by product_name,category
order by total_quantity desc
limit 3


================================
 
Table Name: customer_sales
Customer_Name | Customer_ID | Item_ID | Transaction_Date
-------------|-------------|---------|------------------
Alice        | CUST-A182   | 101    | 2021-01-03
Bob          | CUST-A183   | 102    | 2021-01-03
Charlie      | CUST-C304   | 103    | 2021-01-07
David        | CUST-E576   | 104    | 2021-01-15
Eva          | CUST-G7H6   | 105    | 2021-01-21
Alice        | CUST-A182   | 101    | 2021-01-25
Bob          | CUST-A183   | 103    | 2021-02-05
Charlie      | CUST-C304   | 102    | 2021-02-10
Alice        | CUST-A182   | 105    | 2021-02-14
David        | CUST-E576   | 101    | 2021-02-20
Eva          | CUST-G7H6   | 104    | 2021-02-28
Alice        | CUST-A182   | 101    | 2021-03-05
Bob          | CUST-A183   | 102    | 2021-03-12
Charlie      | CUST-C304   | 103    | 2021-03-18
Frank        | CUST-F890   | 106    | 2021-03-22
Alice        | CUST-A182   | 102    | 2021-04-08
Bob          | CUST-A183   | 101    | 2021-04-15
 
Question 1: Most Frequently Purchased Item per Customer
Problem Statement: Identify the most frequently purchased item by each customer 
across all transactions. If there's a tie (multiple items with the same highest frequency), 
return all item.

with cte as (
select customer_id , item_id , count(*) as count_item
from customer_sales
group by customer_id,item_id
) 
select customer_id , dense_rank () over (partition by customer_id order by count_item desc) as rn
from cte
where rn=1  -- here this will not work bcz rn is being used in same select where its being defined

correct query -- 
with cte as (
select customer_id,item_id,count(*) as item_count
from customer_sales
group by customer_id,item_id
),
ranked as (
select customer_id,item_id , dense_rank() over (partition by customer_id order by item_count desc) as rn
from cte 
)
select customer_id,item_count,item_id
from ranked
where rn=1


===>

Question 2: New vs. Repeat Customer Classification by Month
Problem Statement: Classify customers each month into two categories:
New Customers: Customers making their first-ever purchase in that specific month
Repeat Customers: Customers who have already made purchases in any previous month(s)

--- 1. first purchase per customer
with first_purchase as (
select customer_id,min(cast(transaction_Date as Date)) as first_purchase
from customer_sales
group by customer_id),
customer_month as (
select cs.customer_id,
datetrunc('month',cast(cs.transaction_date as Date)) as txn_month
from customer_sales cs
group by customer_id,datetrunc('month',cast(cs.transaction_date as Date))
,
classified as (
select cm.customer_id,
cm.txn_month,
case when date_trunc('month',cast(cs.transaction_date as Date)=cm.txn_month) then 'New'
else 'Repeat' end as customer_type
from customer_month cm
join first_puchase fp
on cm.customer_id=fp.customer_id)
select txn_month,customer_id,count(distinct customer_id) as customer_count
from classified
group by txn_month,customer_id
order by txn_month,customer_id