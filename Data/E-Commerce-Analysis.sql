/*============================*/
-- E-COMMERCE SALES ANALYSIS
/*============================*/



/*==============================*/
-- Undertand The Dataset
/*==============================*/

--- Row Count

select count(*) as total_rows
from e_commerce_sales;


--- Data Range 

select
min(order_date) as first_order_date,
max(order_date) as last_order_date
from e_commerce_sales;

--- Dataset Summary

select
count(distinct order_id) as unique_orders,
count(distinct customer_name) as unique_customers,
count(distinct category) as categories,
count(distinct region) as regions,
count(distinct city) as cities
from e_commerce_sales;

--- Null Check

select
count(*) as total_rows,
count(*) - count(order_id) as missing_orders,
count(*) - count(order_date) as missing_order_date,
count(*) - count(category) as missing_category,
count(*) - count(sales) as missing_sales,
count(*) - count(profit) as missing_profit,
count(*) - count(discount) as missing_discount,
count(*) - count(quantity) as missing_quantity,
count(*) - count(product_name) as missing_product_name,
count(*) - count(city) as missing_city,
count(*) - count(unit_price) as missing_unit_price,
count(*) - count(region) as missing_region,
count(*) - count(payment_mode) as missing_payment_mode,
count(*) - count(sub_category) as missing_sub_category,
count(*) - count(customer_name) as missing_customer_name
from e_commerce_sales;

--- Sales Lines Per Order

select
order_id,
count(*) as row_count
from e_commerce_sales
group by order_id
having count(*) > 1
order by row_count desc;


--- Duplicate Complete  Records

select order_id,product_name,quantity,customer_name,order_date,category,sales,profit,sub_category,region,payment_mode,unit_price,discount,city,
count(*) as duplicate_count
from e_commerce_sales
group by order_id,customer_name,order_date,category,sales,profit,product_name,quantity,sub_category,region,payment_mode,unit_price,discount,city
having count(*) > 1;

--- Find Invalid or Unusual Numeric Values

select
count(*) filter (where sales < 0) as negative_sales_rows,
count(*) filter (where profit < 0) as negative_profit_rows,
count(*) filter (where quantity <= 0) as nonpositive_quantity_rows,
count(*) filter (where unit_price < 0) as negative_unit_price_rows,
count(*) filter (
where discount < 0 or discount > 100
) as invalid_discount_rows
from e_commerce_sales;


--- Check Order Level Consistency

select
order_id,
count(*) as sales_lines,
round(sum(sales)::numeric, 2) as order_sales,
round(sum(profit)::numeric, 2) as order_profit,
sum(quantity) as total_quantity
from e_commerce_sales
where order_id is not null
group by order_id
order by order_id;

--- Find Orders Containing multiple Products or Discount Levels 

select
order_id,
count(*) as sales_lines,
count(distinct product_name) as distinct_products,
count(distinct discount) as distinct_discount_levels
from e_commerce_sales
where order_id is not null
group by order_id
having count(distinct product_name) > 1
    or count(distinct discount) > 1
order by sales_lines desc;


/*==============================*/
-- Data Cleaning
/*==============================*/

-- Capture a Cleaning Reconciliation Baseline

select
count(*) as row_count,
count(distinct order_id) as distinct_orders,
count(distinct customer_name) as distinct_customer_names,
min(order_date) as first_order_date,
max(order_date) as last_order_date,
count(*) filter (where order_id is null) as missing_order_ids,
count(*) filter (where order_date is null) as missing_dates,
count(*) filter (where customer_name is null) as missing_customer_names,
count(*) filter (where sales is null) as missing_sales,
count(*) filter (where profit is null) as missing_profit,
count(*) filter (where discount is null) as missing_discount,
count(*) filter (where quantity is null) as missing_quantity,
count(*) filter (where unit_price is null) as missing_unit_price,
round(sum(sales)::numeric, 2) as total_revenue,
round(sum(profit)::numeric, 2) as total_profit,
round(sum(quantity)::numeric, 2) as total_quantity
from e_commerce_sales;


--- Trim Text Fields

update e_commerce_sales
set
category = trim(category),
sub_category = trim(sub_category),
customer_name = trim(customer_name),
city = trim(city),
region = trim(region),
payment_mode = trim(payment_mode),
product_name  = trim(product_name);




--- Revenue Reconciliation Audit

with checked as (
select
order_id,
sales,
quantity,
unit_price,
discount,
quantity * unit_price * (1 - discount / 100.0) as expected_sales
from e_commerce_sales
where sales is not null
and quantity is not null
and unit_price is not null
and discount is not null
)
select
count(*) as comparable_lines,
count(*) filter (where abs(sales - expected_sales) > 0.01) as mismatch_lines,
round(100.0 * count(*) filter (where abs(sales - expected_sales) > 0.01) / nullif(count(*), 0), 2) as mismatch_rate_pct,
round(sum(sales)::numeric, 2) as recorded_revenue,
round(sum(expected_sales)::numeric, 2) as formula_revenue,
round(sum(sales - expected_sales)::numeric, 2) as net_difference,
round(sum(abs(sales - expected_sales))::numeric, 2) as absolute_difference
from checked;


--- Corrected E-commerce Analytics View

create or replace view e_commerce_analytics as
select
category,
sub_category,
region,
city,
discount,
case
when discount is null then 'missing discount'
when discount < 0 or discount > 100 then 'invalid discount'
when discount = 0 then '0%'
when discount <= 5 then '1-5%'
when discount <= 10 then '6-10%'
when discount <= 15 then '11-15%'
when discount <= 20 then '16-20%'
else '>20%'
end as discount_band,
extract(year from order_date)::int as order_year,
extract(month from order_date)::int as order_month,
extract(quarter from order_date)::int as order_quarter,
sum(sales) as total_sales,
sum(profit) as total_profit,
count(distinct order_id) as total_orders,
round(sum(profit)::numeric / nullif(count(distinct order_id), 0), 2) as avg_profit_per_order,
round(sum(quantity)::numeric / nullif(count(distinct order_id), 0), 2) as avg_quantity_per_order,
round(100.0 * sum(profit) / nullif(sum(sales), 0), 2) as profit_margin_pct
from e_commerce_sales
group by
category,
sub_category,
region,
city,
discount,
extract(year from order_date),
extract(month from order_date),
extract(quarter from order_date);


/*======================================*/
-- Core Business KPI
/*======================================*/

--- Over All KPI

select
  count(distinct order_id) as orders,
  count(distinct customer_name) as customers,
  sum(sales) as revenue,
  sum(profit) as profit,
  round(100.0 * sum(profit) / nullif(sum(sales),0), 2) as margin_pct,
  round(sum(sales) / count(distinct order_id), 2) as aov,
  round(sum(sales) / count(distinct customer_name), 2) as revenue_per_customer
from e_commerce_sales;

/*===================================*/
--- Time Based Analysis
/*===================================*/


--- Year-over-Year Growth

with bounds as (
select
max(order_date)::date as max_date
    from e_commerce_sales
),

yearly_ytd as (
select
extract(year from e.order_date)::int as year,
sum(e.sales) as ytd_revenue,
		
count(distinct e.order_id) as ytd_orders

from e_commerce_sales e
cross join bounds b

 
where e.order_date >=
date_trunc('year', e.order_date)::date

and e.order_date::date <=
(
date_trunc(
'year',
e.order_date
)::date
+
(
b.max_date
- date_trunc('year', b.max_date)::date
)
)

group by
extract(year from e.order_date)::int
)

select
year,

round(ytd_revenue::numeric, 2)
as ytd_revenue,

ytd_orders,

round(
100.0 * (
ytd_revenue
- lag(ytd_revenue) over (order by year)
)
/ nullif(
lag(ytd_revenue) over (order by year),
0
),
2
) as revenue_yoy_pct

from yearly_ytd

order by year;


--- Monthly Seasonality By Category

select
extract(month from order_date) as month,
category,
count(distinct order_id) as orders,
sum(sales) as revenue
from e_commerce_sales
group by 
extract(month from order_date),
category
order by month,revenue desc;

--- Running (Cumulative) Revenue

select
date_trunc('month',order_date) as month,
sum(sales) as revenue,
sum(sum(sales))over(
order by date_trunc('month',order_date)
rows between unbounded preceding and current row
) as cumulative_revenue
from e_commerce_sales
group by date_trunc('month',order_date)
order by month,revenue;




-- Like For Like Monthly Comparison

with bounds as (
select
max(order_date)::date as max_date
from e_commerce_sales
),
monthly as (
select
date_trunc('month', e.order_date)::date as month_start,
sum(e.sales) as revenue,
sum(e.profit) as profit,
count(distinct e.order_id) as orders
from e_commerce_sales e
cross join bounds b
where e.order_date >= date_trunc('year', b.max_date)::date - interval '1 year'
and e.order_date < date_trunc('month', b.max_date)::date
group by date_trunc('month', e.order_date)::date
),
comparison as (
select
c.month_start as current_month,
p.revenue as prior_revenue,
c.revenue as current_revenue,
p.profit as prior_profit,
c.profit as current_profit,
p.orders as prior_orders,
c.orders as current_orders
from monthly c
join monthly p on p.month_start = (c.month_start - interval '1 year')::date
cross join bounds b
where c.month_start >= date_trunc('year', b.max_date)::date
and c.month_start < date_trunc('month', b.max_date)::date
)
select
current_month,
round(prior_revenue::numeric, 2) as prior_revenue,
round(current_revenue::numeric, 2) as current_revenue,
round(100.0 * (current_revenue - prior_revenue) / nullif(prior_revenue, 0), 2) as revenue_yoy_pct,
round(prior_profit::numeric, 2) as prior_profit,
round(current_profit::numeric, 2) as current_profit,
round(100.0 * (current_profit - prior_profit) / nullif(abs(prior_profit), 0), 2) as profit_change_pct,
prior_orders,
current_orders
from comparison
order by current_month;

-- Find When Decline Start

with bounds as (
select
max(order_date)::date as max_date
from e_commerce_sales
),
monthly_category as (
select
date_trunc('month', e.order_date)::date as month_start,
e.category,
sum(e.sales) as revenue,
sum(e.profit) as profit
from e_commerce_sales e
cross join bounds b
where e.order_date >= date_trunc('year', b.max_date)::date - interval '1 year'
and e.order_date < date_trunc('month', b.max_date)::date
group by date_trunc('month', e.order_date)::date, e.category
),
paired as (
select
c.month_start,
c.category,
p.revenue as prior_revenue,
c.revenue as current_revenue,
p.profit as prior_profit,
c.profit as current_profit
from monthly_category c
join monthly_category p on p.category = c.category
and p.month_start = (c.month_start - interval '1 year')::date
cross join bounds b
where c.month_start >= date_trunc('year', b.max_date)::date
and c.month_start < date_trunc('month', b.max_date)::date
)
select
month_start,
category,
round(prior_revenue::numeric, 2) as prior_revenue,
round(current_revenue::numeric, 2) as current_revenue,
round((current_revenue - prior_revenue)::numeric, 2) as revenue_change,
round(100.0 * (current_revenue - prior_revenue) / nullif(prior_revenue, 0), 2) as revenue_yoy_pct,
round((current_profit - prior_profit)::numeric, 2) as profit_change
from paired
where current_revenue < prior_revenue
order by revenue_change asc;



--- Diagnose The Revenue Decline

with date_bounds as (
select max(order_date)::date as max_date
from e_commerce_sales
),
bounds as (
select
date_trunc('year', max_date)::date as current_start,
max_date + 1 as current_end,
(date_trunc('year', max_date) - interval '1 year')::date as prior_start,
(max_date - interval '1 year')::date + 1 as prior_end
from date_bounds
),
segment_sales as (
select
'category' as dimension,
e.category as segment,
sum(e.sales) filter (where e.order_date >= b.prior_start and e.order_date < b.prior_end) as prior_revenue,
sum(e.sales) filter (where e.order_date >= b.current_start and e.order_date < b.current_end) as current_revenue
from e_commerce_sales e
cross join bounds b
where e.order_date >= b.prior_start
and e.order_date < b.current_end
group by e.category
union all
select
'region',
e.region,
sum(e.sales) filter (where e.order_date >= b.prior_start and e.order_date < b.prior_end),
sum(e.sales) filter (where e.order_date >= b.current_start and e.order_date < b.current_end)
from e_commerce_sales e
cross join bounds b
where e.order_date >= b.prior_start
and e.order_date < b.current_end
group by e.region
union all
select
'city',
e.city,
sum(e.sales) filter (where e.order_date >= b.prior_start and e.order_date < b.prior_end),
sum(e.sales) filter (where e.order_date >= b.current_start and e.order_date < b.current_end)
from e_commerce_sales e
cross join bounds b
where e.order_date >= b.prior_start
and e.order_date < b.current_end
group by e.city
)
select
dimension,
segment,
round(coalesce(prior_revenue, 0)::numeric, 2) as prior_revenue,
round(coalesce(current_revenue, 0)::numeric, 2) as current_revenue,
round((coalesce(current_revenue, 0) - coalesce(prior_revenue, 0))::numeric, 2) as revenue_change,
round(100.0 * (coalesce(current_revenue, 0) - coalesce(prior_revenue, 0)) / nullif(prior_revenue, 0), 2) as growth_pct
from segment_sales
order by revenue_change asc nulls last;



--- Decompose Revenue Growth into Customers Orders and Order Value

with date_bounds as (
select max(order_date)::date as max_date
from e_commerce_sales
),
periods as (
select
(date_trunc('year', max_date) - interval '1 year')::date as prior_start,
(max_date - interval '1 year')::date + 1 as prior_end,
date_trunc('year', max_date)::date as current_start,
max_date + 1 as current_end
from date_bounds
),
order_metrics as (
select
case
when e.order_date >= p.prior_start and e.order_date < p.prior_end then 'prior ytd'
when e.order_date >= p.current_start and e.order_date < p.current_end then 'current ytd'
end as period,
e.customer_name,
e.order_id,
sum(e.sales) as order_revenue
from e_commerce_sales e
cross join periods p
where (e.order_date >= p.prior_start and e.order_date < p.prior_end)
or (e.order_date >= p.current_start and e.order_date < p.current_end)
group by 1, e.customer_name, e.order_id
),
summary as (
select
period,
count(distinct customer_name) as customers,
count(*) as orders,
sum(order_revenue) as revenue
from order_metrics
where period is not null
group by period
)
select
period,
customers,
orders,
round(revenue::numeric, 2) as revenue,
round(orders::numeric / nullif(customers, 0), 2) as orders_per_customer,
round(revenue::numeric / nullif(orders, 0), 2) as revenue_per_order,
round(revenue::numeric / nullif(customers, 0), 2) as revenue_per_customer
from summary
order by case period when 'prior ytd' then 1 else 2 end;

--- Separate Order Volume Changes From Order Value Changes 

with order_metrics as (
select
date_trunc('month', order_date)::date as month_start,
order_id,
sum(sales) as order_revenue
from e_commerce_sales
where order_id is not null
and order_date is not null
group by date_trunc('month', order_date)::date, order_id
),
monthly as (
select
month_start,
count(*) as orders,
sum(order_revenue) as revenue,
sum(order_revenue) / nullif(count(*), 0) as aov
from order_metrics
group by month_start
)
select
month_start,
orders,
round(revenue::numeric, 2) as revenue,
round(aov::numeric, 2) as aov,
lag(orders) over (order by month_start) as prior_month_orders,
lag(revenue) over (order by month_start) as prior_month_revenue,
lag(aov) over (order by month_start) as prior_month_aov,
round(100.0 * (orders - lag(orders) over (order by month_start)) / nullif(lag(orders) over (order by month_start), 0), 2) as orders_mom_pct,
round(100.0 * (aov - lag(aov) over (order by month_start)) / nullif(lag(aov) over (order by month_start), 0), 2) as aov_mom_pct
from monthly
order by month_start;


--- Idnetify Product With Declining Sales or Profit

with bounds as (
select max(order_date)::date as max_date
from e_commerce_sales
),
periods as (
select
(date_trunc('year', max_date) - interval '1 year')::date as prior_start,
(max_date - interval '1 year')::date + 1 as prior_end,
date_trunc('year', max_date)::date as current_start,
max_date + 1 as current_end
from bounds
),
product_comparison as (
select
e.product_name,
e.category,
sum(e.sales) filter (where e.order_date >= p.prior_start and e.order_date < p.prior_end) as prior_revenue,
sum(e.profit) filter (where e.order_date >= p.prior_start and e.order_date < p.prior_end) as prior_profit,
sum(e.sales) filter (where e.order_date >= p.current_start and e.order_date < p.current_end) as current_revenue,
sum(e.profit) filter (where e.order_date >= p.current_start and e.order_date < p.current_end) as current_profit
from e_commerce_sales e
cross join periods p
where e.order_date >= p.prior_start
and e.order_date < p.current_end
group by e.product_name, e.category
)
select
product_name,
category,
round(prior_revenue::numeric, 2) as prior_revenue,
round(coalesce(current_revenue, 0)::numeric, 2) as current_revenue,
round(prior_profit::numeric, 2) as prior_profit,
round(coalesce(current_profit, 0)::numeric, 2) as current_profit,
round((coalesce(current_revenue, 0) - prior_revenue)::numeric, 2) as revenue_change,
round((coalesce(current_profit, 0) - prior_profit)::numeric, 2) as profit_change
from product_comparison
where prior_revenue is not null
and coalesce(current_revenue, 0) < prior_revenue
order by revenue_change asc;


/*====================================*/
--- Category Analysis
/*====================================*/

--- Category Analysis

select 
category,
count(distinct order_id) as orders,
sum(sales) as revenue,
round(100.0 * sum(sales)/sum(sum(sales))over (),2)as revenue_share_pct,
sum(profit) as profit,
round(sum(sales) /nullif(count(distinct order_id),0),2) as aov,
round(100.0 * sum(profit) /nullif(sum(sales),0),2) as margin_pct
from e_commerce_sales
group by category
order by revenue desc;


--- Category X Year

select
category,
extract(year from order_date) as year,
count(distinct order_id) as orders,
sum(sales) as revenue,
sum(profit) as profit
from e_commerce_sales
group by 
extract(year from order_date),
category
order by year,revenue desc;



--- Category x Discount Band

select
category,
discount_band,
sum(total_sales) as revenue,
sum(total_profit) as profit,
round(
100.0 * sum(total_profit) /
nullif(sum(total_sales),0),
2
) as margin_pct
from e_commerce_analytics
group by category,discount_band
order by category,discount_band;

--- Compare Category Profit Contribution With Revenue Contribution

with category_metrics as (
select
category,
sum(sales) as revenue,
sum(profit) as profit
from e_commerce_sales
group by category
),
shares as (
select
*,
100.0 * revenue / nullif(sum(revenue) over (), 0) as revenue_share_pct,
100.0 * profit / nullif(sum(profit) over (), 0) as profit_share_pct
from category_metrics
)
select
category,
round(revenue::numeric, 2) as revenue,
round(profit::numeric, 2) as profit,
round(revenue_share_pct::numeric, 2) as revenue_share_pct,
round(profit_share_pct::numeric, 2) as profit_share_pct,
round((profit_share_pct - revenue_share_pct)::numeric, 2) as profit_share_gap_pp,
round(100.0 * profit / nullif(revenue, 0), 2) as margin_pct
from shares
order by profit_share_gap_pp asc;


-- Find Segments Where sales Grow but Profit Does Not

with bounds as (
select max(order_date)::date as max_date
from e_commerce_sales
),
periods as (
select
(date_trunc('year', max_date) - interval '1 year')::date as prior_start,
(max_date - interval '1 year')::date + 1 as prior_end,
date_trunc('year', max_date)::date as current_start,
max_date + 1 as current_end
from bounds
),
category_metrics as (
select
e.category,
sum(e.sales) filter (where e.order_date >= p.prior_start and e.order_date < p.prior_end) as prior_revenue,
sum(e.profit) filter (where e.order_date >= p.prior_start and e.order_date < p.prior_end) as prior_profit,
sum(e.sales) filter (where e.order_date >= p.current_start and e.order_date < p.current_end) as current_revenue,
sum(e.profit) filter (where e.order_date >= p.current_start and e.order_date < p.current_end) as current_profit
from e_commerce_sales e
cross join periods p
where e.order_date >= p.prior_start
and e.order_date < p.current_end
group by e.category
)
select
category,
round(prior_revenue::numeric, 2) as prior_revenue,
round(current_revenue::numeric, 2) as current_revenue,
round(prior_profit::numeric, 2) as prior_profit,
round(current_profit::numeric, 2) as current_profit,
round((current_revenue - prior_revenue)::numeric, 2) as revenue_change,
round((current_profit - prior_profit)::numeric, 2) as profit_change,
round(100.0 * (current_revenue - prior_revenue) / nullif(prior_revenue, 0), 2) as revenue_growth_pct,
round(100.0 * (current_profit - prior_profit) / nullif(abs(prior_profit), 0), 2) as profit_change_pct
from category_metrics
where current_revenue > prior_revenue
and current_profit <= prior_profit
order by revenue_change desc;


--- Category Revenue Decline Analysis

with yearly_category_sales as (
select
category,
extract(year from order_date)::int as sales_year,
sum(sales) as total_revenue,
sum(profit) as total_profit,
sum(quantity) as total_quantity
from e_commerce_sales
group by
category,
extract(year from order_date)::int
),
category_comparison as (
select
category,
sales_year,
total_revenue,
total_profit,
total_quantity,
lag(total_revenue) over (partition by category order by sales_year) as previous_year_revenue,
lag(total_profit) over (partition by category order by sales_year) as previous_year_profit,
lag(total_quantity) over (partition by category order by sales_year) as previous_year_quantity
from yearly_category_sales
)
select
category,
sales_year,
round(total_revenue::numeric, 2) as current_revenue,
round(previous_year_revenue::numeric, 2) as previous_year_revenue,
round((total_revenue - previous_year_revenue)::numeric, 2) as revenue_change,
round(100.0 * (total_revenue - previous_year_revenue) / nullif(previous_year_revenue, 0), 2) as revenue_change_pct,
round((total_profit - previous_year_profit)::numeric, 2) as profit_change,
total_quantity - previous_year_quantity as quantity_change
from category_comparison
where previous_year_revenue is not null
and total_revenue < previous_year_revenue
order by revenue_change asc;

--- Category Sales Volume vs Average Selling Price

with category_metrics as (
select
category,
extract(year from order_date)::int as sales_year,
sum(sales) as total_revenue,
sum(quantity) as total_quantity,
sum(sales) / nullif(sum(quantity), 0) as average_selling_price
from e_commerce_sales
group by
category,
extract(year from order_date)::int
)
select
category,
sales_year,
round(total_revenue::numeric, 2) as total_revenue,
total_quantity,
round(average_selling_price::numeric, 2) as average_selling_price,
round((total_quantity - lag(total_quantity) over (partition by category order by sales_year))::numeric, 2) as quantity_change,
round((average_selling_price - lag(average_selling_price) over (partition by category order by sales_year))::numeric, 2) as average_price_change,
round(100.0 * (total_revenue - lag(total_revenue) over (partition by category order by sales_year)) / nullif(lag(total_revenue) over (partition by category order by sales_year), 0), 2) as revenue_change_pct
from category_metrics
order by category, sales_year;

/*==================================*/
--- SubCategory Analysis
/*==================================*/

--- Subcategory Wise Sales & Profit

select
category,
sub_category,
count(distinct order_id) as total_orders,
sum(quantity) as total_quantity_sold,
round(sum(sales)::numeric, 2) as total_revenue,
round(sum(profit)::numeric, 2) as total_profit,
round(100.0 * sum(profit) / nullif(sum(sales), 0), 2) as profit_margin_pct
from e_commerce_sales
group by category, sub_category
order by total_revenue desc;


--- Subcategory Wise Year-over-Year Performance

with yearly_performance as (
select
category,
sub_category,
extract(year from order_date)::int as sales_year,
sum(sales) as revenue,
sum(profit) as profit
from e_commerce_sales
group by
category,
sub_category,
extract(year from order_date)
),
comparison as (
select
*,
lag(revenue) over (partition by category, sub_category order by sales_year) as previous_year_revenue,
lag(profit) over (partition by category, sub_category order by sales_year) as previous_year_profit
from yearly_performance
)
select
category,
sub_category,
sales_year,
round(revenue::numeric, 2) as current_revenue,
round(previous_year_revenue::numeric, 2) as previous_year_revenue,
round((revenue - previous_year_revenue)::numeric, 2) as revenue_change,
round(profit::numeric, 2) as current_profit,
round(previous_year_profit::numeric, 2) as previous_year_profit,
round((profit - previous_year_profit)::numeric, 2) as profit_change
from comparison
order by category, sub_category, sales_year;



--- Subcategory Revenue Decline Analysis

with yearly_subcategory_sales as (
select
category,
sub_category,
extract(year from order_date)::int as sales_year,
sum(sales) as total_revenue,
sum(profit) as total_profit,
sum(quantity) as total_quantity
from e_commerce_sales
group by
category,
sub_category,
extract(year from order_date)::int
),
subcategory_comparison as (
select
*,
lag(total_revenue) over (partition by category, sub_category order by sales_year) as previous_year_revenue,
lag(total_profit) over (partition by category, sub_category order by sales_year) as previous_year_profit,
lag(total_quantity) over (partition by category, sub_category order by sales_year) as previous_year_quantity
from yearly_subcategory_sales
)
select
category,
sub_category,
sales_year,
round(total_revenue::numeric, 2) as current_revenue,
round(previous_year_revenue::numeric, 2) as previous_year_revenue,
round((total_revenue - previous_year_revenue)::numeric, 2) as revenue_change,
round(100.0 * (total_revenue - previous_year_revenue) / nullif(previous_year_revenue, 0), 2) as revenue_change_pct,
round((total_profit - previous_year_profit)::numeric, 2) as profit_change,
total_quantity - previous_year_quantity as quantity_change
from subcategory_comparison
where previous_year_revenue is not null
and total_revenue < previous_year_revenue
order by revenue_change asc;



--- Subcategory Sales Volume vs Average Selling Price

with yearly_subcategory_sales as (
select
category,
sub_category,
extract(year from order_date)::int as sales_year,
sum(sales) as total_revenue,
sum(profit) as total_profit,
sum(quantity) as total_quantity
from e_commerce_sales
group by
category,
sub_category,
extract(year from order_date)::int
),
subcategory_comparison as (
select
*,
lag(total_revenue) over (partition by category, sub_category order by sales_year) as previous_year_revenue,
lag(total_profit) over (partition by category, sub_category order by sales_year) as previous_year_profit,
lag(total_quantity) over (partition by category, sub_category order by sales_year) as previous_year_quantity
from yearly_subcategory_sales
)
select
category,
sub_category,
sales_year,
round(total_revenue::numeric, 2) as current_revenue,
round(previous_year_revenue::numeric, 2) as previous_year_revenue,
round((total_revenue - previous_year_revenue)::numeric, 2) as revenue_change,
round(100.0 * (total_revenue - previous_year_revenue) / nullif(previous_year_revenue, 0), 2) as revenue_change_pct,
round((total_profit - previous_year_profit)::numeric, 2) as profit_change,
total_quantity - previous_year_quantity as quantity_change
from subcategory_comparison
where previous_year_revenue is not null
and total_revenue < previous_year_revenue
order by revenue_change asc;


--- Lowest Sales Volume Products 

select
category,
sub_category,
product_name,
count(distinct order_id) as total_orders,
sum(quantity) as total_quantity_sold,
round(sum(sales)::numeric, 2) as total_revenue,
round(sum(profit)::numeric, 2) as total_profit
from e_commerce_sales
group by
category,
sub_category,
product_name
order by
total_quantity_sold asc,
total_revenue asc;


--- High Reveneu Low Margin Products

select
category,
sub_category,
product_name,
round(sum(sales)::numeric, 2) as total_revenue,
round(sum(profit)::numeric, 2) as total_profit,
round(
100.0 * sum(profit) / nullif(sum(sales), 0),
2
) as profit_margin_pct,
round(avg(discount)::numeric, 2) as average_discount
from e_commerce_sales
group by
category,
sub_category,
product_name
having sum(sales) > 0
order by
 profit_margin_pct asc,
 total_revenue desc;

/*======================================*/
--- Market Basket Analysis
/*======================================*/

-- section: market basket analysis

with order_products as (
select distinct
order_id,
product_name
from e_commerce_sales
where order_id is not null
and product_name is not null
),
total_orders as (
select count(distinct order_id) as order_count
from order_products
),
product_frequency as (
select
product_name,
count(distinct order_id) as product_orders
from order_products
group by product_name
),
product_pairs as (
select
a.product_name as product_a,
b.product_name as product_b,
count(distinct a.order_id) as pair_orders
from order_products a
join order_products b
on a.order_id = b.order_id
and a.product_name < b.product_name
group by
a.product_name,
b.product_name
)
select
p.product_a,
p.product_b,
p.pair_orders,
fa.product_orders as product_a_orders,
fb.product_orders as product_b_orders,
round(100.0 * p.pair_orders / nullif(t.order_count, 0), 2) as support_pct,
round(100.0 * p.pair_orders / nullif(fa.product_orders, 0), 2) as confidence_a_to_b_pct,
round(p.pair_orders::numeric * t.order_count / nullif(fa.product_orders::numeric * fb.product_orders, 0), 2) as lift
from product_pairs p
join product_frequency fa on p.product_a = fa.product_name
join product_frequency fb on p.product_b = fb.product_name
cross join total_orders t
order by p.pair_orders desc, lift desc;


/*======================================*/
--- Customer Analysis
/*======================================*/


--- Repeat Customers 

select 
customer_name,
sum(sales) as total_revenue,
sum(profit) as total_profit,
sum(quantity) as total_quantity,
count(distinct order_id) as total_orders
from  e_commerce_sales 
group by customer_name
having count(distinct order_id) > 1
order by total_orders desc;


--- Which Customer Become Inactive 

select 
customer_name,
max(order_date) as last_order_date,
sum(sales) as total_revenue,
sum(profit) as total_profit,
count(distinct order_id) as total_orders
from 
e_commerce_sales
group by 
customer_name
having 
max(order_date) < (select max(order_date) from e_commerce_sales) - interval '90 days'
order by   
last_order_date desc;

--- Customer Revenue Concentration (Top 20% Share)

with c as (
select customer_name,sum(sales) as rev
from e_commerce_sales group by customer_name
), r as (
select rev,ntile(5)over(order by rev desc) as grp from c
)
select round(100.0 * sum(rev)filter(where grp = 1) / sum(rev),1) as top_20pct_customer_share
from r;


--- Identify The Largest Profit Contributors

with contributions as (
select
'category' as dimension,
category as segment,
sum(sales) as revenue,
sum(profit) as profit
from e_commerce_sales
group by category
union all
select
'region',
region,
sum(sales),
sum(profit)
from e_commerce_sales
group by region
union all
select
'product',
product_name,
sum(sales),
sum(profit)
from e_commerce_sales
group by product_name
)
select
dimension,
segment,
round(revenue::numeric, 2) as revenue,
round(profit::numeric, 2) as profit,
round(100.0 * profit / nullif(sum(profit) over (partition by dimension), 0), 2) as share_of_dimension_profit_pct,
round(100.0 * profit / nullif(revenue, 0), 2) as margin_pct
from contributions
order by dimension, profit desc;


-- Repeat Purchase Rate by First Purchase Segments

with customer_orders as (
select
customer_name,
order_id,
min(order_date)::date as order_date
from e_commerce_sales
where customer_name is not null
and order_id is not null
and order_date is not null
group by customer_name, order_id
),
ranked_orders as (
select
customer_name,
order_id,
order_date,
row_number() over (partition by customer_name order by order_date, order_id) as order_number
from customer_orders
),
first_orders as (
select
customer_name,
order_id,
order_date
from ranked_orders
where order_number = 1
),
first_order_segments as (
select
f.customer_name,
min(e.category) as first_category,
min(e.region) as first_region
from first_orders f
join e_commerce_sales e on e.customer_name = f.customer_name
and e.order_id = f.order_id
group by f.customer_name
),
customer_order_counts as (
select
customer_name,
count(distinct order_id) as total_orders
from customer_orders
group by customer_name
),
customer_segments as (
select
s.customer_name,
s.first_category,
s.first_region,
c.total_orders
from first_order_segments s
join customer_order_counts c on c.customer_name = s.customer_name
),
segments as (
select
'first purchase category' as segment_type,
first_category as segment,
customer_name,
total_orders
from customer_segments
union all
select
'first purchase region',
first_region,
customer_name,
total_orders
from customer_segments
)
select
segment_type,
segment,
count(*) as customers,
count(*) filter (where total_orders >= 2) as repeat_customers,
round(100.0 * count(*) filter (where total_orders >= 2) / nullif(count(*), 0), 2) as repeat_customer_rate_pct
from segments
where segment is not null
group by segment_type, segment
order by segment_type, repeat_customer_rate_pct desc;

--- Distribution of Time to Second Purchase     

with customer_orders as (
select
customer_name,
order_id,
min(order_date)::date as order_date
from e_commerce_sales
where customer_name is not null
and order_id is not null
and order_date is not null
group by customer_name, order_id
),
ranked_orders as (
select
customer_name,
order_date,
row_number() over (partition by customer_name order by order_date, order_id) as order_number
from customer_orders
),
gaps as (
select
first_order.customer_name,
second_order.order_date - first_order.order_date as days_to_second_order
from ranked_orders first_order
join ranked_orders second_order
on second_order.customer_name = first_order.customer_name
and first_order.order_number = 1
and second_order.order_number = 2
)
select
case
when days_to_second_order <= 30 then '0-30 days'
when days_to_second_order <= 60 then '31-60 days'
when days_to_second_order <= 90 then '61-90 days'
when days_to_second_order <= 180 then '91-180 days'
else '181+ days'
end as second_purchase_window,
count(*) as customers,
round(100.0 * count(*) / sum(count(*)) over (), 2) as share_of_repeat_customers_pct,
round(avg(days_to_second_order)::numeric, 1) as average_days_in_window
from gaps
group by 1
order by
case
when min(days_to_second_order) <= 30 then 1
when min(days_to_second_order) <= 60 then 2
when min(days_to_second_order) <= 90 then 3
when min(days_to_second_order) <= 180 then 4
else 5
end;


--- Customer Cohort Retention by Month

with first_purchase as (
select
customer_name,
min(date_trunc('month', order_date)) as cohort_month
from e_commerce_sales
where customer_name is not null
and order_date is not null
group by customer_name
),
customer_activity as (
select distinct
s.customer_name,
f.cohort_month,
date_trunc('month', s.order_date) as activity_month
from e_commerce_sales s
join first_purchase f on s.customer_name = f.customer_name
where s.order_date is not null
),
cohort_data as (
select
cohort_month,
(extract(year from age(activity_month, cohort_month)) * 12 + extract(month from age(activity_month, cohort_month)))::int as month_number,
count(distinct customer_name) as active_customers
from customer_activity
group by cohort_month, activity_month
),
cohort_size as (
select
cohort_month,
count(distinct customer_name) as total_customers
from first_purchase
group by cohort_month
)
select
to_char(c.cohort_month, 'yyyy-mm') as cohort_month,
c.month_number,
s.total_customers,
c.active_customers,
round(100.0 * c.active_customers / nullif(s.total_customers, 0), 2) as retention_pct
from cohort_data c
join cohort_size s on c.cohort_month = s.cohort_month
order by c.cohort_month, c.month_number;


/*======================================*/
--- Customer Segmentation
/*======================================*/

--- RFM Customer Segmentation

with customer_metrics AS (
select
customer_name,
max(order_date)::date AS last_order_date,
count(distinct order_id) AS frequency,
sum(sales) AS monetary,
sum(profit) AS total_profit, -- Added profit tracking
(
select max(order_date)::date
from e_commerce_sales
) - max(order_date)::date AS recency_days
from e_commerce_sales
where customer_name is not null
and order_date is not null
group by  customer_name
),
rfm_scores AS (
select
*,
6 - ntile(5) OVER (order by recency_days asc) as r_score,
ntile(5) over (order by  frequency asc) as f_score,
ntile(5) OVER (order by monetary asc) as m_score
from customer_metrics
),
customer_segments AS (
select
*,
case
when r_score >= 4 and m_score >= 4 and frequency >= 2  
then 'high-value loyal customers'
when m_score >= 4 and frequency = 1
then 'high-value one-time customers'
when r_score >= 4 and f_score >= 3
then 'recent active customers'
when r_score <= 2
then 'at-risk customers'
else 'regular customers'
end as as customer_segment
from rfm_scores
)
select
customer_segment,
count(customer_name) AS total_customers,
round(count(customer_name) * 100.0 / sum(count(customer_name)) over (), 2) as customer_share_pct,
round(sum(monetary)::numeric, 2) AS total_revenue,
round(sum(monetary)::numeric * 100.0 / sum(sum(monetary)::numeric) over (), 2) as revenue_share_pct,
round(sum(total_profit)::numeric, 2) AS total_profit,
round(sum(total_profit)::numeric * 100.0 / sum(sum(total_profit)::numeric) over (), 2) as profit_share_pct,
round(avg(monetary)::numeric, 2) AS avg_customer_value
from customer_segments
group by  customer_segment
order by total_profit desc;

/*======================================*/
--- Discount Analysis 
/*======================================*/


--- Discount band Performance by Year

select
order_year,
discount_band,
sum(total_sales) as revenue,
sum(total_profit) as profit,
round(
100.0 * sum(total_profit) /
nullif(sum(total_sales),0),
2
) as margin_pct
from e_commerce_analytics
group by order_year,discount_band
order by order_year,discount_band;

--- Measure Discount Efficiency

with discount_metrics as (
select
discount,
sum(sales) as revenue,
sum(profit) as profit,
sum(quantity * unit_price * discount / 100.0) as estimated_discount_cost,
count(distinct order_id) as orders,
count(*) as sales_lines
from e_commerce_sales
where discount is not null
and sales is not null
and profit is not null
and quantity is not null
and unit_price is not null
group by discount
)
select
discount,
sales_lines,
orders,
round(revenue::numeric, 2) as revenue,
round(profit::numeric, 2) as profit,
round(estimated_discount_cost::numeric, 2) as estimated_discount_cost,
round(revenue::numeric / nullif(estimated_discount_cost, 0), 2) as revenue_per_discount_rupee,
round(profit::numeric / nullif(estimated_discount_cost, 0), 2) as profit_per_discount_rupee,
round(100.0 * profit / nullif(revenue, 0), 2) as margin_pct
from discount_metrics
order by discount;


--- Find High Discount Low Margin Products

with product_metrics as (
select
product_name,
category,
sub_category,
sum(sales) as revenue,
sum(profit) as profit,
sum(quantity) as quantity_sold,
avg(discount) as avg_discount_pct,
sum(quantity * unit_price * discount / 100.0) as estimated_discount_cost
from e_commerce_sales
group by product_name, category, sub_category
),
benchmarks as (
select
percentile_cont(0.75) within group (order by avg_discount_pct) as high_discount_threshold,
percentile_cont(0.25) within group (order by 100.0 * profit / nullif(revenue, 0)) as low_margin_threshold
from product_metrics
where revenue <> 0
)
select
p.product_name,
p.category,
p.sub_category,
round(p.revenue::numeric, 2) as revenue,
round(p.profit::numeric, 2) as profit,
round(p.avg_discount_pct::numeric, 2) as avg_discount_pct,
round((100.0 * p.profit / nullif(p.revenue, 0))::numeric, 2) as margin_pct,
round(p.estimated_discount_cost::numeric, 2) as estimated_discount_cost
from product_metrics p
cross join benchmarks b
where p.avg_discount_pct >= b.high_discount_threshold
and 100.0 * p.profit / nullif(p.revenue, 0) <= b.low_margin_threshold
order by p.profit asc;


--- Measure product dependence on discounted sales

with product_discount_mix as (
select
product_name,
category,
sum(sales) as total_revenue,
sum(sales) filter (where discount > 0) as discounted_revenue,
sum(sales) filter (where discount = 0) as full_price_revenue,
sum(profit) filter (where discount > 0) as discounted_profit,
sum(profit) filter (where discount = 0) as full_price_profit
from e_commerce_sales
group by product_name, category
)
select
product_name,
category,
round(total_revenue::numeric, 2) as total_revenue,
round(coalesce(discounted_revenue, 0)::numeric, 2) as discounted_revenue,
round(coalesce(full_price_revenue, 0)::numeric, 2) as full_price_revenue,
round(100.0 * coalesce(discounted_revenue, 0) / nullif(total_revenue, 0), 2) as discounted_revenue_share_pct,
round(coalesce(discounted_profit, 0)::numeric, 2) as discounted_profit,
round(coalesce(full_price_profit, 0)::numeric, 2) as full_price_profit
from product_discount_mix
where total_revenue > 0
order by discounted_revenue_share_pct desc nulls last;


--- Quantify Loss Making Sales by Discount band

with classified as (
select
case
when discount is null then 'missing discount'
when discount < 0 or discount > 100 then 'invalid discount'
when discount = 0 then '0%'
when discount <= 5 then '1-5%'
when discount <= 10 then '6-10%'
when discount <= 15 then '11-15%'
when discount <= 20 then '16-20%'
else '>20%'
end as discount_band,
sales,
profit,
order_id
from e_commerce_sales
where discount is not null
),
band_metrics as (
select
discount_band,
count(*) as sales_lines,
count(distinct order_id) as orders,
count(*) filter (where profit < 0) as loss_lines,
sum(sales) as revenue,
sum(profit) as total_profit,
sum(profit) filter (where profit < 0) as negative_profit
from classified
group by discount_band
)
select
discount_band,
sales_lines,
orders,
loss_lines,
round(100.0 * loss_lines / nullif(sales_lines, 0), 2) as loss_line_rate_pct,
round(revenue::numeric, 2) as revenue,
round(total_profit::numeric, 2) as total_profit,
round(negative_profit::numeric, 2) as negative_profit,
round(100.0 * abs(coalesce(negative_profit, 0)) / nullif(sum(abs(coalesce(negative_profit, 0))) over (), 0), 2) as share_of_negative_profit_pct
from band_metrics
order by
case discount_band
when '0%' then 1
when '1-5%' then 2
when '6-10%' then 3
when '11-15%' then 4
when '16-20%' then 5
else 6
end;

/*=======================================*/
--- Geography Analysis
/*=======================================*/


--- Revenue by City (Top 20)

select
city,
sum(sales) as revenue,
sum(profit) as profit,
round(100.0 * sum(profit) / nullif(sum(sales),0),2) as margin_pct,
count(distinct order_id) as orders
from e_commerce_sales
group by city
order by revenue desc
limit 20;


--- Region X Category 

select
region,
category,
count(distinct order_id) as orders,
sum(sales) as revenue,
sum(profit) as profit,
round(
100.0 * sum(profit)/
nullif(sum(sales),0),2
) as margin_pct
from e_commerce_sales
group by region,category
order by revenue desc;


--- Region x Discount Band

select
region,
discount_band,
sum(total_sales) as revenue,
sum(total_profit) as profit,
round(
100.0 * sum(total_profit) /
nullif(sum(total_sales),0),
2
) as margin_pct
from e_commerce_analytics
group by region,discount_band
order by region,discount_band;


--- Loss-Making Region and Cities

select region, city, sum(sales) as revenue, sum(profit) as profit,
       round(100.0 * sum(profit) / nullif(sum(sales),0), 2) as margin_pct
from e_commerce_sales
group by region, city
having sum(profit) < 0
order by profit;


-- Find High Revenue, Low Margin Regions

with regional as (
select
region,
sum(sales) as revenue,
sum(profit) as profit,
count(distinct order_id) as orders
from e_commerce_sales
group by region
),
overall as (
select
sum(sales) as total_revenue,
sum(profit) as total_profit
from e_commerce_sales
)
select
r.region,
r.orders,
round(r.revenue::numeric, 2) as revenue,
round(r.profit::numeric, 2) as profit,
round(100.0 * r.profit / nullif(r.revenue, 0), 2) as margin_pct,
round(100.0 * o.total_profit / nullif(o.total_revenue, 0), 2) as overall_margin_pct,
round((100.0 * r.profit / nullif(r.revenue, 0) - 100.0 * o.total_profit / nullif(o.total_revenue, 0))::numeric, 2) as margin_gap_pp,
case
when r.revenue >= o.total_revenue * 0.10 and r.profit / nullif(r.revenue, 0) < o.total_profit / nullif(o.total_revenue, 0) then 'high revenue, below-average margin'
when r.profit / nullif(r.revenue, 0) < o.total_profit / nullif(o.total_revenue, 0) then 'below-average margin'
else 'at or above overall margin'
end as suggested_action
from regional r
cross join overall o
order by margin_gap_pp asc nulls last;

-- Rank The Five Largest Profit Leakage Sources

with loss_sources as (
select
'category' as source_type,
category as source_name,
sum(profit) as net_profit,
sum(profit) filter (where profit < 0) as negative_profit,
sum(sales) filter (where profit < 0) as revenue_on_loss_lines,
count(*) filter (where profit < 0) as loss_lines
from e_commerce_sales
group by category
union all
select
'subcategory',
sub_category,
sum(profit),
sum(profit) filter (where profit < 0),
sum(sales) filter (where profit < 0),
count(*) filter (where profit < 0)
from e_commerce_sales
group by sub_category
union all
select
'region',
region,
sum(profit),
sum(profit) filter (where profit < 0),
sum(sales) filter (where profit < 0),
count(*) filter (where profit < 0)
from e_commerce_sales
group by region
union all
select
'product',
product_name,
sum(profit),
sum(profit) filter (where profit < 0),
sum(sales) filter (where profit < 0),
count(*) filter (where profit < 0)
from e_commerce_sales
group by product_name
),
ranked as (
select
*,
row_number() over (order by negative_profit asc) as loss_rank
from loss_sources
where negative_profit < 0
)
select
loss_rank,
source_type,
source_name,
round(net_profit::numeric, 2) as net_profit,
round(negative_profit::numeric, 2) as negative_profit_on_loss_lines,
round(revenue_on_loss_lines::numeric, 2) as revenue_on_loss_lines,
loss_lines
from ranked
where loss_rank <= 5
order by loss_rank;


/*=========================================*/
--- Payment Method Analysis
/*=========================================*/


select
payment_mode,
count(distinct order_id) as total_orders,
sum(quantity) as total_quantity,
round(sum(sales)::numeric, 2) as total_revenue,
round(sum(profit)::numeric, 2) as total_profit,
round(
100.0 * sum(profit) / nullif(sum(sales), 0),
2
) as profit_margin_pct,
round(avg(discount)::numeric, 2) as average_discount
from e_commerce_sales
group by payment_mode
order by total_profit desc;


/*=====================================*/
--- Root Cause Analysis
/*=====================================*/

--- Check Discount Impact & Sub-Category Breakdown

select 
sub_category,
count(distinct order_id) AS total_orders,
sum(quantity) AS total_units,
round(avg(discount)::numeric, 2) AS avg_discount_pct,
round(sum(sales)::numeric, 2) AS total_sales,
round(sum(profit)::numeric, 2) AS total_profit,
round((sum(profit) / nullif(sum(sales), 0))::numeric * 100, 2) AS profit_margin_pct
FROM 
e_commerce_sales
where region = 'East' 
and category = 'Home Decor'
group by 
sub_category
order by  
total_profit asc;


--- Check Profit Margin by Discount Tier 

select 
case 
when discount = 0 then '0% (No Discount)'
when discount <= 5 then '5%'
when discount <= 10 then '10%'
when discount <= 15 then '15%'
when discount <= 20 then '20%'
else '20%'
end as  discount_tier,
count(*) as line_items,

round(sum(sales)::numeric, 2) as total_sales,
round(sum(profit)::numeric, 2) as total_profit,
round((sum(profit) / nullif(sum(sales), 0))::numeric * 100, 2) AS margin_pct
from 
e_commerce_sales
where 
region = 'East' 
AND category = 'Home Decor'
group by
discount_tier
order by  margin_pct asc;


--- Find Top Loss Making Orders/Products

select
order_id,
order_date,
customer_name,
product_name,
quantity,
discount,
sales,
profit
from e_commerce_sales
where region = 'East'
and category = 'Home Decor'
and profit < 0
order by profit asc
limit 10;


--- Loss Contribution by Subcategory

select
sub_category,
count(distinct order_id) as loss_orders,
sum(quantity) as units_sold_at_loss,
round(avg(discount)::numeric * 100, 2) as avg_discount_pct,
round(sum(sales)::numeric, 2) as total_sales,
round(sum(profit)::numeric, 2) as total_loss,
round(sum(profit)::numeric * 100.0 / sum(sum(profit)::numeric) over (), 2) as pct_of_total_loss
from e_commerce_sales
where region = 'East'
and category = 'Home Decor'
and profit < 0
group by sub_category
order by total_loss asc;


--- Lowest Performing Subcategories & Products 

select
sub_category,
product_name,
count(distinct order_id) as total_orders,
sum(quantity) as total_units,
round(sum(sales)::numeric, 2) as total_sales,
round(sum(profit)::numeric, 2) as total_profit,
round((sum(profit) / nullif(sum(sales), 0))::numeric * 100, 2) as profit_margin_pct
from e_commerce_sales
where region = 'East'
and category = 'Home Decor'
group by
sub_category,
product_name
order by total_profit asc
limit 15;


--- Subcategory Drop Breakdown (Period 1 vs Period 2)

with period_perf as (
select
sub_category,
case
when order_date::date between '2023-10-04' and '2024-10-03' then 'period_1'
when order_date::date between '2024-10-04' and '2025-10-03' then 'period_2'
end as period,
count(distinct order_id) as total_orders,
sum(sales) as total_sales,
sum(profit) as total_profit
from e_commerce_sales
where region = 'East'
and category = 'Home Decor'
group by
sub_category,
period
)
select
sub_category,
coalesce(max(case when period = 'period_1' then total_profit end), 0) as p1_profit,
coalesce(max(case when period = 'period_2' then total_profit end), 0) as p2_profit,
round((
coalesce(max(case when period = 'period_2' then total_profit end), 0) -
coalesce(max(case when period = 'period_1' then total_profit end), 0)
)::numeric, 2) as profit_diff,
round((
(coalesce(max(case when period = 'period_2' then total_profit end), 0) -
coalesce(max(case when period = 'period_1' then total_profit end), 0)) * 100.0 /
nullif(max(case when period = 'period_1' then total_profit end), 0)
)::numeric, 2) as yoy_profit_change_pct
from period_perf
group by sub_category
order by profit_diff asc; -- biggest rupee/dollar drop at the top


--- Top 10 Products Driving the Decline 

with product_perf as (
select
sub_category,
product_name,
case
when order_date::date between '2023-10-04' and '2024-10-03' then 'period_1'
when order_date::date between '2024-10-04' and '2025-10-03' then 'period_2'
end as period,
sum(quantity) as units_sold,
sum(sales) as total_sales,
sum(profit) as total_profit
from e_commerce_sales
where region = 'East'
and category = 'Home Decor'
group by
sub_category,
product_name,
period
)
select
sub_category,
product_name,
coalesce(max(case when period = 'period_1' then units_sold end), 0) as p1_units,
coalesce(max(case when period = 'period_2' then units_sold end), 0) as p2_units,
round(coalesce(max(case when period = 'period_1' then total_profit end), 0)::numeric, 2) as p1_profit,
round(coalesce(max(case when period = 'period_2' then total_profit end), 0)::numeric, 2) as p2_profit,
round((
coalesce(max(case when period = 'period_2' then total_profit end), 0) -
coalesce(max(case when period = 'period_1' then total_profit end), 0)
)::numeric, 2) as profit_diff
from product_perf
group by
sub_category,
product_name
order by profit_diff asc
limit 10;


--- Driver Diagnostic Query (Discount vs Costs vs Mix)

with period_data as (
select
sub_category,
case
when order_date::date between '2023-10-04' and '2024-10-03' then 'p1'
when order_date::date between '2024-10-04' and '2025-10-03' then 'p2'
end as period,
sum(quantity) as units,
sum(sales) as sales,
sum(profit) as profit,
avg(discount) as avg_discount -- remove this line if your table has no discount column
from e_commerce_sales
where region = 'East'
and category = 'Home Decor'
group by
sub_category,
period
),
period_totals as (
select
*,
sum(sales) over (partition by period) as total_period_sales
from period_data
)
select
sub_category,
-- 1. product mix (share of total east home decor sales)
round(coalesce(max(case when period = 'p1' then sales * 100.0 / total_period_sales end), 0)::numeric, 2) as p1_sales_mix_pct,
round(coalesce(max(case when period = 'p2' then sales * 100.0 / total_period_sales end), 0)::numeric, 2) as p2_sales_mix_pct,
-- 2. discount driver
round(coalesce(max(case when period = 'p1' then avg_discount * 100 end), 0)::numeric, 2) as p1_avg_disc_pct,
round(coalesce(max(case when period = 'p2' then avg_discount * 100 end), 0)::numeric, 2) as p2_avg_disc_pct,
-- 3. cost / margin driver (profit margin %)
round(coalesce(max(case when period = 'p1' then profit * 100.0 / nullif(sales, 0) end), 0)::numeric, 2) as p1_margin_pct,
round(coalesce(max(case when period = 'p2' then profit * 100.0 / nullif(sales, 0) end), 0)::numeric, 2) as p2_margin_pct
from period_totals
group by sub_category
order by p1_sales_mix_pct desc;


--- Order Volume vs Average Order Values (AOV) Decomposition

with period_summary as (
select
case
when order_date::date between '2023-10-04' and '2024-10-03' then 'period_1'
when order_date::date between '2024-10-04' and '2025-10-03' then 'period_2'
end as period,
count(distinct order_id) as total_orders,
sum(quantity) as total_units,
sum(sales) as total_revenue,
sum(sales) / nullif(count(distinct order_id), 0) as aov
from e_commerce_sales
where category = 'Home Decor'
-- and region = 'East' -- uncomment if checking east region only
group by period
)
select
max(case when period = 'period_1' then total_orders end) as p1_orders,
max(case when period = 'period_2' then total_orders end) as p2_orders,
round((
(max(case when period = 'period_2' then total_orders end) -
max(case when period = 'period_1' then total_orders end)) * 100.0 /
nullif(max(case when period = 'period_1' then total_orders end), 0)
)::numeric, 2) as order_volume_change_pct,
round(max(case when period = 'period_1' then aov end)::numeric, 2) as p1_aov,
round(max(case when period = 'period_2' then aov end)::numeric, 2) as p2_aov,
round((
(max(case when period = 'period_2' then aov end) -
max(case when period = 'period_1' then aov end)) * 100.0 /
nullif(max(case when period = 'period_1' then aov end), 0)
)::numeric, 2) as aov_change_pct,
round((
max(case when period = 'period_2' then total_revenue end) -
max(case when period = 'period_1' then total_revenue end)
)::numeric, 2) as total_revenue_diff
from period_summary;



--- Which Sub Category Contribute the Most to Drop Sells

with subcat_rev as (
select
sub_category,
sum(case when order_date::date between '2023-10-04' and '2024-10-03' then sales else 0 end) as p1_revenue,
sum(case when order_date::date between '2024-10-04' and '2025-10-03' then sales else 0 end) as p2_revenue
from e_commerce_sales
where category = 'Home Decor'
-- and region = 'East'
group by sub_category
)
select
sub_category,
round(p1_revenue::numeric, 2) as p1_revenue,
round(p2_revenue::numeric, 2) as p2_revenue,
round((p2_revenue - p1_revenue)::numeric, 2) as revenue_diff,
round(((p2_revenue - p1_revenue) * 100.0 / nullif(p1_revenue, 0))::numeric, 2) as yoy_change_pct,
round(((p2_revenue - p1_revenue) * 100.0 / nullif(sum(p2_revenue - p1_revenue) over (), 0))::numeric, 2) as share_of_total_decline_pct
from subcat_rev
order by revenue_diff asc;


--- Which Months Contributed Most (Seasonality & Dip Detection)

with monthly_rev as (
select
extract(month from order_date::date) as month_num,
to_char(order_date::date, 'mon') as month_name,
sum(case when order_date::date between '2023-10-04' and '2024-10-03' then sales else 0 end) as p1_revenue,
sum(case when order_date::date between '2024-10-04' and '2025-10-03' then sales else 0 end) as p2_revenue
from e_commerce_sales
where category = 'Home Decor'
-- and region = 'East'
group by
extract(month from order_date::date),
to_char(order_date::date, 'mon')
)
select
month_num,
month_name,
round(p1_revenue::numeric, 2) as p1_revenue,
round(p2_revenue::numeric, 2) as p2_revenue,
round((p2_revenue - p1_revenue)::numeric, 2) as monthly_diff,
round(((p2_revenue - p1_revenue) * 100.0 / nullif(p1_revenue, 0))::numeric, 2) as yoy_change_pct
from monthly_rev
order by monthly_diff asc; -- worst-performing months first (change to month_num for chronological)


--- Profit Margin & Volume Comparision Across Discount Tiers

select
round(discount::numeric, 0) as discount_pct,
count(distinct order_id) as total_orders,
count(*) as line_items,
sum(quantity) as total_units,
round(avg(quantity)::numeric, 2) as avg_units_per_item,
round(sum(sales)::numeric, 2) as total_revenue,
round(avg(sales)::numeric, 2) as avg_revenue_per_item,
round(sum(profit)::numeric, 2) as total_profit,
round(avg(profit)::numeric, 2) as avg_profit_per_item,
round((sum(profit) * 100.0 / nullif(sum(sales), 0))::numeric, 2) as profit_margin_pct
from e_commerce_sales
group by round(discount::numeric, 0)
order by discount_pct asc;


--- Products With Less Profit at High Discount 

with product_disc_perf as (
select
category,
sub_category,
product_name,
sum(case when round(discount::numeric, 0) in (0, 5) then sales else 0 end) as low_disc_sales,
sum(case when round(discount::numeric, 0) in (0, 5) then profit else 0 end) as low_disc_profit,
sum(case when round(discount::numeric, 0) >= 15 then sales else 0 end) as high_disc_sales,
sum(case when round(discount::numeric, 0) >= 15 then profit else 0 end) as high_disc_profit,
sum(case when round(discount::numeric, 0) >= 15 then quantity else 0 end) as high_disc_units
from e_commerce_sales
group by
category,
sub_category,
product_name
)
select
category,
sub_category,
product_name,
high_disc_units,
round((low_disc_profit * 100.0 / low_disc_sales)::numeric, 2) as margin_at_0_5_pct,
round((high_disc_profit * 100.0 / high_disc_sales)::numeric, 2) as margin_at_high_disc_pct,
round((
(high_disc_profit * 100.0 / high_disc_sales) -
(low_disc_profit * 100.0 / low_disc_sales)
)::numeric, 2) as margin_erosion_pct,
round(high_disc_profit::numeric, 2) as net_profit_at_high_disc
from product_disc_perf
where high_disc_sales > 0
and low_disc_sales > 0 -- removes rows with null margins
order by
margin_erosion_pct asc, -- biggest margin drop first
net_profit_at_high_disc asc
limit 15;


--- Products That Become Loss Making at Higher Discount

with product_disc_perf as (
select
category,
sub_category,
product_name,
sum(case when round(discount::numeric * 100, 0) in (0, 5) then sales else 0 end) as low_disc_sales,
sum(case when round(discount::numeric * 100, 0) in (0, 5) then profit else 0 end) as low_disc_profit,
sum(case when round(discount::numeric * 100, 0) in (15, 20) then sales else 0 end) as high_disc_sales,
sum(case when round(discount::numeric * 100, 0) in (15, 20) then profit else 0 end) as high_disc_profit,
sum(case when round(discount::numeric * 100, 0) in (15, 20) then quantity else 0 end) as high_disc_units
from e_commerce_sales
group by
category,
sub_category,
product_name
)
select
category,
sub_category,
product_name,
high_disc_units,
round((low_disc_profit * 100.0 / nullif(low_disc_sales, 0))::numeric, 2) as margin_at_0_5_pct,
round((high_disc_profit * 100.0 / nullif(high_disc_sales, 0))::numeric, 2) as margin_at_15_20_pct,
round((
(high_disc_profit * 100.0 / nullif(high_disc_sales, 0)) -
(low_disc_profit * 100.0 / nullif(low_disc_sales, 0))
)::numeric, 2) as margin_erosion_pct,
round(high_disc_profit::numeric, 2) as net_profit_at_high_disc
from product_disc_perf
where high_disc_sales > 0
order by
net_profit_at_high_disc asc, -- loss-making (if any) or lowest-profit products first
margin_at_15_20_pct asc
limit 15;


--- Do Higher Discount Generate Enough Extra Quantity/Revenue to Justify their Cost

with tier_stats as (
select
round(discount::numeric, 0) as discount_pct,
count(*) as line_items,
round(avg(quantity)::numeric, 2) as avg_qty_per_item,
round(avg(sales)::numeric, 2) as avg_rev_per_item,
round(avg(profit)::numeric, 2) as avg_profit_per_item,
round((sum(profit) * 100.0 / nullif(sum(sales), 0))::numeric, 2) as margin_pct
from e_commerce_sales
group by round(discount::numeric, 0)
)
select
discount_pct,
line_items,
avg_qty_per_item,
avg_rev_per_item,
avg_profit_per_item,
margin_pct,
round((avg_profit_per_item - first_value(avg_profit_per_item) over (order by discount_pct asc))::numeric, 2) as profit_diff_vs_0_pct
from tier_stats
order by discount_pct asc;

--- Low Margin Products 

with category_benchmarks as (
select
category,
round((sum(profit) * 100.0 / nullif(sum(sales), 0))::numeric, 2) as category_avg_margin_pct,
round(avg(discount)::numeric, 2) as category_avg_disc_pct
from e_commerce_sales
group by category
),
total_company as (
select sum(profit) as grand_total_profit from e_commerce_sales
)
select
s.product_name,
s.category,
s.sub_category,
count(distinct s.order_id) as total_orders,
sum(s.quantity) as total_units,
round(sum(s.sales)::numeric, 2) as total_sales,
round(sum(s.sales - s.profit)::numeric, 2) as implied_total_cost,
round(sum(s.profit)::numeric, 2) as total_profit,
round((sum(s.profit) * 100.0 / nullif(sum(s.sales), 0))::numeric, 2) as product_margin_pct,
cb.category_avg_margin_pct,
round(((sum(s.profit) * 100.0 / nullif(sum(s.sales), 0)) - cb.category_avg_margin_pct)::numeric, 2) as margin_vs_category_diff,
round(avg(s.discount)::numeric, 2) as product_avg_disc_pct,
cb.category_avg_disc_pct,
round((sum(s.profit) * 100.0 / tc.grand_total_profit)::numeric, 4) as pct_of_total_company_profit
from e_commerce_sales s
join category_benchmarks cb on s.category = cb.category
cross join total_company tc
where s.product_name in ('Camera Dolore', 'Board Game Similique')
group by
s.product_name,
s.category,
s.sub_category,
cb.category_avg_margin_pct,
cb.category_avg_disc_pct,
tc.grand_total_profit;



--- Customer Concerntration & Revenue at Risk 

with cust_orders as (
select
customer_name,
count(distinct order_id) as order_count,
sum(sales) as total_sales,
sum(profit) as total_profit
from e_commerce_sales
where customer_name is not null
group by customer_name
)
select
case when order_count = 1 then 'one-time customers (1 order)' else 'repeat customers (2+ orders)' end as buyer_type,
count(customer_name) as customer_count,
round(count(customer_name) * 100.0 / sum(count(customer_name)) over (), 2) as pct_of_customers,
sum(order_count) as total_orders,
round(sum(order_count) * 100.0 / sum(sum(order_count)) over (), 2) as pct_of_orders,
round(sum(total_sales)::numeric, 2) as total_revenue,
round(sum(total_sales) * 100.0 / sum(sum(total_sales)) over (), 2) as pct_of_revenue,
round((sum(total_sales) / sum(order_count))::numeric, 2) as avg_order_value
from cust_orders
group by buyer_type;


--- Which High Value Customers Have Not Returned & Total Revenue at Risk 

with customer_rfm as (
select
customer_name,
max(order_date)::date as last_order_date,
(select max(order_date)::date from e_commerce_sales) - max(order_date)::date as days_inactive,
count(distinct order_id) as total_orders,
sum(sales) as lifetime_revenue,
sum(profit) as lifetime_profit,
ntile(5) over (order by sum(sales) asc) as monetary_quintile
from e_commerce_sales
where customer_name is not null
group by customer_name
)
-- part a: top 15 high-value churned customers to target first
select
customer_name,
last_order_date,
days_inactive,
total_orders,
round(lifetime_revenue::numeric, 2) as lifetime_revenue,
round(lifetime_profit::numeric, 2) as lifetime_profit
from customer_rfm
where monetary_quintile >= 4 -- top 40% highest spenders (change to = 5 for top 20%)
and days_inactive > 180 -- haven't returned in 6+ months
order by lifetime_revenue desc
limit 15;


--- Inactive Customer Prioritization query 


with customer_metrics as (
select
customer_name,
count(distinct order_id) as total_orders,
sum(sales) as lifetime_revenue,
sum(profit) as lifetime_profit,
max(order_date)::date as last_order_date
from e_commerce_sales
group by customer_name
),
dataset_date as (
select max(order_date)::date as latest_date
from e_commerce_sales
),
inactive_customers as (
select
c.*,
d.latest_date,
d.latest_date - c.last_order_date as inactive_days
from customer_metrics c
cross join dataset_date d
where d.latest_date - c.last_order_date >= 180
)
select
customer_name,
total_orders,
round(lifetime_revenue::numeric, 2) as lifetime_revenue,
round(lifetime_profit::numeric, 2) as lifetime_profit,
last_order_date,
inactive_days,
case
when inactive_days >= 365 then 'high inactivity'
when inactive_days >= 180 then 'medium inactivity'
end as inactivity_segment,
case
when lifetime_profit > 0 and lifetime_revenue >= 200000 then 'high priority'
when lifetime_profit > 0 then 'medium priority'
else 'review profitability'
end as reactivation_priority
from inactive_customers
order by lifetime_profit desc, lifetime_revenue desc;


--- Time To Second Order 

with ranked_orders as (
select 
customer_name,
order_id,
min(order_date)::date as order_date,
row_number() over (
partition by customer_name 
order by min(order_date)::date asc, order_id asc
) as order_num
from 
e_commerce_sales
where 
customer_name is not null
and order_date is not null
group by 
customer_name,
order_id
),
second_order_gaps as (
select 
customer_name,
order_date as second_order_date,
lag(order_date) over (
partition by customer_name 
order by order_num asc
) as first_order_date,
order_date - lag(order_date) over (
partition by customer_name 
order by order_num asc
) as days_to_second_order
		
from 
ranked_orders
where 
order_num in (1, 2)
)
select 
count(customer_name) as repeat_customers_analyzed,
min(days_to_second_order) as fastest_repeat_days,
round(avg(days_to_second_order)::numeric, 1) as avg_days_to_second_order,
percentile_cont(0.5) within group (order by days_to_second_order) as median_days_to_second_order,  
max(days_to_second_order) as slowest_repeat_days
from 
second_order_gaps
where 
days_to_second_order is not null;


--- Total Revenue at Risk Summary 

with customer_rfm as (
select 
customer_name,
(select max(order_date)::date from e_commerce_sales) - max(order_date)::date as days_inactive,
count(distinct order_id) as total_orders,
sum(sales) as lifetime_revenue,
sum(profit) as lifetime_profit,
ntile(5) over (order by sum(sales) asc) as monetary_quintile
from 
e_commerce_sales
where 
customer_name is not null
group by 
customer_name
)
select 
count(customer_name) as high_value_inactive_customers,
round(sum(lifetime_revenue)::numeric, 2) as total_revenue_at_risk,
round(sum(lifetime_profit)::numeric, 2) as total_profit_at_risk,
round(avg(lifetime_revenue)::numeric, 2) as avg_revenue_per_at_risk_customer
from 
customer_rfm
where 
monetary_quintile >= 4
and days_inactive > 180;

/*
FINAL BUSINESS CONCLUSION:

The analysis identified five major business opportunities:

1. REVENUE RECOVERY:
   Revenue declined by ₹5.58M, with order volume
   decreasing by 12.04% and AOV decreasing by 6.50%.

2. CATEGORY PERFORMANCE:
   Home Decor revenue declined by ₹11.13M (-35.63%).
   Lamp accounted for 46.95% of the identified
   overall revenue decline.

3. PROFITABILITY:
   Vase recorded a profit decline of ₹192,494.73.
   Several products operated at approximately
   5% profit margins.

4. DISCOUNT OPTIMIZATION:
   The 20% discount tier showed a 14.74% margin
   compared with 15.22% at the 5% tier.

5. CUSTOMER RETENTION:
   4,690 customers made only one purchase, while
   1,444 high-value customers were classified as
   inactive under the 180-day definition.

OVERALL RECOMMENDATION:

The business should focus on profitable growth rather
than revenue expansion alone.

Priority actions:
- Recover declining sales in Home Decor and Lamp.
- Investigate product-level profitability.
- Optimize discounts using incremental profit.
- Improve customer repeat-purchase rates.
- Reactivate valuable inactive customers.

The objective is to increase revenue while protecting
profit margins and strengthening customer retention.
*/