create table customer_orders (
order_id integer,
customer_id integer,
order_date date,
order_amount integer
);

insert into customer_orders values(1,100,cast('2022-01-01' as date),2000),(2,200,cast('2022-01-01' as date),2500),(3,300,cast('2022-01-01' as date),2100)
,(4,100,cast('2022-01-02' as date),2000),(5,400,cast('2022-01-02' as date),2200),(6,500,cast('2022-01-02' as date),2700)
,(7,100,cast('2022-01-03' as date),3000),(8,400,cast('2022-01-03' as date),1000),(9,600,cast('2022-01-03' as date),3000)
;


WIth CTE as (
SELECT *,min(order_date) over(partition by customer_id order by order_date asc) as first_time_order FROM customer_orders)

, CTE2 as (
SELECT * ,case when order_date=first_time_order then 1 else 0 end as customer_Status,
case when order_date!=first_time_order then 1 else 0 end as customer_Status_2  From CTE
)




SELECT order_date,sum(customer_Status),sum(customer_Status_2) FROM CTE2
Group by order_date 