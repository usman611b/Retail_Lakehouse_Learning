# Gold layer learning notes

## Purpose and grain
Bronze records the source, Silver makes typed and checked rows, and Gold turns them into business views. Grain means what one row represents. Joins can multiply rows, so each notebook checks its grain before writing. These are full snapshots: rerunning a notebook recalculates from current Silver and overwrites the active Delta table. Incremental updates and scheduling come later.

## Metric definitions
The assignment names the marts but does not fully specify tax or status treatment. We explicitly use only completed orders for sales. Cancelled and returned orders are excluded. Payment status is not a second filter in this training snapshot; a payment reconciliation is a later exercise.
Revenue is order subtotal minus discount, before tax, in PKR. Tax and amount including tax are separate daily fields. Estimated cost is the sum of Silver item quantity times product cost. Estimated gross profit is net revenue minus that estimated cost, before other business expenses. Average order value is net revenue divided by completed order count; for a zero-order group it is zero. These are project decisions and must use the same wording in Power BI.

## Silver cost dependency
The assignment asks Silver to derive estimated line cost and margin. We updated Silver order_items to save estimated_line_cost = quantity times Silver product cost_price, and estimated_line_margin = line_total minus estimated_line_cost. Both are decimal(14,2). The Silver line margin is before order discount and tax. Gold discounts revenue, so Gold profit differs from raw line margin. All 9,868 Silver lines passed; zero were rejected. Historical profit would require historical product costs if prices change.

## Daily store sales
Notebook 01_gold_daily_store_sales.ipynb. Grain: calendar date and store, including zero-sale dates. It first sums items to one row per order, then joins completed order headers. Joining unsummarized items and summing order subtotal would repeat the header amount for every item. It checks line subtotal against each header.
The notebook builds a date range from first to last Silver order and crosses it with six stores, then left joins sales. Result: 552 rows, 550 days with completed sales, two zero-sale store-days, 3,665 completed orders, 13,628 units, PKR 12,824,593.40 revenue, and PKR 3,489,436.22 estimated gross profit. DQ009 requires date/store uniqueness; duplicates found: zero. Of 4,000 source orders, 210 cancelled and 125 returned orders are outside this sales definition.

## Product performance
Notebook 02_gold_product_performance.ipynb. Grain: date, store, product; 8,417 rows. An order discount lives on the header, but product revenue lives on its lines. The notebook allocates discount proportional to line_total divided by subtotal, rounds to cents, and assigns any rounding remainder to one line. It verifies that allocated discounts sum exactly to each order discount. Product revenue and profit both equal the daily totals.
The product order count uses distinct orders containing that product. Do not add product order counts across products to get overall orders: one order may contain several products. Units and allocated money are additive across products.

## Customer sales
Notebook 03_gold_customer_sales.ipynb. Grain: customer_id. A left join retains all 750 Silver customers; nine have no completed order. Sum of customer orders is 3,665 and sum of customer revenue is PKR 12,824,593.40, matching daily. The view contains no email or phone because those personal fields are unnecessary for the planned report.

## Weather and sales
Notebook 04_gold_weather_sales_analysis.ipynb. Grain: date and store. Daily sales is the left side of the weather join, so weather gaps cannot erase sales. The has_weather flag exposes gaps. Here all 552 rows have weather and the revenue sum matches daily. Weather is observational context; an association between rain and sales does not prove a causal effect.

## Delta, validation, and run order
Each notebook writes Delta data and reads the committed table back to verify row count and money. The _delta_log records table versions. Generated Delta data stays local and is ignored by Git; notebook code and notes are versioned.
Critical checks raise an error before writing on bad keys, mismatched totals, or changed grain. The clean supplied data did not exercise every failure branch. A later bad-data trial can test them.
Run updated Silver 08_silver_order_items.ipynb, then Gold notebooks 01, 02, 03, 04. The later Gold notebooks compare their sums to the daily control table. Next: export approved Gold views to Power BI, create the report, then add orchestration and cloud equivalents. Never sum averages to get an overall average.
