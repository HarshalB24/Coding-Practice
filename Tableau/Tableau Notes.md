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

# 📘 Tableau Notes – Day 2

---

## 🔁 Converting Dimensions and Measures

- If Tableau misclassifies a field (e.g., identifies a measure as a dimension or vice versa):
  - **Right-click the field → Convert to Measure/Dimension**
- **Left pane**: Displays all fields from your data source
- Use the **funnel icon** to filter field types

---

## 🔵 Discrete vs 🟢 Continuous

### Discrete (Blue)
- Usually associated with **dimensions**
- Represent **distinct and separate values**
- Often **categorical** (non-numeric) data
- Examples: Department (`Analytics`, `Sales`)
- Create **labels**, not axes

### Continuous (Green)
- Typically associated with **measures**
- Represent **quantitative** values that exist on a number line
- Can be aggregated (e.g., SUM, AVG)
- Examples: `2`, `5` – values in a range
- Create **axes**, not just labels

> **By default:**
> - All **dimensions** are **discrete**
> - All **measures** are **continuous**
> - You can change a field’s behavior manually (Discrete ↔ Continuous)

---

## 📄 Tableau Worksheet Overview

- **Left Pane**: Fields and data source connections  
- **Top**: Rows and Columns shelves  
- **Right Pane**: Chart/Canvas area  
- **Filters Shelf**: Apply filters to refine data  
- **Marks Shelf**: Customize charts (color, size, label, tooltip, etc.)

---

## 📊 Data Behavior in Tableau

- Tableau **summarizes data by default**
- Dragging a **discrete field** like `Sub-Category` to rows only shows **distinct values**
- **Measures** (like `Sales`) are **aggregated by default** → e.g., `SUM(Sales)`
- To turn off aggregation:
  - `Analysis → Uncheck Aggregate Measures` → Raw-level data is displayed

> **Behind the scenes:**
> ```sql
> SELECT Sub-Category, SUM(Sales)
> FROM Orders
> GROUP BY Sub-Category
> ```

### Understanding Marks
- Bottom-left label like `17 marks` = Number of data points or chart elements

---

## 📐 Chart Granularity

- Granularity = Number of **dimensions** in the view
- More dimensions = More detailed breakdown

### Example:
- Add `Region`, `Category`, and `Sub-Category`
- 4 Regions × 17 Sub-Categories = **68 Marks**

> **Equivalent SQL:**
> ```sql
> SELECT Region, Category, Sub-Category, SUM(Sales)
> FROM Orders
> GROUP BY Region, Category, Sub-Category
> ```

---

## 📝 Describe Field Feature

- **Right-click → Describe** any field to see:
  - Data type
  - Source
  - Role (dimension or measure)
  - Aggregation
  - Value preview

---

## 🔗 Live vs Extract Connections

### 🔴 Live Connection (Default)
- Tableau stays connected to the **original data source**
- **Changes in data are reflected immediately** (on refresh)
- Suitable for **real-time analysis**
- **Slower performance** for large datasets

### 🟢 Extract Connection (.hyper file)
- Creates a **snapshot** of the data
- Tableau reads from the **.hyper extract**, not the live source
- Data must be **refreshed** to reflect updates

#### Benefits:
- **Faster performance**
- **Offline access**
- **Less load** on the original data source

---

## 🛠️ When to Use Which?

| Use Case                     | Live                         | Extract                      |
|-----------------------------|------------------------------|------------------------------|
| Real-time data updates      | ✅                            | ❌ (needs manual refresh)    |
| Offline access needed       | ❌                            | ✅                            |
| Performance optimization    | ❌                            | ✅                            |
| Frequent changes in data    | ✅                            | ❌                            |
| Large datasets (static)     | ❌                            | ✅                            |

> ⚠️ If you join multiple data sources:
> - A **single extract** (.hyper) is created for the join  
> - Otherwise, each data source has its **own extract**



