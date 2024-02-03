select * from artist
select * from canvas_size
select * from image_link
select * from museum
select * from museum_hours
select * from product_size
select * from subject
select * from work

-- 1) Fetch all the paintings which are not displayed on any museums?

select distinct work_id,name ,artist_id,style
from work 
where museum_id is NULL

-- 2) Are there museuems without any paintings?

select * from museum 
where museum_id not in (select museum_id from work)

-- 3) How many paintings have an asking price of more than their regular price? 

select count(work_id) from product_size 
where sale_price>regular_price

-- 4) Identify the paintings whose asking price is less than 50% of its regular price

select * from work w 
join product_size p on p.work_id=w.work_id
where p.sale_price<0.5*p.regular_price

-- 5) Which canva size costs the most?

select c.*,p.sale_price 
from canvas_size c 
join product_size p on c.size_id=p.size_id::int
where p.sale_price=(select max(sale_price) from product_size)

-- 6) Identify the museums with invalid city information in the given dataset

select * from museum where not city ~ '^[0-9]'

-- 7) Fetch the top 10 most famous painting subject

select * from
(select subject,dense_rank() over(order by count(work_id) desc) as rk from subject
group by 1)a
where rk<=10

-- 8) Identify the museums which are open on both Sunday and Monday. Display museum name, city.

with sunday as 
(
select m.museum_id,m.name,m.city,mh.day
from museum m 
join museum_hours mh on m.museum_id=mh.museum_id
where mh.day='Sunday'
),
monday as 
(
select m.museum_id,m.name,m.city,mh.day
from museum m 
join museum_hours mh on m.museum_id=mh.museum_id
where mh.day='Monday'
)

select distinct s.name as museum_name,s.city from sunday s join monday m on s.museum_id=m.museum_id

-- 9) How many museums are open every single day?

select count(museum_id) as count_of_museum
from (
select museum_id,count(distinct day) as cnt 
from museum_hours 
group by 1 
having count(distinct day)=7
)a

-- 10) Which are the top 5 most popular museum? (Popularity is defined based on most no of paintings in a museum)

select museum_id,name as museum_name,country,city,num_of_paintings
from 
(select m.museum_id,m.name,m.country,m.city,count(w.work_id) as num_of_paintings,dense_rank() over(order by count(w.work_id) desc) as rk
from museum m 
join work w
on m.museum_id=w.museum_id 
group by 1,2,3,4)a
where rk<=5

-- 11) Who are the top 5 most popular artist? (Popularity is defined based on most no of paintings done by an artist)

select artist_id,full_name as artist_name,nationality,style,num_of_paintings
from 
(select a.artist_id,a.full_name,a.nationality,a.style,count(w.work_id) as num_of_paintings,dense_rank() over(order by count(w.work_id) desc) as rk
from artist a 
join work w
on a.artist_id=w.artist_id 
group by 1,2,3,4)a
where rk<=5

-- 12) Display the 3 least popular canva sizes

select size_id,label,num_of_paintings from
(select c.size_id,c.label,count(p.work_id) as num_of_paintings,dense_rank() over(order by count(p.work_id)) as rk
from canvas_size c 
join product_size p on c.size_id::text=p.size_id
group by 1,2
)a
where rk<=3

-- 13) Which museum is open for the longest during a day. Dispay museum name, state and hours open and which day?

select museum_id,name as museum_name,state,day,hours_open 
from
(select m.museum_id,m.name,m.state,mh.day,
extract (hour from (to_timestamp(mh.open,'HH:MI')-to_timestamp(mh.close,'HH:MI'))) as hours_open,
dense_rank() over(order by extract (hour from (to_timestamp(mh.open,'HH:MI')-to_timestamp(mh.close,'HH:MI'))) desc) as rk
from museum m join museum_hours mh on m.museum_id=mh.museum_id)a
where rk=1

-- 14) Which museum has the most no of most popular painting style?

select museum_id,name as museum_name,country,state,city,style,num_of_paintings
from
(select m.museum_id,m.name,m.country,m.state,m.city,w.style,
count(w.work_id) as num_of_paintings,dense_rank() over(order by count(w.work_id) desc) as rk
from
museum m join work w on w.museum_id=m.museum_id
group by 1,2,3,4,5,6
)a
where rk=1

-- 15) Identify the artists whose paintings are displayed in multiple countries

select a.artist_id,a.full_name as artist_name,count(distinct m.country) as num_of_countries
from artist a join work w on a.artist_id=w.artist_id
join museum m on m.museum_id=w.museum_id
group by 1,2
having count(m.country)>1
order by 3 desc

-- 16) Display the country and the city with most no of museums. Output 2 seperate columns to mention the city and country. If there are multiple value, seperate them with comma.

with countries as
( select string_agg(country,',') as countries_with_most_museums
 from
	(select country,dense_rank() over(order by count(museum_id) desc) as rk
 	from museum
 	group by 1)a
 where rk=1
 group by rk
),
cities as (
select string_agg(city,',') as cities_with_most_museums
from
	(select city,dense_rank() over(order by count(museum_id) desc) as rk
 	from museum
 	group by 1)a
 where rk=1
 group by rk
)
select * from countries cross join cities

-- 17) Identify the artist and the museum where the most expensive and least expensive painting is placed. Display the artist name, sale_price, painting name, museum name, museum city and canvas label

with m_exp as 
(
select distinct full_name as artist_name,name as museum_name,sale_price,case when true then 'most expensive' end as category
from
	(select a.artist_id,a.full_name,m.name,p.sale_price,dense_rank() over(order by p.sale_price desc) as rk
	from artist a 
	join work w on a.artist_id=w.artist_id
	join product_size p on p.work_id= w.work_id
	join museum m on m.museum_id=w.museum_id)x
where rk=1
),
l_exp as 
(
select distinct full_name as artist_name,name as museum_name,sale_price,case when true then 'least expensive' end as category
from
	(select a.artist_id,a.full_name,m.name,p.sale_price,dense_rank() over(order by p.sale_price) as rk
	from artist a 
	join work w on a.artist_id=w.artist_id
	join product_size p on p.work_id= w.work_id
	join museum m on m.museum_id=w.museum_id)x
where rk=1
)

select * from m_exp
union all
select * from l_exp

-- 18) Which country has the highest and lowest number of paintings?

with highest as 
( 
select case when true then 'highest' end as category,string_agg(country,',')as country,num_of_paintings
from
	(select m.country,count(w.work_id) as num_of_paintings,dense_rank() over(order by count(w.work_id ) desc) as rk
	from museum m join work w on m.museum_id=w.museum_id
	group by 1)x
where rk=1
group by 1,3
),
lowest as 
(
select case when true then 'lowest' end as category,string_agg(country,',')as country,num_of_paintings
from
	(select m.country,count(w.work_id) as num_of_paintings,dense_rank() over(order by count(w.work_id )) as rk
	from museum m join work w on m.museum_id=w.museum_id
	group by 1)x
where rk=1
group by 1,3
)
select * from highest
union
select * from lowest

-- 19) Which are the 3 most popular and 3 least popular painting styles?

with most_p as (
select case when true then '3 most popular' end as category,style,num_of_paintings
from
	(select style,count(case when style is not null then work_id end) as num_of_paintings ,dense_rank() over(order by count(case when style is not null then work_id end) desc) as rk 
	from work group by 1)a
where rk<=3
),
least_p as 
(
select case when true then '3 least popular' end as category,style,num_of_paintings
from
	(select style,count(work_id) as num_of_paintings ,dense_rank() over(order by count(work_id )) as rk 
	from work group by 1)a
where rk<=3
)
select * from most_p
union 
select * from least_p
order by 3

-- 20) Which artist has the most no of Portraits paintings outside USA?. Display artist name, no of paintings and the artist nationality.

select full_name as artist_name,nationality,num_of_paintings 
from
(select a.full_name,a.nationality,count(w.work_id) as num_of_paintings,dense_rank() over(order by count(w.work_id) desc) as rk
from artist a join work w on a.artist_id=w.artist_id
join museum m on m.museum_id=w.museum_id
where m.country<>'USA'
group by 1,2)x
where rk=1
