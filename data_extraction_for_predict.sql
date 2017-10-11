with order_list as (
	select
		o.id as order_id,
		--o.start_at,
		c.region_id,
		
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
		extract(epoch from o.start_at - now())/3600 as hours_to_cln,
	
		a.lat,
		a.lng,
	
		extract(dow from o.start_at) as dow,
		extract(hours from o.start_at) as hours
	
	from orders o
		left join addresses a on (o.address_id = a.id)
		left join cities c on (a.city_id = c.id)
	where o.deal_id is null
		and date(start_at) = current_date + 5
		--and date(start_at) >= current_date + 1
		--and date(start_at) < current_date + 7
		and a.lat is not null
		and a.lng is not null
		and o.workflow_state = 'confirmed'
), master_list as (
	select
		m.id as master_id,
		m.region_id,
		a.lat,
		a.lng
	from masters m
		left join addresses a on (m.user_id = a.user_id)
	where block_reason_id is null
		and cleaner_type != 'windows'
		and new_skill !='lead'
		and m.id not in (72192,12438,53705,48852)
		and a.lat is not null
		and a.lng is not null
)

select
	master_id,
	rooms,
	bathrooms,
	total_time,
	lite_flg,
	cash_flg,
	subscr_flg,
	keys_flg,
	vacuum_flg,
	hours_to_cln,
	o.lat,
	o.lng,
	dow,
	hours
from master_list m
	left join order_list o on (m.region_id = o.region_id and st_distance_sphere(st_makepoint(m.lng, m.lat),st_makepoint(o.lng, o.lat))/1000 < 10)
where order_id is not null;