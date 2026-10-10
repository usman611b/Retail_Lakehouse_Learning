# Silver layer study notes

## 1. What Silver does

Bronze keeps data close to its source. Silver creates reliable, typed records that later Gold models can join and summarize. Silver does **not** calculate revenue or build dashboard measures. Our pipeline is:

Source -> Bronze Delta -> Silver checks and conversions -> accepted Silver Delta
                                               -> rejected error Delta

The source is still available in Bronze when a Silver rule changes. Each Silver table is a **snapshot**: rerunning its notebook overwrites that table with the latest accepted Bronze rows. Error records, if any, are appended under error/data with a run ID and processing timestamp. Both generated data folders are ignored by Git; notebook code and these notes are versioned.

## 2. The nine tables and their grain

| Table | One row means | Bronze rows | Saved Silver rows | Rejected | Warnings |
| --- | --- | ---: | ---: | ---: | ---: |
| customers | one customer | 750 | 750 | 0 | 0 |
| suppliers | one supplier | 18 | 18 | 0 | 0 |
| products | one product | 120 | 120 | 0 | 0 |
| stores | one store | 6 | 6 | 0 | 0 |
| promotions | one promotion | 15 | 15 | 0 | 0 |
| weather | one store on one observed date | 552 | 552 | 0 | 0 |
| orders | one order header | 4,000 | 4,000 | 0 | 0 |
| order_items | one order line | 9,868 | 9,868 | 0 | 0 |
| payments | one payment record | 4,000 | 4,000 | 0 | 0 |

Total: 19,329 Bronze rows became 19,329 Silver rows in this training snapshot. A count match proves no rows were lost, but it does not by itself prove every business rule is correct. The notebooks also checked required fields, keys, references, types, allowed values, and several numeric relationships.

## 3. Why the notebook order matters

Customers and stores must exist before orders can check their customer_id and store_id. Suppliers must exist before products check supplier_id. Products supply valid categories for promotions. Stores must exist before weather checks store_id. Orders and products must exist before order_items checks order_id and product_id. Orders must exist before payments checks order_id.

The relationship map is:

- customers -> orders
- stores -> orders and weather
- promotions -> orders (promo_id is optional)
- suppliers -> products
- orders -> order_items and payments
- products -> order_items

A primary key identifies a row in its own table. A foreign key points to an existing row in another table. Weather uses the pair (store_id, observed_date) as its grain and duplicate check.

## 4. A notebook, step by step

1. **Start Spark with Delta.** The WSL kernel uses Linux Java. The Delta extension and catalog let Spark read and write Delta tables. The newer notebooks use two local threads and four shuffle partitions to limit resource use.
2. **Read Bronze.** Spark reads the current Delta version. The notebook checks the expected column names and counts source rows before changing anything.
3. **Clean and type fields.** Surrounding whitespace is removed from text. Optional blank text becomes null. A safe type conversion changes numeric, date, timestamp, and boolean fields; unconvertible input becomes null and is caught by later rules. The original row is kept as JSON in source_record for possible rejection evidence.
4. **Check references.** A left join keeps every candidate row and marks whether its referenced Silver key exists. The notebook also verifies that joins do not change the source row count. Promotions uses distinct product categories because many products share a category.
5. **Check quality.** A window count finds repeated cleaned keys, including IDs that only differ by surrounding spaces. Named rule results are joined into quality_issue, critical_issue, and warning_issue. Null SQL predicate results are treated as false so a missing value is handled by its explicit missing-value rule.
6. **Split accepted and rejected rows.** Rows with empty quality_issue are eligible for Silver; other rows are error candidates. The accepted and rejected counts must add up to Bronze count.
7. **Save and read back.** Rejections are saved first, if any. Critical failures then stop before the Silver snapshot changes. Otherwise, accepted rows overwrite the Silver Delta table. The notebook reads the saved version back and verifies its count, columns, and types.

Spark DataFrame transformations such as select, withColumn, and join describe work; actions such as count, show, and write make Spark perform it. Several counts make the notebook transparent for learning, though each count costs time.

## 5. Rules used by each table

- **Customers:** unique nonblank customer_id; required names, email, loyalty tier, join date, and active flag; email contains @; loyalty tier is Bronze, Silver, or Gold. Optional phone and city can be null.
- **Suppliers:** unique nonblank supplier_id; required name; lead_time_days is a positive integer; active_flag is boolean; optional email, if present, contains @. Optional contact information can be null.
- **Products:** unique nonblank product_id; required name, category, and supplier; supplier exists in Silver; cost and list price are nonnegative decimals; currency is PKR; active_flag is boolean. List price below cost is a warning under DQ007, so it does not reject an otherwise valid product. The six category names used here came from the training source because the workbook does not enumerate its allowed category list.
- **Stores:** unique nonblank store_id; required name, city, and region; latitude is between -90 and 90; longitude is between -180 and 180; opened_date is a valid date. manager_name is optional.
- **Promotions:** unique nonblank promo_id; required name; type is PERCENT or FIXED; discount is positive; category is All or a category found in Silver products; valid start and end dates with start no later than end; active_flag is boolean. The category lookup is an additional project check.
- **Weather:** store exists in Silver; store_id plus observed_date is unique; observed_date is a valid date; rainfall and wind speed are nonnegative; temperature and humidity convert to numeric values; source is present. Humidity outside 0 to 100 is a DQ008 warning. The -50 to 60 C temperature warning range is provisional because the workbook says only “reasonable range.” A warning remains visible in Silver.
- **Orders:** unique nonblank order_id; customer and store exist; optional promo_id, when present, exists; valid timestamps with updated_at at or after order_ts; status is completed, cancelled, or returned; channel is store or online; money fields are nonnegative; currency is PKR. DQ001–DQ003 (order key, customer, store) are critical and stop the build. DQ010 reports a warning if total_amount differs from subtotal minus discount plus tax by over PKR 0.02. That tolerance is a project choice.
- **Order items:** unique nonblank order_item_id; order and product exist; quantity is positive; unit_price and line_total are nonnegative; currency is PKR. DQ004–DQ006 (order reference, product reference, quantity and price) are critical. A line_total difference greater than PKR 0.02 is reported as a warning.
- **Payments:** unique nonblank payment_id; order exists; valid payment timestamp; method is cash, card, wallet, or bank_transfer; status is paid, refunded, or cancelled; amount is nonnegative; currency is PKR. Silver preserves payment facts without deciding which statuses count as revenue.

The critical branch and rejection-write branch were not exercised by this clean training dataset. Their code exists, but a future bad-data test should confirm them before treating the workflow as production ready. DQ009, uniqueness of Gold daily_store_sales by date and store, belongs to the next layer.

## 6. How Delta and Git fit

A Delta table is a folder with Parquet data files and a transaction log in _delta_log. The log records committed table versions and the schema. The Silver verification checked that each table's log exists and that saved row counts match accepted counts. At this point each Silver table has one committed version.

Git records notebook source and these notes. Git does not store Requirements, landing extracts, Silver data, or error data in this project. Running notebooks saves outputs into the notebook files, so check Git status before committing. Notebook execution counts and long Spark logs can change even when the code does not.

## 7. Problems encountered and what they taught us

- **WSL memory pressure:** running another Spark process while an older Jupyter Spark kernel was active almost filled WSL memory and swap. Close unused kernels; run one Silver notebook at a time. A slow Spark stage is not automatically a data error.
- **Out-of-order Jupyter execution:** Promotions' final type-check cell initially raised NameError because saved_df had not yet been created in that kernel. Its save cell later succeeded, and the final cell was rerun successfully. A cell's saved output reflects the last time that cell ran, not necessarily notebook order. Use execution counts and the Delta table itself to understand the actual state.
- **Spark warnings:** messages about native Hadoop libraries or a truncated plan did not stop the jobs. Check for an exception and the final verification output before classifying a warning as a failure.
- **Zero rejected rows:** this is evidence that this particular snapshot satisfied the implemented rules. It does not mean rejection logic is unnecessary or proven under bad input.

## 8. What Gold will use

Silver now gives typed, checked inputs for Gold. Gold must define sales metrics deliberately: the order header total, the order-line amount, payment status, cancellations and returns, and the grain of each Gold table all affect revenue. A one-to-many join from orders to order_items can multiply an order total, so aggregations must respect grain. The planned Gold outputs are daily_store_sales, product_performance, customer_sales, and weather_sales_analysis.
