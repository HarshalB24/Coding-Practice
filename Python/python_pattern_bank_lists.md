# Python Pattern Bank — Lists

## Current Version

| Pattern | When to use | Core idea / template |
|---|---|---|
| **Filter elements** | Keep only values matching a condition | `if condition: result.append(i)` |
| **Filter-out pattern** | Remove a target/special value | `if i != target: result.append(i)` |
| **Counter pattern** | Count how many times something appears | Initialize `cnt = 0`, increment on match |
| **Built-in frequency check** | Quick duplicate/frequency check | `nums.count(i)` |
| **Deduplicate preserving order** | Unique values, same original order | `if i not in result: result.append(i)` |
| **Aggregate → Filter** | Filter based on average/total/etc. | First calculate aggregate, then second loop |
| **Largest / Second-largest tracking** | Find top values without sorting | Maintain `largest` and `second_largest` |
| **Distinct second-largest using sorting** | Simpler second-largest solution | `sorted(set(nums), reverse=True)[1]` |
| **Move special values** | Move zeros/nulls to end | Collect normal values + count specials + append later |
| **Intersection / common elements** | Values present in two lists | `if i in b and i not in result:` |
| **Nested loop frequency** | Manually count occurrences | Outer loop picks value, inner loop counts matches |
| **Flatten one-level nested list** | `[[1,2],[3,4]] → [1,2,3,4]` | Outer loop sublists, inner loop items |
| **List comprehension** | Concise filtering/transformation | `[expression for x in nums if condition]` |
| **Sorting by key** | Sort dicts/objects by a field | `sorted(data, key=lambda x: x["field"])` |
| **Slicing** | Subset / skipping / reversing | `lst[start:stop:step]` |
| **Reverse list with slicing** | Reverse sequence | `lst[::-1]` |
| **Skip elements with slicing** | Every 2nd/3rd value | `lst[::2]`, `lst[::3]` |
| **Shallow copy** | Create new outer list | `b = a.copy()` or `a[:]`; nested objects still shared |
| **Value iteration** | When you need actual list elements | `for i in nums:` |
| **Index iteration** | When you specifically need positions | `for i in range(len(nums)):` |
| **Avoid modifying while iterating** | Removing/filtering elements | Preferably build a new list instead |

## Mental Triggers

```text
"only values that..."       → FILTER
"remove all..."             → FILTER OUT
"how many..."               → COUNTER
"appears more than once"    → FREQUENCY
"unique, preserve order"    → DEDUP
"common in both lists"      → INTERSECTION
"largest / second largest"  → TRACK VARIABLES
"nested list → flat list"   → NESTED LOOPS
"move zeroes to end"        → COUNT + REBUILD
"sort by experience/salary" → KEY + LAMBDA
```

## Important Syntax Reminder

### Value iteration

```python
for i in nums:
    # i is the actual value
```

### Index iteration

```python
for i in range(len(nums)):
    # i is the index
```

## Key List Problems Practiced

### 1. Sum and Average Without `sum()`

```python
total = 0

for i in nums:
    total += i

avg = total / len(nums)
```

### 2. Filter Even Numbers

```python
result = []

for i in nums:
    if i % 2 == 0:
        result.append(i)
```

Pythonic version:

```python
result = [i for i in nums if i % 2 == 0]
```

### 3. Count Occurrences Without `count()`

```python
cnt = 0

for i in nums:
    if i == target:
        cnt += 1
```

### 4. Remove Duplicates While Preserving Order

```python
result = []

for i in nums:
    if i not in result:
        result.append(i)
```

### 5. Second Largest Distinct Value — One Pass

```python
largest = None
second_largest = None

for i in nums:
    if largest is None or i > largest:
        second_largest = largest
        largest = i

    elif i != largest and (second_largest is None or i > second_largest):
        second_largest = i
```

Simpler built-in version:

```python
second_largest = sorted(set(nums), reverse=True)[1]
```

### 6. Move Zeroes to the End

```python
result = []
zero_count = 0

for i in nums:
    if i != 0:
        result.append(i)
    else:
        zero_count += 1

for _ in range(zero_count):
    result.append(0)
```

### 7. Values Greater Than Average

```python
total = 0

for i in nums:
    total += i

avg = total / len(nums)

result = []

for i in nums:
    if i > avg:
        result.append(i)
```

### 8. Find Repeated Values

Simple version:

```python
result = []

for i in nums:
    if nums.count(i) > 1 and i not in result:
        result.append(i)
```

Manual counting version:

```python
result = []

for i in nums:
    cnt = 0

    for j in nums:
        if i == j:
            cnt += 1

    if cnt > 1 and i not in result:
        result.append(i)
```

### 9. Common Elements Without Duplicates

```python
result = []

for i in a:
    if i in b and i not in result:
        result.append(i)
```

### 10. Remove All Occurrences of a Target

```python
result = []

for i in nums:
    if i != target:
        result.append(i)
```

Pythonic version:

```python
result = [i for i in nums if i != target]
```

### 11. Flatten a One-Level Nested List

```python
result = []

for sublist in nested:
    for item in sublist:
        result.append(item)
```

### 12. Sort List of Dictionaries by a Field

```python
sorted_data = sorted(
    employees,
    key=lambda x: x["experience"],
    reverse=True
)
```

## Current Assessment

- **List concepts:** Strong
- **Easy list coding:** Good
- **Medium list coding:** Needs more practice
- **Pattern recognition:** Improving
- **Main gap:** Translating the correct idea into clean Python syntax without help
- **Next topic:** Strings, while continuing mixed List revision
