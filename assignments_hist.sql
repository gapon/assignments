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
	), cleaner_deltas as (
		select
			order_id,
			field_action,
			(field_value::json ->> 'id')::int as master_id,
			
			o.user_id as act_user_id,
			m.id as act_master_id,
			
			case
				when r.user_id is not null then 'admin'
				when m.user_id is not null then 'master'
				when o.user_id is not null then 'user'
				else 'auto'
			end as act_user_type,
			o.created_at
		from order_deltas o
			left join users_roles r on (o.user_id = r.user_id and r.role_id = 1)
			left join masters m on (o.user_id = m.user_id) -- r.role_id = 1, чтобы не задвайвалось
		where field_name = 'cleaners'
	        --and field_action != 'R' --чтобы не попадали удаления клинеров
	), assignes as (
		select
			*,
			
			lead(field_action,1) OVER (partition by order_id order by created_at) as next_action,
			lead(master_id,1) OVER (partition by order_id order by created_at) as next_master_id,
			lead(act_master_id,1) OVER (partition by order_id order by created_at) as next_act_master_id,
			lead(act_user_id,1) OVER (partition by order_id order by created_at) as next_act_user_id,
			lead(act_user_type,1) OVER (partition by order_id order by created_at) as next_act_user_type,
			lead(created_at,1) OVER (partition by order_id order by created_at) as next_created_at
		from cleaner_deltas
	)
	
	select * from assignes
	where field_action = 'A';