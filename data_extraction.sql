-- 1. assignments_hist.sql
-- 2. orders_hist.sql
-- Время start_at на момент распределения заказа
select
	a.master_id,
	o.rooms,
	o.bathrooms,
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
		when keys_delivery then 1
		else 0
	end as keys_flg,
	case
		when need_vacuum_cleaner then 1
		else 0
	end as vacuum_flg,
	extract(epoch from s.start_at - a.created_at)/3600 as hours_to_cln,
	
	-- по идее широты и долготы должно хватить
	-- можно попробовать квадраты-зоны
	-- можно попробовать считать расстояния
	ad.lat,
	ad.lng,
	
	extract(dow from s.start_at) as dow,
	extract(hours from s.start_at) as hours, 
	
	/*
	case
		when next_action = 'R' and a.master_id = a.next_act_master_id then 0 -- клинер сам отказался от заказа
		when o.workflow_state in ('paid', 'checked_in', 'checked_out') and a.master_id = p.cleaner_id and (a.created_at - p.created_at) < interval '1 minute' then 1 -- заказа состоялся
		when o.workflow_state = 'canceled' and a.master_id = p.cleaner_id and (a.created_at - p.created_at) < interval '1 minute' then 2 -- заказ отменился
		when next_action = 'R' and next_act_user_type in ('admin', 'user') then 3 -- админ или юзер снял клинера или перенес заказ
	end as assigne_state_details
	*/
	
	case
		when next_action = 'R' and a.master_id = a.next_act_master_id then 0
		else 1
	end as assigne_state
from assignments_hist a
	left join orders_hist s on (a.order_id = s.order_id and a.created_at between s.valid_from and s.valid_to)
	left join performers p on (a.master_id::integer = p.cleaner_id and a.order_id = p.order_id)
	left join orders o on (a.order_id = o.id)
	left join addresses ad on (o.address_id = ad.id)
where --user_type = 'auto'
	deal_id is null
	and ad.lat is not null
	and ad.lng is not null
	and o.workflow_state in ('paid', 'checked_in', 'checked_out', 'canceled');