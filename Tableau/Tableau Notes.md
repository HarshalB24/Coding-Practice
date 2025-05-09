# Tableau Session 1

## Tableau for Data Analytics

### What is Data Analytics?
- **Data** = Information  
- **Analytics** = Using data to make business decisions  
  - *Example:*  
    - Netflix recommends movies using historical data  
    - Amazon suggests purchases based on purchase history

- Today, data is growing rapidly and is used to **drive analytics**  
- With data, analytics becomes **evidence-based**, not just intuition

---

### Generic Data Analytics Project Flow
1. **Extract** data from multiple sources  
2. **Transform** or format the data  
3. **Load** it into a data warehouse  
4. **Analyze** the data  
5. **Visualize** the data using Tableau, Power BI, etc.

> The concept of data visualization remains the same across tools  
> When working with big data, tools like **Tableau** or **Power BI** are used

---

## Data Visualization

### Definition
- Presenting data in a **visual format**

### Why is Data Visualization Important?
- Simplifies complex data  
- Helps solve problems  
  - *Example:* Identify low/high sales in a specific week/category using a chart  
- Identifies trends, patterns, and relationships  
- Enables fast decision-making  
- Highlights key information  
- Improves retention and recall (better than raw rows and columns)

---

### What is a Dashboard?
- A **group or collection of charts/views**
- **Why it's better than Excel:**
  - Fast and efficient  
  - No need to repeat the same process  
  - Reusable and user-friendly for business users

---

## What is Tableau?

- A **powerful data visualization tool** used to turn raw data into understandable formats using interactive, shareable dashboards
- Offers a **wide range of visualizations**
- Has a **user-friendly interface**  
- Easily connects to multiple data sources, performs analysis, and shares insights  
- Widely used in **BI** for **data-driven decision-making**

---

## Tableau Ecosystem

| Product                     | Use Case |
|----------------------------|----------|
| Tableau Desktop (Public & Professional) | Build visualizations and dashboards |
| Tableau Server             | Share dashboards; self-managed |
| Tableau Online             | Fully managed by Tableau (higher cost) |
| Tableau Reader             | View dashboards (read-only); editing requires Desktop |
| Tableau Prep               | Data modeling, cleaning, and processing |

---

## Practical 1

**Dataset Used:** Amazon Orders  
Fields include:  
`order_id`, `order_date`, `ship_date`, `customer`, `customer_id`, `country`, `city`, `state`, `sales`, `quantity`, `discount`, `profit`, etc. (~10,000 rows)

**Step:** Connect to `orders_data.xlsx`

---

### What Happens When You Drag the Table?

Two sections appear:

#### 1. Field Details Panel
- Displays:
  - **Type** — data type symbol  
  - **Field Name** — can be renamed for visualization  
  - **Physical Table** — name of the table  
  - **Remote Field Name** — original name (read-only)

#### 2. Data Preview Panel
- Shows top 100 rows to preview the dataset

---

### Data Type Symbols in Tableau

| Symbol         | Meaning                 |
|----------------|-------------------------|
| ABC            | String field            |
| #              | Integer or Number       |
| 📅 (Calendar)  | Date field              |
| 📅⏰ (Calendar + Clock) | Datetime field     |
| T\|F           | Boolean (True/False)    |

> Fields can be renamed by right-clicking or editing in the left panel

---

## Visualizing and Creating Charts

When you enter a worksheet, the left panel shows all fields.  
You’ll notice a **line separating some fields** — this is because Tableau separates:

### Dimensions vs Measures

#### Dimensions (Blue)
- Categorical/attribute data
- Describe: **what**, **who**, **where**, **when**
- Examples: Names, City, Country
- Used to create **headers**, **labels**, etc.
- Typically discrete values

#### Measures (Green)
- Numerical/quantitative data
- Represent metrics you want to analyze
- Examples: Sales, Profit, Revenue, Quantity
- **Continuous** — can be summed, averaged, etc.
- Used for calculations and aggregations

---

### ⚠️ Exceptions to Data Type Logic

- **Row ID**: A number, but used as a Dimension — because quantifying it doesn't make sense  
- **Postal Code**: Also numeric, but treated as a Dimension

> Tableau considers not just data type, but **context** and **field label** when classifying


# Tableau Notes: Filters, Mark Types, and Basic Data Visualization

---

## Custom SQL

If you don’t want to use the data from the table or data source as-is, Tableau provides an option to write **Custom SQL**.

- Navigate to the data source
- Click on **"Custom SQL"**
- Modify or write your own SQL query

> This is the query Tableau sends to the database to fetch the data.

You can also use the **"New Custom SQL"** option to write your query directly instead of using the default table schema.

---

## Filters in Tableau

### Types of Filters

1. **Extract Filter**
2. **Data Source Filter**
3. **Context Filter**
   - Sets  
   - Conditional Filters  
   - Top N  
   - Fixed LODs
4. **Dimension Filter**
   - Include/Exclude LODs  
   - Data Blending
5. **Measure Filters**
   - Forecasts  
   - Table Calculations  
   - Clusters  
   - Totals
6. **Table Calculation Filters**
   - Trend Lines  
   - Reference Lines

---

## Tableau Order of Operations

### 1. Extract Filter

- Access via *Edit* during extract creation
- Filters the data **before it’s stored** in the extract
- Used to **reduce extract size** and keep only relevant data

> **When to use:**  
> When you want to have a smaller subset of data with only relevant records in the extract.

---

### 2. Data Source Filter

- Useful when **multiple users or teams** are working on the same extract
- You create **one .hyper extract**, and users apply filters based on their needs
- Great for **performance and access control**

> **Note:**  
> If both **Extract Filter** and **Data Source Filter** are applied:  
> - Extract Filter is applied **first**  
> - Data Source Filter is applied **on top** of the result

**Example:**

Example:

You work in a wholesale company with multiple categories:
  - Extract Filter includes: Electronics, Furniture, etc.
  - Data Source Filter includes: Only Furniture (for your department)



# 📊 Tableau Learning Notes

## 📁 Basic Field Management in Tableau

- If Tableau incorrectly identifies a field as a **dimension** when it should be a **measure** (or vice versa), you can right-click the field and **convert it** appropriately.

---

## 🔍 Viewing and Filtering Fields

- You can view all fields in the **left pane** of the Tableau interface.
- Use the **funnel icon** to filter which types of fields (dimensions, measures, calculated fields, etc.) are visible.

---

## 🎯 Discrete vs Continuous

### Discrete:
- Usually applies to **dimensions**.
- Categorical and contain distinct, separate values.
- Represent things that can be counted in distinct units.
- Often used for segmentation or classification.
- **Displayed in Blue**.

### Continuous:
- Usually applies to **measures**.
- Quantitative values that can take any value within a range.
- Represent measurable quantities.
- **Displayed in Green**.

> 🧠 **Note**: By default, dimensions are discrete and measures are continuous. This behavior can be changed manually if needed.

**Examples:**
- `"Analytics"` and `"Sales"` departments are discrete (categorically different).
- `2` and `5` are continuous (they exist on a numeric range).

---

## 🧾 Sheet Overview

- **Left Pane**: Fields and data source connections.
- **Right Pane**: The canvas where charts are created.
- **Top Section**: Row and column shelves.
- **Filter Shelf**: Used to apply filters on data.
- **Marks Shelf**: Used to style and decorate charts.

---

## 🧠 Tableau Basics and Aggregation

- Tableau is a **data visualization tool** and **summarizes data by default**.
- Dropping a **discrete field** (like `Subcategory`) into rows shows **distinct values**, not the full record count.
- If a **measure** is dropped (like `Sales`), Tableau shows `SUM(Sales)` by default.

> ✅ You can change aggregation behavior under:
`Analysis > Aggregate Measures`

**SQL Equivalent (under the hood):**

SELECT Subcategory, SUM(Sales)
FROM Orders
GROUP BY Subcategory;

# Tableau Basics Cheat Sheet

## Creating Your First Chart
To create a basic chart like `SUM(Sales)` vs `Category`, Tableau will automatically assign a chart type. The name of the worksheet will also become the title of the chart.

> 💡 80% of the time, bar chart and line chart variations are used.

---

# Tableau Chart Basics and Behavior

## Creating First Chart

Create a chart of `SUM(Sales)` vs `Category`. Tableau will, by default, assign a chart type, and the name of the worksheet becomes the chart title.

> 🎯 80% of the time we use **bar chart** & **line chart** variations.


## Mark Types

- **Color**: Click on color to change the charts color.  
- **Size**: Changes the size of bars — narrower or wider.  
- **Label**: Displays exact value on top of the bar. *(Drag any field into label)*  
- **Tooltip**: Shows value on hover.

### Example:
If we group by `Category` and `SUM(Sales)`, we only get 3 marks.  

![alt text](<Tableau images/image.png>)


**BUT** — If we add a dimension (e.g., `Region`) to Color or any Mark:
- It changes the **granularity** of data.
- Tableau performs `GROUP BY Category, Region` and `SUM(Sales)`.
- This creates stacked bars.

![alt text](<Tableau images/image-1.png>)

If we add **Region** in *Size*, then:
- It changes granularity again.
- Displays `SUM(Sales)` by Region.

![alt text](<Tableau images/image-2.png>)


Even **Details** add granularity to data.

> 📝 Adding a dimension to *Label* or *Tooltip* does **not** change the granularity of the chart.

---

## Mark Types on Measures

- Adding **Dimensions** increases **granularity**.
- Adding **Measures** does **not** affect granularity.  
  It just displays a new measure from high to low.

![alt text](<Tableau images/image-3.png>)

> 🎯 You can double-click on *Sales* to:
> - Edit X & Y axes.
> - Customize starting value (e.g., start from 200k instead of 0).
> - Customize almost everything.

---

## Measure Names & Measure Values

- **Measure Names** = Names of measure fields in your dataset.
- **Measure Values** = The actual values of those measures.

> *Italicized fields* are **created by Tableau**.  
> Useful for quick dataset summaries.

![alt text](<Tableau images/image-4.png>)
---

## Workaround to Get Headers in Tableau

1. **Standard Approach**:
   - Drag a measure into the view.
   - If you only use one measure, headers are not displayed.
   - Add a second measure, then filter out the unwanted one using **Measure Names** in the Filters shelf.
   - The header remains since Tableau assumes multiple measures are shown.

2. **Manual Header**:
   - Double-click on a column.
   - Enter a custom header in single or double quotes, like `"Sales"`.

---

## Dates in Tableau

We deal with two types of date fields:

### 1. Date Part
- **Discrete**
- Aggregates values **across years** for each month or quarter.
- Example: Values for Jan = Jan 2018 + Jan 2019 + Jan 2020, etc.

![alt text](<Tableau images/image-5.png>)

### 2. Date Value
- **Continuous**
- Shows actual date-wise breakdown (e.g., Jan 2018, Jan 2019, etc.)
- Provides **continuous** timeline values.

![alt text](<Tableau images/image-6.png>)

---

## Calculated Fields

Use calculated fields for **custom calculations**.

- Represented by `=ABC` → This is a **dimension**.
- When working with **measures**, **be cautious** while calculating ratios.

### Important:
- Tableau calculates ratios at **row-level by default**:
  ```text
  SUM(Profit/Sales)  → ❌ Incorrect
  SUM(Profit) / SUM(Sales) → ✅ Correct
