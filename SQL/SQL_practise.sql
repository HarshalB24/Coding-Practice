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

output grain - one record per employee satisfying the condition
comparison - salary compared with aggregate / avg salary of their department
pattern - we use a subquery to just say salary > avg(salary) using the window function we can also do using subquery
Yes — your reasoning is correct. ✅

Sharper version:

Output grain: one row per employee who qualifies
Comparison: employee salary vs average salary of that employee’s own department
Pattern: row value vs group aggregate

Two valid implementation patterns:

Window aggregate: AVG(salary) OVER (PARTITION BY department_id)
Correlated subquery: compare each employee to AVG(salary) for the same department
For interviews, the window version is often cleaner because it preserves row-level detail while attaching the department average to every employee.

So your pattern recognition here is clear.

Now write the SQL.

with cte as (
select employee_id , salary , avg(salary) over (partition by department_id) as avg_sal
from employees)
select employee_id from cte
where salary > avg_sal

alternative 2 : 
select employee_id ,salary from employees
group by department_id 
where salary > (select avg(salary) from employees)
Your first solution is correct. ✅

WITH cte AS (
    SELECT
        employee_id,
        salary,
        AVG(salary) OVER (
            PARTITION BY department_id
        ) AS avg_sal
    FROM Employees
)
SELECT employee_id
FROM cte
WHERE salary > avg_sal;

That matches the pattern perfectly:

row value vs group aggregate → window aggregate

Your second solution is not correct.

SELECT employee_id, salary
FROM Employees
GROUP BY department_id
WHERE salary > (SELECT AVG(salary) FROM Employees)

There are two issues:

WHERE comes before GROUP BY
more importantly, (SELECT AVG(salary) FROM Employees) gives the company-wide average, not that employee’s department average
The correct correlated-subquery version would be:

SELECT
    e.employee_id,
    e.salary
FROM Employees e
WHERE e.salary > (
    SELECT AVG(e2.salary)
    FROM Employees e2
    WHERE e2.department_id = e.department_id
);

Pattern takeaway
Row vs its own group aggregate

Window: AVG(...) OVER (PARTITION BY group)
Correlated subquery: aggregate filtered to the outer row’s group
Don’t compare against a global aggregate unless the question asks for company-wide/global comparison
I’d mark this pattern Clear.

ahh yeah self join
Yes — conceptually it’s the same “compare a row to its own group” idea.

A correlated subquery is often easier than a self-join for this:

SELECT e.employee_id, e.salary
FROM Employees e
WHERE e.salary > (
    SELECT AVG(e2.salary)
    FROM Employees e2
    WHERE e2.department_id = e.department_id
);

A true self-join approach is also possible, but for an average comparison it usually becomes more verbose because you still need to aggregate the joined rows.

So for interviews, remember:

Row vs own-group aggregate → window function first choice, correlated subquery second choice.

ok
Question 3/3 — New interview-style pattern
Table: Orders

order_id
customer_id
order_date
amount
Return the customers whose latest order amount is greater than their own average order amount.

For now, do not write SQL.

Give me only:

Output grain → what exactly is being compared → pattern

output grain - one record per customer satisfying the condtioin
comparison - customers order amount vs customers own avg amount
pattern - same we can do using row number and avg window function
Yes — correct. ✅

Sharper framing:

Output grain: one row per qualifying customer
Comparison: latest order amount vs that same customer’s average order amount
Pattern: latest-row identification + group-level aggregate on the same entity

The cleanest way is to calculate both in one CTE:

WITH cte AS (
    SELECT
        customer_id,
        amount,
        ROW_NUMBER() OVER (
            PARTITION BY customer_id
            ORDER BY order_date DESC
        ) AS rn,
        AVG(amount) OVER (
            PARTITION BY customer_id
        ) AS avg_amount
    FROM Orders
)
SELECT customer_id
FROM cte
WHERE rn = 1
  AND amount > avg_amount;

This is a useful combined pattern because it mixes two ideas:

latest row per entity + row vs own-group aggregate

That’s exactly the kind of compound logic product-company DE interviews can test.


############################ 10/05/2026 #############
with cte c as (
select c.account_id,c.status,c.effective_date, row_number() over (partition by c.account_id order by c.effective_date desc) as rn
from accountstatus
where effective_date < = '2026-09-30'
)
with cte_2 c2 as (
select c.account_id from accountstatus
)
select account_id , coalesce(status,'unknown') as status
from cte left join cte 2 on 
c.account_id=c2.account_id and rn=1
Pattern recognition was correct, but the SQL assembly still needs work. This is exactly why this pattern is still in the revisit bank.

Main fixes:

CTE syntax is WITH cte AS (...), not WITH cte c AS (...).
You define multiple CTEs in one WITH, separated by commas.
cte_2 should contain distinct account IDs.
Most importantly, the all-accounts CTE must be on the left side of the LEFT JOIN so accounts with no valid historical status are preserved.
rn = 1 belongs to the ranked CTE side of the join.
Correct version:

WITH cte AS (
    SELECT
        account_id,
        status,
        effective_date,
        ROW_NUMBER() OVER (
            PARTITION BY account_id
            ORDER BY effective_date DESC
        ) AS rn
    FROM AccountStatus
    WHERE effective_date <= '2026-09-30'
),
cte_2 AS (
    SELECT DISTINCT account_id
    FROM AccountStatus
)
SELECT
    c2.account_id,
    COALESCE(c.status, 'Unknown') AS status
FROM cte_2 c2
LEFT JOIN cte c
    ON c2.account_id = c.account_id
   AND c.rn = 1;

Assessment
Pattern identification: ✅
<= target date: ✅
ROW_NUMBER() + descending date: ✅
Default fallback idea: ✅
Preserve-all-entities join direction: ❌
CTE syntax/assembly: ❌
So I’d mark this pattern Improving, not Stable yet.

The key thing to drill is:

The population you must preserve goes on the LEFT side of the LEFT JOIN.

Let’s do another mixed question next, not another as-of-date one immediately.

ok
Mixed Pattern Drill — Q2
Table: EmployeeSalary

employee_id
department_id
salary
Return the employees whose salary is greater than every employee in department 20.

For now, do not write SQL.

Give me only:

Output grain → what exactly is being compared → pattern

we will do 10 questions today u decide which but we will stop there
Got it. Exactly 10 questions today, then we stop.

I’ll choose a mixed set from your current pattern bank so we test recognition, not memorization. We’ll keep the same flow:

Output grain → comparison/relationship → pattern
then you write SQL only after I validate the reasoning.

We’re currently on Q2/10.

Q2/10
Table: EmployeeSalary

employee_id
department_id
salary
Return the employees whose salary is greater than every employee in department 20.

For now, do not write SQL.

Give me only:

Output grain → what exactly is being compared → pattern

output grain - one record per employee satisfying the condtiion
comparison - salary of employee against salary of every employee in dept 20
pattern - using max and subquery
Correct. ✅

Sharper framing:

Output grain: one row per employee who qualifies
Comparison: each employee’s salary vs the set of salaries in department 20
Pattern: ALL / every one → compare against the maximum salary in that set
So the clean mental shortcut is:

greater than every employee in dept 20
= salary > MAX(salary) of dept 20

Your pattern recognition is correct.

Now write the SQL.

select employee_id , salary from employeesalary
where department_id=20 
and salary > (select max(salary) from employeesalary group by department_id )
Close, but there are two logic mistakes.

Your pattern recognition was right: greater than every employee in department 20 → compare against the maximum salary in department 20.

The problems are:

This outer filter is wrong:
WHERE department_id = 20

That restricts the result to employees inside department 20. The question asks for employees whose salary is greater than everyone in department 20, regardless of their own department.

Your subquery:
SELECT MAX(salary)
FROM EmployeeSalary
GROUP BY department_id

returns one maximum per department, not specifically department 20. We need one scalar value.

Correct query:

SELECT
    employee_id,
    salary
FROM EmployeeSalary
WHERE salary > (
    SELECT MAX(salary)
    FROM EmployeeSalary
    WHERE department_id = 20
);

Assessment
Output grain: ✅
Pattern recognition (ALL → MAX): ✅
Population being compared against: ⚠️ implementation mistake
Subquery scope: ❌
Memory rule:

The filter that defines the comparison population belongs inside the subquery.

So this pattern is Improving, not fully stable yet.

Ready for Q3/10.

but u only said greater than every employee in dept 20
Yes — exactly. The phrase:

“employees whose salary is greater than every employee in department 20”

means:

take all employees as candidates, and compare each candidate’s salary against the salaries of employees in department 20.

So department_id = 20 defines the comparison set, not the output set.

That’s why it belongs inside the subquery:

WHERE salary > (
    SELECT MAX(salary)
    FROM EmployeeSalary
    WHERE department_id = 20
)

If I had said:

“employees in department 20 whose salary is greater than every other employee in department 20”

then the outer rows would also be department 20 — but that becomes a different question.

So your confusion is valid; the important lesson is:

Who are we returning? vs Who are we comparing against?

Those can be different populations.

Table: Orders
order_id
customer_id
order_date
amount

Return the customers whose latest order amount is greater than their own average order amount.
For now, do not write SQL.
Give me only:
Output grain → what exactly is being compared → pattern





    







output grain - one row per customer satisffying the condition
comp - latest order value against their own avg order amount
pattern - row number and filter condtiion












Correct direction. ✅
Sharper framing:
- Output grain: one row per qualifying customer
- Comparison: that customer’s latest order amount vs that same customer’s average order amount
- Pattern: combine latest-row identification + own-group aggregate
So the clean pattern is:
ROW_NUMBER() to identify latest order  
- AVG(amount) OVER (PARTITION BY customer_id) to attach each customer’s average
- filter rn = 1 AND amount > avg_amount

Your reasoning is good; just remember the second half of the pattern is not only “filter condition” — it is specifically row vs own-group aggregate.
Now write the SQL.





    







with cte as (
select customer_id , order_id , order_Date , amount , row_number() over (partition by customer_id order by order_date desc ) as rn , avg(amount) over (partition by customer_id ) as avg_amount
from orders
)
select customer_id , amount from cte
where amount > avg_amount and rn=1












Correct. ✅
Your query matches the requirement cleanly:
WITH cte AS (
    SELECT
        customer_id,
        order_id,
        order_date,
        amount,
        ROW_NUMBER() OVER (
            PARTITION BY customer_id
            ORDER BY order_date DESC
        ) AS rn,
        AVG(amount) OVER (
            PARTITION BY customer_id
        ) AS avg_amount
    FROM Orders
)
SELECT
    customer_id,
    amount
FROM cte
WHERE rn = 1
  AND amount > avg_amount;

Assessment
- Output grain: ✅
- Latest-row logic: ✅
- Own-group average: ✅
- Combined pattern recognition: ✅
- SQL: ✅
Pattern status
Latest row + own-group aggregate → Stable
Memory line:
Attach group metric with a window, identify target row with another window, then compare in the outer query.

Ready for Q4/10.





    







yes












Q4/10
Table: Payments
payment_id
customer_id
payment_date
amount

Return the customers whose total payment amount in 2026 is greater than the average total payment amount across all customers in 2026.
For now, do not write SQL.
Give me only:
Output grain → what exactly is being compared → pattern





    







output grain - one row per customer satisfying condition
comp - customers total amount of 2026 greater than avg total payment for all customer in 2026
pattern - we use windows function here to get total amount per customer in 2026 and avg for all customers and compare












Your reasoning is mostly correct, but I want to tighten the pattern because this one has a subtle grain change.
The comparison is:
each customer’s 2026 total
vs
the average of those customer-level totals

So the safest mental model is:
first aggregate to one row per customer → then compare those customer totals against the average of customer totals

A window function can absolutely be used, but only after you have customer-level totals.
So the pattern is:
group-level aggregate → aggregate over those grouped results

This is slightly different from:
row vs own-group aggregate

because here both sides of the comparison are already customer-level aggregates.
A clean approach is:
filter 2026 → SUM(amount) per customer → AVG(total_amount) across customers → compare

Your reasoning is accepted. Now write the SQL.





    







with cte as (
select customer_id , sum(amount) as total_amount , avg(amount) as avg_amount
from payments
where year(payment_date)=2026
group by customer_id
)
select customer_id from cte
where total_amount > avg_amount












Close — but the second aggregation level is wrong.
You correctly got:
SUM(amount) AS total_amount

per customer.
But this:
AVG(amount) AS avg_amount

calculates the average individual payment for that customer, not the average customer total across all customers.
The requirement is:
customer 2026 total
vs
average of all customers’ 2026 totals

So you need to first create customer totals, then average those totals:
WITH cte AS (
    SELECT
        customer_id,
        SUM(amount) AS total_amount
    FROM Payments
    WHERE YEAR(payment_date) = 2026
    GROUP BY customer_id
),
cte2 AS (
    SELECT
        customer_id,
        total_amount,
        AVG(total_amount) OVER () AS avg_customer_total
    FROM cte
)
SELECT customer_id
FROM cte2
WHERE total_amount > avg_customer_total;

Exact mistake
You averaged at the payment-row level instead of the customer-total level.
Memory rule:
If the question says “average of customer totals,” first create the customer totals, then average those totals.

Pattern status
Aggregate of aggregates / grain transition → Needs Revisit
This is a good one to keep in the revisit bank.

Table: ContestRegistrations
contest_id
user_id

Table: Users
user_id

Return each contest_id whose registration percentage is greater than the average registration percentage across all contests.
For now, do not write SQL.
Give me only:
Output grain → what exactly is being compared → pattern





    







output grain - one row per contest id satisfying the condtiion
cmop - id of contest with avg % of registration across all
pattern - find total contest then avg registration % and then compare boht












Close, but the comparison needs to be stated more precisely.
- Output grain: one row per qualifying contest_id ✅
- Comparison: each contest’s registration percentage vs the average of the registration percentages of all contests
- Pattern: this is a two-stage aggregate:
  1. calculate each contest’s percentage = registered users in contest / total users overall
  2. calculate the average of those contest-level percentages
  3. compare each contest percentage against that average
The key thing is: do not average raw registration rows. First get one percentage per contest, then average those percentages.
So the pattern is:
group-level metric → global average of that metric → compare

Your reasoning is close, but I’d tighten it to that before writing SQL.
Now write the SQL.





    







with cte as (
Select c.contest_id,count(c.user_id) as registerd_user ,count(u.user_id) as total_users
from contestregistrations c join users u on 
c.user_id=u.user_id
group by c.contest_id
)
, cte_2 as (
select c.contest_id , (registered_user/total_users) as contest_reg_perc , avg(contest_reg_perc) as reg
from cte
)
select c.contest_id 
from cte_2
where contest_reg_perc > reg












You’ve got the right high-level structure, but the denominator and second-stage average are still off.
The biggest issue is here:
COUNT(u.user_id) AS total_users

Because you joined Users to registrations and grouped by contest, that count becomes the number of users registered in that contest, not the total number of users overall.
For each contest, the denominator should be the same global value:
(SELECT COUNT(*) FROM Users)

Then in the next step, you need the average of the contest percentages, so use a window over the already-calculated contest-level percentages.
A clean version is:
WITH cte AS (
    SELECT
        contest_id,
        COUNT(user_id) * 100.0 /
        (SELECT COUNT(*) FROM Users) AS contest_reg_perc
    FROM ContestRegistrations
    GROUP BY contest_id
),
cte_2 AS (
    SELECT
        contest_id,
        contest_reg_perc,
        AVG(contest_reg_perc) OVER () AS avg_reg_perc
    FROM cte
)
SELECT contest_id
FROM cte_2
WHERE contest_reg_perc > avg_reg_perc;

Your exact mistakes were:
- Global denominator became contest-level because of the join
- tried AVG(contest_reg_perc) in the same select where contest_reg_perc was being created
- needed AVG(...) OVER() because you want to preserve one row per contest while attaching the global average
Pattern status
Grouped metric → global average of grouped metric → compare = Improving
Memory rule:
First create one metric per group. Then calculate the overall average across those group-level metrics.



###################################
10/09/2026

raw grain - one row per order per customer
intermediate grain - one row with first order amount per customer + latest order amount attached
comparison - first order amount > latest order amount 
pattern - we find the first order per customer using rank / dense rank (in case cust placed more than one but assuming it will be one order only use rank)
then we use row number to find the the latest order amount and then compare the first order amount > latest order amount 

one other alternative i was thinking is we use row number for both the first order and latest order just change the order by from asc to desc for order_date col
Your second alternative is the cleaner one, and your reasoning is almost there.

For this question, because we assume each customer has exactly one first order and one latest order, use ROW_NUMBER() for both:

ascending order_date → first order
descending order_date → latest order
I would not use RANK()/DENSE_RANK() here unless the problem says multiple rows on the same earliest/latest date should all be kept.

Your grain reasoning is good, but I’d sharpen the intermediate grain:

Raw grain: one row per order
Intermediate grain: each order row carries both a first-order rank and latest-order rank for that customer
Final grain: one row per qualifying customer

Then the pattern is:

first row vs latest row within the same entity

A neat way to think about it is:

rn_first  = ROW_NUMBER() ... ORDER BY order_date ASC
rn_latest = ROW_NUMBER() ... ORDER BY order_date DESC
Then compare the amount from rn_first = 1 with the amount from rn_latest = 1.

So yes — your instinct that “same function, just flip ASC/DESC” is the right one here.

cool
Q4/5
Table: EmployeeSalary

employee_id
department_id
salary
Return the employees whose salary is greater than the average salary of their department but less than the maximum salary in their department.

For now, give me only:

Raw grain → Intermediate grain(s) → Final grain → Comparison → Pattern

raw grain - one row per employee 
intermediate grain - salary of employee + avg salary of dept + max salary of dept
final grain - one row per employee satisfying the condition
comp - salary > avg_sal_dept and sal<max_sal_dept
pattern - we use window function here to first find the avg salary per dept and max sal per dept and simply compare sal > avg_sal and sal < max_sal of their dept using partition by dept
Correct. ✅

This is exactly the right reasoning structure:

Raw grain: one row per employee
Intermediate grain: keep employee row and attach department-level AVG(salary) and MAX(salary)
Final grain: one row per qualifying employee
Comparison: salary > avg_dept_salary and salary < max_dept_salary
Pattern: row vs own-group aggregates, using window functions partitioned by department
This is a very good example of when window functions are the natural fit because you want to preserve the employee row while attaching multiple group metrics.

Q5/5
Table: Orders

order_id
customer_id
order_date
amount
Return the customers whose total order amount in their latest month is greater than their average monthly order amount across all months.

For now, give me only:

Raw grain → Intermediate grain(s) → Final grain → Comparison → Pattern

raw grain - one row per customer per order
intermediate grain - we calculate total order amount per customer for latest month and attach avg order amount across all months at customer level
final grain - one row per customer satisfying the condition
comp - total_amount_latest_month > avg(total_amount_months)
pattern - first calculate total amount for latest month using row nnumber then use window function to calculate avg amount across all months per customer then compare both
Your comparison is correct, but the pattern needs one important correction.

You should not use ROW_NUMBER() on individual orders to find the latest month. The question is at a monthly grain, so you first need to create one row per:

customer_id + month

with that month’s total order amount.

Then from those monthly rows:

identify the latest month per customer
calculate AVG(monthly_total) across all months for that customer
compare latest-month total vs average monthly total
So the correct reasoning is:

Raw grain: one row per order
Intermediate grain 1: one row per customer + month with monthly_total
Intermediate grain 2: monthly rows with latest-month rank + customer-level average monthly total attached
Final grain: one row per qualifying customer
Comparison: latest_month_total > avg(monthly_total)
Pattern: pre-aggregate to month grain → latest row within monthly grain + own-group aggregate

The key correction is:

When the requirement says “latest month,” first build monthly rows. Don’t rank raw orders.

This is exactly the kind of grain-identification improvement we’re trying to build.

raw grain - one row per customer per order
intermediate grain - one row per customer with total order amount + attached avg (total order amount)
final grain - one row per customer satisfying the condition
pattern - first find total order amount per customer then use avg(total order amount) over () as avg order amount then compare boht

sql : 
with cte as (
select customer_id , sum(amount) as total_order_amount
from orders
group by customer_id
),
cte2 as (
select avg(total_order_amount) as avg_cust_amount from cte
)
select customer_id from cte2
where total_order_amount > avg_cust_amount
Your reasoning is correct, but the SQL has one grain/projection mistake.

The problem is here:

cte2 AS (
    SELECT AVG(total_order_amount) AS avg_cust_amount
    FROM cte
)

cte2 now has only one row and only one column: avg_cust_amount.

So this final query cannot access:

customer_id
total_order_amount

because they are not present in cte2.

The cleanest fix is to keep the customer-level rows and attach the overall average with a window:

WITH cte AS (
    SELECT
        customer_id,
        SUM(amount) AS total_order_amount
    FROM Orders
    GROUP BY customer_id
),
cte2 AS (
    SELECT
        customer_id,
        total_order_amount,
        AVG(total_order_amount) OVER () AS avg_cust_amount
    FROM cte
)
SELECT customer_id
FROM cte2
WHERE total_order_amount > avg_cust_amount;

Assessment
Raw grain: ✅
Intermediate grain: ✅
Final grain: ✅
Pattern: ✅
SQL logic: ✅
CTE projection: ❌
The key lesson:

If you still need row-level/customer-level columns after calculating a global metric, use a window to attach the global metric instead of collapsing to one row.

So this was a query construction miss, not a logic-building miss.

SQL Q2/5
Transactions
transaction_id
account_id
transaction_date
amount

Return the accounts whose latest transaction amount is greater than their own average transaction amount.
Write the SQL only.






    








raw grain - one row per accoutn
intermediate grain - one row per account with latest transaction amount + thier own avg transaction amount attached
final grain - one row per account satisfying the condition of latest_transaction_amount > avg_transaction_amount
pattern - use row numberto find the latest trnsaction amou t anf thn avg trnsc amount and compare

sql : 
with cte as (
select account_id , amount , row_number() over (partition by account_id order by transaction_date desc) as latest_amt,avg(amount) over (partition by account_id) as avg_trans_amount
from transactions
)
select account_id from cte
where latest_amt > avg_trans_amount












Your reasoning is correct, but there’s one SQL mistake:
ROW_NUMBER() ... AS latest_amt

That alias is the rank, not the latest transaction amount. So this comparison:
latest_amt > avg_trans_amount

is comparing 1,2,3... against an average amount.
You want:
rn = 1
AND amount > avg_trans_amount

Correct version:
WITH cte AS (
    SELECT
        account_id,
        amount,
        ROW_NUMBER() OVER (
            PARTITION BY account_id
            ORDER BY transaction_date DESC
        ) AS rn,
        AVG(amount) OVER (
            PARTITION BY account_id
        ) AS avg_trans_amount
    FROM Transactions
)
SELECT account_id
FROM cte
WHERE rn = 1
  AND amount > avg_trans_amount;

Also, your grain wording can be slightly sharper:
Raw grain: one row per transaction
Intermediate grain: transaction rows with latest-row rank + account average attached
Final grain: one row per qualifying account

Assessment
- Logic building: ✅
- Grain thinking: mostly ✅
- SQL construction: ⚠️ alias meaning confused
- Pattern recognition: ✅
Key rule:
ROW_NUMBER() identifies the row; it does not become the row’s value.







    








my bad i was in hurry












No issue — that was a hurry mistake, not a reasoning mistake.
The important part is you had the right structure:
latest row per account + own-account average → compare the latest row’s amount

Just keep the alias semantics clean:
rn = row position
amount = transaction value

Let’s continue with SQL Q3/5.