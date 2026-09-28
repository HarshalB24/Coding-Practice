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