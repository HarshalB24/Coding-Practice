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