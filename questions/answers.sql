-- PART 2A
-- What is the most ordered item based on the number of times it appears in an order cart that checked out successfully?

-- CTE to select customer IDs associated with successfully checked out orders
with successfulcheckouts as (
    -- Selecting customer IDs from events table where orders are successfully checked out
    select e.customer_id
    from alt_school.events e
    join alt_school.orders o on e.customer_id = o.customer_id
    where o.status = 'success' -- Filtering for successful orders
),
-- CTE to select cart events of successfully checked out orders
cartevents as (
    -- Selecting customer IDs and product IDs from events table for successful checkouts
    select e.customer_id,
           e.event_data ->> 'item_id' as product_id -- Extracting product ID from event data
    from alt_school.events e
    join successfulcheckouts sc on e.customer_id = sc.customer_id
    where e.event_data ->> 'event_type' = 'add_to_cart' -- Filtering for add to cart events
      and e.event_data ->> 'item_id' is not null -- Ensuring item ID is not null
)
-- Query to count appearances of products in carts with successful orders
select ce.product_id, -- Selecting product ID
       p.name as product_name, -- Selecting product name
       count(*) as user_cart_successful_checkout -- Counting the number of appearances in carts that successfully checked out
from cartevents ce
join alt_school.products p on ce.product_id = p.id::text -- Joining with products table
group by ce.product_id, p.name -- Grouping by product ID and name
order by user_cart_successful_checkout desc -- Sorting by cart appearances in descending order
limit 1; -- Limiting the result to the most ordered item





-- Without considering currency, and without using the line_item table, find the top 5 spenders.

-- Selecting customer ID, location, and calculating total spend
select
    e.customer_id, -- Selecting customer ID
    c.location, -- Selecting customer location
    sum(p.price * (e.event_data ->> 'quantity')::numeric) as total_spend -- Calculating total spend
from
    alt_school.events e -- Accessing events table, aliased as 'e'
join
    alt_school.customers c on e.customer_id = c.customer_id -- Joining events table with customers table
join
    alt_school.products p on (e.event_data ->> 'item_id')::int = p.id -- Joining events table with products table
join
    alt_school.orders o on e.customer_id = o.customer_id -- Joining events table with orders table
where
    e.event_data ->> 'event_type' = 'add_to_cart' -- Filtering for add to cart events
    and o.status = 'success' -- Filtering for successful orders
group by
    e.customer_id, c.location -- Grouping by customer ID and location
order by
    total_spend desc -- Ordering by total spend
limit 5; -- Limiting results to top 5 spenders





-- PART 2B
-- Using the events table, determine the most common location (country) where successful checkouts occurred.

-- Selecting the location and count of successful checkouts
select c.location as location,  -- Selecting the location from the customers table and aliasing it as 'location'
       count(*) as checkout_count -- Counting the occurrences of successful checkouts and aliasing it as 'checkout_count'
from alt_school.events e -- Selecting data from the 'events' table in the 'alt_school' schema and aliasing it as 'e'
join alt_school.orders o on e.customer_id = o.customer_id -- Joining the 'events' and 'orders' tables based on the customer_id
join alt_school.customers c on o.customer_id = c.customer_id -- Joining the 'orders' and 'customers' tables based on the customer_id
where e.event_data->>'event_type' = 'checkout' -- Filtering the events data to include only 'checkout' events
  and o.status = 'success' -- Filtering the orders to include only successful orders
group by c.location -- Grouping the data by the location from the customers table
order by checkout_count desc -- Ordering the results by the count of successful checkouts in descending order
limit 1; -- Limiting the output to only the top 1 row, which represents the most common location for successful checkouts





-- Using the events table, identify the customers who abandoned their carts and count the number of events (excluding visits) that occurred before the abandonment.

-- Common table expression to extract events of removing items from the cart excluding visits
with cart_events as (
    select customer_id,
           (event_data->>'timestamp')::timestamp as timestamp,  -- Extracting timestamp from event data
           row_number() over (partition by customer_id order by (event_data->>'timestamp')::timestamp) as event_sequence  -- Generating event sequence number
    from alt_school.events
    where event_data->>'event_type' = 'remove_from_cart'  -- Filtering events for removing items from the cart
      and event_data->>'event_type' <> 'visit'  -- Excluding events of type 'visit'
),
-- Common table expression to extract events of adding items to the cart excluding visits
checkout_events as (
    select customer_id,
           (event_data->>'timestamp')::timestamp as timestamp,  -- Extracting timestamp from event data
           row_number() over (partition by customer_id order by (event_data->>'timestamp')::timestamp) as event_sequence  -- Generating event sequence number
    from alt_school.events
    where event_data->>'event_type' = 'add_to_cart'  -- Filtering events for adding items to the cart
      and event_data->>'event_type' <> 'visit'  -- Excluding events of type 'visit'
)
-- Main query to identify customers who abandoned their carts and count relevant events before abandonment
select ce.customer_id,
       count(*) as num_events  -- Counting the number of relevant events
from cart_events ce
join checkout_events co on ce.customer_id = co.customer_id and ce.timestamp < co.timestamp  -- Joining cart and checkout events, ensuring cart event occurs before checkout event
where ce.event_sequence < co.event_sequence  -- Filtering for events that occurred before abandonment
group by ce.customer_id;  -- Grouping by customer_id





-- Find the average number of visits per customer, considering only customers who completed a checkout! return average_visits to 2 decimal place.

-- Common table expression (CTE) to select distinct customer IDs who completed a checkout
with checkout_customers as (
    select distinct customer_id
    from alt_school.events
    where event_data->>'event_type' = 'checkout' -- Filtering events for checkout completions
),
-- CTE to count the number of visits for customers who completed a checkout
customer_visits as (
    select e.customer_id, count(*) as num_visits
    from alt_school.events e
    join alt_school.customers c on e.customer_id = c.customer_id -- Joining with customers table to get customer details
    where e.customer_id in (select customer_id from checkout_customers) -- Filtering events for customers who completed a checkout
      and e.event_data->>'event_type' = 'visit' -- Filtering events for visits
    group by e.customer_id -- Grouping by customer_id to count visits per customer
)
-- Main query to calculate the average number of visits per customer
select round(avg(num_visits)::numeric, 2) as average_visits
from customer_visits; -- Calculating the average of the number of visits per customer