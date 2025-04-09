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