# TradeZone E-Commerce Operations Analysis

A full-cycle SQL analytics project on a Nigerian e-commerce platform — covering data cleaning, business intelligence queries and executive reporting across two years of transaction data (2023–2024).

---
## Project Overview

TradeZone is a fast-growing Nigerian e-commerce platform connecting buyers and sellers across Lagos, Abuja (FCT), Kano, Port Harcourt and Ibadan. Over 2023–2024, the platform scaled rapidly — but that growth masked operational problems across customer retention, seller performance and category concentration.

This project delivers a full data review ahead of a 2025 planning cycle, covering:

- **Data cleaning & preparation** — handling NULLs, duplicates, formatting inconsistencies and validation flags across 7 relational tables
- **Eight business SQL queries** — answering specific questions from the Head of Growth and Head of Seller Operations
- **An analyst memo** — translating query results into actionable decisions for leadership

---

## Business Context

The analysis was structured around three core business concerns:

1. **Customer retention is dropping** — acquisition is happening but post-signup conversion is inconsistent across states
2. **Seller quality is uneven** — some sellers are dragging down overall platform ratings and fulfilment standards
3. **Category underperformance** — certain product categories are underperforming despite being part of the platform's catalogue

The goal was not to produce a dashboard — but to answer specific operational questions with SQL and turn those answers into decisions.

---

## Tools & Tech Stack

| Tool | Purpose |
|------|---------|
| PostgreSQL 18 | Primary database engine |
| pgAdmin 4 | Query execution & database management |
| SQL (CTEs, Window Functions, Aggregations) | Data cleaning & analysis |
| Git & GitHub | Version control & portfolio documentation |

---

## Database Schema

The TradeZone database consists of 7 relational tables:

```
customers       — customer profiles, location, signup date
sellers         — seller profiles, product category, location
products        — product catalogue with pricing and seller attribution
orders          — order records with status, dates and total amount
order_items     — line-level breakdown of each order
payments        — payment transactions linked to orders
reviews         — customer ratings linked to products and orders
```

### Entity Relationships

```
customers ──< orders >── sellers
                │
          order_items >── products >── sellers
                │
            payments
            
reviews >── products
reviews >── customers
reviews >── orders
```

### Key Schema Notes

- `orders` carries both `customer_id` and `seller_id` — enabling direct seller-level order attribution without going through `products`
- `reviews` links to `product_id` not `seller_id` directly — seller ratings must be derived by joining `reviews → products → sellers`
- `order_items` holds `unit_price` and `line_total` independently — allowing validation of `quantity × unit_price = line_total` and `SUM(line_total) = orders.total_amount`

---

## Data Cleaning

All cleaning logic lives in [Part 1.sql](Part%201.sql) PostgreSQL file, structured across four labelled sections.

### Section 1: Missing Values

**Strategy:** Delete records where NULLs make them analytically unusable. Flag non-critical NULLs with SELECT queries and document the decision.

| Table | Column(s) | Action | Reason |
|-------|-----------|--------|--------|
| customers | email, city, state, signup_date | Flag only | Customer still trackable via orders |
| sellers | city, state, onboarding_date | Flag only | Seller still attributable |
| products | seller_id, unit_price | Delete (cascade) | Orphaned/unpriced products break joins and revenue calc |
| products | category | Flag only | Product retained, excluded from category queries |
| orders | customer_id, seller_id, order_date, total_amount | Delete (cascade) | Core attribution and time-window fields — unusable without them |
| order_items | order_id, quantity, unit_price, line_total | Delete | Line items without these cannot be validated or aggregated |
| payments | order_id, amount | Delete | Unlinked or valueless payments are analytically inert |
| payments | payment_method | Flag only | Excluded from Q6 as documented |
| reviews | rating | Delete | A review without a rating contributes nothing |
| reviews | review_date | Flag only | Rating still valid for scoring |

**Cascade handling:** Deleting from `products` requires clearing `reviews` then `order_items` first. Deleting from `orders` requires clearing `reviews`, `payments` and `order_items` first. All deletes follow this dependency order throughout.

### Section 2: Duplicate Records

Duplicates defined as:
- **customers** — same `email` (same person, multiple registrations)
- **sellers** — same `seller_name + city + state` combination
- **orders** — same `customer_id + seller_id + order_date + total_amount`

Strategy: Keep the record with the earliest primary key (`MIN()`). Delete dependents before deleting parent rows to avoid FK violations.

**Result:** Duplicate customers found and removed. No duplicate sellers or orders were found in the dataset.

### Section 3: Inconsistent Formatting

**City names:** Raw data contained mixed case (`lagos`, `LAGOS`), leading/trailing whitespace (`Lagos `), mid-word typos (`Lago s`), hyphens (`Port-Harcourt`) and missing spaces (`PortHarcourt`, `Portharcourt`). Fixed using a combination of explicit `UPDATE` statements for non-standard variants followed by `INITCAP(TRIM(REGEXP_REPLACE()))` for general standardisation.

Final canonical city values: `Abuja`, `Ibadan`, `Kano`, `Lagos`, `Port Harcourt`

**Date formats:** All date columns are native PostgreSQL `DATE` or `TIMESTAMP` types — format is enforced at the type level. Verification queries confirmed 0 malformed entries across all date columns.

**Product categories:** Raw data contained casing issues (`ELECTRONICS`, `electronics`), typos (`Electronis`, `Fashon`), `and` vs `&` variants (`Food and Beverages` vs `Food & Beverages`) and abbreviated forms (`BEAUTY`, `BOOKS`, `FOOD`, `SPORTS`).

Fixed in order:
1. Explicit typo corrections
2. `REGEXP_REPLACE` to normalise `and` → `&`
3. Explicit mapping of short forms to full canonical names
4. `INITCAP(TRIM())` for remaining case issues

Final canonical category values: `Beauty & Personal Care`, `Books & Stationery`, `Electronics`, `Fashion`, `Food & Beverages`, `Home & Garden`, `Sports & Fitness`

### Section 4: Data Validation

| Check | Method | Result |
|-------|--------|--------|
| `orders.total_amount` vs `SUM(order_items.line_total)` | ABS difference > ₦10 | 120 orders flagged → preserved in `flagged_order_totals` table |
| `order_items.line_total` vs `quantity × unit_price` | ABS difference > ₦0.01 | 0 discrepancies — all clean |
| Review ratings outside 1–5 | `WHERE rating < 1 OR rating > 5` | Invalid ratings deleted |
| Negative product prices | `WHERE unit_price < 0` | 0 found — all clean |
| Discount percentage > 100% | N/A | No discount column exists in schema — documented |

The 120 flagged orders were preserved rather than deleted — the discrepancy between `total_amount` and line item sums could reflect order-level discounts, delivery fees or service charges not captured in `order_items`. Deleting them would remove valid transaction records.

---

## Business Questions & Key Findings

### Q1: Customer Acquisition & 30-Day Conversion
[Click to see PostgreSQL Script](Q1.sql)

Top 5 states by 2024 sign-ups and first-30-day purchase conversion rate:

| State | New Sign-ups | Converted (30 days) | Conversion Rate |
|-------|-------------|---------------------|-----------------|
| Lagos | 142 | 66 | 46.48% |
| FCT | 92 | 35 | 38.04% |
| Rivers | 65 | 24 | 36.92% |
| Oyo | 62 | 19 | 30.65% |
| Kano | 57 | 17 | 29.82% |

Cancelled orders excluded from conversion count — a cancelled order does not represent a real purchase.

---

### Q2: Product Performance — Top 10 by Revenue (2024)
[Click to see PostgreSQL Script](Q2.sql)

| Product | Category | Total Revenue | Orders |
|---------|----------|--------------|--------|
| HP Pavilion 15 Laptop Intel i5 - v2 | Electronics | ₦22,520,184 | 20 |
| TP-Link WiFi Router AC1200 - v2 | Electronics | ₦22,145,644 | 22 |
| Mechanical Keyboard RGB Backlit | Electronics | ₦20,371,479 | 20 |
| Hisense 32 inch LED TV | Electronics | ₦20,226,795 | 21 |
| Apple AirPods Pro 2nd Gen | Electronics | ₦17,911,088 | 21 |
| JBL Bluetooth Speaker Portable | Electronics | ₦17,608,019 | 18 |
| Garmin Forerunner 255 Watch - v2 | Electronics | ₦17,518,139 | 26 |
| Lenovo IdeaPad 3 Laptop 8GB RAM - v2 | Electronics | ₦17,190,700 | 18 |
| Kingston 256GB USB Flash Drive - v2 | Electronics | ₦16,503,221 | 18 |
| Anker PowerBank 20000mAh USB-C | Electronics | ₦14,822,757 | 16 |

All top 10 products are Electronics — a significant category concentration finding.

---

### Q3: Seller Fulfilment Efficiency
[Click to see PostgreSQL Script](Q3.sql)

Top 15 sellers by average fulfilment time (hours) among those with ≥20 completed orders:

| Seller | Completed Orders | Avg Fulfilment (hrs) | Avg Rating |
|--------|-----------------|----------------------|------------|
| SportNation NG | 28 | 92.57 | 3.14 |
| SportsCentral NG | 20 | 98.40 | 4.00 |
| GadgetPro NG | 24 | 102.00 | 4.07 |
| GadgetKing NG | 22 | 109.09 | 0.00 |
| TechHub Nigeria | 22 | 110.18 | 3.67 |
| AllFashion NG | 20 | 112.80 | 3.40 |
| GreenHome Stores | 20 | 115.20 | 4.00 |
| PureSkin NG | 20 | 117.60 | 3.67 |
| TechStore NG | 20 | 118.80 | 3.36 |
| EarthHome NG | 20 | 121.20 | 4.10 |
| WellnessHub NG | 26 | 121.85 | 3.91 |
| StyleKraft NG | 22 | 122.18 | 3.80 |
| VogueNG | 27 | 126.22 | 3.62 |
| QuickTech NG | 24 | 129.00 | 4.17 |
| GymPro NG | 23 | 134.61 | 3.89 |

Only 15 sellers met the ≥20 completed orders threshold. GadgetKing NG's 0 rating indicates no reviews exist for their products — flagged as a data gap. Rating derived via `reviews → products → sellers` join path.

---

### Q4: Quarterly Revenue Trends
[Click to see PostgreSQL Script](Q4.sql)

| Quarter | Orders 2023 | Orders 2024 | Revenue 2023 | Revenue 2024 | Growth (₦) | Growth % |
|---------|------------|------------|-------------|-------------|-----------|---------|
| Q1 | 17 | 284 | ₦5,394,189 | ₦99,539,731 | ₦94,145,542 | 1,745% |
| Q2 | 64 | 391 | ₦16,276,229 | ₦123,491,384 | ₦107,215,155 | 659% |
| Q3 | 120 | 571 | ₦41,898,658 | ₦199,469,806 | ₦157,571,148 | 376% |
| Q4 | 190 | 863 | ₦63,798,906 | ₦304,036,935 | ₦240,238,029 | 377% |

Q1's 1,745% growth is a base effect — only 17 orders existed in Q1 2023. Q4 2024 is the platform's peak period by both volume and revenue.

---

### Q5: Customer Spend Segmentation (2024)
[Click to see PostgreSQL Script](Q5.sql)

| Segment | Customers | Avg Spend | Total Revenue |
|---------|-----------|-----------|--------------|
| High Spender (≥₦100,000) | 553 | ₦1,306,612 | ₦722,556,461 |
| Medium Spender (₦50,000–₦99,999) | 41 | ₦71,044 | ₦2,912,798 |
| Low Spender (<₦50,000) | 49 | ₦21,808 | ₦1,068,597 |

86% of customers fall into the High Spender band, contributing 99.5% of revenue. The thresholds are misaligned with the platform's average order value (~₦350,000).

---

### Q6: Payment Method Preferences by State
[Click to see PostgreSQL Script](Q6.sql)

| State | Most Popular Method | Transactions |
|-------|-------------------|-------------|
| Lagos | Card | 338 |
| FCT | Card | 176 |
| Rivers | Card | 122 |
| Oyo | Cash on Delivery | 106 |
| Kano | Cash on Delivery | 84 |

Card dominates in urban/commercial states. Cash on Delivery leads in Kano and Oyo. Mobile Money holds consistent second or third position across all states.

---

### Q7: Review Ratings & Sales Performance
[Click to see PostgreSQL Script](Q7.sql)
| Rating Category | Products | Total Revenue | Avg Unit Price |
|----------------|----------|--------------|----------------|
| High Rated (≥4.0) | 112 | ₦249,279,400 | ₦44,138 |
| Mid Rated (3.0–3.99) | 118 | ₦356,492,811 | ₦66,571 |
| Low Rated (<3.0) | 46 | ₦122,027,001 | ₦51,949 |

Mid Rated products generate the most revenue despite not having the best ratings. Higher priced products attract more critical reviews — no straightforward positive correlation between rating and revenue exists in this dataset.

---

### Q8: Top Seller Bonus Qualification (2024)
[Click to see PostgreSQL Script](Q8.sql)

Criteria: ≥10 delivered orders, average rating ≥4.0, ranked by total revenue.

| Seller | Orders | Avg Rating | Total Revenue |
|--------|--------|-----------|--------------|
| SportsCentral NG | 18 | 4.00 | ₦11,304,995 |
| GreenHome Stores | 17 | 4.00 | ₦10,906,987 |
| GardenHouse NG | 16 | 4.33 | ₦9,024,516 |
| LearnMore NG | 13 | 4.60 | ₦7,775,590 |
| FitLife Nigeria | 18 | 4.13 | ₦7,173,667 |
| Naija Grains | 15 | 4.00 | ₦6,591,255 |
| GardenPlus NG | 19 | 4.25 | ₦6,491,013 |
| RunFast NG | 16 | 4.00 | ₦6,228,668 |
| QuickTech NG | 20 | 4.17 | ₦6,054,975 |

Only 9 sellers qualified — the rating threshold (≥4.0) was the primary binding constraint. QuickTech NG is the only seller appearing in both the fulfilment efficiency top 15 and the bonus qualification list.

---

## Key Insights & Recommendations

### Customer Acquisition
- Lagos leads in both sign-up volume (142) and 30-day conversion (46.48%) — the highest-ROI acquisition market on the platform
- Kano and Oyo have the weakest conversion rates — targeted onboarding incentives (first-order discounts, free delivery) should be tested in these states
- FCT is underperforming relative to its sign-up volume — second in sign-ups, third in conversion

### Revenue & Segmentation
- Q4 is consistently the platform's peak trading period — operational capacity (inventory, logistics, seller readiness) must be scaled ahead of it each year
- The current spend segmentation thresholds (₦100K / ₦50K) are too low for the platform's average order value (~₦350K). Recommended revised thresholds: High ≥₦1M, Medium ₦500K–₦999K, Low <₦500K
- 553 customers generate 99.5% of revenue — retention of this base is the single highest-leverage action available to the business

### Product Performance
- All top 10 revenue products are Electronics — significant concentration risk across a 7-category platform
- Ratings do not reliably predict revenue — Mid Rated products outperform High Rated products by ₦107M. Category management decisions should weight revenue contribution alongside ratings
- 46 Low Rated products are still generating ₦122M — a reputational liability that needs seller-level intervention

### Seller Performance
- Only 15 sellers meet the ≥20 completed orders threshold — most sellers operate at low volume
- A 120-hour (5-day) maximum fulfilment standard is supported by the data as a reasonable platform-wide benchmark
- Only 9 sellers qualify for the bonus programme — a seller development initiative focused on fulfilment speed, review generation and order volume would expand this pool
- QuickTech NG is the platform's most well-rounded seller — fast fulfilment, strong rating, solid revenue. A benchmark case worth documenting

### Payment Infrastructure
- Card infrastructure should be prioritised in Lagos, FCT and Rivers
- Cash on Delivery logistics should be strengthened in Kano and Oyo — CoD dominance there is a market reality, not a problem
- Mobile Money is the most geographically universal method — a platform-wide Mobile Money partnership would unlock growth across all states simultaneously

---

## How to Run Locally

1. Install PostgreSQL (v17 or v18 recommended)
2. Create a new database:
   ```sql
   CREATE DATABASE tradezone;
   ```
3. Restore the cleaned dump:
   ```bash
   psql -U postgres -d tradezone -f cleaned_dump.sql
   ```
4. Run cleaning script first (if using raw data):
   ```bash
   psql -U postgres -d tradezone -f "Part 1.sql"
   ```
5. Run any business query:
   ```bash
   psql -U postgres -d tradezone -f Q1.sql
   ```

---

*Full analytical findings and business recommendations are documented in `Analyst_Memo.pdf`.*
