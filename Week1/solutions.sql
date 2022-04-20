/* --------------------
   Case Study Questions
   --------------------*/

-- 1. What is the total amount each customer spent at the restaurant?
SELECT s.customer_id,sum(m.price)
FROM sales s
JOIN menu m on m.product_id = s.product_id
GROUP BY s.customer_id;

-- 2. How many days has each customer visited the restaurant?
SELECT s.customer_id,count(distinct order_date) as visit_count
FROM sales s
GROUP BY s.customer_id;

-- 3. What was the first item from the menu purchased by each customer?
with a as (
SELECT s.customer_id,m.product_name ,dense_rank() over(partition by s.customer_id order by s.order_date ) as order_num
FROM sales s
JOIN menu m on m.product_id = s.product_id)
select customer_id,product_name from a
where order_num = 1
group by customer_id,product_name;

-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?

SELECT m.product_name,count(*) as times_purchased
FROM sales s
JOIN menu m on m.product_id = s.product_id
GROUP BY m.product_name
order by times_purchased desc
limit 1;

-- 5. Which item was the most popular for each customer?
with a as (
  SELECT s.customer_id,m.product_name, count(*) as no_of_ordered_times
  FROM sales s
  JOIN menu m on m.product_id = s.product_id
  GROUP BY s.customer_id,m.product_name
),
 b as (
select customer_id,max(no_of_ordered_times) as no_of_ordered_times from a
group by 1)
select a.customer_id, a.product_name, b.no_of_ordered_times
from a join b on a.customer_id = b.customer_id and a.no_of_ordered_times = b.no_of_ordered_times;

with a as (
    SELECT s.customer_id,m.product_name, count(*) as no_of_ordered_times, dense_rank() over (partition by  s.customer_id order by count(s.product_id) desc) as r
  FROM sales s
  JOIN menu m on m.product_id = s.product_id
  GROUP BY s.customer_id,m.product_name
)
  select customer_id,product_name,no_of_ordered_times from a
  where r=1;

-- 6. Which item was purchased first by the customer after they became a member?
with a as (
SELECT s.customer_id,m.product_name ,dense_rank() over(partition by s.customer_id order by s.order_date ) as order_num
FROM sales s
JOIN menu m on m.product_id = s.product_id
JOIN members c on c.customer_id=s.customer_id
where s.order_date > c.join_date)
select customer_id,product_name from a
where order_num = 1
group by customer_id,product_name;

-- 7. Which item was purchased just before the customer became a member?
with a as (
SELECT s.customer_id,m.product_name ,dense_rank() over(partition by s.customer_id order by s.order_date desc) as order_num
FROM sales s
JOIN menu m on m.product_id = s.product_id
JOIN members c on c.customer_id=s.customer_id
where s.order_date < c.join_date)
select customer_id,product_name from a
where order_num = 1
group by customer_id,product_name;


-- 8. What is the total items and amount spent for each member before they became a member?
SELECT c.customer_id,count(distinct s.product_id) as total_items,sum(price) as amount_spent
FROM sales s
JOIN menu m on m.product_id = s.product_id
JOIN members c on c.customer_id=s.customer_id
where s.order_date < c.join_date
GROUP BY 1;


-- 9.  If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
SELECT s.customer_id,sum(case when m.product_name = 'sushi' then 2 * price else price end) * 10 as points
FROM sales s
JOIN menu m on m.product_id = s.product_id
GROUP BY s.customer_id;


-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?

SELECT s.customer_id,sum(case when m.product_name = 'sushi' then 2 * price
when s.order_date between c.join_date and  c.join_date + INTERVAL '7 DAY' then 2 * price else price end) * 10 as points
FROM sales s
JOIN menu m on m.product_id = s.product_id
JOIN members c on c.customer_id=s.customer_id
where s.order_date <= '2021-01-31'
GROUP BY s.customer_id;
