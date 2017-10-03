drop table if exists tmp_assignments;
create temp table tmp_assignments as
	with order_deltas as (
		select
			id,
			model_id as order_id,
			user_id,
			json_array_elements(object)->>'name' as field_name,
			json_array_elements(object)->>'object' as field_value,
	    	json_array_elements(object)->>'action' as field_action,
			created_at
		from deltas
		where model_type = 'Order'
			and created_at >= '2017-04-01' -- чтобы быстрее работало
	), assignes as (
		select
			order_id,
			field_action,
			field_value::json ->> 'id' as master_id,
			o.user_id,
			case
				when r.user_id is not null then 'admin'
				when m.user_id is not null then 'master'
				when o.user_id is not null then 'user'
				else 'auto'
			end as user_type,
			o.created_at
		from order_deltas o
			left join users_roles r on (o.user_id = r.user_id and r.role_id = 1)
			left join masters m on (o.user_id = m.user_id) -- r.role_id = 1, чтобы не задвайвалось
		where field_name = 'cleaners'
	        --and field_action != 'R' --чтобы не попадали удаления клинеров
	)
	
select * from assignes;


with chains as (

select
	*,
	lead(field_action,1) OVER (partition by order_id order by created_at) as next_action,
	lead(master_id,1) OVER (partition by order_id order by created_at) as next_master_id,
	lead(created_at,1) OVER (partition by order_id order by created_at) as next_created_at

from tmp_assignments
-- where order_id = 1253343 -- DEBUG
), sa_data as (
	select 
		*,
		(extract(epoch from next_created_at - created_at)/3600)::int as hrs_to_r,
		(extract(epoch from now() - created_at)/3600)::int as age_hrs
	from chains
	where user_type = 'auto'
		and field_action = 'A'
		and (next_action = 'R' or next_action is null)
		and created_at >= '2017-09-01'
), hours as (
	select
		h as t
	from generate_series(0, 300, 1) as h
)

select
	t,
	(select count(*) from sa_data where age_hrs >= t and (hrs_to_r >= t or hrs_to_r is null)) as population,
	(select count(*) from sa_data where hrs_to_r = t) as deaths
from hours;