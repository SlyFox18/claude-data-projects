## Weekend Logic - How It Works

The **"Business Hours Since Sale"** calculated column does this:

1. Calculates total actual hours from sale to now
2. Counts how many Saturday/Sunday days fall in that period
3. Subtracts 24 hours for each weekend day

**Example scenarios:**

- Part sold **Friday 5pm** → checked **Monday 9am**
    - Actual hours: 64 hours
    - Weekend days: 2 (Sat + Sun)
    - Business hours: 64 - 48 = **16 hours** ✓
- Part sold **Tuesday 2pm** → checked **Wednesday 2pm**
    - Actual hours: 24 hours
    - Weekend days: 0
    - Business hours: **24 hours** ✓