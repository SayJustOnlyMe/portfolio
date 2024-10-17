-- Задание 1

/* При вставке данных, чем больше индексов на таблице orders - тем сложнее вставка.
При анализе запросов к таблице orders видим, что чаще всего в фильтрации выборки фигурируют
столбцы order_id, user_id, order_dt, собственно индексы с ними оставим, а остальные удалим */

DROP INDEX
    orders_city_id_idx,
    orders_device_type_city_id_idx,
    orders_device_type_idx,
    orders_discount_idx,
    orders_final_cost_idx,
    orders_total_cost_idx,
	orders_total_final_cost_discount_idx;

/*  Также следует изменить способ добавления нового id для таблицы order, избавимся от агрегирующей функции 
в вставке */

-- Подгатавливаем столбец к трансформации в serial, создадим последовательность

CREATE SEQUENCE orders_order_id_seq OWNED BY orders.order_id;

-- Устанавливаем автоинкремент для столбца по последовательности

ALTER TABLE orders ALTER COLUMN order_id SET DEFAULT nextval('orders_order_id_seq');

-- Настраиваем начальное значение последовательности

SELECT setval('orders_order_id_seq', COALESCE(MAX(order_id), 0) + 1) FROM orders;

-- Перепишем запрос на добавление, т.к. столбец order_id теперь имеет автоинкремент, значит его можно убрать

INSERT INTO orders
    (order_dt, user_id, device_type, city_id, total_cost, discount, final_cost)
VALUES (current_timestamp,'329551a1-215d-43e6-baee-322f2467272d','Mobile', 1, 1000.00, null, 1000.00);



-- Задание 2

-- Начнём с того, что уберём из запроса приведение к типам данных, для этого изменим тип данных в самой таблице

ALTER TABLE users ALTER COLUMN user_id TYPE uuid USING user_id::text::uuid;
ALTER TABLE users ALTER COLUMN first_name TYPE text;
ALTER TABLE users ALTER COLUMN last_name TYPE text;
ALTER TABLE users ALTER COLUMN first_name TYPE text;
ALTER TABLE users ALTER COLUMN city_id TYPE int;
ALTER TABLE users ALTER COLUMN gender TYPE text;
ALTER TABLE users ALTER COLUMN birth_date TYPE text;

-- Далее создадим индекс на столбец city_id

CREATE INDEX users_city_id_idx ON users (city_id);

-- Выполним запрос используя CTE

WITH 
birth_day AS (
    SELECT
		date_part('day', to_date('31-12-2023', 'dd-mm-yyyy')) AS value
),
birth_month AS (
	SELECT 
	    date_part('month', to_date('31-12-2023', 'dd-mm-yyyy')) AS value
)
        SELECT 
	        user_id, 
	        first_name, 
	        last_name,
            city_id,
	        gender
        FROM users
        JOIN birth_day ON date_part('day', to_date(users.birth_date, 'yyyy-mm-dd')) = birth_day.value
        JOIN birth_month ON date_part('month', to_date(users.birth_date, 'yyyy-mm-dd')) = birth_month.value
        WHERE city_id = 4;



-- Задание 3

/* В процедуре add_payment происходит вставки в три таблицы.
В таблице sales нет новой информации, все эти данные есть в связке таблиц payments и order_statuses,
поэтому предлагаю её удалить */

DROP TABLE IF EXISTS sales CASCADE;

-- Изменим процедуру, убрав из неё вставку в таблицу sales

CREATE OR REPLACE PROCEDURE add_payment(p_order_id bigint, p_sum_payment numeric)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO order_statuses (order_id, status_id, status_dt)
    VALUES (p_order_id, 2, statement_timestamp());
    
    INSERT INTO payments (payment_id, order_id, payment_sum)
    VALUES (nextval('payments_payment_id_sq'), p_order_id, p_sum_payment);
END;
$$;  

-- В таблице sales использовалась последовательность - её тоже удалим

DROP SEQUENCE IF EXISTS sales_sale_id_sq CASCADE;



-- Задание 4

-- Создадим дочернии таблицы, которые унаследую всё от таблицы user_logs - укажем ограничения по кварталам

CREATE TABLE user_logs_y2021q1 (
    CHECK ( log_date >= DATE '2021-01-01' AND log_date < DATE '2021-04-01' )
) INHERITS (user_logs);
CREATE TABLE user_logs_y2021q2 (
    CHECK ( log_date >= DATE '2021-04-01' AND log_date < DATE '2021-07-01' )
) INHERITS (user_logs);
CREATE TABLE user_logs_y2021q3 (
    CHECK ( log_date >= DATE '2021-07-01' AND log_date < DATE '2021-10-01' )
) INHERITS (user_logs);
CREATE TABLE user_logs_y2021q4 (
    CHECK ( log_date >= DATE '2021-10-01' AND log_date < DATE '2022-01-01' )
) INHERITS (user_logs);

-- Создадим индекс по столбцу log_date для наших дочерних таблиц

CREATE INDEX user_logs_y2021q1_log_date ON user_logs_y2021q1 (log_date);
CREATE INDEX user_logs_y2021q2_log_date ON user_logs_y2021q2 (log_date);
CREATE INDEX user_logs_y2021q3_log_date ON user_logs_y2021q3 (log_date);
CREATE INDEX user_logs_y2021q4_log_date ON user_logs_y2021q4 (log_date);

-- Создадим триггерную функцию, которая будет определять в какую из дочерних таблиц добавить запись

CREATE OR REPLACE FUNCTION user_logs_insert_trigger()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF ( NEW.log_date >= DATE '2021-01-01' AND
         NEW.log_date < DATE '2021-04-01' ) THEN
        INSERT INTO user_logs_y2021q1 VALUES (NEW.*);
    ELSIF ( NEW.log_date >= DATE '2021-04-01' AND
            NEW.log_date < DATE '2021-07-01' ) THEN
        INSERT INTO user_logs_y2021q2 VALUES (NEW.*);
    ELSIF ( NEW.log_date >= DATE '2021-07-01' AND
            NEW.log_date < DATE '2021-10-01' ) THEN
        INSERT INTO user_logs_y2021q3 VALUES (NEW.*);
    ELSIF ( NEW.log_date >= DATE '2021-10-01' AND
            NEW.log_date < DATE '2022-01-01' ) THEN
        INSERT INTO user_logs_y2021q4 VALUES (NEW.*);
    ELSE
        RAISE EXCEPTION
  'Date out of range.  Fix the user_logs_insert_trigger() function!';
    END IF;
    RETURN NULL;
END;
$$;

-- После функции создадим вызывающий её триггер

CREATE TRIGGER insert_user_logs_trigger
    BEFORE INSERT ON user_logs
    FOR EACH ROW EXECUTE FUNCTION user_logs_insert_trigger();



-- Задание 5

-- Для сбора и хранения данных создадим материализованное представление

CREATE MATERIALIZED VIEW market_otchet AS
WITH 
d AS (
    SELECT 
	    object_id,
        spicy,
        fish,
        meat
    FROM dishes
),    
ord_it AS (
    SELECT order_id,
        SUM(d.spicy * oi.count) AS sum_s, 
        SUM(d.fish*oi.count) AS sum_f, 
        SUM(d.meat*oi.count) AS sum_m,
        SUM(oi.count) AS sum_total
    FROM order_items AS oi
    INNER JOIN d ON oi.item = d.object_id
    GROUP BY order_id
),
ors AS (
    SELECT 
	ord_it.sum_s,
    ord_it.sum_f, 
    ord_it.sum_m, 
    ord_it.sum_total,
    ord.user_id, 
    ord.order_dt::date
    FROM orders AS ord
    INNER JOIN ord_it ON ord_it.order_id = ord.order_id
)
 
SELECT 
	ors.order_dt AS day,
    CASE
	WHEN DATE_PART('year', AGE(ors.order_dt::date, u.birth_date::date)) >= 0 AND DATE_PART('year', AGE(ors.order_dt::date, u.birth_date::date)) < 21
	THEN '0-20'
	WHEN DATE_PART('year', AGE(ors.order_dt::date, u.birth_date::date)) >= 20 AND DATE_PART('year', AGE(ors.order_dt::date, u.birth_date::date)) < 31
	THEN '20-30'
	WHEN DATE_PART('year', AGE(ors.order_dt::date, u.birth_date::date)) >= 30 AND DATE_PART('year', AGE(ors.order_dt::date, u.birth_date::date)) < 41
	THEN '30-40'
	WHEN DATE_PART('year', AGE(ors.order_dt::date, u.birth_date::date)) >= 40
	THEN '40-100'
END age,
    SUM(sum_s) / SUM(sum_total) AS spicy,
	SUM(sum_f) / SUM(sum_total) AS fish,
	SUM(sum_m) / SUM(sum_total) AS meat
FROM users AS u
INNER JOIN ors ON ors.user_id::text = u.user_id::text
GROUP BY day, age
ORDER BY day;
