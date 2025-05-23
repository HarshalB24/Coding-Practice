/* 
📌 QUESTION:
You have access to data from an electricity billing system, detailing the electricity usage and cost 
for specific households over billing periods in the years 2023 and 2024. 

🎯 Objective:
Present the total electricity consumption, total cost and average monthly consumption 
for each household per year. 

🧾 Display:
- Total consumption
- Total cost
- Average monthly consumption (per year)
- Output should be sorted in ascending order of household ID & bill year.

🗃️ Table: electricity_bill
+-----------------+---------------+
| COLUMN_NAME     | DATA_TYPE     |
+-----------------+---------------+
| bill_id         | int           |
| household_id    | int           |
| billing_period  | varchar(7)    | -- e.g. '2023-01'
| consumption_kwh | decimal(10,2) |
| total_cost      | decimal(10,2) |
+-----------------+---------------+
*/


-- ✅ SOLUTION:
select houselhold_id,left(billing_period) as billing_year,
sum(consumption_kwh) as total_consumption,
sum(total_cost) as total_cost,
avg(consumption_kwh) as avg_consumption
from electricity_bill
group by household_id,left(billing_period) 

/*
📌 QUESTION:
-- ============================================
-- SQL Script: Categorize Products by Price Range

🎯 Objective:
Count number of products in each price category
-- Categories:
--   1. Low Price    : price < 100
--   2. Medium Price : 100 <= price <= 500
--   3. High Price   : price > 500

-- 🧾 Display:
Category name and count of products, sorted by count descending
-- ============================================
*/

SELECT CASE 
WHEN PRICE <100 THEN 'Low Price'
WHEN PRICE BETWEEN 100 AND 500 THEN 'Medium Price'
ELSE 'High Price'
END AS CATEGORY,
COUNT(PRODUCT_ID) AS NO_PRODUCT
from PRODUCTS
GROUP BY CATEGORY
ORDER BY COUNT(PRODUCT_ID) DESC

---- USING CTE
WITH CTE AS (
SELECT * , CASE WHEN PRICE < 100 THEN 'Low Price' 
when PRICE >= 100 AND PRICE <=500 THEN 'Medium Price'
ELSE 'High Price'
END AS CATEGORY
FROM PRODUCTS
)

SELECT CATEGORY,COUNT(*) AS CNT FROM CTE      
GROUP BY CATEGORY 
ORDER BY CNT DESC;

/*
===============================================
SQL Problem: Borrowed Books Report
===============================================

Imagine you're working for a library and you're tasked with generating a report 
on the borrowing habits of patrons. You have two tables in your database: 
Books and Borrowers.

Write an SQL query to display the name of each borrower along with a 
comma-separated list of the books they have borrowed in alphabetical order. 
Display the output in ascending order of Borrower Name.

----------------------------
Table: Books
+-------------+-------------+
| COLUMN_NAME | DATA_TYPE   |
+-------------+-------------+
| BookID      | int         |
| BookName    | varchar(30) |
| Genre       | varchar(20) |
+-------------+-------------+

Table: Borrowers
+--------------+-------------+
| COLUMN_NAME  | DATA_TYPE   |
+--------------+-------------+
| BorrowerID   | int         |
| BorrowerName | varchar(10) |
| BookID       | int         |
+--------------+-------------+
*/

-- ✅ Solution: Generate Borrower Report with Book List

SELECT 
    b.BorrowerName,
    STRING_AGG(bo.BookName, ', ' ORDER BY bo.BookName) AS BorrowedBooks
FROM 
    Borrowers b
JOIN 
    Books bo ON b.BookID = bo.BookID
GROUP BY 
    b.BorrowerName
ORDER BY 
    b.BorrowerName ASC;

-- Note: If using MySQL instead of PostgreSQL or SQL Server, replace STRING_AGG with:
-- GROUP_CONCAT(bo.BookName ORDER BY bo.BookName SEPARATOR ', ')

-- USING CTE
WITH CTE AS (
SELECT 
b.borrowername,bo.bookname
from books bo inner join borrower b 
on b.bookid=bo.bookid
)
SELECT borrowername,group_concat(bo.bookname order by bo.bookname seperator ',') 
from CTE  
order by b.borrowername

/*
===============================================
SQL Problem: Math Champions
===============================================
-- Tables: Students
-- +--------------+-------------+
-- | COLUMN_NAME  | DATA_TYPE   |
-- +--------------+-------------+
-- | class_id     | int         |
-- | student_id   | int         |
-- | student_name | varchar(20) |
-- +--------------+-------------+

-- Tables: Grades
-- +-------------+-------------+
-- | COLUMN_NAME | DATA_TYPE   |
-- +-------------+-------------+
-- | student_id  | int         |
-- | subject     | varchar(20) |
-- | grade       | int         |
-- +-------------+-------------+

-- Query: Find students who have higher grade in Math than 
-- the average grades of all the students together in Math.
-- Display student name and grade in Math order by grades.
*/
SELECT 
    s.student_name,
    g.grade
FROM 
    Students s
JOIN 
    Grades g ON s.student_id = g.student_id
WHERE 
    g.subject = 'Math'
    AND g.grade > (
        SELECT 
            AVG(grade)
        FROM 
            Grades
        WHERE 
            subject = 'Math'
    )
ORDER BY 
    g.grade;

--- USING CTE 
With CTE AS (
    SELECT STUDENT_NAME,GRADES 
    INNER JOIN STUDENTS ON S.STUDENT_ID=G.STUDENT_ID
    WHERE SUBJECT='MATH'
)
SELECT STUDENT_NAME,GRADES 
FROM CTE 
HAVING GRADE > (SELECT AVG(GRADE) FROM GRADE WHERE SUBJECT='MATH')
ORDER BY GRADE

/*
===============================================
SQL Problem: Math Champions
===============================================

-- Tables: orders
-- +---------------+-----------+
-- | COLUMN_NAME   | DATA_TYPE |
-- +---------------+-----------+
-- | customer_id   | int       |
-- | delivery_time | int       |
-- | order_id      | int       |
-- | restaurant_id | int       |
-- | total_cost    | int       |
-- +---------------+-----------+

-- Query: Find the customer with the highest total expenditure.
-- Display customer ID and the total expense by him/her.
*/
SELECT 
    customer_id,
    SUM(total_cost) AS total_expense
FROM 
    orders
GROUP BY 
    customer_id
ORDER BY 
    total_expense DESC
LIMIT 1;


/*
===============================================
SQL Problem: Employee Salary Levels
===============================================
-- Tables: Employees
-- +---------------+--------------+
-- | COLUMN_NAME   | DATA_TYPE    |
-- +---------------+--------------+
-- | employee_id   | int          |
-- | employee_name | varchar(20)  |
-- | salary        | int          |
-- +---------------+--------------+

-- Query: Find the average salaries of employees at each salary level.
-- Salary Levels:
--   - "Low" for salary < 50000
--   - "Medium" for salary between 50000 and 100000 (inclusive)
--   - "High" for salary > 100000
-- Round the average to the nearest integer.
-- Output should be in ascending order of salary level.

*/

SELECT 
    CASE
        WHEN salary < 50000 THEN 'Low'
        WHEN salary BETWEEN 50000 AND 100000 THEN 'Medium'
        ELSE 'High'
    END AS salary_level,
    ROUND(AVG(salary)) AS avg_salary
FROM 
    Employees
GROUP BY 
    salary_level
ORDER BY 
    salary_level ASC;

-- USING CTE
with cte as (
select round(avg(salary),0) as avg_salary,
case when salary < 50000 then 'Low'
when salary between 50000 and 100000 then 'Medium'
else 'High'
end as sal_level
from employees
group by sal_level
 )
select sal_level,avg_salary
from cte
order by sal_level;


/*
===============================================
SQL Problem: Average Salary Calculation
===============================================
-- Table: employee
-- +-------------+-------------+
-- | COLUMN_NAME | DATA_TYPE   |
-- +-------------+-------------+
-- | emp_id      | int         |
-- | salary      | int         |
-- | department  | varchar(15) |
-- +-------------+-------------+

-- You are given the data of employees along with their salary and department.
-- Write an SQL to find a list of employees who have salary greater than 
-- average employee salary of the company, excluding their own department 
-- from the average calculation.
-- Display the output in ascending order of employee ids.

*/

-- USING SUBQUERY 
SELECT EMP_ID,SALARY,DEPARTMENT
FROM EMPLOYEE E1
GROUP BY DEPARTMENT
WHERE SALARY > (SELECT AVG(SALARY) FROM EMPLOYEE E2
WHERE E1.DEPARTMENT != E2.DEPARTMENT)

----
SELECT 
    e1.emp_id,
    e1.salary
FROM 
    employee e1
WHERE 
    e1.salary > (
        SELECT 
            AVG(e2.salary)
        FROM 
            employee e2
        WHERE 
            e2.department != e1.department
    )
ORDER BY 
    e1.emp_id;

/*
===============================================
SQL Problem: Product Reviews
===============================================
-- Table: product_reviews
-- +-------------+--------------+
-- | COLUMN_NAME | DATA_TYPE    |
-- +-------------+--------------+
-- | review_id   | int          |
-- | product_id  | int          |
-- | review_text | varchar(40)  |
-- +-------------+--------------+

-- Suppose you are a data analyst working for a retail company, and your team 
-- is interested in analysing customer feedback to identify trends and patterns 
-- in product reviews.

-- Your task is to write an SQL query to find all product reviews containing 
-- the word "excellent" or "amazing" in the review text. 
-- However, you want to exclude reviews that contain the word "not" immediately 
-- before "excellent" or "amazing". 

-- Please note that the words can be in upper or lower case or any combination of both. 
-- Your query should return the review_id, product_id, and review_text for each review 
-- meeting the criteria, and display the output in ascending order of review_id.

*/

SELECT 
    review_id,
    product_id,
    review_text
FROM 
    product_reviews
WHERE 
    (
        LOWER(review_text) LIKE '%excellent%' 
        OR LOWER(review_text) LIKE '%amazing%'
    )
    AND LOWER(review_text) NOT LIKE '%not excellent%'
    AND LOWER(review_text) NOT LIKE '%not amazing%'
ORDER BY 
    review_id;


/*
===============================================
SQL Problem: Category Sales (Part 1)
===============================================
-- Write an SQL query to retrieve the total sales amount for each product category 
-- in the month of February 2022, only including sales made on weekdays (Monday to Friday). 
-- Display the output in ascending order of total sales.

-- Table: sales
-- +-------------+-------------+
-- | COLUMN_NAME | DATA_TYPE   |
-- +-------------+-------------+
-- | id          | int         |
-- | product_id  | int         |
-- | category    | varchar(12) |
-- | amount      | int         |
-- | order_date  | date        |
-- +-------------+-------------+
*/

SELECT 
    category,
    SUM(amount) AS total_sales
FROM 
    sales
WHERE 
    order_date >= '2022-02-01' 
    AND order_date < '2022-03-01'
    AND EXTRACT(DOW FROM order_date) BETWEEN 1 AND 5 -- Monday (1) to Friday (5)
GROUP BY 
    category
ORDER BY 
    total_sales ASC;

--ALTERNATE METHOD
select category,sum(amount) as total_sales from sales
where month(order_date)=2 and year(order_date)=2022 and dayofweek(order_date) between 2 and 6
group by category
order by total_sales;

/*
===============================================
SQL Problem: Category Sales (Part 2)
===============================================
-- Write an SQL query to retrieve the total sales amount in each category.
-- Include all categories. If no products were sold in a category, display total_sales as 0.
-- Display the output in ascending order of total_sales.

-- Tables: sales
-- +-------------+-----------+
-- | COLUMN_NAME | DATA_TYPE |
-- +-------------+-----------+
-- | amount      | int       |
-- | category_id | int       |
-- | sale_date   | date      |
-- | sale_id     | int       |
-- +-------------+-----------+

-- Tables: Categories
-- +---------------+-------------+
-- | COLUMN_NAME   | DATA_TYPE   |
-- +---------------+-------------+
-- | category_id   | int         |
-- | category_name | varchar(12) |
-- +---------------+-------------+
*/

SELECT 
    c.category_id,
    c.category_name,
    COALESCE(SUM(s.amount), 0) AS total_sales
FROM 
    Categories c
LEFT JOIN 
    sales s ON c.category_id = s.category_id
GROUP BY 
    c.category_id, c.category_name
ORDER BY 
    total_sales ASC;




/*
===============================================
SQL Problem: Department Average Salary
===============================================
-- Question:
-- You are provided with two tables: Employees and Departments.
-- The Employees table contains information about employees, including their IDs, names, salaries, and department IDs.
-- The Departments table contains information about departments, including their IDs and names.
--
-- Write an SQL query to find the average salary of employees in each department,
-- but only include departments that have more than 2 employees.
-- Display department name and average salary (rounded to 2 decimal places).
-- Sort the result by average salary in descending order.

-- Tables:
-- Employees(employee_id INT, employee_name VARCHAR(20), salary INT, department_id INT)
-- Departments(department_id INT, department_name VARCHAR(10))

Tables: Employees
+---------------+-------------+
| COLUMN_NAME   | DATA_TYPE   |
+---------------+-------------+
| employee_id   | int         |
| employee_name | varchar(20) |
| salary        | int         |
| department_id | int         |
+---------------+-------------+
Tables: Departments
+-----------------+-------------+
| COLUMN_NAME     | DATA_TYPE   |
+-----------------+-------------+
| department_id   | int         |
| department_name | varchar(10) |
+-----------------+-------------+
*/

-- 1. Standard GROUP BY approach
SELECT 
    d.department_name,
    ROUND(AVG(e.salary), 2) AS avg_salary
FROM employees e
JOIN departments d ON e.department_id = d.department_id
GROUP BY d.department_name
HAVING COUNT(*) > 2
ORDER BY avg_salary DESC;


-- 2. CTE approach
WITH dept_avg AS (
    SELECT 
        d.department_name,
        ROUND(AVG(e.salary), 2) AS avg_salary,
        COUNT(*) AS emp_count
    FROM employees e
    JOIN departments d ON e.department_id = d.department_id
    GROUP BY d.department_name
)
SELECT 
    department_name,
    avg_salary
FROM dept_avg
WHERE emp_count > 2
ORDER BY avg_salary DESC;


-- 3. Window Function approach
WITH employee_with_stats AS (
    SELECT 
        d.department_name,
        e.salary,
        ROUND(AVG(e.salary) OVER (PARTITION BY d.department_name), 2) AS avg_salary,
        COUNT(*) OVER (PARTITION BY d.department_name) AS emp_count
    FROM employees e
    JOIN departments d ON e.department_id = d.department_id
)
SELECT DISTINCT 
    department_name, 
    avg_salary
FROM employee_with_stats
WHERE emp_count > 2
ORDER BY avg_salary DESC;

/*-- 
===============================================
SQL Problem: Product Sales
===============================================

Question:
-- You are provided with two tables: Products and Sales.
-- The Products table contains information about various products, including their IDs, names, and prices.
-- The Sales table contains data about sales transactions, including the product IDs, quantities sold, and dates of sale.
--
-- Your task is to write a SQL query to find the total sales amount for each product.
-- Display product name and total sales.
-- Sort the result by product name.

-- Tables:
-- Products(product_id INT, product_name VARCHAR(10), price INT)
-- Sales(sale_id INT, product_id INT, quantity INT, sale_date DATE)

Table: products
+--------------+-------------+
| COLUMN_NAME  | DATA_TYPE   |
+--------------+-------------+
| product_id   | int         |
| product_name | varchar(10) |
| price        | int         |
+--------------+-------------+
Table: sales
+-------------+-----------+
| COLUMN_NAME | DATA_TYPE |
+-------------+-----------+
| sale_id     | int       |
| product_id  | int       |
| quantity    | int       |
| sale_date   | date      |
+-------------+-----------+
*/
--Note : Sales = Quantity * Price
-- SQL Query:
SELECT 
    p.product_name,
    SUM(s.quantity * p.price) AS total_sales
FROM products p
JOIN sales s ON p.product_id = s.product_id
GROUP BY p.product_name
ORDER BY p.product_name;

/*
===============================================
SQL Problem: Product Sales
===============================================
/*
-- Question:
-- You are provided with a table that lists various product categories,
-- each containing a comma-separated list of products.
-- Your task is to write a SQL query to count the number of products in each category.
-- Sort the result by product count.

-- Table: categories
-- Columns:
-- category VARCHAR(15)
-- products VARCHAR(30)  -- Comma-separated product names

-- Example:
-- +------------+-------------------------+
-- | category   | products                |
-- +------------+-------------------------+
-- | Electronics| TV,Laptop,Tablet        |
-- | Groceries  | Milk,Bread,Butter,Cheese|
-- +------------+-------------------------+

-- Expected Output:
-- +------------+--------------+
-- | category   | product_count|
-- +------------+--------------+
-- | Groceries  | 4            |
-- | Electronics| 3            |
-- +------------+--------------+
*/

-- SQL Query (PostgreSQL-compatible using string_to_array and unnest):
SELECT 
    category,
    COUNT(*) AS product_count
FROM (
    SELECT 
        category,
        UNNEST(STRING_TO_ARRAY(products, ',')) AS product
    FROM categories
) sub
GROUP BY category
ORDER BY product_count DESC;

-- USING THE LENGTH FUNCTION 
select category , 
length(products) as no_of_Commas,  --gives us total length 
length(replace(products,',','')) as remove_commas, -- length without commas
legnth(products) - kength(replace(products,',','')) + 1  as count_products  --- we do a +1 bcz if we count the comma's and +1=no of products
from products 
order by count_products


/*
===============================================
SQL Problem: GAP Sales
===============================================
-- Question:
-- You have a table called gap_sales. 
-- Write an SQL query to find the total sales for each category in each store for Q2 (April-June) of 2023. 
-- Return the store ID, category name, and total sales for each category in each store. 
-- Sort the result by total sales in ascending order.

-- Table: gap_sales
-- +-------------+-------------+
-- | COLUMN_NAME | DATA_TYPE   |
-- +-------------+-------------+
-- | sale_id     | int         |
-- | store_id    | int         |
-- | sale_date   | date        |
-- | category    | varchar(10) |
-- | total_sales | int         |
-- +-------------+-------------+
*/

SELECT 
    store_id,
    category,
    SUM(total_sales) AS total_sales
FROM 
    gap_sales
WHERE 
    sale_date >= '2023-04-01' AND sale_date < '2023-07-01'
GROUP BY 
    store_id, category
ORDER BY 
    total_sales ASC;

---
select 
store_id,
category,
sum(total_sales) as sales 
from gap_sales
where month(sale_date) in (4,5,6) and year(sale_date)=2023
group by store_id,category
order by sales

/*
===============================================
SQL Problem: Electronics Items Sale
===============================================
-- Question:
-- You have a table called electronic_items. 
-- Write an SQL query to find the average price of electronic items in each category,
-- considering only categories where the average price exceeds 500 and at least 20 total quantity of items is available. 
-- Additionally, only include items with a warranty period of 12 months or more. 
-- Return the category name along with the average price of items in that category. 
-- Order the result by average price (round to 2 decimal places) in descending order.

-- Table: electronic_items
-- +-----------------+--------------+
-- | COLUMN_NAME     | DATA_TYPE    |
-- +-----------------+--------------+
-- | item_id         | int          |
-- | item_name       | varchar(20)  |
-- | category        | varchar(15)  |
-- | price           | decimal(5,1) |
-- | quantity        | int          |
-- | warranty_months | int          |
-- +-----------------+--------------+
*/

SELECT 
    category,
    ROUND(AVG(price), 2) AS avg_price
FROM 
    electronic_items
WHERE 
    warranty_months >= 12
GROUP BY 
    category
HAVING 
    AVG(price) > 500 AND SUM(quantity) >= 20
ORDER BY 
    avg_price DESC;

/*
===============================================
SQL Problem: Domain Names
===============================================

-- Question:
-- Write an SQL query to extract the domain names from email addresses stored in the Customers table.

-- Table: Customers
-- +-------------+-------------+
-- | COLUMN_NAME | DATA_TYPE   |
-- +-------------+-------------+
-- | CustomerID  | int         |
-- | Email       | varchar(25) |
-- +-------------+-------------+
*/

SELECT 
    CustomerID,
    SUBSTRING(Email, CHARINDEX('@', Email) + 1, LEN(Email)) AS Domain
FROM 
    Customers;

/*
===============================================
SQL Problem: Subject Average Score
===============================================
-- Write an SQL query to find the course names where the average score 
-- (calculated only for students who have scored less than 70 in at least one course) 
-- is greater than 70. 
-- Sort the result by the average score in descending order.

-- Table: students
-- +-------------+--------------+
-- | COLUMN_NAME | DATA_TYPE    |
-- +-------------+--------------+
-- | student_id  | int          |
-- | course_name | VARCHAR(10)  |
-- | score       | int          |
-- +-------------+--------------+
*/

WITH low_scorers AS (
    SELECT DISTINCT student_id
    FROM students
    WHERE score < 70
),
filtered_scores AS (
    SELECT s.course_name, s.score
    FROM students s
    JOIN low_scorers ls ON s.student_id = ls.student_id
)
SELECT 
    course_name, 
    ROUND(AVG(score),


--- USING SUB QUERY
select course_name,avg(score) as avg_Score
from students
where student_id in (
  select distinct student_id
  from students
  where score < 70
  )
  group by course_name
  having avg(score) > 70
  order by avg_score desc