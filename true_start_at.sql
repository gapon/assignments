-- 1. assignments_hist.sql
-- 2. orders_hist.sql
-- Время start_at на момент распределения заказа
select 
	s.start_at,
	a.*
from assignments_hist a
	left join orders_hist s on (a.order_id = s.order_id and a.created_at between s.valid_from and s.valid_to)
where a.order_id = 960209;