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
    -- and [created_at = daterange_no_tz] -- так нельзя
), assignes as (
	select
		order_id,
		field_value::json ->> 'id' as master_id,
		o.user_id,
		case
			when r.user_id is not null then 'admin'
			when m.user_id is not null then 'master'
			when o.user_id is not null then 'user'
			else 'auto'
		end as user_type,
		o.created_at as assigned_at
	from order_deltas o
		left join users_roles r on (o.user_id = r.user_id and r.role_id = 1)
		left join masters m on (o.user_id = m.user_id) -- r.role_id = 1, чтобы не задвайвалось
	where field_name = 'cleaners'
        and field_action != 'R' --чтобы не попадали удаления клинеров
)

select
	a.master_id,
	o.rooms,
	o.total_time,
	case
		when type = 'lite' then 1
		else 0
	end as lite_flg,
	case
		when payment_type = 'cash' then 1
		else 0
	end as cash_flg,
	case
		when subscription_id is not null then 1
		else 0
	end as subscr_flg,
	case
		when keys_delivery is not null then 1
		else 0
	end as keys_flg,
	case
		when need_vacuum_cleaner then 1
		else 0
	end as vacuum_flg,
	extract(epoch from o.start_at - a.assigned_at)/3600 as hours_to_cln,
	ad.lat,
	ad.lng,
	extract(dow from start_at) as dow,
	extract(hours from start_at) as hours,
	case
		when o.workflow_state in ('paid', 'checked_in', 'checked_out') and p.id is not null then 1 -- 'done'
    	when o.workflow_state in ('paid', 'checked_in', 'checked_out') and p.id is null then 0 --'broken_by_cleaner'
		when o.workflow_state = 'canceled' then 1 --'broken_by_user' 
		else 1 --'in_progress'
	end as assigne_state
from assignes a
	left join performers p on (a.master_id::integer = p.cleaner_id and a.order_id = p.order_id)
	left join orders o on (a.order_id = o.id)
	left join addresses ad on (o.address_id = ad.id)
where user_type = 'auto'
	and deal_id is null
	and ad.lat is not null
	and ad.lng is not null
	and o.workflow_state in ('paid', 'checked_in', 'checked_out');
	