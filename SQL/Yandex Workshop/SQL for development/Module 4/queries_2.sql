-- Медленные запросы найдём с помощью модуля pg_stat_statments

CREATE EXTENSION pg_stat_statements; 

-- Найдём идентификатор нашей базы данных с помощью запроса

SELECT oid, datname FROM pg_database;

-- Поочерёдно выполним все 15 предложенных запросов из задания

-- Выполним поиск пяти самых медленных запросов из представленных, добавив идентификатор нашей базы данных

SELECT 
	query, 
    calls,
    total_exec_time,
    min_exec_time, 
    max_exec_time, 
    mean_exec_time,
    rows
FROM pg_stat_statements 
WHERE dbid = 46575 
ORDER BY total_exec_time DESC
LIMIT 5;

-- Получим пять медленных запросов под номерами 9, 15, 7, 8, 2



-- Запрос 8

-- Составим план запроса до оптимизации

EXPLAIN ANALYZE
SELECT *
FROM user_logs
WHERE datetime::date > current_date;

-- Общее время выполнения (actual time = 1005.736.. 1005.737)

/* Самые нагруженные узлы - это последовательное чтение (Seq Scan) таблицы user_logs и её партиций
при наличии индексов по datetime во всех таблицах из за преобразования типа данных datetime в date, происходит полный перебор
где фильтр по итогу отсеивает огромное колличество строк, затрачивая большой ресурс */

-- Предлагаю преобразовывать не datetime к date, а current_date к TIMESTAMP

SELECT *
FROM user_logs
WHERE datetime > current_date::TIMESTAMP;

-- Составим план запроса после оптимизации

EXPLAIN ANALYZE
SELECT *
FROM user_logs
WHERE datetime > current_date::TIMESTAMP;

-- Поиск в нагруженных узлах изменился на Index Scan и благодаря наличию индексов существенно снизил ресурс затрат

-- Общее время выполнения (actual time = 0.037.. 0.037)



-- Запрос 7

-- Составим план запроса до оптимизации

EXPLAIN ANALYZE
SELECT event, datetime
FROM user_logs
WHERE visitor_uuid = 'fd3a4daa-494a-423a-a9d1-03fd4a7f94e0'
ORDER BY 2;

-- Общее время выполнения (actual time = 388.115.. 408.113)

/* Самые нагруженные узлы - это последовательное чтение (Seq Scan) таблицы user_logs и её партиций
при наличии индексов по datetime, отсутствует индекс по visitor_uuid, а так же не затронут столбец event */

-- Для ускорения предлагаю создать индекс по индексируемому столбцу visitor_uuid и дополнительно добавить покрывающим столбец event

-- Для основной таблицы и её партиций

CREATE INDEX visitor_uuid_user_logs_idx
ON user_logs (visitor_uuid)
INCLUDE (event);

CREATE INDEX visitor_uuid_user_logs_y2021q2_idx
ON user_logs_y2021q2 (visitor_uuid)
INCLUDE (event);

CREATE INDEX visitor_uuid_user_logs_y2021q3_idx
ON user_logs_y2021q3 (visitor_uuid)
INCLUDE (event);

CREATE INDEX visitor_uuid_user_logs_y2021q4_idx
ON user_logs_y2021q4 (visitor_uuid)
INCLUDE (event);

-- Составим план запроса после оптимизации

EXPLAIN ANALYZE
SELECT event, datetime
FROM user_logs
WHERE visitor_uuid = 'fd3a4daa-494a-423a-a9d1-03fd4a7f94e0'
ORDER BY 2;

-- Поиск в нагруженных узлах изменился на Index Scan и благодаря наличию индексов существенно снизил ресурс затрат

-- Общее время выполнения (actual time = 0.280.. 0.281)



-- Запрос 9

-- Составим план запроса до оптимизации

EXPLAIN ANALYZE
SELECT count(*)
FROM order_statuses os
    JOIN orders o ON o.order_id = os.order_id
WHERE (SELECT count(*)
	   FROM order_statuses os1
	   WHERE os1.order_id = o.order_id AND os1.status_id = 2) = 0
	AND o.city_id = 1;
	
-- Общее время выполнения (actual time = 37097.284.. 37097.285)

-- Самые нагруженные узлы - это соединение таблиц вложенными циклами (Nested Loop)

-- Предлагаю переписать запрос используя CTE

WITH 
ord AS (
    SELECT * 
    FROM orders
    WHERE city_id = 1
),

st AS (
    SELECT *
    FROM order_statuses
    WHERE status_id = 2
)

SELECT COUNT(*)
FROM ord AS o
LEFT JOIN st ON o.order_id = st.order_id
WHERE st.order_id IS NULL;

-- Составим план запроса после оптимизации

EXPLAIN ANALYZE
WITH 
ord AS (
    SELECT * 
    FROM orders
    WHERE city_id = 1
),

st AS (
    SELECT *
    FROM order_statuses
    WHERE status_id = 2
)

SELECT COUNT(*)
FROM ord AS o
LEFT JOIN st ON o.order_id = st.order_id
WHERE st.order_id IS NULL;

-- Соединенизменилось на Hash Anti Join и снизило ресурсные затраты

-- Общее время выполнения (actual time = 15.818.. 15.820)



-- Запрос 15

-- Составим план запроса до оптимизации

EXPLAIN ANALYZE
SELECT d.name, SUM(count) AS orders_quantity
FROM order_items oi
    JOIN dishes d ON d.object_id = oi.item
WHERE oi.item IN (
	SELECT item
	FROM (SELECT item, SUM(count) AS total_sales
		  FROM order_items oi
		  GROUP BY 1) dishes_sales
	WHERE dishes_sales.total_sales > (
		SELECT SUM(t.total_sales)/ COUNT(*)
		FROM (SELECT item, SUM(count) AS total_sales
			FROM order_items oi
			GROUP BY
				1) t)
)
GROUP BY 1
ORDER BY orders_quantity DESC;

-- Общее время выполнения (actual time = 71.144.. 71.160)

-- Избыточное обращение к таблице order_items

-- Предлагаю вынести этот запрос в СТЕ

WITH
a AS (
SELECT  
    item, 
    SUM(count) AS total_sales  
FROM order_items oi
GROUP BY item
),
b AS (
SELECT
	item
FROM a
WHERE total_sales > (SELECT SUM(total_sales)/ COUNT(*) FROM a)
)

SELECT d.name, SUM(count) AS orders_quantity
FROM order_items oi
JOIN dishes d ON d.object_id = oi.item
WHERE oi.item IN (SELECT item FROM b)
GROUP BY 1
ORDER BY orders_quantity DESC;

-- Составим план запроса после оптимизации

EXPLAIN ANALYZE
WITH
a AS (
SELECT  
    item, 
    SUM(count) AS total_sales  
FROM order_items oi
GROUP BY item
),
b AS (
SELECT
	item
FROM a
WHERE total_sales > (SELECT SUM(total_sales)/ COUNT(*) FROM a)
)

SELECT d.name, SUM(count) AS orders_quantity
FROM order_items oi
JOIN dishes d ON d.object_id = oi.item
WHERE oi.item IN (SELECT item FROM b)
GROUP BY 1
ORDER BY orders_quantity DESC;

-- Общее время выполнения (actual time = 54.841.. 54.855)



-- Запрос 2

-- Составим план запроса до оптимизации

EXPLAIN ANALYZE
SELECT o.order_id, o.order_dt, o.final_cost, s.status_name
FROM order_statuses os
    JOIN orders o ON o.order_id = os.order_id
    JOIN statuses s ON s.status_id = os.status_id
WHERE o.user_id = 'c2885b45-dddd-4df3-b9b3-2cc012df727c'::uuid
	AND os.status_dt IN (
	SELECT max(status_dt)
	FROM order_statuses
	WHERE order_id = o.order_id
    );

-- Общее время выполнения (actual time = 123.910.. 123.913)

-- Самые нагруженные узлы - это фильтрация со списком внутри

-- Предлагаю убрать из сравнения IN и заменить на JOIN

SELECT o.order_id, o.order_dt, o.final_cost, s.status_name
FROM order_statuses os
    JOIN orders o ON o.order_id = os.order_id
    JOIN statuses s ON s.status_id = os.status_id
	JOIN (SELECT MAX(status_dt) AS status, order_id 
          FROM order_statuses GROUP BY order_id) max_st 
        ON max_st.order_id = o.order_id
WHERE o.user_id = 'c2885b45-dddd-4df3-b9b3-2cc012df727c'::uuid
AND os.status_dt = max_st.status;

-- Составим план запроса после оптимизации

EXPLAIN ANALYZE
SELECT o.order_id, o.order_dt, o.final_cost, s.status_name
FROM order_statuses os
    JOIN orders o ON o.order_id = os.order_id
    JOIN statuses s ON s.status_id = os.status_id
	JOIN (SELECT MAX(status_dt) AS status, order_id 
          FROM order_statuses GROUP BY order_id) max_st 
        ON max_st.order_id = o.order_id
WHERE o.user_id = 'c2885b45-dddd-4df3-b9b3-2cc012df727c'::uuid
AND os.status_dt = max_st.status;
	
-- Общее время выполнения (actual time = 51.733.. 55.848)
