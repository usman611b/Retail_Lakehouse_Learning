# Silver layer study notes

## 1. What Silver does

Bronze keeps data close to its source. Silver creates reliable, typed records that later Gold models can join and summarize. Silver does **not** calculate revenue or build dashboard measures. Our pipeline is:

Source -> Bronze Delta -> Silver checks and conversions -> accepted Silver Delta
                                               -> rejected-row DataFrame
                                               -> error Delta where implemented

The source is still available in Bronze when a Silver rule changes. Each Silver table is a **snapshot**: rerunning its notebook overwrites that table with the latest accepted Bronze rows. For suppliers, products, stores, promotions, weather, orders, order_items, and payments, rejected records are appended under error/data with a run ID and processing timestamp. The Customers notebook currently only creates and counts rejected rows; it does not persist them. Both generated data folders are ignored by Git; notebook code and these notes are versioned.

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

Total: 19,329 Bronze rows became 19,329 Silver rows in this training snapshot. Customers and suppliers have no warning rules, so their zero warning cells mean none were defined, not that a separate warning check ran. A count match proves no rows were lost, but it does not by itself prove every business rule is correct. The notebooks also checked required fields, keys, references, types, allowed values, and several numeric relationships.

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
2. **Read Bronze.** Spark reads the current Delta version and counts source rows before changing anything. The six newer notebooks also compare the complete Bronze column list with an expected schema; the first three inspect their schema without that explicit whole-list check.
3. **Clean and type fields.** Surrounding whitespace is removed from text. Optional blank text becomes null. A safe type conversion changes numeric, date, timestamp, and boolean fields; unconvertible required input becomes null and is caught by later rules. Optional weather_code has the caveat explained in section 9. In supplier, product, and the six newer notebooks, the original row is kept as JSON in source_record for possible rejection evidence. The Customers notebook does not create source_record.
4. **Check references where needed.** Customers, suppliers, and stores have no Silver parent lookup. For dependent tables, a left join keeps every candidate row and marks whether its referenced Silver key exists. The notebook also verifies that joins do not change the source row count. Promotions uses distinct product categories because many products share a category.
5. **Check quality.** A window count finds repeated cleaned keys, including IDs that only differ by surrounding spaces. Every notebook creates quality_issue for rejected rows. Products also creates warning_issue. The six newer notebooks create quality_issue, critical_issue, and warning_issue. Their SQL rule helper converts a null predicate result to false; explicit missing-value rules handle null fields. Customers and suppliers use direct DataFrame expressions instead of that SQL rule helper.
6. **Split accepted and rejected rows.** Rows with empty quality_issue are eligible for Silver; other rows are error candidates. The accepted and rejected counts must add up to Bronze count.
7. **Save and read back.** In supplier, product, and the six newer notebooks, rejections are saved first when present. The six newer notebooks then stop on a critical failure before the Silver snapshot changes. The Customers notebook has no error-data write or critical branch. Accepted rows overwrite a Silver Delta table. Every notebook reads it back and checks the saved count; the newer notebooks also check saved column order and all converted types. Supplier and product notebooks check selected types, while we additionally inspected all saved Delta schemas during verification.

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

The critical branch and rejection-write branches were not exercised by this clean training dataset. They need a deliberate bad-data test before production use. The Customers notebook has no rejection-write branch yet. DQ009, uniqueness of Gold daily_store_sales by date and store, belongs to the next layer.

## 6. How Delta and Git fit

A Delta table is a folder with Parquet data files and a transaction log in _delta_log. The log records committed table versions and the schema. The Silver verification checked that each table's log exists and that saved row counts match accepted counts. At this point each Silver table has one committed version.

Git records notebook source and these notes. Git does not store Requirements, landing extracts, Silver data, or error data in this project. Running notebooks saves outputs into the notebook files, so check Git status before committing. Notebook execution counts and long Spark logs can change even when the code does not.

## 7. Problems encountered and what they taught us

- **WSL memory pressure:** running another Spark process while an older Jupyter Spark kernel was active almost filled WSL memory and swap. Close unused kernels; run one Silver notebook at a time. A slow Spark stage is not automatically a data error.
- **Out-of-order Jupyter execution:** Promotions' final type-check cell initially raised NameError because saved_df had not yet been created in that kernel. Its save cell later succeeded, and the final cell was rerun successfully. A cell's saved output reflects the last time that cell ran, not necessarily notebook order. Use execution counts and the Delta table itself to understand the actual state.
- **Spark warnings:** messages about native Hadoop libraries or a truncated plan did not stop the jobs. Check for an exception and the final verification output before classifying a warning as a failure.
- **Zero rejected rows:** this is evidence that this particular snapshot satisfied the implemented rules. It does not mean rejection logic is unnecessary or proven under bad input.

### Estimated line cost and margin for Gold

The updated order_items notebook joins accepted lines to Silver product costs. It saves estimated_line_cost = quantity times cost_price and estimated_line_margin = line_total minus estimated_line_cost, both decimal(14,2). These are before order discount or tax. Missing derived values fail validation. The rerun kept 9,868 lines, rejected zero, and verified the saved schema. Gold uses estimated_line_cost for profit after allocating discounts.

## 8. What Gold will use

Silver now gives typed, checked inputs for Gold. Gold must define sales metrics deliberately: the order header total, the order-line amount, payment status, cancellations and returns, and the grain of each Gold table all affect revenue. A one-to-many join from orders to order_items can multiply an order total, so aggregations must respect grain. The planned Gold outputs are daily_store_sales, product_performance, customer_sales, and weather_sales_analysis.

## 9. Data types and why they matter

The Bronze source determines the starting schema. PostgreSQL supplied already typed customer, order, order-item, and payment columns; the flat-file and weather CSV columns entered Bronze as strings. Silver brings these sources to useful business types. A string amount cannot reliably support arithmetic, and a string date is easy to sort incorrectly or join inconsistently.

- **string:** identifiers and categories. We trim leading and trailing spaces. We do not change case, so S001 and s001 would remain different keys.
- **integer:** whole numbers such as quantity, lead_time_days, humidity_pct, and optional weather_code.
- **boolean:** true or false flags. The CSV text True became a Spark boolean. A null or unconvertible required flag fails validation.
- **date:** a calendar day without a clock time, such as opened_date, start_date, or observed_date.
- **timestamp:** date plus time, such as order_ts and payment_ts. Silver keeps the source timestamp meaning; a Gold daily calculation will need an explicit choice of business timezone if sources later differ.
- **decimal(p,s):** exact base-ten numeric storage with p total digits and s digits after the decimal. Prices and amounts use decimal(12,2). Store coordinates use decimal(9,6). This avoids using binary floating-point arithmetic for currency. A cast is still a conversion policy: unusually precise input can be rounded, so precision checks would be needed for new sources.

The schema displays nullable=true for many fields even when our quality rules require values. This is Spark schema metadata; the notebook checks the rows rather than adding physical NOT NULL constraints to these path-based Delta tables. Seeing nullable=true does not mean the accepted dataset had null IDs.

The later notebooks use try_cast, which returns null when a value cannot be converted. A required field then fails its null rule. The optional weather_code is different: an invalid nonblank code can also become null and currently has no rejection rule. That is a known information-loss edge case to revisit if weather codes matter to Gold.

## 10. Spark and Python vocabulary from our notebooks

- **Path and /:** Python pathlib combines project folders into a path. Converting the Path with str gives Spark the folder location.
- **SparkSession and getOrCreate:** the notebook obtains one Spark session with Delta enabled. getOrCreate can reuse an existing session in the same kernel; simply changing a builder setting later does not guarantee a fresh SparkContext.
- **DataFrame:** a distributed table-like object. A DataFrame variable usually describes a plan; it is not a Python list of all rows.
- **F.col and alias:** refer to a named column and name the resulting column after cleaning or casting.
- **select:** choose or transform columns. **withColumn:** add or replace a column. Neither changes Bronze in place.
- **trim:** remove spaces at the start and end of text. It does not remove internal spaces or standardize spelling.
- **when/otherwise:** conditional expression for one row. We use it to turn optional blank text into null and to label failing quality rules.
- **isNull/isNotNull:** test for a real null. An empty string is not null, so required text checks need both tests.
- **isin and contains:** membership in an allowed set, or a basic substring check. Checking for @ is only a basic email rule, not full email validation.
- **filter:** retain rows matching a condition. Accepted rows have an empty quality_issue; rejected rows have a nonempty one.
- **groupBy/count/distinct/orderBy:** explore duplicates, value distributions, and unique lookup values. The early exploratory groupBy count can inspect the original ID, while the final window check uses the cleaned ID.
- **Window.partitionBy plus count:** count rows sharing a key without collapsing them. Every duplicate row retains its own row and can receive the duplicate issue.
- **join:** compare rows across tables. A left join keeps the Bronze-side row even if its reference is absent. A match marker records whether the lookup succeeded. An inner join here would silently drop unknown keys.
- **F.expr:** evaluate the later notebooks' rule predicates written as Spark SQL strings. **F.coalesce(predicate, false):** turn an unknown/null SQL result into false; separate rules explicitly flag required nulls. SQL AND, OR, NOT, IS NULL, IN, and BETWEEN appear in these predicates.
- **F.concat_ws:** join multiple issue labels with semicolons. A row can have several problems. When no labels match, it produces the empty issue string used by the split.
- **F.to_json(F.struct(...)):** capture the original Bronze columns as one JSON text value for debugging rejected supplier/product and later-table rows. It is excluded from accepted Silver output.
- **list comprehensions and for loops:** build the later notebooks' field conversion list, lookups, and issue expressions from their table-specific configuration. The first three notebooks write more checks explicitly.
- **count, show, collect, write:** actions that make Spark execute a plan. Our notebooks mainly use count, show, and write. Repeating count provides visible checks but can make local runs slow. printSchema inspects the planned schema without showing every record.

Spark uses lazy evaluation for transformations. For example, creating clean_df does not rewrite a file. Saving with write.format("delta") is the operation that persists a new Silver version.

## 11. Key and join reasoning

A primary key has two obligations: a value must be present, and accepted rows must not repeat it. Trimming happens before the final duplicate window, so IDs written as S001 and space-S001-space collide. The first exploratory duplicate count in a notebook may look at raw values; the final cleaned-key check is authoritative for Silver.

A foreign key check compares an ID with a cleaned reference table. The lookups are intentionally ordered: products use Silver suppliers; orders use Silver customers, stores, and promotions; order_items uses Silver orders and products; payments uses Silver orders. Promotions' category lookup uses distinct product categories rather than individual products. Otherwise several products in one category could multiply one promotion row. Later notebooks also verify that a non-category lookup key is unique and that each left join preserves the input row count.

The weather grain is a composite key. A store may have many observations on different dates, and a date may have observations for many stores. Only a repeated pair of store_id and observed_date violates that table's uniqueness rule. A row-count check after a join is important because a duplicated reference key can multiply rows even when no input row was dropped.

## 12. Reject, warning, critical failure, and evidence

These outcomes mean different things:

| Outcome | What happens | Example |
| --- | --- | --- |
| Accepted | Saved to the Silver Delta snapshot | Valid store with valid coordinates |
| Rejected | Excluded from Silver; saved to error Delta where that branch exists | Missing product_id |
| Warning | Accepted, but warning_issue remains in Silver where implemented | Product list price below cost |
| Critical | Rejection evidence is saved, then the build raises an error before overwriting Silver | Order with unknown customer |

The data dictionary calls DQ001–DQ006 critical for orders and order_items. DQ007 product price, DQ008 weather humidity, and DQ010 order formula are warnings. DQ009 is a future Gold uniqueness check. Other required-field and allowed-value checks come from the field dictionary and our project rules.

A saved error record contains a quality_issue string and, for suppliers/products and newer tables, source_record JSON, run_id, and rejected_at. The run ID allows us to count just the rejections from one execution even if an error table contains earlier runs. Because the training data produced zero rejects, those error tables may not exist yet. The Customers notebook currently leaves rejected rows only in a DataFrame during that session; it should gain persisted error evidence before production use.

The error append and the Silver overwrite are **separate Delta transactions**. The notebook verifies the error write before proceeding, but this is not one atomic transaction spanning both tables. If a job stops between them, error evidence might exist while Silver still has its previous version. Reruns also create a new run ID and can append the same rejected source row again; an incremental production design would need a deduplication or run-state policy.

## 13. What verification proves, and what it does not

For the completed training snapshot, we observed 19,329 accepted rows, no rejected rows, no accepted warnings, and a Delta log for each of the nine Silver tables. The saved tables have the expected key fields and converted types. Counts were checked at the stages relevant to each notebook: source, cleaned rows, reference joins where used, accepted/rejected split, and saved output.

These observations do **not** prove every possible bad row will be classified correctly. In particular, no rejected-row append or critical-failure branch was exercised. The early notebooks contain training-snapshot expected counts in their display checks; if source volume changes, use the dynamic Bronze count in the save-stage reconciliation. Row counts alone cannot prove financial totals or business meaning.

A useful future practice exercise is to copy a Bronze table to a temporary test path, add one deliberately invalid row, run the Silver logic against that path, and confirm the named issue, the accepted/rejected counts, and the behavior of error and critical rules. Never corrupt the original Bronze table for this exercise.

## 14. Runtime, Jupyter, and version control lessons

The WSL Jupyter kernel uses Linux Python, Linux Java, and the F: drive mounted at /mnt/f. Spark plus Delta packages must be available in that kernel. PostgreSQL Docker is not needed to rerun Silver from existing Bronze Delta folders; Bronze PostgreSQL extraction is the stage that needs it.

A Jupyter kernel keeps Python variables in memory. Cells can be run out of order; a saved output can remain from an earlier execution even after another cell succeeds. The Promotions NameError came from running its audit cell before saved_df existed. Rerunning it after the save cell fixed the displayed result. Restarting the kernel clears variables but not files already committed to Delta.

Multiple Spark kernels can exhaust WSL memory. Stop unused kernels and run these local notebooks one at a time. A shuffle uses network-like data exchange between Spark tasks; reducing shuffle partitions to four in the newer notebooks avoids scheduling many tiny tasks for these small tables, although Delta file operations can still be slow on the Windows-mounted drive.

The notebooks and notes are tracked in Git; generated Delta folders, Requirements, landing extracts, and error data are ignored. Git status showed modified notebooks after execution because outputs and execution counts are saved inside .ipynb JSON. We checked that notebook code had not changed before committing the verified outputs. LF/CRLF line-ending warnings during Git staging did not indicate broken notebook content.

## 15. Read the notebook variables as a data journey

| Variable in the newer notebooks | Meaning | Persisted? |
| --- | --- | --- |
| bronze_df | Current source-shaped Bronze Delta data | Already stored in Bronze |
| clean_df | Trimmed and typed values plus source_record | No |
| checked_base_df | Clean values plus lookup-match markers | No |
| checked_df | Each row plus duplicate count and issue strings | No |
| accepted_df / rejected_df | Two row sets after the quality split | No |
| silver_df | Accepted business columns plus warning_issue | Written to Silver Delta |
| saved_df | A fresh read of the committed Silver Delta version | Reads the stored result |

These are different DataFrames, not in-place changes to one table. A variable points to a transformation plan. Dropping helper columns before saving keeps output useful for Gold; rejected rows retain investigation evidence. The older customer, supplier, and product notebooks use more table-specific variable names but follow the same idea.

Small helpers in the code have precise jobs: F.lit creates a constant Spark column; F.abs measures absolute numeric difference for formula warnings; F.current_timestamp records processing time; uuid4 creates a new run ID; mkdir creates a folder only when needed; and a Python raise stops execution when a check fails. The functions run in the Spark or Python environment indicated by the code, so a Python if statement controls a job, while a Spark when expression decides a value separately for each row.

## 16. Walk through one record and one formula

Imagine a product arrives with cost_price text equal to bad_value. Bronze keeps that source text. Silver try_cast to decimal(12,2) produces null. The missing_or_invalid_cost rule puts that label in quality_issue, so the product goes to rejected_df. The original bad_value remains in source_record for investigation. This is the intended path, but the current clean dataset did not execute its error-write branch.

Imagine an order with subtotal 2,200.00, discount 220.00, and tax 99.00. The expected total is 2,079.00. We compare the stored total to this calculation using absolute difference. A difference over 0.02 receives a warning, while the row can still enter Silver if it passes its rejection rules. We do not add item rows to the order header before this comparison.

These are row-level checks. Gold aggregation is a different step: the sum of order totals across orders is valid only after choosing which statuses represent sales. Joining one order to three items creates three joined rows; summing the header total after that join would triple-count it. The order-item line_total belongs to each line's grain, while the order total belongs to the header's grain.
