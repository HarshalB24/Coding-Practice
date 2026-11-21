# Python Pattern Bank — Lists, Strings, Dictionaries & Pandas

**Version:** 2.0 · 21 November 2026  
**Purpose:** One reliable source for interview revision, based on the original *Python Pattern Bank — Lists* and the exercises we actually worked through in this chat.  
**Study approach:** Finish **one data structure at a time** (basic → intermediate → advanced). No mixed problem sets until the fundamental patterns are fluent.

> **How to use this file:** Skim the *Mental Triggers* and *Mistake Bank* first. Then hide the solution, code the problem from scratch, check your answer, and retry the next day. Items marked **Practised** were attempted in our sessions; **Bank / reference** items were in your supplied bank or discussed as examples, but were not necessarily solved independently.

## Contents

1. [Mental triggers and the 8 rules](#1-mental-triggers-and-the-8-rules)
2. [List pattern bank](#2-list-pattern-bank)
3. [List questions and correct solutions](#3-list-questions-and-correct-solutions)
4. [String patterns and questions](#4-string-patterns-and-questions)
5. [Dictionary patterns and questions](#5-dictionary-patterns-and-questions)
6. [Lists of dictionaries: project-style questions](#6-lists-of-dictionaries-project-style-questions)
7. [Pandas patterns practised](#7-pandas-patterns-practised)
8. [Personal mistake bank: wrong → right](#8-personal-mistake-bank-wrong--right)
9. [Syntax cheat sheet](#9-syntax-cheat-sheet)
10. [Next-session diagnostic: one topic at a time](#10-next-session-diagnostic-one-topic-at-a-time)

---

## 1. Mental triggers and the 8 rules

### Problem → pattern

| Interview phrasing | Think |
|---|---|
| “Only values that…” | **FILTER:** `if condition: result.append(x)` |
| “Remove every occurrence of…” | **FILTER OUT:** `if x != target` |
| “How many…” | **COUNT:** start at `0`, increment on match |
| “Frequency of each item…” | **DICTIONARY COUNT:** `counts[x] = counts.get(x, 0) + 1` |
| “Unique values, same order” | **DEDUP:** `if x not in result: result.append(x)` |
| “Common to both” | **INTERSECTION:** `if x in b` |
| “Highest / lowest” | **TRACK:** compare current value to remembered best |
| “Second largest distinct” | **TWO TRACKERS** or `sorted(set(...))` |
| “Greater than average” | **AGGREGATE → FILTER:** first total/average, then filter |
| “Reverse a string” | **PREPEND:** `result = char + result` |
| “First non-repeating character” | **FREQUENCY → SCAN:** count first; return first count of 1 |
| “Move zeros to the end” | **COUNT + REBUILD** (or two pointers later) |
| “Flatten a nested list” | **NESTED LOOPS** |
| “Sort dict objects by salary/experience” | **KEY + LAMBDA** |
| “Duplicates in a DataFrame” | **PANDAS** `duplicated(..., keep=False)` |
| “Duplicate rows with frequency per original row” | **PANDAS** `groupby(...).transform('size')` |

### Eight rules that prevent most of your mistakes

1. **Check the input type.** `employees` is a *list*; `employee` is one *dictionary*; `employee['salary']` is its numeric value.
2. **Check the required output.** If asked for the *name*, return `employee['name']` (or tracked `highest_name`), not an entire dictionary or the salary.
3. **Keep loop-variable names consistent.** `for employee in employees:` → use `employee[...]` inside that loop. `for char in word:` → use `char`.
4. **Assignment ≠ comparison.** `=` stores; `==` compares. `>` excludes equality; `>=` includes equality.
5. **Read from a dictionary, not the input list.** `counts[x] = counts.get(x, 0) + 1` — `counts` on both sides.
6. **Indent by levels.** Function body 4 spaces; `for` body +4; `if` body +4. In general, return **after** the loop; return **inside** only when you specifically want to stop at the first match.
7. **Guard empty inputs before division, `max()`, or `[-2]`.** `if not nums: ...`; `if len(unique) < 2: return None`.
8. **Dry-run two items before submitting.** Track what changes after iteration 1 and iteration 2.

### Value vs index vs dictionary key

```python
nums = [10, 20, 30]
for value in nums:                 # value: 10, 20, 30
    print(value)

for index in range(len(nums)):     # index: 0, 1, 2
    print(index, nums[index])

employees = [{'name': 'Amit', 'salary': 50000}]
for employee in employees:         # employee = one dictionary
    print(employee['salary'])      # 50000

salary = employees[0]['salary']     # the number 50000 is now stored in salary
```

> `counts[item]` means *the value stored for key held in the variable `item`*. `counts['item']` means *the literal key named "item"*. `item` itself is just the current item.

---

## 2. List pattern bank

This preserves the patterns in your original bank while adding validity and edge-case notes.

| Pattern | When to use | Core template / caution |
|---|---|---|
| Filter elements | Keep matching items | `if condition: result.append(x)` |
| Filter-out | Remove target values | `if x != target: result.append(x)` |
| Counter | How many match? | `cnt = 0` then `cnt += 1` |
| Built-in count | Quick occurrences | `nums.count(x)`; repeated calls may be slow |
| Deduplicate preserving order | Unique, stable sequence | `if x not in result: result.append(x)` |
| Aggregate → filter | Above average/total threshold | Calculate aggregate, then second loop |
| Largest / second-largest tracking | One-pass top values | Track `largest` and `second`; handle duplicates |
| Distinct second-largest via sorting | Short interview solution | `ordered = sorted(set(nums)); ordered[-2]` after length check |
| Move special values | Push zero/null to end | Keep non-specials, count specials, rebuild |
| Intersection / common elements | Present in both lists | `if x in b and x not in result` for unique output |
| Nested-loop frequency | No dictionary allowed | Outer picks target; inner counts matches |
| Flatten one-level nested list | `[[1,2],[3,4]]` | Outer sublist, inner item |
| List comprehension | Concise map/filter | `[expression for x in nums if condition]` |
| Sorting by key | List of dictionaries/objects | `sorted(data, key=lambda x: x['field'])` |
| Slicing | Subset/skip/reverse | `lst[start:stop:step]` |
| Reverse with slicing | Reverse sequence | `lst[::-1]` |
| Skip with slicing | Every 2nd/3rd element | `lst[::2]`, `lst[::3]` |
| Shallow copy | New outer list only | `a.copy()` / `a[:]`; nested objects may be shared |
| Value iteration | Work with actual values | `for x in nums:` |
| Index iteration | Need positions | `for idx in range(len(nums)):` or `enumerate(nums)` |
| Avoid modifying during iteration | Removing/filtering | Build a new list instead |

**Complexity reminders:** `x in some_list` scans up to O(n) elements; a loop with that check is often O(n²). A set membership check is O(1) on average for hashable values. Sorting generally costs O(n log n).

---

## 3. List questions and correct solutions

### L1. Sum and average without `sum()` — Bank / practised as salary and order totals

```python
def sum_and_average(nums):
    if not nums:
        return 0, None                # average undefined for empty list
    total = 0
    for num in nums:
        total += num
    return total, total / len(nums)
```

**Avoid:** calculating average inside the total-building loop; dividing by `len(num)` rather than `len(nums)`; forgetting the empty-list case.

### L2. Filter even numbers — Bank / revised

```python
def even_numbers(nums):
    result = []
    for num in nums:
        if num % 2 == 0:
            result.append(num)
    return result

# Pythonic: [num for num in nums if num % 2 == 0]
```

### L3. Count target occurrences — Bank

```python
def count_target(nums, target):
    cnt = 0
    for num in nums:
        if num == target:
            cnt += 1
    return cnt

# Built-in: nums.count(target)
```

**Avoid:** resetting `cnt = 1` when a value does not match.

### L4. Remove duplicates preserving order — Practised; correct independent attempt

```python
def remove_duplicates(nums):
    result = []
    for num in nums:
        if num not in result:
            result.append(num)
    return result

# [7, 14, 7, 21, 14, 28] -> [7, 14, 21, 28]
# Compact, for hashable items: list(dict.fromkeys(nums))
```

**Avoid:** `list(set(nums))` if you must preserve insertion order; sets do not guarantee the original sequence's order.

### L5. Common elements — Practised; correct independent attempt

```python
def common_elements(a, b):
    result = []
    for num in a:
        if num in b:
            result.append(num)
    return result

# [10,20,30,40,50], [20,40,60,80] -> [20,40]
```

**If unique common elements are required:**

```python
def unique_common(a, b):
    result = []
    for num in a:
        if num in b and num not in result:
            result.append(num)
    return result
```

**Avoid:** assuming the original version removes duplicates from `a`; it does not.

### L6. Second-largest distinct, built-in solution — Practised

```python
def second_largest_sorted(nums):
    ordered = sorted(set(nums))
    if len(ordered) < 2:
        return None
    return ordered[-2]

# [10, 50, 30, 50, 20] -> 30
```

**Avoid:** using `[-2]` without checking at least two distinct values. `sorted(lst)` returns a new list; it does **not** sort `lst` in place.

### L7. Second-largest distinct, O(n) single pass — Practised with corrections

```python
def second_largest(nums):
    largest = None
    second = None

    for num in nums:
        if largest is None or num > largest:
            second = largest
            largest = num
        elif num != largest and (second is None or num > second):
            second = num

    return second

# [25,80,40,80,65,90,55] -> 80
# [-10,-5,-20] -> -10
# [5,5] -> None
```

**Avoid:** overwriting `num` instead of the tracking variables; comparing numbers to `None`; forgetting duplicate-largest exclusion; accidental reference to the *function name* `second_largest` instead of variable `second`.

### L8. Values above average — Practised in salary form

```python
def above_average_numbers(nums):
    if not nums:
        return []
    total = 0
    for num in nums:
        total += num
    average = total / len(nums)

    result = []
    for num in nums:
        if num > average:
            result.append(num)
    return result
```

**Avoid:** reversing the comparison (`average > num` finds *below* average); including equal values when the question says *strictly above*.

### L9. Move zeros to end — Original bank / reference

```python
def move_zeros(nums):
    result = []
    zero_count = 0
    for num in nums:
        if num != 0:
            result.append(num)
        else:
            zero_count += 1
    for _ in range(zero_count):
        result.append(0)
    return result

# [0,3,0,1,4] -> [3,1,4,0,0]
```

**Avoid:** modifying the input list with `remove()` while iterating over it.

### L10. Find repeated values once — Original bank / reference

```python
def repeated_values(nums):
    result = []
    for num in nums:
        if nums.count(num) > 1 and num not in result:
            result.append(num)
    return result

# [3,5,3,5,7] -> [3,5]
```

**Manual nested-loop alternative (if built-in `.count()` is disallowed):**

```python
def repeated_values_manual(nums):
    result = []
    for num in nums:
        cnt = 0
        for other in nums:
            if num == other:
                cnt += 1
        if cnt > 1 and num not in result:
            result.append(num)
    return result
```

### L11. Remove all target occurrences — Original bank / reference

```python
def remove_target(nums, target):
    result = []
    for num in nums:
        if num != target:
            result.append(num)
    return result

# Pythonic: [num for num in nums if num != target]
```

### L12. Flatten one-level nested list — Original bank / reference

```python
def flatten(nested):
    result = []
    for sublist in nested:
        for item in sublist:
            result.append(item)
    return result

# [[1,2],[3,4]] -> [1,2,3,4]
```

### L13. Find missing values from 1 through maximum — Asked, not independently attempted

```python
def find_missing(nums):
    if not nums:
        return []
    result = []
    for n in range(1, max(nums) + 1):
        if n not in nums:
            result.append(n)
    return result

# [1,2,4,6] -> [3,5]
```

For larger lists, `present = set(nums)` makes membership tests faster; this implementation mirrors our beginner practice.

### L14. Sort a list of dictionaries — Original bank / reference

```python
sorted_data = sorted(employees, key=lambda x: x['experience'], reverse=True)
```

### L15. Slicing, reverse, skipping, copying, comprehension — Original bank / revised

```python
nums = [10, 20, 30, 40, 50]
nums[1:4]           # [20, 30, 40]
nums[::-1]          # [50, 40, 30, 20, 10]
nums[::2]           # [10, 30, 50]
nums[::3]           # [10, 40]
copy_of_nums = nums.copy()    # shallow copy
above_20 = [n for n in nums if n > 20]
```

**Edge case:** a shallow copy creates a different *outer* list, but elements that are nested mutable objects remain shared.

---

## 4. String patterns and questions

| Trigger | Pattern |
|---|---|
| Reverse a word | `result = char + result` (manual) or `word[::-1]` |
| Is palindrome? | Reverse completely, then compare with original |
| Count vowels | `if char in 'aeiou': count += 1` |
| Case-insensitive check | `word.lower()` |
| Begins with A/a? | `name.lower().startswith('a')` |
| Frequency of each character | `counts[char] = counts.get(char, 0) + 1` |
| First character occurring once | Count all characters, then scan original string |
| Remove extra outer spaces | `word.strip()` |
| Words from a sentence | `sentence.split()` |
| Join tokens | `' '.join(words)` |

### S1. Reverse a string using a loop — Practised, needed reminder

```python
def reverse_string(word):
    result = ''
    for char in word:
        result = char + result
    return result

# 'python' -> 'nohtyp'
```

**Why it works:** for `'cat'`, result becomes `'c'` → `'ac'` → `'tac'`.

**Avoid:** `result = result + char` if the goal is reverse; that preserves the original order. For a quick interview solution, `word[::-1]` is fine unless loops are required.

### S2. Palindrome — Practised

```python
def is_palindrome(word):
    reversed_word = ''
    for char in word:
        reversed_word = char + reversed_word
    return reversed_word == word

# 'madam' -> True; 'python' -> False
```

**Avoid:** comparing before reversing the entire string; using lowercase `true`/`false` (Python requires `True`/`False`); returning `True` unconditionally. This is an exact, case-sensitive check unless requirements say otherwise.

### S3. Count vowels — Practised

```python
def count_vowels(word):
    count = 0
    for char in word.lower():
        if char in 'aeiou':
            count += 1
    return count

# 'education' -> 5; 'banana' -> 3; 'hello world' -> 3
```

**Avoid these exact mistakes from your attempts:**

- `char in ['aeiou']` checks whether a *single character* equals the **entire** string `'aeiou'` stored as one list item. Instead use `char in 'aeiou'` or `char in ['a','e','i','o','u']`.
- `if char in word:` is nearly always true while looping over `word`; it does not test vowels.
- `else: count = 1` resets your accumulated count. No `else` is needed.
- Don't name your variable `str`; that shadows the built-in `str` type.

### S4. Filter names starting with A/a — Practised earlier

```python
def names_starting_a(names):
    result = []
    for name in names:
        if name.lower().startswith('a'):
            result.append(name)
    return result
```

**Avoid:** a nonexistent method such as `namestartswith`; the method is `.startswith(...)` on a string.

### S5. Character frequency — Practised, including `'mississippi'`

```python
def character_count(word):
    counts = {}
    for char in word:
        counts[char] = counts.get(char, 0) + 1
    return counts

# character_count('mississippi') -> {'m': 1, 'i': 4, 's': 4, 'p': 2}
```

**Avoid:** looping over `words` when the parameter is `word`; Python variable names must match exactly.

### S6. First non-repeating character — Practised

```python
def first_unique(word):
    counts = {}
    for char in word:
        counts[char] = counts.get(char, 0) + 1

    for char in word:
        if counts[char] == 1:
            return char
    return None

# 'swiss' -> 'w'; 'aabb' -> None
```

**Avoid:** returning `counts[char]` (that's the *count*, not the *character*) or `counts['char']` (literal key); compare only after frequency counting is complete.

---

## 5. Dictionary patterns and questions

| Trigger | Technique |
|---|---|
| Read known key | `employee['salary']` |
| Read optional key with default | `employee.get('salary', 0)` |
| Add/update key | `employee['salary'] = 75000` |
| Count each value | `counts[x] = counts.get(x, 0) + 1` |
| Iterate keys and values | `for key, value in data.items():` |
| Filter dictionary entries | `if value > threshold:` then `result[key] = value` |
| Count values from records | Extract field first (`dept = employee['department']`) |

### D1. Frequency dictionary from list — Practised repeatedly

```python
def count_names(names):
    counts = {}
    for name in names:
        counts[name] = counts.get(name, 0) + 1
    return counts

# ['Amit','Neha','Amit','Rahul','Neha','Amit']
# -> {'Amit': 3, 'Neha': 2, 'Rahul': 1}
```

**Avoid:** `names.get(name, 0)` — `names` is a list; `.get()` belongs to the dictionary (`counts`).

### D2. Filter a frequency dictionary — Practised

```python
def only_duplicates(counts):
    result = {}
    for key, count in counts.items():
        if count > 1:
            result[key] = count
    return result

# {'Amit':2,'Rahul':1,'Priya':3} -> {'Amit':2,'Priya':3}
```

**Avoid:** `for item in counts.items(): item.key()` — `.items()` produces key-value pairs, usually unpacked as `for key, count in ...`.

### D3. Check a dictionary value vs the key — Practised as quick quiz

```python
counts = {'a': 2, 'b': 1}
item = 'b'
print(item)             # 'b'
print(counts[item])     # 1
print(counts['b'])      # 1
# counts['item'] would raise KeyError (no literal key 'item')
```

### D4. Count departments from a list of dictionaries — Practised

```python
def count_departments(employees):
    counts = {}
    for employee in employees:
        dept = employee['department']
        counts[dept] = counts.get(dept, 0) + 1
    return counts

# IT, HR, IT, IT, Finance -> {'IT': 3, 'HR': 1, 'Finance': 1}
```

**Avoid:** `counts[employee]` — `employee` is a dictionary, and dictionaries cannot be used as dictionary keys. Extract the department string first.

---

## 6. Lists of dictionaries: project-style questions

These combine lists (looping), dictionaries (field access) and simple algorithms. We practised them; the diagnostic will test each data structure *separately* first.

### R1. Names of employees earning > 60,000 — Practised

```python
def high_salary_names(employees):
    result = []
    for employee in employees:
        if employee['salary'] > 60000:
            result.append(employee['name'])
    return result

# For salaries Amit 50k, Rahul 75k, Priya 90k, Neha 55k:
# -> ['Rahul', 'Priya']
```

**Avoid:** `employees['salary']` (the whole list cannot be indexed by a string); `result.append(employee)` if names, not entire records, were requested.

### R2. Filter IT staff earning > 70,000 — Practised

```python
def filter_employees(employees):
    result = []
    for employee in employees:
        if employee['department'] == 'IT' and employee['salary'] > 70000:
            result.append(employee['name'])
    return result

# -> ['Priya', 'Neha'] for the provided exercise
```

**Avoid:** `=` in a condition instead of `==`; using `employee` if you named your loop variable `item` (keep the naming consistent).

### R3. Highest-paid employee / highest-scoring student — Practised

```python
def highest_paid(employees):
    highest_salary = None
    highest_name = None

    for employee in employees:
        if highest_salary is None or employee['salary'] > highest_salary:
            highest_salary = employee['salary']
            highest_name = employee['name']

    return highest_name

# -> 'Priya' for 50k, 75k, 95k, 65k
# -> None for []
```

For students, replace `'salary'` with `'marks'`, and rename `highest_salary` → `highest_marks`. The name still comes from `student['name']`.

**Avoid:** `return employee['name']` after the loop (returns last employee, not the winner); overwriting the input employee instead of the tracking variables; forgetting to update **both** highest value and associated name.

### R4. Lowest-priced product — Prompt reviewed as a minimum-version reference, not independently solved

```python
def cheapest_product(products):
    lowest_price = None
    lowest_name = None
    for product in products:
        if lowest_price is None or product['price'] < lowest_price:
            lowest_price = product['price']
            lowest_name = product['name']
    return lowest_name

# Laptop 60000, Mouse 800, Keyboard 1500, Monitor 12000 -> 'Mouse'
```

### R5. Total order sales — Practised; correct independent attempt

```python
def total_sales(orders):
    total = 0
    for order in orders:
        total += order['amount']
    return total

# 1500 + 2500 + 1000 -> 5000; [] -> 0
```

### R6. Average employee salary — Practised

```python
def average_salary(employees):
    if not employees:
        return 0
    total = 0
    for employee in employees:
        total += employee['salary']
    return total / len(employees)
```

**Avoid:** computing `employee['salary'] / len(employees)` for each employee; dividing by `len(employee)` (which counts dictionary keys); calculating final average before the total is complete.

### R7. Names earning strictly above average — Practised; later solved correctly in logic

```python
def above_avg(employees):
    if not employees:
        return []

    total = 0
    for employee in employees:
        total += employee['salary']
    avg_salary = total / len(employees)

    result = []
    for employee in employees:
        if employee['salary'] > avg_salary:
            result.append(employee['name'])
    return result

# 40k, 60k, 90k, 50k -> average 60k -> ['Priya']
```

**Avoid:** comparing `avg_salary > employee['salary']` (below-average records); `>=` if the task says **strictly more**; leaving `return result` outside the function.

---

## 7. Pandas patterns practised

Keep this as a *separate* interview mini-sheet; do not mix it into tomorrow's core Lists/Strings/Dictionaries learning.

```python
# All rows with repeated name, including the first occurrence:
duplicates = df[df.duplicated(subset=['name'], keep=False)]

# Frequency on every original row (for non-null name values):
df['name_count'] = df.groupby('name')['name'].transform('size')

# Only duplicate rows, with the frequency attached:
duplicates_with_counts = df[df['name_count'] > 1]

# Aggregate summary: one row per duplicate name:
summary = df.groupby('name').size().reset_index(name='count')
summary = summary[summary['count'] > 1]

# Total salary per department / sales per city:
total_by_department = df.groupby('department')['salary'].sum().reset_index()
total_by_city = df.groupby('city')['sales'].sum().reset_index()

# Filter rows / find nulls / join:
above_60000 = df[df['salary'] > 60000]
null_counts = df.isna().sum()
joined = df1.merge(df2, on='customer_id', how='left')
```

**If null group keys should be treated as one group:** use `groupby('name', dropna=False)`; the default excludes null group keys.

**Distinctions:**
- `df.duplicated(...)` returns a Boolean Series; wrap it in `df[...]` to obtain rows.
- `groupby(...).size()` returns one count per group; `.transform('size')` broadcasts a count back onto each original grouped row.
- `df['name_count'] = ...` creates a column; `df = df[df['name_count'] > 1]` filters rows. They are not interchangeable.
- In `groupby('department')['salary'].sum()`, `department` is the *grouping key*, `salary` is the *column being summed*. Do **not** pass the salary Series into `.sum()`.

---

## 8. Personal mistake bank: wrong → right

These are based on mistakes you actually made. Review this table before each coding session.

| Pitfall / wrong example | Correct pattern | Why |
|---|---|---|
| `for char in words:` when parameter is `word` | `for char in word:` | Variable names must match |
| `names.get(name, 0)` | `counts.get(name, 0)` | `.get()` belongs to the dictionary |
| `counts[employee]` where `employee` is a dict | `counts[employee['department']]` | Dictionary keys must be hashable |
| `counts['item']` | `counts[item]` | Quotes make a literal key |
| `return counts[item]` when asked for a character | `return item` | Count ≠ original character |
| `employees['salary']` for a list | `employee['salary']` inside `for employee in employees` | Access current dictionary, not the list |
| `if employee['department'] = 'IT':` | `== 'IT'` | `=` assigns; `==` compares |
| `if avg > employee['salary']` | `if employee['salary'] > avg` | Correct comparison direction |
| Including a value equal to average with `>` | Use `>=` **only** if equality is requested | `>` excludes equality |
| `salary = highest_salary` | `highest_salary = employee['salary']` | Assignment is left ← right |
| `return employee['name']` after maximum loop | `return highest_name` | Last record ≠ highest record |
| `len(employee)` to count employees | `len(employees)` | Dictionary length counts its keys |
| Compute `avg = total / len(...)` inside summing loop | After summing loop | Need the full total first |
| `if char in ['aeiou']:` | `if char in 'aeiou':` | A one-item list is not five vowels |
| `if char in word:` while looping over word | `if char in 'aeiou':` | Original string ≠ vowel set |
| `else: count = 1` after non-vowel | No `else`; keep the current count | Prevents accidental reset |
| `result = result + char` to reverse | `result = char + result` | Prepend reverses order |
| Compare palindrome inside reversal loop | Compare after loop | Full reversed word needed |
| `return true` | `return True` | Python Boolean capitalization |
| `return True` unconditionally | `return reversed_word == word` | Must evaluate both cases |
| `sorted(lst)` then `return lst[-2]` | `ordered = sorted(lst); return ordered[-2]` | `sorted()` doesn't change `lst` |
| `sorted(set(nums))[-2]` with no guard | Check `len(ordered) >= 2` | Prevents `IndexError` |
| `df = df.duplicated(...)` expecting rows | `df = df[df.duplicated(...)]` | Boolean mask vs DataFrame |
| `df.duplicated(...).transform('size')` | `df.groupby('name')['name'].transform('size')` | Grouping is required |
| `df[emp_count]` | `df['emp_count']` | Literal column name needs quotes |
| `df['emp_count'] = df[df['emp_count'] > 1]` | `df = df[df['emp_count'] > 1]` | Filter the DataFrame, not one column |
| `groupby('city')['city'].sum(df['sales'])` | `groupby('city')['sales'].sum()` | Choose metric column, then aggregate |
| Indentation outside `def` / `for` / `if` | Indent every nested block by 4 spaces | Python uses indentation to define blocks |
| Multiple `return result` statements | Keep one purposeful return | Avoid unreachable/dead code |

### Pre-submit checklist (30 seconds)

- [ ] Am I looping over a **list**, **string**, or **dictionary**? What is one loop element?
- [ ] Does my loop variable name match every field access inside the loop?
- [ ] Is the expression on the **left** of `=` the variable I want to update?
- [ ] Am I storing a count (`counts[key]`) or returning the original key (`key`)?
- [ ] Is the comparison direction right (`>` vs `<`, strict vs inclusive)?
- [ ] Do `if`, `for`, `def` end with `:` and have proper indentation?
- [ ] Is `return` after the loop (unless deliberately stopping on first match)?
- [ ] Does it work for `[]`, duplicates, one element and, when relevant, negatives?

---

## 9. Syntax cheat sheet

```python
# Function and loop
def fn(nums):
    result = []
    for num in nums:
        if num > 0:
            result.append(num)
    return result

# List basics
nums.append(5)
nums[0]                 # first
nums[-1]                # last (only if non-empty)
nums[::-1]              # reverse copy
nums[::2]               # every other element
len(nums)               # number of elements

# Dictionary basics
employee['name']        # value at required key
employee.get('salary', 0)  # value or default
employee['salary'] = 90000
for key, value in employee.items():
    print(key, value)

# Frequency
counts = {}
for x in nums:
    counts[x] = counts.get(x, 0) + 1

# String basics
word.lower()
word.strip()
word.startswith('a')
word.split()
' '.join(['hello', 'world'])

# Conditions
x == y                   # equal
x != y                   # not equal
x > y                    # strictly greater
x >= y                   # greater or equal
x in nums                # membership
x not in nums            # absence
x is None                # no value yet

# Aggregation
total = 0
for x in nums:
    total += x
average = total / len(nums) if nums else None

# Sort / unique
sorted(nums)             # new sorted list
nums.sort()              # modifies original list
list(dict.fromkeys(nums))  # unique + order, for hashable values
```

---

## 10. Next-session diagnostic: one topic at a time

**Do not solve every topic in one sitting.** Start with **Lists**, identify gaps, and complete List fundamentals/intermediate/advanced before moving to Strings, then Dictionaries. There will be **4 short diagnostic questions per topic**, presented one by one, with no pre-shared answers.

### Assessment rubric

For each question, score independently:
- **3:** Correct without hints; can explain and handle an edge case.
- **2:** Correct with a minor syntax fix or one small hint.
- **1:** Understands approach after guidance but cannot independently finish.
- **0:** Cannot identify the pattern yet.

Interpretation **per topic** (max 12 points):
- **0–4:** Basics need reinforcement.
- **5–8:** Basic competence; build intermediate accuracy.
- **9–10:** Solid intermediate readiness; test transfer to unseen problems.
- **11–12:** Advanced candidate *for this small diagnostic only*; confirm with new, harder timed problems before calling the topic advanced.

A diagnostic is a *starting point*, not a formal certification. Note **hints used**, **syntax vs logic mistakes**, **explanation quality**, and **edge-case handling** separately.

### Lists: 4 prompts (one at a time tomorrow)

1. **Basic:** Return unique values from `[4, 4, 2, 6, 2, 9]`, retaining first-seen order, without `set()`.
2. **Basic → intermediate:** Move all zeros to the end of `[0, 5, 0, 3, 8, 0, 2]` while preserving non-zero order. First do it using a new list; discuss space complexity.
3. **Intermediate:** Find the second-largest **distinct** integer without sorting or `set()`. Test `[-8, -3, -5, -3]`, `[7,7]`, and `[]`.
4. **Advanced diagnostic:** Find the **maximum sum of a contiguous non-empty subarray** in `[4,-1,2,1,-7,5,2]`, aiming for O(n). Explain what state you track; it's fine if this is new.

### Strings: 4 prompts (later, after Lists)

1. **Basic:** Count vowels in `'ApplE'` case-insensitively.
2. **Basic → intermediate:** Reverse `'level'` manually; then use the reversal to test whether the word is a palindrome.
3. **Intermediate:** Find the first character occurring once in `'aabbcdde'`; return `None` if none.
4. **Advanced diagnostic:** Find the length of the longest substring without repeating characters in `'abcabcbb'`; explain the approach and aim for O(n).

### Dictionaries: 4 prompts (after Strings)

1. **Basic:** Count frequencies in `['a','b','a','c','b','a']` without `Counter`.
2. **Basic → intermediate:** From `{'A': 4, 'B': 1, 'C': 3}`, return only entries whose counts are >1 using `.items()`.
3. **Intermediate:** Given a list of `{'department': ..., 'sales': ...}` records, build a dictionary of **total sales per department**.
4. **Advanced diagnostic:** From a word list, return the **top two most frequent distinct words**, breaking frequency ties alphabetically; explain edge cases and approach.

### Session flow (start next time)

1. **Lists diagnostic only:** 4 questions, one at a time, no solution revealed before your attempt.
2. Review the answers by **pattern**, **logic**, **syntax**, **edge cases** and **complexity**.
3. Give a **provisional Lists level** and map missing subskills.
4. Practise Lists from basic → intermediate → advanced until you can solve unseen versions without hints.
5. Repeat this for Strings, then Dictionaries. Mix topics only after separate foundations are stable.

### Evidence from practice so far (not a formal level score)

- **Lists:** Deduplication and common-element filtering were solved independently; simple loop patterns are improving. Single-pass second-largest still needed guidance.
- **Strings:** Vowel counting, palindrome and reversal required corrections or recall cues; patterns are emerging but not yet automatic.
- **Dictionaries:** `.get()`-based counting is understood but use of the correct key/value and `item` vs `counts[item]` remains inconsistent under recall.
- **Lists of dictionaries:** Maximum-value comparison and average → filter improved substantially after targeted explanation.
- **Pandas:** Correct independent `groupby('city')['sales'].sum().reset_index()`; duplicate-row/row-count syntax required reinforcement.

**Learning goal:** Reliable recall and independent implementation, not merely recognizing a solved example.
