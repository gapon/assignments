-- История изменения start_at	
drop table if exists orders_hist;
create temp table orders_hist as
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
			and created_at >= '2017-03-01' -- чтобы быстрее работало
	), shifts as (
		select
			order_id,
			field_action,
			field_value,
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
			left join masters m on (o.user_id = m.user_id)
		where field_name = 'start_at'
	), order_shift_hist as (
	select
		order_id,
		field_value::timestamp - interval '3 hours' as start_at,
		created_at as valid_from,
		case
			when lead(created_at,1) OVER (partition by order_id order by created_at) is null then '2020-01-01 00:00:00'::timestamp
			else lead(created_at,1) OVER (partition by order_id order by created_at)
		end as valid_to
	from shifts
	)

	select * from order_shift_hist;