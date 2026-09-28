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