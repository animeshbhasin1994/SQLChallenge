-- Preprocess/Cleanse data
drop table if exists customer_orders_clean;
create table customer_orders_clean as
select
	order_id,
	customer_id,
	pizza_id,
	case
		when exclusions = 'null' then null
		when exclusions = '' then null
		else exclusions
	end as exclusions,
	case
		when extras = 'null' then null
		when extras = '' then null
		else extras
	end as extras,
	order_time
from
	customer_orders;

drop table if exists runner_orders_clean;
create table runner_orders_clean as
 select
 	order_id,
 	runner_id,
 	case
 		when pickup_time = 'null' then null
 		else pickup_time
 	end as pickup_time,
 	case
 		when  distance = 'null' then null
 		when distance like '%km' then TRIM('km' from distance)
 		else distance
 	end as distance,
 	case
 		when duration = 'null' then null
        WHEN duration LIKE '%mins' THEN TRIM('mins' from duration)
        WHEN duration LIKE '%minute' THEN TRIM('minute' from duration)
        WHEN duration LIKE '%minutes' THEN TRIM ('minutes' from duration)
 		else duration
 	end as duration,
 	case
		when cancellation  = 'null' then null
		when cancellation = '' then null
--		when cancellation = 'NaN' then null
		else cancellation
	end as cancellation
 from
 	runner_orders
 ;

--Fix data types
alter table pizza_runner.runner_orders_clean alter column pickup_time type TIMESTAMP
	using pickup_time::TIMESTAMP,
alter column duration type INT
	using duration::integer,
alter column distance type FLOAT
	using distance::FLOAT;

--A. Pizza Metrics

--1. How many pizzas were ordered?
select
	count(pizza_id)
from
	customer_orders_clean;

--2. How many unique customer orders were made?
select
	count(distinct order_id)
from
	customer_orders_clean;

--3. How many successful orders were delivered by each runner?
select
	runner_id ,
	count(order_id)
from
	runner_orders_clean ro
where
	cancellation is null
group by
	runner_id ;

--4. How many of each type of pizza was delivered?
select
	pn.pizza_name ,
	count(roc.order_id)
from
	customer_orders_clean coc
join runner_orders_clean roc on
	roc.order_id = coc.order_id
join pizza_names pn on
	pn.pizza_id = coc.pizza_id
where
	roc.cancellation is null
group by
	pn.pizza_name ;

--5. How many Vegetarian and Meatlovers were ordered by each customer?
select
	coc.customer_id ,
	pn.pizza_name ,
	count(coc.order_id)
from
	customer_orders_clean coc
join pizza_names pn on
	pn.pizza_id = coc.pizza_id
group by
	coc.customer_id, pn.pizza_name ;

--6. What was the maximum number of pizzas delivered in a single order?
with order_pizza_count as (
select
	roc.order_id ,
	count(coc.pizza_id) as pizza_count_per_order
from
	customer_orders_clean coc
join runner_orders_clean roc on
	roc.order_id = coc.order_id
where
	roc.cancellation is null
group by
	roc.order_id )
select
	max(pizza_count_per_order)
from
	order_pizza_count;
--7. For each customer, how many delivered pizzas had at least 1 change and how many had no changes?
select
	coc.customer_id ,
	sum(case when exclusions is not null or extras is not null then 1 else 0 end) as no_of_orders_atleast_1_change,
	sum(case when exclusions is null and extras is null then 1 else 0 end) as no_of_orders_no_change
from
	customer_orders_clean coc
join runner_orders_clean roc on
	roc.order_id = coc.order_id
where
	roc.cancellation is null
group by
	coc.customer_id;


--8. How many pizzas were delivered that had both exclusions and extras?
select
	count(pizza_id)
from
	customer_orders_clean coc
join runner_orders_clean roc on
	roc.order_id = coc.order_id
where
	roc.cancellation is null
	and coc.exclusions is not null
	and coc.extras is not null;

--9. What was the total volume of pizzas ordered for each hour of the day?
select
	extract('hour' from order_time) as hour_of_day,
	count(pizza_id) as total_volume
from
	customer_orders_clean coc
group by
	hour_of_day;

--10. What was the volume of orders for each day of the week?
select
	to_char(order_time, 'day') as hour_of_day,
	count(pizza_id) as total_volume
from
	customer_orders_clean coc
group by
	hour_of_day;

--B. Runner and Customer Experience

--1. How many runners signed up for each 1 week period? (i.e. week starts 2021-01-01)
select
	to_char(registration_date , 'w') as signup_week,
	count(runner_id) as no_of_runner_signups
from
	runners
group by signup_week
;

--2. What was the average time in minutes it took for each runner to arrive at the Pizza Runner HQ to pickup the order?
select
	roc.runner_id ,
	avg(extract(epoch from (roc.pickup_time - coc.order_time )))/60 as avg_time_to_arrive
from
	customer_orders_clean coc
join runner_orders_clean roc on
	roc.order_id = coc.order_id
group by
	roc.runner_id ;

--3. Is there any relationship between the number of pizzas and how long the order takes to prepare?
with order_summary as (
select
	coc.order_id ,
	extract(epoch
from
	(roc.pickup_time - coc.order_time ))/ 60 as prep_time,
	count(pizza_id) as no_of_pizzas
from
	customer_orders_clean coc
join runner_orders_clean roc on
	roc.order_id = coc.order_id
where
	roc.cancellation is null
group by
	coc.order_id,
	roc.pickup_time,
	coc.order_time)
select
	no_of_pizzas,
	avg(prep_time)
from
	order_summary
group by
	no_of_pizzas ;

--4. What was the average distance travelled for each customer?
select
	coc.customer_id ,
	avg(distance) as avg_distance
from
	customer_orders_clean coc
join runner_orders_clean roc on
	roc.order_id = coc.order_id
group by
	coc.customer_id ;


--5. What was the difference between the longest and shortest delivery times for all orders?
select
	max(duration ) - min(duration ) as delivery_time_diff
from
runner_orders_clean;

--6. What was the average speed for each runner for each delivery and do you notice any trend for these values?
select
	roc.runner_id ,
	roc.order_id ,
	sum(roc.distance) * 60 / sum(roc.duration) as avg_speed
from
	customer_orders_clean coc
join runner_orders_clean roc on
	roc.order_id = coc.order_id
where
	roc.distance is not null
group by
	roc.runner_id ,
	roc.order_id ;

--7. What is the successful delivery percentage for each runner?
select
	runner_id ,
	100 * sum(case when cancellation is null then 1 else 0 end) / count(order_id)
from
	runner_orders_clean roc
group by
	runner_id ;

--C Ingredient Optimisation !
-- 1. What are the standard ingredients for each pizza?
with pizza_ingredients as (
select
	pizza_id,
	unnest(string_to_array(toppings, ','))::numeric as topping_id
from
	pizza_recipes pr)
select
	pn.pizza_name ,
	pt.topping_name
from
	pizza_ingredients pi
join pizza_names pn on
	pi.pizza_id = pn.pizza_id
join pizza_toppings pt on
	pt.topping_id = pi.topping_id ;

-- 2. What was the most commonly added extra?
with order_extras as (
select
	order_id,
	unnest(string_to_array(extras , ','))::numeric as topping_id
from
	customer_orders_clean coc
	)
select oe.topping_id,pt.topping_name ,count(oe.topping_id) as no_of_times_ordered
from order_extras oe
join pizza_toppings pt on
	oe.topping_id = pt.topping_id
group by
	oe.topping_id,pt.topping_name
order by
	no_of_times_ordered desc;

-- 3. What was the most common exclusion?

with order_exclusions as (
select
	order_id,
	unnest(string_to_array(exclusions , ','))::numeric as topping_id
from
	customer_orders_clean coc
	)
select oe.topping_id,pt.topping_name ,count(oe.topping_id) as no_of_times_excluded
from order_exclusions oe
join pizza_toppings pt on
	oe.topping_id = pt.topping_id
group by
	oe.topping_id,pt.topping_name
order by
	no_of_times_excluded desc;

-- 4. Generate an order item for each record in the customers_orders table in the format of one of the following:
--     Meat Lovers
--     Meat Lovers - Exclude Beef
--     Meat Lovers - Extra Bacon
--     Meat Lovers - Exclude Cheese, Bacon - Extra Mushroom, Peppers

-- Need to debug further (not completely correct for order_id = 10)
with pizza_name as (
select
	coc.order_id ,
	coc.pizza_id ,
	pn.pizza_name
from
	customer_orders_clean coc
left join pizza_names pn on
	coc.pizza_id = pn.pizza_id ),
order_exclusions as (
select
	order_id,
	pt.topping_name as exclusion_1 ,
	pt2.topping_name as exclusion_2,
	case
		when pt.topping_name is not null
		and pt2.topping_name is not null then concat(' - Exclude ' , pt.topping_name, ', ' , pt2.topping_name)
		when pt.topping_name is not null then concat(' - Exclude ' , pt.topping_name)
	end as order_summary
from
	customer_orders_clean coc
 left join pizza_toppings pt on
	split_part(coc.exclusions, ',', 1)::numeric = pt.topping_id
 left join pizza_toppings pt2 on
	case
		when split_part(coc.exclusions, ',', 2) = '' then null
		else split_part(coc.exclusions, ',', 2)::numeric
	end = pt2.topping_id ),
order_extras as (
select
	order_id,
	pt3.topping_name as extra_1,
	pt4.topping_name as extra_2,
	case
		when pt3.topping_name is not null
		and pt4.topping_name is not null then concat(' - Extra ' , pt3.topping_name, ', ' , pt4.topping_name)
		when pt3.topping_name is not null then concat(' - Extra ' , pt3.topping_name)
		else null
	end as order_summary
from
	customer_orders_clean coc
 left join pizza_toppings pt3 on
	split_part(coc.extras, ',', 1)::numeric = pt3.topping_id
 left join pizza_toppings pt4 on
	case
		when split_part(coc.extras, ',', 2) = '' then null
		else split_part(coc.extras, ',', 2)::numeric
	end = pt4.topping_id )
select
	distinct
	pn.order_id,
	concat(pn.pizza_name, oe.order_summary, oex.order_summary),
from
	pizza_name pn
join order_exclusions oe on
	pn.order_id = oe.order_id
join order_extras oex on
	pn.order_id = oex.order_id;