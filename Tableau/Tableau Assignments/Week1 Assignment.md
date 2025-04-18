# Week 1 Assignments

### 1. Create a table which shows region and count of distinct customers in each region as shown below. Verify the results by writing the SQL.


-- Example SQL Query:
SELECT region, COUNT(DISTINCT customer_id) AS distinct_customers
FROM orders
GROUP BY region;


### 2. Convert the following SQL in Tableau cross table and verify the results.

SELECT category, sub_category, SUM(sales) AS total_sales,
       AVG(profit) AS avg_profit
FROM orders 
WHERE region IN ('Central','East')
GROUP BY category, sub_category
HAVING AVG(quantity) > 4;


3-	Create a table in tableau which shows distinct number of orders from each value of quantity as shown below:

![alt text](<../Tableau images/assignment image.png>)

### 4-	Create a table in tableau which shows total sales by region and state. Allow user to filter the data based on region. For the selected region/s show the top 3 states by total profit.

### 5-	Create a line chart which show profit to sales ratio for each month/year using order date. Filter the data where the ratio is greater than 0.1

### 6-	Create a bar chart which shows total sales for each category. When the user hover over each bar it should show total profit on the tooltip. 

### 7-	Create a bar chart which shows total sales for each region and each region/bar should have different colour as shown below:
![alt text](<../Tableau images/assign ques8.png>)

### 8 -	Create a bar chart which shows total sales in each subcategory. Allow users to filter data for different regions. As per the selection of the region, the region names should reflect on the worksheet title as shown below.
![alt text](<../Tableau images/assign ques9.png>)

### 9 - Create a bar chart which shows total profit by sub category for the month of Jan-2018 and show only subcategories for which the total profit is negative for that month. Verify the result by writing SQL on your database.