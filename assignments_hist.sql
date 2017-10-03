-- История распределения заказов
drop table if exists assignments_hist;
create temp table assignments_hist as
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
	        and field_action != 'R' --чтобы не попадали удаления клинеров
	)
	
	select * from assignes;