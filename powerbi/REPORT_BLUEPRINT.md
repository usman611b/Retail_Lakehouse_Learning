# Retail Lakehouse Power BI report blueprint

## Goal and metric contract

Build a professional multi-page Power BI report from the four Gold Parquet exports. A report page is a focused business question; a visual should earn its space by answering that question. Use one consistent sales contract throughout: completed orders only; revenue = subtotal - discount, before tax; estimated gross profit = revenue - estimated product cost; average order value = revenue / completed orders. Currency is PKR. Dates cover June 1 through August 31, 2026 in this training snapshot.

Baseline checks: revenue PKR 12,824,593.40; completed orders 3,665; completed units 13,628; estimated gross profit PKR 3,489,436.22; 552 date-store rows; 8,417 date-store-product rows; 750 customers, including 9 with no completed sale; 552 weather-store-date rows.

Do not sum revenue from different Gold tables together. Each mart represents the same sales at a different grain.

## Model before design

Use daily_store_sales as the source for executive sales measures. Product performance supplies product measures. Customer sales is a June-August snapshot and has no order-date grain. Weather_sales_analysis contains daily sales repeated with weather context; use it only for weather questions, not as an additional source for the executive revenue card.

Create shared Date and Store dimensions and one-to-many, single-direction relationships from them to daily_store_sales, product_performance, and weather_sales_analysis. Do not relate fact tables directly. A Product dimension may filter product_performance. Customer sales stays independent until a suitable customer-order fact exists. Check Power BI's automatic relationships before accepting them. Global date and store slicers should not appear on the customer page because that table cannot respond correctly to those filters.

## Visual design system

Canvas: 16:9, with a roomy header, four or fewer KPI cards in one row, one main chart, and two supporting views. Background #F7F8FA, white cards, dark navy text #14213D, teal primary #0F766E, warm amber accent #D99A24, muted red alert #C85250. Use one readable font, consistent 16-18 point chart titles, 26-30 point page titles, modest corner radius, subtle borders, and generous whitespace. Show PKR, thousands separators, and units on axes; use the same numeric precision across pages. Avoid 3D effects, crowded labels, rainbow palettes, and relying on color alone for meaning.

## Pages to build from current Gold tables

1. Executive overview. Question: how is the retail business performing? Cards: net revenue, completed orders, estimated gross profit, estimated margin. Main visual: daily revenue line. Supporting visuals: ranked store revenue horizontal bar and product category revenue horizontal bar. Slicers: date range and store/region. Add a small note that revenue excludes tax and profit is estimated.

2. Sales trends. Question: when did sales change? Cards: units sold and average order value. Daily revenue line with optional prior-period comparison; separate order-volume line or column chart; month summary matrix with revenue, orders, units, profit, and margin. Use the shared Date and Store dimensions. Do not sum the stored average_order_value column; calculate AOV from sums.

3. Store performance. Question: which locations lead or lag? Ranked horizontal bars for revenue and estimated margin, not two scales on one chart. Matrix by region and store with revenue, orders, units, AOV, and profit. A store drillthrough page can show the selected store's date trend and product mix. Six stores fit readable labels; a map is optional, not required.

4. Product and category. Question: what sells and what earns? Category revenue bar, top products by revenue bar, product profit or margin scatter/column view, and searchable product matrix with units, revenue, cost, profit, margin, and distinct order count. Product order counts cannot be added across products because a basket may contain several products. Date and Store slicers work here through shared dimensions.

5. Customers and loyalty. Question: who are the customers in this snapshot? Cards: total customers, customers with completed sales, no-sale customers, and revenue per buying customer. Bars by loyalty tier and city; distribution of completed orders per customer; a customer table with customer ID, name, tier, orders, revenue, AOV, and last completed order date. Explain that this is a period-to-date snapshot, not a date-filterable order history. Avoid showing email or phone.

6. Weather context. Question: how do store-day sales vary with weather? Scatter plot of rainfall vs revenue, with store as legend or small multiples; grouped summary by rainfall band; weather/day table with temperature, rainfall, orders, revenue, and profit. Use has_weather for a data-coverage card. Label findings as association, never causation.

7. Detail explorer and definitions. Provide date-store and date-store-product matrices with drillthrough, plus a definitions section for completed sales, revenue, estimated cost/profit, and data coverage. Tooltips add context; they must not hide essential metrics.

## Further marts needed for full business coverage

The current four Gold exports do not contain enough information for accurate payment/refund, cancellation/return, channel, promotion, supplier, basket, and transaction-detail pages. Build additional checked Gold marts from Silver before claiming these analyses. Candidate marts: order_status_and_payments, channel_sales, promotion_performance, supplier_performance, and order_detail. Specify their grains and reconciliation rules first. A customer-date fact is needed before customer trends or customer-level date slicers can be reliable.

## Interaction and quality checklist

Use consistent page navigation and synced Date/Store slicers only where their relationships work. Configure visual interactions deliberately. Add store and product drillthrough, report tooltips for secondary details, a reset-filters bookmark, descriptive titles, and alt text. Check tab order and contrast. Validate every card against Gold totals, test each slicer for unexpected blanks, check that product and weather visuals do not duplicate executive revenue, and confirm refresh works after rerunning the Parquet export notebook.

## Build order

Save the report under powerbi, inspect relationships and column types, create Date/Store dimensions, create and validate DAX measures, apply the theme, build pages 1-7 one at a time, test interactions and accessibility, then build the additional Gold marts and their pages. Keep the PBIX local unless there is a clear reason to publish it.
