select customer_id, sum(amount) as total_sales
from orders
group by customer_id;
