Retention Question 1/10
Table: Payments
Column Name	Type
payment_id	int
customer_id	int
payment_date	date
amount	int


Write a query to return the payment_id for every payment whose amount is greater than the immediately previous payment amount for the same customer.
A customer may go many days without making a payment.
Give me:
Output grain → one-line approach → SQL





    







output grain - one row per payment_id satisfying the condition
approach - we use the lag window function and order by payment_Date desc

sql :
with cte as (
select amount , payment_id , lag(amount,1) over (partition by customer_id order by payment_date) as prev_amount
from payments
)
select payment_id from payments
where amount > prev_amount












Partially correct. Your pattern recognition is right, but there are two issues.
- Output grain: correct ✅
- Pattern: LAG() within each customer ✅
- Ordering: should be chronological, so ORDER BY payment_date ascending. You said DESC in the approach, but your SQL correctly used ascending.
- Main SQL mistake: your outer query reads from payments, but prev_amount exists only inside the CTE.
Correct version:
WITH cte AS (
    SELECT
        payment_id,
        amount,
        LAG(amount) OVER (
            PARTITION BY customer_id
            ORDER BY payment_date, payment_id
        ) AS prev_amount
    FROM Payments
)
SELECT payment_id
FROM cte
WHERE amount > prev_amount;

Mistake type: CTE usage / query structure
Pattern status: concept is clear, implementation still needs attention.


Retention Question 2/10
Table: Scores
Column Name	Type
student_id	int
subject_id	int
score	int


Write a query to return the student_id for every student who has the second highest distinct score within each subject.
If multiple students share that second-highest score, return all of them.
Give me:
Output grain → one-line approach → SQL





    







output grain - one or more row per subject satisfying the condition
approach - since we need second highest distinct we use dense rank

with cte as (
select student_id , dense_rank() over (partition by subject order by score desc) as rn
from scores
)
select student_id from cte
where rn=2












Almost clean. Your pattern choice is correct, but there’s one column-name issue and one wording refinement.
- Output grain: better phrased as one row per qualifying student per subject. If the same student is second-highest in two subjects, they can appear twice depending on requested columns.
- Pattern: DENSE_RANK() is exactly right for second highest distinct score ✅
- Partition: should use subject_id, not subject.
Correct query:
WITH cte AS (
    SELECT
        student_id,
        subject_id,
        DENSE_RANK() OVER (
            PARTITION BY subject_id
            ORDER BY score DESC
        ) AS rn
    FROM Scores
)
SELECT student_id
FROM cte
WHERE rn = 2;

If the interviewer wants subject context too, return both:
SELECT subject_id, student_id
FROM cte
WHERE rn = 2;
Status: logic pass, minor implementation slip.


Retention Question 3/10
Table: Activity
Column Name	Type
user_id	int
activity_date	date
points	int


Write a query to return the user_id, activity_date, and points for the earliest activity record(s) of each user.
If a user has multiple records on their earliest date, return all of them.
Give me:
Output grain → one-line approach → SQL





    







output grain - one row per user satisfying the condition 
approach - we use row number here since we need the earliest activity record

sql :
with cte as (
select user_id , activity_date,points ,row_number () over (partition by user_id order by activity_date) as rn
from activity
)
select user_id , activity_date , points from cte
where rn=1












Partially correct. You chose the right general family, but because the question says earliest activity record(s) and explicitly says return all rows tied on the earliest date, ROW_NUMBER() is not the best choice.
If a user has:
2026-01-01  10
2026-01-01  20
2026-01-03  30

ROW_NUMBER() would arbitrarily give one of the two earliest rows rn = 1 and the other rn = 2, so you’d lose a valid tied row.
Use DENSE_RANK() or RANK() on activity_date instead:
WITH cte AS (
    SELECT
        user_id,
        activity_date,
        points,
        DENSE_RANK() OVER (
            PARTITION BY user_id
            ORDER BY activity_date
        ) AS rn
    FROM Activity
)
SELECT
    user_id,
    activity_date,
    points
FROM cte
WHERE rn = 1;

Your exact mistake was:
Need one actual row → ROW_NUMBER()
Need all rows tied on earliest/latest value → RANK()/DENSE_RANK()

So for the retention tracker:
- Pattern recognition: partial
- Mistake: chose ROW_NUMBER() despite tie requirement
- Status: Needs one more reinforcement

Table: Orders
- order_id
- customer_id
- order_date
- amount
Write a query to return each customer_id and their latest order date.
Return exactly one row per customer.
Give me:
Output grain → one-line approach → SQL





    







output grain - one row per customer 
approach - we use row number since we only need latest order date
with cte as (
select customer_id , row_number () over (partition by customer_id order by order_date desc) as rn
from orders
)
select customer_id from cte
where rn=1












Partially correct. You overused a window again.
The question asks only for the latest order date, not the full latest order row.
So the simplest pattern is:
Need only latest value per group → MAX() + GROUP BY

SELECT
    customer_id,
    MAX(order_date) AS latest_order_date
FROM Orders
GROUP BY customer_id;

Your current query also misses order_date in the final output.
So the exact reflex is:
Need only earliest/latest value → MIN/MAX
Need full earliest/latest row → window

This is one of the patterns we already reinforced, so mark this as retention miss due to rushing.
Retention Question 5/10
Table: Logins
Column Name	Type
user_id	int
login_date	date


Write a query to return the user_id values for users who logged in on at least 3 consecutive calendar days.
Give me:
Output grain → one-line approach → SQL





    







output grain - one record per customer who satisfy conditon
approach - we use lag window function and datediff 

with cte as (
select user_id , login_date , lag(login_date,1) over (partition by customer_id order by login_date) as lag_1,lag(login_date,2) over (partition by customer_id order by login_date) as lag_2,
from  logins
)
select user_id form cte 
where datediff(login_date,lag_1)=1 and datediff(login_date,lag_2)=1












You chose the right pattern family, but there are a few important misses.
What you got right
- Output should be one row per qualifying user_id ✅
- LAG() is the right idea ✅
- Need exact date-gap logic ✅
What went wrong
- You used customer_id instead of user_id
- extra comma before FROM
- form typo
- most importantly:
DATEDIFF(login_date, lag_2) = 1

is wrong.
If you want 3 consecutive days:
lag_2 -> lag_1 = 1 day
lag_1 -> current = 1 day

So either use:
DATEDIFF(login_date, lag_1) = 1
AND DATEDIFF(lag_1, lag_2) = 1

or:
DATEDIFF(login_date, lag_1) = 1
AND DATEDIFF(login_date, lag_2) = 2

Correct version:
WITH cte AS (
    SELECT
        user_id,
        login_date,
        LAG(login_date, 1) OVER (
            PARTITION BY user_id
            ORDER BY login_date
        ) AS lag_1,
        LAG(login_date, 2) OVER (
            PARTITION BY user_id
            ORDER BY login_date
        ) AS lag_2
    FROM Logins
)
SELECT DISTINCT user_id
FROM cte
WHERE DATEDIFF(login_date, lag_1) = 1
  AND DATEDIFF(lag_1, lag_2) = 1;

Exact retention issue
You remembered:
consecutive → LAG + DATEDIFF

But the exact condition still isn’t fully automatic yet.
Keep this one line:
3 consecutive dates = current-prev = 1 AND prev-prevprev = 1

This pattern is not stable yet, so we should hit it again later tonight.





    







ok so it should be datediff(login_Date,lag_1)=1 and datediff(login_date,lag_2)=2 or datediff(lag_1,lag_2)=1 understood












Exactly.
For 3 consecutive dates, either of these is valid:
DATEDIFF(login_date, lag_1) = 1
AND DATEDIFF(lag_1, lag_2) = 1

or:
DATEDIFF(login_date, lag_1) = 1
AND DATEDIFF(login_date, lag_2) = 2

The first version is usually easier to reason about because it checks each adjacent gap directly.
Memory line:
3 consecutive = 1-day gap + 1-day gap.

That’s the one to keep.

Retention Question 6/10
Table: EmployeeSalary
Column Name	Type
employee_id	int
department_id	int
salary	int


Write a query to return the employee_id and salary for employees whose salary is greater than the average salary of their department.
Give me:
Output grain → one-line approach → SQL





    







output grain - one row per employee satisfying the conditon 
approach - we can do avg salary > sal or we can also use window function

approach 1 : 
select employee_id ,salary from employeesalary
where salary > (select avg(salary) from employeesalary group by department_id)

appraoch 2 :
with cte as (
select employee_id,salary ., avg(salary) over (partition by department_id) as avg_sal
from employeesalary
)
select employee_id,salary
from cte 
where salary > avg_sal












Approach 2 is correct. Approach 1 is not correct as written.
Your reasoning is good: this is a row-level output + group-level metric problem, so a window aggregate is a natural fit.
Your second query only has a typo:
salary .

should be:
salary,

Correct version:
WITH cte AS (
    SELECT
        employee_id,
        salary,
        AVG(salary) OVER (
            PARTITION BY department_id
        ) AS avg_sal
    FROM EmployeeSalary
)
SELECT employee_id, salary
FROM cte
WHERE salary > avg_sal;

Why approach 1 is wrong:
WHERE salary > (
    SELECT AVG(salary)
    FROM EmployeeSalary
    GROUP BY department_id
)

That subquery returns multiple department averages, while > expects one scalar value.
If you wanted a subquery approach, you’d need a correlated subquery:
SELECT e.employee_id, e.salary
FROM EmployeeSalary e
WHERE e.salary > (
    SELECT AVG(e2.salary)
    FROM EmployeeSalary e2
    WHERE e2.department_id = e.department_id
);

Assessment
- Output grain: ✅
- Pattern recognition: ✅
- Window solution: ✅
- Scalar subquery understanding: ⚠️ needs care
Memory line:
Compare each row to its group average → window aggregate or correlated subquery.

Retention Question 7/10
Table: StudentCourse
Column Name	Type
student_id	int
course_id	int


A student may appear multiple times.
Table: RequiredCourse
Column Name	Type
course_id	int


Write a query to return the student_id values of students who have completed every course listed in RequiredCourse.
Give me:
Output grain → one-line approach → SQL





    







output grain - one row per student who completed all the course
appraoch - we find count of course completed by each student and then count of all courses and whoever completed all will be otuput
with cte as (
select student_id , count(course_id) as student_course_count
from studentcourse
group by student_id
)
select student_id from cte
where student_course_count = (select count(Distinct course_id) from requiredcourse)

or other approach is : 
select s.student_id , count(s.course_id) as student_count
from studentcourse s
join requiredcourse r on 
s.course_id=r.course_id
having count(s.course_id) = (select count(distinct r.course_id) from requiredcourse)












Your reasoning is correct, but both SQL versions need a little tightening.
For the first approach, the main issue is that StudentCourse may contain duplicates, so you should count distinct courses, not raw rows. Otherwise repeated completion records could falsely make a student look like they completed all required courses.
A clean version is:
SELECT student_id
FROM StudentCourse
GROUP BY student_id
HAVING COUNT(DISTINCT course_id) = (
    SELECT COUNT(*)
    FROM RequiredCourse
);

This works if StudentCourse.course_id values are all valid required-course keys. If not, then the safer version is to compare only against required courses.
Your second approach is closer to that safer version, but it is missing a GROUP BY and should also use COUNT(DISTINCT ...):
SELECT s.student_id
FROM StudentCourse s
JOIN RequiredCourse r
    ON s.course_id = r.course_id
GROUP BY s.student_id
HAVING COUNT(DISTINCT s.course_id) = (
    SELECT COUNT(*)
    FROM RequiredCourse
);

So the pattern is still:
Entity has all required items → GROUP BY entity + HAVING COUNT(DISTINCT matched_item) = total required items

Assessment
- Output grain: ✅
- Core pattern: ✅
- Need for DISTINCT: ⚠️ missed
- HAVING/GROUP BY: second approach incomplete
- Overall: Mostly correct, one precision gap
This one is better than before because you identified the correct pattern immediately.


Retention Question 8/10
Table: Connections
Column Name	Type
user_a	int
user_b	int
connected_at	date


Each row means user_a and user_b are connected.
Write a query to return the user_id with the highest total number of connections, counting connections where the person appears in either user_a or user_b.
Assume there is only one person with the maximum count.
Give me:
Output grain → one-line approach → SQL





    







output grain - one row of user having highest connection
appraoch - since its bidectional relation we do union all

with cte as (
select user_a, as user_id ,count(user_a) as u_count
from connections

union all 
select user_b as user_id ,count(user_b) as u_count
from connections
)
select user_id
from cte
order by u_count desc
limit 1





 






Pattern recognition is correct, but the aggregation is in the wrong place.
You correctly identified:
- Output grain: one row for the user with the most connections ✅
- Pattern: symmetric relation → combine both columns with UNION ALL ✅
The issue is that you are counting inside each branch before stacking:
select user_a as user_id, count(user_a) ...
union all
select user_b as user_id, count(user_b) ...

That gives one total for all user_a rows and one total for all user_b rows, not one count per person.
The correct flow is:
stack both sides first → then group by user → count → sort → top 1

WITH cte AS (
    SELECT user_a AS user_id
    FROM Connections

    UNION ALL

    SELECT user_b AS user_id
    FROM Connections
)
SELECT
    user_id,
    COUNT(*) AS connection_count
FROM cte
GROUP BY user_id
ORDER BY connection_count DESC
LIMIT 1;

Exact mistake
You remembered the right pattern but aggregated before normalizing both sides into one entity column.
Memory rule:
Same entity in 2 columns → UNION ALL first, aggregate second.

Status
- Pattern recognition: ✅
- SQL structure: ⚠️
- Retention status: not fully stable yet


Retention Question 9/10
Table: Applications
Column Name	Type
application_id	int
candidate_id	int
city	varchar
country	varchar
score	int


Return the sum of score for applications where:
- candidate_id appears more than once
- (city, country) appears exactly once
Give me:
Output grain → one-line approach → SQL





   







output grain - one row per application satisfying condition
appraoch -- group by and having + count

select sum(Score) from applications where 
application_id = (
select candidate_id,count(*) from application
group by application_id
having count(candidate_id) >1
) and (city,country) in (
select application_id,count(*) from applications 
group by (city,country)
having count(*)=1)












This one is not correct yet, and it shows that this pattern still isn’t stable.
The first issue is the output grain. The query asks for the sum of score, so the final output is:
one row total

not one row per application.
Your reasoning should be:
repeated candidate_id → get candidate IDs with COUNT(*) > 1
unique (city, country) → get pairs with COUNT(*) = 1
keep applications matching both conditions
sum score

The clean query is:
SELECT SUM(score) AS total_score
FROM Applications
WHERE candidate_id IN (
    SELECT candidate_id
    FROM Applications
    GROUP BY candidate_id
    HAVING COUNT(*) > 1
)
AND (city, country) IN (
    SELECT city, country
    FROM Applications
    GROUP BY city, country
    HAVING COUNT(*) = 1
);

Your specific mistakes were:
- used application_id = (...) instead of filtering by candidate_id
- subquery returned multiple columns
- grouped by the wrong column
- for the city/country condition, you need to return city, country, not application_id
- final output grain was misread
The short memory rule is:
Repeated value → GROUP BY x HAVING COUNT(*) > 1
Unique pair → GROUP BY x,y HAVING COUNT(*) = 1
Outer query uses IN to keep matching rows


Retention Question 10/10
Table: Seat
Column Name	Type
id	int
student	varchar


id starts from 1 and is continuous.
Write a query to swap every pair of consecutive seat ids:
1 ↔ 2, 3 ↔ 4, 5 ↔ 6, ...
If the final row has no pair, leave its id unchanged.
Return all rows ordered by the resulting id.
Give me:
Output grain → one-line approach → SQL





    







output grian - all orws with correct seat id
approach - we first check total seats and if its odd we leave it unchanged andd then change the rest 

select case when id %2=1 and id=(select max(id) from seat) then id
case when id%2!=0 then id+1
else id-1
end as id from seat
order by id












Logic is basically right; just fix the CASE syntax.
You wrote two CASE keywords. It should be one CASE with multiple WHENs:
SELECT
    CASE
        WHEN id % 2 = 1
             AND id = (SELECT MAX(id) FROM Seat)
        THEN id
        WHEN id % 2 = 1
        THEN id + 1
        ELSE id - 1
    END AS id,
    student
FROM Seat
ORDER BY id;

Assessment:
- Output grain: ✅
- Pattern recognition: ✅
- Odd-last handling: ✅
- Swap direction: ✅
- SQL syntax: minor slip only
So this pattern is stable now.
For the 10-question retention round, the main items still needing revisit are:
- duplicate single value + unique composite pair
- symmetric relationship: UNION ALL first, aggregate second
- earliest/latest: value only vs full row/ties
- 3 consecutive dates exact-gap condition
- CTE projection / outer query reading from CTE
- “has all required items” → COUNT(DISTINCT) precision


#######################
LeetCode SQL 50 — Question 13/50
Let’s do a medium one now: Game Play Analysis IV. This is an exact SQL 50 problem. LeetCode
Table: Activity
Column Name	Type
player_id	int
device_id	int
event_date	date
games_played	int


(player_id, event_date) is the primary key.
Write a query to report the fraction of players who logged in again on the day immediately after their first login, rounded to 2 decimal places.
In other words:
players who logged in on first_login_date + 1 day
divided by
total number of distinct players

soln - 
1.first find the first login of a player then find which player logged in the immediate next date and divide those by total player

with first_login as (
    select player_id , min(event_Date) as first_login_date
    from activity
    group by player_id
)
select round(count(distinct case when a.event_date=f.first_date,interval 1 Day )then a.player_id)*1.0/count(distinct player_id) as fraction
from first_login f 
left join activity a 
on f.player_id=a.player_id

LeetCode SQL 50 — Question 14/50
Let’s do another medium one: Immediate Food Delivery II. This is an exact SQL 50 problem. LeetCode
Table: Delivery
Column Name	Type
delivery_id	int
customer_id	int
order_date	date
customer_pref_delivery_date	date


If customer_pref_delivery_date = order_date, the order is immediate. Otherwise it is scheduled.
The first order of a customer is the one with the earliest order_date. It is guaranteed that each customer has exactly one first order.
Write a query to find the percentage of immediate orders among the first orders of all customers, rounded to 2 decimal places.
Give me:
Output grain → one-line approach → SQL





    







output grain - one row per customer satisfying the condition
approach - we first get the count of first orders and then count of immediate orders adn then cal the % 

with cte as (
select customer_id ,sum(Case when customer_pref_delivery_Date=order_date then 1 else 0 end) as immediate_order , min(order_date) as first_order
from delivery
group by customer_id 
)
select round(100 * immediate_order / count(first_order) ,2) as perc_immediate_order
from cte












Partially correct. Your high-level idea is right, but the query is not isolating each customer’s first order row before deciding whether it was immediate.
The main issue is here:
SUM(CASE WHEN customer_pref_delivery_date = order_date THEN 1 ELSE 0 END)

inside a GROUP BY customer_id.
That counts all immediate orders for the customer, not whether the first order was immediate.
The clean logic is:
identify each customer’s first order row → check whether that row is immediate → calculate percentage across customers.

A good solution is:
WITH first_orders AS (
    SELECT
        customer_id,
        order_date,
        customer_pref_delivery_date,
        ROW_NUMBER() OVER (
            PARTITION BY customer_id
            ORDER BY order_date
        ) AS rn
    FROM Delivery
)
SELECT
    ROUND(
        100.0 * SUM(
            CASE
                WHEN customer_pref_delivery_date = order_date THEN 1
                ELSE 0
            END
        ) / COUNT(*),
        2
    ) AS immediate_percentage
FROM first_orders
WHERE rn = 1;

Because the problem guarantees exactly one first order per customer, ROW_NUMBER() works cleanly here.
Exact mistake
You mixed:
“find first date”

with
“count immediate orders”

without first reducing to the actual first-order rows.
Short memory rule:
If the condition applies specifically to the first/last row, isolate that row first, then aggregate.

For history:
- Pattern: first row per group + conditional percentage
- Mistake: aggregated all customer orders instead of only first orders
- Reinforcement needed: yes
- Status: Needs Revisit

Let’s do a medium one now: Restaurant Growth. This is an exact LeetCode problem. LeetCode
Table: Customer
Column Name	Type
customer_id	int
name	varchar
visited_on	date
amount	int


Each row is one customer transaction at the restaurant.
Write a query to compute, for each day starting from the 7th available day:
- visited_on
- total amount paid in the 7-day window ending on that day
- average_amount over that same 7-day window, rounded to 2 decimals
The result should be ordered by visited_on ascending. LeetCode
Give me:
Output grain → one-line approach → SQL





    







output grain = one row per visit when condition is satisfied
approach - we use the windows function of 6 precedding and current row
with cte as (
select visited_on , sum(amount) over (partition by customer_id order by visited_on rows between 6 preceeding and current_row) as total_amount ,avg(amount) over (partition by customer_id order by visited_on rows between 6 preceding and current_row) as avg_amount,row_number() over (order by visited_on) as rn
from customer
)
Select visited_on , total_amount , avg_amount
from cte
where rn>=7












Partially correct — you recognized the rolling-window idea, but the grain is wrong in two places.
The question is asking for one row per calendar day, not one row per customer visit. And the 7-day window is for the restaurant overall, so you should not partition by customer_id.
The other important point is that there may be multiple customer rows on the same visited_on, so first you need to collapse them to:
one row per day → daily total amount

Then apply the 7-day window over those daily totals.
A clean approach is:
WITH daily AS (
    SELECT
        visited_on,
        SUM(amount) AS daily_amount
    FROM Customer
    GROUP BY visited_on
),
rolling AS (
    SELECT
        visited_on,
        SUM(daily_amount) OVER (
            ORDER BY visited_on
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ) AS amount,
        AVG(daily_amount) OVER (
            ORDER BY visited_on
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ) AS average_amount,
        ROW_NUMBER() OVER (
            ORDER BY visited_on
        ) AS rn
    FROM daily
)
SELECT
    visited_on,
    amount,
    ROUND(average_amount, 2) AS average_amount
FROM rolling
WHERE rn >= 7
ORDER BY visited_on;

Your exact misses were:
Output grain should be one row per day
Aggregate to daily totals first
No PARTITION BY customer_id
Average should be over daily totals, not individual transactions

Your good instinct was:
7-day rolling window → current row + 6 preceding

That part was right.
For history:
- Pattern: pre-aggregate to correct grain → rolling window
- Mistake: wrong grain and wrong partition
- Status: Needs Revisit





    







so we took sum(daily_amount) at visited level and then again sumed it so we get daily level amont ?












Almost. The sequence is:
First, we calculate one total per day:
SELECT
    visited_on,
    SUM(amount) AS daily_amount
FROM Customer
GROUP BY visited_on

So if 10 customers visited on the same day, those 10 rows become one row for that date with the day’s total.
Then we apply another SUM() as a window over those daily totals:
SUM(daily_amount) OVER (
    ORDER BY visited_on
    ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
)

That second SUM() is not creating daily amount again. It is creating the 7-day rolling total.
So think:
raw customer transactions → daily total → 7-day rolling total

Example:
Jan 1 daily_amount = 100
Jan 2 daily_amount = 200
Jan 3 daily_amount = 150
...

Then on Jan 7:
rolling amount = Jan1 + Jan2 + ... + Jan7

And AVG(daily_amount) gives the average daily revenue across those 7 days.
That two-step grain change is the important pattern here.





LeetCode SQL 50 — Question 17/50
Let’s do another medium one: Product Price at a Given Date.
Table: Products
Column Name	Type
product_id	int
new_price	int
change_date	date


Each row shows that a product’s price changed to new_price on change_date.
Write a query to find the price of each product on 2019-08-16.
Assume every product had an initial price of 10 before any change.
Give me:
Output grain → one-line approach → SQL





    







output grain  - one row per product 
approach - we use case when statement and if change_date > 2019-08-16 then new price else 10

select product_id , sum(Case when change_date > 2019-08-16 then new_price else 10 end) as price
from products
group by product_id












Not correct yet — the main issue is the date logic.
You said:
if change_date > 2019-08-16 then new price else 10

But we need the price on 2019-08-16, so we care about the latest price change on or before 2019-08-16.
Example:
product 1:
2019-08-10 → 20
2019-08-14 → 30
2019-08-20 → 50

Price on Aug 16 = 30, not 10 and not 50.
So the pattern is:
latest row per product where change_date <= target_date

If no such row exists → default price = 10.
A clean solution:
WITH cte AS (
    SELECT
        product_id,
        new_price,
        ROW_NUMBER() OVER (
            PARTITION BY product_id
            ORDER BY change_date DESC
        ) AS rn
    FROM Products
    WHERE change_date <= '2019-08-16'
),
all_products AS (
    SELECT DISTINCT product_id
    FROM Products
)
SELECT
    p.product_id,
    COALESCE(c.new_price, 10) AS price
FROM all_products p
LEFT JOIN cte c
    ON p.product_id = c.product_id
   AND c.rn = 1;

Your SUM(CASE...) approach doesn't work because a product may have multiple historical price changes, and we don't want to add prices together. We want the single latest applicable row.
Assessment
- Output grain: ✅ one row per product
- Pattern selection: ❌
- Main mistake: treated this as conditional aggregation instead of latest row before/equal date
- Status: Needs Revisit
Memory rule:
Value as of a date → filter <= date → order descending → take latest row.





###############################################
PATTERN REINFORCEMENT

CHEAT SHEET :
Pattern	What it means	Typical clue in question	Usual SQL idea
1. First/last row + condition	Condition must be checked only on the first/latest record, not all records	“first order was…”, “latest transaction is…”	isolate row first with ROW_NUMBER() / MIN-MAX, then apply condition
2. Pre-aggregate → window	Raw data grain is too detailed, so summarize first, then run rolling/window logic	“daily total”, “7-day average”, “monthly rolling”	GROUP BY date first → then SUM() OVER(...)
3. Value as of a date	Find the latest value that was valid on/before a target date	“price on 2019-08-16”, “status as of date”	filter date <= target → order DESC → take latest row
4. Consecutive dates	Need actual calendar continuity, not merely previous available record	“3 consecutive days”, “logged in next day”	LAG() + DATEDIFF(...)=1
5. Has all required items	Entity must contain every item from another required set	“bought all products”, “completed all courses”	GROUP BY entity + COUNT(DISTINCT item) = total required
6. Same entity in two columns	One entity can appear in either side/role of a relationship	requester/accepter, caller/receiver	UNION ALL both columns into one column → aggregate
7. Duplicate one thing + unique combination	Need rows satisfying two independent frequency conditions	duplicate value but unique (x,y) pair	separate GROUP BY ... HAVING checks, then filter original rows
8. Choose MIN/MAX vs ROW_NUMBER vs DENSE_RANK	Different “first/latest/Nth” questions need different tools	earliest date, full earliest row, tied earliest rows	value only → MIN/MAX; one full row → ROW_NUMBER; all ties → RANK/DENSE_RANK


The most important distinction to remember is:
Ask what exact row/grain the final condition belongs to before writing SQL.

For example:
- “first order was immediate” → first isolate first order
- “7-day restaurant revenue” → first get one row per day
- “price on a date” → latest valid row on/before that date
- “all products” → compare distinct possessed items with total required items
And one compact memory line for pattern 8:
Value only = aggregate, one row = ROW_NUMBER, all tied rows = RANK/DENSE_RANK.




########################## 30/09/ 2026
output grain - one row per customer who satisfy the condition
appraoch - since we need latest order per customer we do a row number and filter with status='cancelled'

with cte as (
select status,customer_id , row_number () over (partition by customer_id order by order_Date desc) as rn
from orders
)
select customer_id from cte
where status='cancelled' and rn=1
Correct. ✅

Output grain: one row per qualifying customer ✅
Pattern: latest row per customer + apply condition on that row ✅
Function choice: ROW_NUMBER() is correct because we need the single latest row ✅
SQL: correct ✅
Your query:

WITH cte AS (
    SELECT
        status,
        customer_id,
        ROW_NUMBER() OVER (
            PARTITION BY customer_id
            ORDER BY order_date DESC
        ) AS rn
    FROM Orders
)
SELECT customer_id
FROM cte
WHERE status = 'cancelled'
  AND rn = 1;

Pattern status
First/last row + condition → Clear

Revision Q2/8
Table: Sales

sale_id
product_id
sale_date
amount
Return:

product_id
sale_date
amount
for all sales rows that happened on each product’s latest sale date.

A product can have multiple sales on the same latest date, and all of them must be returned.

Give me:

Output grain → one-line approach → SQL

output grain - one or more row per sales satsifying the condition
appraoch - we need latest sales and use dense rank 

with cte as (
select product_id, sale_date,amount,dense_rank() over (order by product_id order by sale_date desc) as rn
from sales
)
select product_id , sale_date,amount
from cte where rn=1
Conceptually correct. ✅ You picked the right pattern: because all sales tied on the latest date must be returned, DENSE_RANK() is appropriate.

The only issue is the window syntax. You wrote:

DENSE_RANK() OVER (
    ORDER BY product_id
    ORDER BY sale_date DESC
)

You need PARTITION BY product_id:

WITH cte AS (
    SELECT
        product_id,
        sale_date,
        amount,
        DENSE_RANK() OVER (
            PARTITION BY product_id
            ORDER BY sale_date DESC
        ) AS rn
    FROM Sales
)
SELECT
    product_id,
    sale_date,
    amount
FROM cte
WHERE rn = 1;

And your output grain is better stated as:

One row per sale record occurring on that product’s latest sale date.

Pattern status
All tied latest rows → Clear

Memory line:

Need all rows tied on earliest/latest date → RANK() or DENSE_RANK().

Revision Q3/8
Table: Logins

user_id
login_date
Return each user_id who logged in on 3 consecutive calendar days at least once.

Return each qualifying user only once.

Give me:

Output grain → one-line approach → SQL

output grain - one record per user who satisfy the condition
appraoch - we use the lag function and datediff to check for consecutive calendar day

with cte as (
select user_id , login_date,lag(login_date,1) over (partition by user_id order by login_date) as lag_1,lag(login_date,2) over (partition by user_id order by login_date) as lag_2
from logins
)
select user_id from cte
where datediff(login_date,lag_1)=1 and datediff(lag_1,lag_2)=1
Almost perfect. ✅ The consecutive-day logic itself is correct.

Only one fix: because a user could have more than one qualifying 3-day streak, use DISTINCT in the final output.

WITH cte AS (
    SELECT
        user_id,
        login_date,
        LAG(login_date, 1) OVER (
            PARTITION BY user_id
            ORDER BY login_date
        ) AS lag_1,
        LAG(login_date, 2) OVER (
            PARTITION BY user_id
            ORDER BY login_date
        ) AS lag_2
    FROM Logins
)
SELECT DISTINCT user_id
FROM cte
WHERE DATEDIFF(login_date, lag_1) = 1
  AND DATEDIFF(lag_1, lag_2) = 1;

So:

Output grain: ✅
Pattern recognition: ✅
Exact date-gap logic: ✅
Minor miss: DISTINCT
Pattern status
Consecutive calendar dates → Clear

Memory line:

3 consecutive dates → current-prev = 1 AND prev-prev2 = 1

Ready for Revision Q4/8.

ok
Revision Q4/8
Table: StudentCourse

student_id
course_id
Table: RequiredCourse

course_id
Return every student_id who has completed all required courses.

A student may have duplicate rows for the same course.

Give me:

Output grain → one-line approach → SQL

output grain - one row per student satisfying condition
approach - we count course per student and count of courses and return who satify condition using group by + having 

select student_id , count(distinct course_id) as course_count
from studentcourse
group by student_id 
having course_count=(select count(*) from requiredcourse)
Correct. ✅

You got the important part right:

COUNT(DISTINCT course_id)

That handles duplicate course rows correctly.

A slightly safer version is:

SELECT student_id
FROM StudentCourse
GROUP BY student_id
HAVING COUNT(DISTINCT course_id) = (
    SELECT COUNT(*)
    FROM RequiredCourse
);

I’d avoid relying on the alias course_count inside HAVING, because some SQL dialects do not allow that consistently.

Pattern status
Has all required items → Clear

Memory line:

Group by entity → count distinct owned items → compare with total required items.


output grian = one row per employee satisfying condition
appraoch -filter valid history rank latest role keep rn=1 left join to all roles and default if missing

select employee_id , role_name,row_number() over (partition  by employee_id order by effective_Date desc) as rn
from employeerole
where effective_Date ='2026-09-05'
),
all_roles as (
select distinct role_name from employeerole
)
select cte.employee_id,coalesce(cte.role_name,'unassigned') as role
from cte c left join all_roles r
on r.emplouee_id = c.employee_id and r.rn=1
You remembered the right pattern, but the SQL construction got mixed up. The biggest issue is that the “all entities” CTE should contain all employees, not all roles.

Your intended logic was right:

filter valid history → rank latest row → keep rn = 1 → left join to all employees → default missing role

But these parts need fixing:

Target date should be <= '2026-09-25', not = '2026-09-05'
You need a WITH cte AS ( at the start
all_roles should actually be all employees
all_roles only selected role_name, so it cannot join on employee_id
rn belongs to the ranked CTE, not the all-employees CTE
In the final SELECT, use the employee ID from the left/base table so employees with no valid historical role are preserved
Correct version:

WITH cte AS (
    SELECT
        employee_id,
        role_name,
        ROW_NUMBER() OVER (
            PARTITION BY employee_id
            ORDER BY effective_date DESC
        ) AS rn
    FROM EmployeeRole
    WHERE effective_date <= '2026-09-25'
),
all_employees AS (
    SELECT DISTINCT employee_id
    FROM EmployeeRole
)
SELECT
    e.employee_id,
    COALESCE(c.role_name, 'Unassigned') AS role_name
FROM all_employees e
LEFT JOIN cte c
    ON e.employee_id = c.employee_id
   AND c.rn = 1;

Assessment
Your pattern recall is now correct. The remaining issue is SQL assembly, not understanding.

Memory line:

As-of date = filter <= target → latest row per entity → join back to all entities → COALESCE default.

I’d still do one more quick one for this pattern before marking it clear.

will mark this as revist lets move
Yep — marking Q7 “as-of date” as Revisit.

Revision Q8/8
Table: Orders

order_id
customer_id
order_date
amount
Return:

customer_id
order_date
amount
for each customer’s latest order.

Assume each customer has exactly one latest order.

Give me:

Output grain → one-line approach → SQL

output grain - one row per customer 
approach - since we need for latest customer use row numebr

with cte as (
select customer_id , order_date , amount , row_number () over (partition by customer_id order by order_date desc) as rn
from orders 
)
Select customer_id , order_date , amount
from cte
where rn=1
Correct. ✅

This is exactly the right pattern:

WITH cte AS (
    SELECT
        customer_id,
        order_date,
        amount,
        ROW_NUMBER() OVER (
            PARTITION BY customer_id
            ORDER BY order_date DESC
        ) AS rn
    FROM Orders
)
SELECT
    customer_id,
    order_date,
    amount
FROM cte
WHERE rn = 1;

So for Q8:

Need the full latest row → use ROW_NUMBER() per entity ordered by date DESC.

Revision result
You’re clear on most of the 8 patterns. The one we should explicitly carry forward as Revisit is:

As-of date / latest valid row on or before a target date

You also had a few minor execution slips today around GROUP BY, DISTINCT, and composite counts, but the underlying patterns were mostly recognized correctly.

Next time we can do a very short 3-question revisit focused on the remaining weak spots, then continue from LeetCode 18/50.

yes
Great. We’ll do a 3-question mini-revisit first, focused only on the remaining weak spots, then continue with fresh LeetCode from 18/50.

Mini-Revisit Q1/3
Table: ProductStatus

product_id
status
effective_date
Return each product’s status as of 2026-09-18.

Rules:

Use the latest status row on or before 2026-09-18.
If a product has no status row on or before that date, return 'Unknown'.
Give me:

Output grain → one-line approach → SQL

output grain - one row per product 
Appraoch - filter valid histroy -> apply rn 1 -> left join for all -> default for missing

with cte as (
select product_id , status , row_number () over (partition by product_id order effective_Date desc) as rn
from productstatus
where effective_date <='2026-09-18'),
all_prods as (
select distinct product_id from productstatus
)
select product_id , coalesce(c.status,'unknown') from cte
left join all_prods p on 
c.product_id=p.product_id and c.rn=1
You remembered the pattern much better this time. ✅ The concept is right; the remaining issues are just SQL construction.

Your intended flow is correct:

filter valid history → rank latest row → keep rn = 1 → left join from all products → default if missing

Fixes needed:

ORDER effective_date DESC → ORDER BY effective_date DESC
the LEFT JOIN direction should start from all products, because that is the set we must preserve
select p.product_id, not the ID from the filtered CTE
Correct version:

WITH cte AS (
    SELECT
        product_id,
        status,
        ROW_NUMBER() OVER (
            PARTITION BY product_id
            ORDER BY effective_date DESC
        ) AS rn
    FROM ProductStatus
    WHERE effective_date <= '2026-09-18'
),
all_prods AS (
    SELECT DISTINCT product_id
    FROM ProductStatus
)
SELECT
    p.product_id,
    COALESCE(c.status, 'Unknown') AS status
FROM all_prods p
LEFT JOIN cte c
    ON p.product_id = c.product_id
   AND c.rn = 1;

Assessment
Pattern recognition: ✅
<= target date: ✅
latest-row ranking: ✅
default fallback: ✅
join direction/base table: ⚠️
syntax: minor slip
I’d mark this Almost Clear, not fully Revisit anymore.

Memory line:

The table that must preserve every entity goes on the LEFT side of the LEFT JOIN.


Reinforcement — Consecutive Same Values
Table: SensorReadings
reading_id
sensor_id
status

reading_id defines the order of readings.
Return every status that appears in 4 consecutive readings at least once.
Example:
reading_id | status
1          | OK
2          | FAIL
3          | FAIL
4          | FAIL
5          | FAIL
6          | OK

Here FAIL qualifies.
Give me:
Output grain → one-line approach → SQL





    







output - one row per status
appraoch - use lag and see if a status appears 4 times

with cte as (
select reading_id , status , lag(status,1) over (order by reading_id) as lag_1,
lag(status,2) over (order by reading_id) as lag_2,
lag(status,3) over (order by reading_id) as lag_3
from sensorreadings
)
select reading_id from cte
where status=lag_1 and lag_1=lag_2 and lag_2=lag_3












Conceptually correct. ✅ You fixed the main mistake from the LeetCode question:
- ordered by the actual sequence column reading_id ✅
- compared the status values directly ✅
- used 3 lags for a 4-row streak ✅
Only the final output is wrong. The question asks for the qualifying status, not reading_id.
Also use DISTINCT, because the same status could form multiple overlapping 4-row streaks.
WITH cte AS (
    SELECT
        reading_id,
        status,
        LAG(status, 1) OVER (ORDER BY reading_id) AS lag_1,
        LAG(status, 2) OVER (ORDER BY reading_id) AS lag_2,
        LAG(status, 3) OVER (ORDER BY reading_id) AS lag_3
    FROM SensorReadings
)
SELECT DISTINCT status
FROM cte
WHERE status = lag_1
  AND lag_1 = lag_2
  AND lag_2 = lag_3;

Pattern status
Consecutive same value in ordered rows → Clear
Memory line:
Order by sequence column → compare values for equality → DISTINCT qualifying value.






    







ok next












LeetCode SQL 50 — Question 19/50
Department Top Three Salaries
Table: Employee
id
name
salary
departmentId

Table: Department
id
name

Return the employees who earn one of the top three distinct salaries in their department.
Output:
- Department
- Employee
- Salary
Important: if multiple employees have the same salary, include all of them.
Give me:
Output grain → one-line approach → SQL





    







output grain - one row per employee who satisfy the condition
appraoch - we use dense rank here since there can be more than one employee earning same sal within dept in top 3

with cte as (
select d.name as department , e.name as employee , e.salary as salary, dense_rank(0 over (partition by d.name order by e.salary desc) as rn
from employee e join department d on 
e.id=d.id
)
select department,employee,salary
from cte 
where rn<=3












Your pattern choice is correct. ✅ DENSE_RANK() is exactly right because the problem asks for the top 3 distinct salaries and wants all employees tied at those salary levels.
There are two SQL mistakes:
1. Syntax typo:
dense_rank(0

should be:
DENSE_RANK()

2. The join condition is wrong. You wrote:
e.id = d.id

but Employee.departmentId links to Department.id.
Correct query:
WITH cte AS (
    SELECT
        d.name AS Department,
        e.name AS Employee,
        e.salary AS Salary,
        DENSE_RANK() OVER (
            PARTITION BY e.departmentId
            ORDER BY e.salary DESC
        ) AS rn
    FROM Employee e
    JOIN Department d
        ON e.departmentId = d.id
)
SELECT
    Department,
    Employee,
    Salary
FROM cte
WHERE rn <= 3;

Assessment:
- Output grain: ✅
- Pattern recognition: ✅
- DENSE_RANK() choice: ✅
- Tie handling: ✅
- Join condition: ❌
- Minor syntax typo: ⚠️
Memory line:
Top N distinct values within a group → DENSE_RANK() partitioned by the group.

LeetCode SQL 50 — Question 20/50
Monthly Transactions I
Table: Transactions
id
country
state
amount
trans_date

state is either 'approved' or 'declined'.
For each month and country, return:
- month in YYYY-MM format
- country
- total number of transactions
- total amount of transactions
- number of approved transactions
- total amount of approved transactions
Give me:
Output grain → one-line approach → SQL





    







output grain - one row per month and country satisfying conditon
appraoch - we use the case statement along with group by 

with cte as (
select month,country , state , count(*) as total_trans,sum(amount) as total_amount , sum(case when status='approved' then 1 else 0 end) as no_approved,sum(Case when status='approved' then amount else 0 end) as approved_amount
from transactions
group by month,country
)select dateformat(month,'%YYYY-MM%') as month , country , total_trans,total_amount,no_approved,approved_amount
from cte












Your pattern is correct — this is conditional aggregation grouped by month + country. ✅
The main issues are column/syntax related:
- There is no month column; derive it from trans_date.
- Column is state, not status.
- MySQL format should be '%Y-%m', not '%YYYY-MM%'.
- Since you’re already aggregating, the CTE is unnecessary.
Clean version:
SELECT
    DATE_FORMAT(trans_date, '%Y-%m') AS month,
    country,
    COUNT(*) AS trans_count,
    SUM(amount) AS trans_total_amount,
    SUM(CASE WHEN state = 'approved' THEN 1 ELSE 0 END) AS approved_count,
    SUM(CASE WHEN state = 'approved' THEN amount ELSE 0 END) AS approved_total_amount
FROM Transactions
GROUP BY
    DATE_FORMAT(trans_date, '%Y-%m'),
    country;

Assessment
- Output grain: ✅
- Pattern recognition: ✅
- Conditional aggregation: ✅
- Grouping idea: ✅
- Column/date-format syntax: ⚠️
So I’d mark this Clear conceptually.
Memory line:
Grouped totals + conditional totals → GROUP BY + SUM(CASE WHEN ... THEN ... END)

Ready for LeetCode 21/50.


if i have a table with cols emp id , emp_name , mnth_salary 
i have to find list off employees with salary greater than annual salary of any employees 

output grain - one record per employee satisfying the condition 
approach - i already have monthly salary , i will calculate annual salary per employee using sum() windows function and then just compare if salary > annual sal 

with cte as (
select employee_id , salary , sum(salary) over (partition by employee_id) as annual_sal
from employees
)
select employeee_id from cte
where salary > annual_sal

now here ignore col name just focus on logic for noww
Your current logic is not correct for this requirement.

The key thing is the word “any employee”.

If the table has one row per employee with monthly salary, then annual salary is simply:

monthly_salary * 12

You do not need:

SUM(salary) OVER (PARTITION BY employee_id)

because if there is only one row per employee, that sum is just the same monthly salary.

Also, this:

WHERE salary > annual_sal

compares each employee's monthly salary against their own annual salary. Naturally, monthly salary will almost never be greater than its own annual salary.

The requirement is:

Find employees whose monthly salary is greater than the annual salary of at least one other employee.

So conceptually:

Employee monthly salary
>
ANY employee's annual salary
And greater than any / at least one is equivalent to:

monthly salary > minimum annual salary

So the simplest logic is:

SELECT employee_id
FROM Employees
WHERE monthly_salary > (
    SELECT MIN(monthly_salary * 12)
    FROM Employees
);

Pattern to remember
Greater than ANY / at least one → compare against MIN

Greater than ALL → compare against MAX

Example:

A monthly = 100,000 → annual = 1,200,000
B monthly = 20,000  → annual =   240,000
C monthly = 30,000  → annual =   360,000
For A:

100,000 > 240,000 ❌
So even A doesn't qualify here.

Your main mistake was not the window function itself; it was comparing each employee against their own annual salary instead of comparing against annual salaries across employees.

ahh keep this to revisit and also concept
Yes — I’ll keep both the question type and the concept in the revisit bucket.

Revisit concept:

Compare against ANY / ALL

Key memory rule:

Greater than ANY / at least one → compare against the MIN
Greater than ALL → compare against the MAX
The comparison must be against other rows / the population, not the same employee’s own derived value.
And the specific mistake to revisit:

You used a window to derive each employee’s own annual salary, then compared monthly salary to that same employee’s annual salary.

We’ll include this in the next revision set before moving much further.

