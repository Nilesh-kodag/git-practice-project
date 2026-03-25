select customer_id, sum(sales) as total_sales
from orders
group by customer_id;