-- ============================
-- E-COMMERCE SALES ANALYSIS
-- ============================


-- ===============================
-- DATA CLEANING
-- ===============================

-- Preview Data 

select * from e_commerce_sales
limit 100;

-- Total Rows

select count(*) from e_commerce_sales;

-- Check Duplicates

select order_ID,count(*)
from e_commerce_sales
group by order_ID
having count(*) >1;

-- Check Null Values

select *
from e_commerce_sales
where customer_name is null
or sales is null
or profit is null
or discount is null
or order_date is null;

-- Check Blank Values

select *
from e_commerce_sales
where trim(customer_name) = '';

-- Remove Extra Space

update e_commerce_sales
set customer_name = trim(customer_name);

-- Check Unique Values

select distinct category
from e_commerce_sales;

-- Check Outliers

select *
from e_commerce_sales
order by sales desc;

-- Final Validation

select count(*) from e_commerce_sales;

/*============================================*/
 : CREATE ENRICHED TABLE WITH HELPER COLUMNS
/*============================================*/

create table orders_enriched as
select
    *,

-- 1. Profit Margin % 
	
    round((profit / nullif(sales, 0)) * 100, 2) as profit_margin_pct,

-- 2. Discount Bucket 

    case
        when discount = 0 then 'No Discount'
        when discount <= 5 then 'Low Discount'
        when discount <= 10 then 'Medium Discount'
        else 'High Discount'
    end as  discount_bucket,

-- 3. Profit Flag 
	
    case when profit < 0 then 'Loss' else 'Profit' end as  profit_flag,


-- 4. Avg Price Per Unit 
	
    round(sales / nullif(quantity, 0), 2) as avg_price_per_unit,

-- 5. Order Month / Year 
	
    to_char(order_date, 'YYYY-MM') as order_month,
    to_char(order_date,'YYYY') as order_year,
	
-- 6. Order Size Category 
	
    case
        when quantity <= 2 then 'Small'
        when quantity <= 5 then 'Medium'
        else 'Bulk'
    end as  order_size_category,

-- 7. High Value Order Flag 
	
    case when sales >= 500 then 'High Value' else 'Regular' end as order_value_flag
	
-- 8 Quarter 

from e_commerce_sales;

alter table orders_enriched
add column quarter varchar(2);

update orders_enriched
set quarter = 'Q' || extract(quarter from order_date);


-- ================================================
-- KEY PERFORMANCE INDICATOR (KPI)
-- ================================================

select
count(distinct order_ID) as total_orders,
count(distinct customer_name) as total_customer,
sum(sales) as total_sales,
sum(profit) as total_profit,
sum(quantity) as total_quantity,
round(avg(sales),2) as avg_order_values,
round(
sum(profit)*100.0/
nullif(sum(sales),0),2) as profit_margin
from orders_enriched;

-- ========================================
-- CATEGORY & REGION ANALYSIS
-- ========================================

-- Sales & Profit by Category
select
category,
count(distinct order_id) as total_orders,
sum(quantity) as total_quantity,
sum(sales) as total_sales,
sum(profit) as total_profit,
round(
sum(profit)*100.0/
nullif(sum(sales),0),2) as profit_margin,
round(avg(discount),2) as avg_discount,
rank()over(
order by sum(profit)desc) as profit_rank
from orders_enriched
group by category
order by total_sales desc;


-- Total Sales & Profit by Region

select
region,
sum(sales) as total_sales,
sum(profit) as total_profit,
count(order_id) as total_orders,
round(sum(sales)*100.0/
sum(sum(sales))over(),2) as sales_contribution_percentage,
round(sum(profit)*100.0/
nullif(sum(sales),0),2) as profit_margin
from orders_enriched
group by region
order by total_sales desc;

-- Multi Level Grouping Region X Category

select
region,
category,
sum(sales) as total_sales
from orders_enriched
group by region,category
order by total_sales desc;

-- City Analysis

select
city,
category, 
count(distinct order_id) as total_orders,
round(sum(sales),2) as total_sales,
round(sum(profit),2) as total_profit,
sum(quantity) as total_quantity,
round(sum(profit) * 100.0/nullif(sum(sales),0),2) as profit_margin
from orders_enriched
group by city,category
order by total_sales desc;

-- Top & Bottom Cities by Profit

select
city,
sum(sales) as total_sales,
sum(profit) as total_profit
from orders_enriched
group by city
order by total_profit desc;

-- Top Profitable Cities

select
city,
sum(profit) as total_profit
from orders_enriched
group by city
order by total_profit desc;

-- Year & Quarter Trend 

select
quarter,
order_year,
sum(sales) as total_sales,
sum(profit) as total_profit
from orders_enriched
group by order_year,quarter
order by order_year,quarter;




-- ==============================================
-- DISCOUNT ANALYSIS
-- ==============================================

-- Discount Bucket performance

select
discount_bucket,
count(*) as total_orders,
sum(sales) as total_sales,
sum(profit) as total_profit,
round(sum(profit)*100.0/nullif(sum(sales),0),2) as profit_margin
from orders_enriched
group by discount_bucket
order by profit_margin desc;

-- Discount Analysis

select
discount,
count(*) as total_orders,
sum(sales) as total_sales,
sum(profit)as total_profit,
round(avg(discount),2) as avg_discount,
round(
sum(profit)*100.0/
nullif(sum(sales),0),2) as profit_margin
from orders_enriched
group by discount
order by profit_margin desc;

-- Average Discount by category

select
category,
round(avg(discount),2) as avg_discount
from orders_enriched
group by  category 
order by avg_discount desc;

-- Discount vs Profit by Category

select
category,
discount,
count(*) as total_orders,
sum(sales) as total_sales,
sum(profit) as total_profit,
round(sum(profit)*100.0/
nullif(sum(sales),0),2) as profit_margin
from orders_enriched
group by discount,category
order by category,discount;


-- =======================================
-- PRODUCT ANALYSIS
-- =======================================

-- Product Ranking (Top 5 Per Category)

with ranked_product as 
(
select
category,
product_name,
sum(sales) as total_sales,
sum(profit) as total_profit,
dense_rank()over(partition by category order by sum(sales)desc) as product_rank
from orders_enriched
group by category,product_name
)
select
category,
product_name,
total_sales,
total_profit,
product_rank
from ranked_product
where product_rank <=5
order by category,product_rank;

-- Top vs Loss Product

select
product_name,
sum(sales) as total_sales,
sum(profit) as total_profit,
case 
when sum(profit)<0 then 'Loss Product' else 'Profitable Product'
end as product_status
from orders_enriched
group by product_name
order by total_profit desc;

-- Top 10 Product by Sales Contribution

with product_sales as (
select
product_name,
sum(sales) as total_sales,
sum(profit) as total_profit
from orders_enriched
group by product_name
)
select
product_name,
total_sales,
total_profit,
round(100*total_sales/sum(total_sales)over(),2) as contribution_percentage,
rank()over(order by total_sales desc) as sales_rank
from product_sales
order by total_sales desc
limit 10;


-- High Sales But Low Profit

with product_summary as (
select
product_name,
sum(sales) as total_sales,
sum(profit) as total_profit
from orders_enriched
group by product_name
)
select 
product_name,
total_sales,
total_profit,
round(total_profit / nullif(total_sales, 0)* 100, 2) as profit_margin_percent
from product_summary
where total_sales >(select avg(total_sales)from product_summary)
and total_profit <(select avg(total_profit)from product_summary)
order by total_sales desc;


-- Highest Profit Margin Products 

with product_margin as (
select
product_name,
category,
sum(sales) as total_sales,
sum(profit)as total_profit,
round(sum(profit)*100.0/nullif(sum(sales),0),2) as profit_margin
from orders_enriched
group by product_name,category
)
select
product_name,
category,
total_sales,
total_profit,
profit_margin
from product_margin
where profit_margin > ( select avg(profit_margin) from product_margin)
order by profit_margin desc;


-- Best Selling Product In Every Region

with ranked_products as (
select
region,
product_name,
sum(profit) as total_profit,
round(avg(profit),2) avg_profit,
sum(sales) as total_sales,
dense_rank()over(partition by region order by sum(sales)desc) as sales_rank
from orders_enriched
group by region,product_name
)
select
region,
product_name,
total_sales,
total_profit,
avg_profit
from ranked_products
where sales_rank = 1
order by region;


-- Sub-Category Analysis

select
category,
sub_category,
sum(sales) as total_sales,
sum(profit)as total_profit,
round(sum(profit) * 100.0 / nullif(sum(sales),0),2) as profit_margin,
dense_rank()over(partition by category order by sum(sales)desc) as sub_category_rank
from orders_enriched
group by category,sub_category
order by category,sub_category_rank;


-- Average Selling Performance by Category

select
category,
round(avg(avg_price_per_unit),2) as avg_selling_price,
min(avg_price_per_unit) as lowest_price,
max(avg_price_per_unit) as highest_price,
stddev(avg_price_per_unit) as price_variation
from orders_enriched
group by category
order by avg_selling_price desc;

-- Sales Contribution Of Every Product

select
product_name,
sum(sales) as total_sales,
round(100*sum(sales)/sum(sum(sales))over(),2) as contribution_percentage
from orders_enriched
group by product_name
order by total_sales desc;

-- Category Wise Market Share 

select
category,
sum(sales) as total_sales,
round(sum(sales)*100.0/sum(sum(sales))over(),2) as market_share
from orders_enriched
group by category
order by market_share desc;


-- Category Analysis by Payment Method

select
category,
payment_mode,
sum(sales) as total_sales,
sum(profit) as total_profit,
count(order_id) as total_orders
from orders_enriched
group by category,payment_mode
order by total_sales desc 
limit 10;

-- Payment Method Analysis

select
payment_mode,
count(order_id) as total_orders,
round(sum(sales),2) as total_sales,
round(sum(profit),2) as total_profit,
round(avg(sales),2) as avg_order_value
from orders_enriched
group by payment_mode
order by total_sales desc;

-- =================================
-- TIME BASED TRENDS
-- =================================


-- Month Over Month Growing 

with monthly as (
select 
order_month as month,
sum(sales) as total_sales
from orders_enriched
group by month
)
select
month,
total_sales,
lag(total_sales)over(order by month) as prev_month_sales,
round(
(total_sales - lag(total_sales)over(order by month))
/nullif(lag(total_sales)over(order by month),0)*100,2
) AS mon_growth_pct
from monthly
order by month;



-- Monthly Trend

select
order_month as month,
to_char(order_date,'Month') as month_name,
sum(sales) as total_sales,
sum(profit)as total_profit,
count(order_id) as total_orders
from orders_enriched
group by month,month_name
order by month;

-- Yearly Sales with Growth % 

with yearly_sales as (
select 
to_char(order_date,'YYYY') as year,
sum(sales) as total_sales,
sum(profit)as total_profit
from orders_enriched
group by year
)
select
year,
total_sales,
total_profit,
coalesce(lag(total_sales)over(order by year),0) as previous_sales,
coalesce(
round(
100.0* (total_sales - lag(total_sales)over(order by year))
/
nullif(lag(total_sales)over(order by year),0),2),0.00) as sales_growth_percentage
from yearly_sales;



-- Running Total

with monthly_sales as (
select
order_year as year,
order_month as month,
to_char(order_date,'Month')  as month_number,
sum(sales) as monthly_sales
from orders_enriched
group by year,month,month_number)
select
year,
month,
month_number,
sum(monthly_sales)over(
partition by year 
order by month_number
rows between unbounded preceding and current row
) as cumulative_sales
from monthly_sales
order by year,month_number;

-- Running Profit By Date

select
order_date,
sum(profit) as total_profit,
sum(sum(profit))over(
order by order_date) as running_total
from orders_enriched
group by order_date
order by order_date;


-- Monthly Category Trend

select
category,
order_month,
sum(sales) as total_sales
from orders_enriched
group by order_month,category
order by order_month;

-- ==================================
-- CUSTOMER ANALYSIS
-- ==================================

-- Customers With Above Average Sales

with customer_sales as (
select
order_ID,
customer_name,
sum(sales) as total_sales
from orders_enriched
group by order_ID,customer_name
)
select *
from customer_sales
where total_sales >(select avg(total_sales) from customer_sales)
order by total_sales desc;

-- Top 5 Customer in Every Region

with customer_sales as (
select
customer_name,
region,
sum(sales)as total_sales,
sum(profit) as total_profit,
dense_rank()over
(partition by region order by sum(sales)desc) as customer_rank
from orders_enriched
group by region,customer_name)

select
region,
customer_name,
total_sales,
total_profit,
customer_rank
from customer_sales
where customer_rank <= 5
order by 
region,
customer_rank;


-- Customer Purchase Frequency 

select
customer_name,
count(distinct order_ID) as total_orders,
sum(quantity) as total_quantity,
sum(sales) as total_sales,
sum(profit) as total_profit,
round(avg(sales),2) as avg_order_value,
min(order_date) as first_purchase,
max(order_date) as last_purchase,
max(order_date)-min(order_date) as customer_lifespam
from orders_enriched
group by customer_name
order by total_sales desc;


-- Customer Segmentation (RFM)

with customer_metrics as (
select
customer_name,
max(order_date) as last_order_date,
count(order_id) as frequency,
sum(sales) as monetary
from orders_enriched
group by customer_name
),
scored as (
select *,
ntile(4)over(order by last_order_date) as recency_score,
ntile(4)over(order by frequency)as frequency_score,
ntile(4)over(order by monetary) as monetary_score
from customer_metrics
)
select
customer_name,
recency_score,frequency_score,monetary_score,
(recency_score + frequency_score + monetary_score) as rfm_total,
case 
when (recency_score + frequency_score + monetary_score) >= 10 then 'High Value'
when (recency_score + frequency_score + monetary_score) >= 6 then 'Medium Value' 
else 'Low Value'
end as customer_segment
from scored
order by rfm_total desc;

-- Repeat vs One Time Customers

select
case
when total_orders = 1 then 'One Time'
else 'Repeat'
end as customer_type,
count(*) as customers
from (
select customer_name,
count(distinct order_id) as total_orders
from orders_enriched
group by customer_name
)t
group by customer_type;

-- Top 5 Most Profittable Customers

select
customer_name,
sum(profit) as total_profit
from orders_enriched
group by customer_name
order by total_profit desc
limit 5;

--  ==============================================
--  ADVANCED STASTISTICAL ANALYSIS
--  ==============================================

-- Top 3 Products per Region

select * 
from (
select region,product_name,sales,
row_number()over(partition by region order by sales desc) as rank
from orders_enriched
) ranked 
where rank <= 3;


-- Pareto Analysis 

with sales_cte as (
select
product_name,
sum(sales) as total_sales
from orders_enriched
group by product_name
),
pareto as 
(
select
product_name,
total_sales,
sum(total_sales)
over(order by total_sales desc)
running_sales,
sum(total_sales)
over()overall_sales from sales_cte)
select
product_name,
total_sales,
round(running_sales*100.0/overall_sales,2) cumulative_percentage
from pareto 
where running_sales*100.0/overall_sales<=80
order by total_sales desc;

-- Profit Distribution

with product_profit as (
select
product_name,
sum(profit) as total_profit
from orders_enriched
group by product_name
)
select
product_name,
total_profit,
ntile(4)over(
order by total_profit
) as profit_quartile
from product_profit;

-- Sales Outliers Detection

with stats as (
select
avg(sales) as avg_sales,
stddev(sales) as std_sales
from e_commerce_sales
)
select
product_name,
s.sales,
s.quantity, 
round((s.sales - st.avg_sales) / st.std_sales,2) as z_score
from orders_enriched s
cross join stats st
where abs((s.sales-st.avg_sales)/st.std_sales)>3;

-- ======================================
-- QUARTERLY ANALYSIS
-- ======================================


-- Quarter wise Sales & Profit
select 
quarter,
round(sum(sales),2) as total_sales,
round(sum(profit),2) as total_profit,
count(order_id) as total_orders
from orders_enriched
group by quarter
order by quarter;

-- Quarter Wise Category Performance

select
quarter,
category,
round(sum(sales),2) as total_sales
from orders_enriched
group by quarter,category
order by quarter,total_sales desc;

-- =====================================
-- INSIGHTS 
-- =====================================


-- 1. Goa generated the highest total sales among all cities.

-- 2. The Electronics category recorded the highest average selling price and also contained both the highest-priced and lowest-priced products.

-- 3. Bad Esse was the lowest-selling product based on sales.

-- 4. Aarya Medan was one of the top customers, placing 3 orders, purchasing 10 units, with an average order value of approximately 21,000.

-- 5. Dumbbells Doloribus achieved the highest profit margin among all products.

-- 6. The highest-selling product in each region was:

   -- East: Lipstick Accusam
   -- North: Bed Tenetur
   -- South:  Oil Iusto
   -- West: Lamp Veritatis

-- 7. Home Decor captured the largest market share among all categories at **10.72%**.

-- 8. Headphone Accusantium was the highest-selling product overall.

-- 9. Camera Repellendus had the lowest profit margin percentage.

-- 10. Net Banking was the most preferred payment method across the highest-selling category.

-- 11. Sales grew by 324% in 2024 compared to 2023, then declined by 26.99% in 2025.

-- 12. Toys received the highest average discount among all product categories.

-- 13. The North region generated the highest overall sales.

-- 14. Products with a 5% discount** generated higher sales than products with larger discount percentages.

-- 15. Q2 generated the highest revenue among all four quarters.

-- 16. Top-performing category by quarter:

    -- Q1: Home Decor
    -- Q2: Books
    -- Q3: Home Decor
    -- Q4: Kitchen


-- ======================================
-- BUSINESS RECOMMENDATIONS
-- ======================================

-- 1. Increase inventory before Q2 to meet peak demand.
-- 2. Expand the Home Decor category.
-- 3. Focus marketing campaigns on the North region.
-- 4. Maintain a 5% discount strategy for better sales.
-- 5. Promote high-margin products.
-- 6. Improve profitability of low-margin products.
-- 7. Reward high-value customers through loyalty programs.
-- 8. Investigate the sales decline after 2024.
