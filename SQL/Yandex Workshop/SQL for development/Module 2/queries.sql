-- Этап 1

-- Шаг 1. Cоздать enum cafe.restaurant_type с типом заведения coffee_shop, restaurant, bar, pizzeria.

CREATE TYPE cafe.restaurant_type AS enum
    ('coffee_shop', 'restaurant', 'bar', 'pizzeria');

/* Шаг 2. Создать таблицу cafe.restaurants с информацией о ресторанах. 
В качестве первичного ключа использовать случайно сгенерированный uuid. 
Таблица хранит: restaurant_uuid, название заведения, его локацию в формате PostGIS, тип кафе и меню. */

CREATE TABLE cafe.restaurants (
    restaurant_uuid uuid PRIMARY KEY DEFAULT GEN_RANDOM_UUID(),
	cafe_name varchar(50),
	location geometry(Point, 4326),
	cafe_type cafe.restaurant_type,
	menu jsonb
);



INSERT INTO cafe.restaurants (cafe_name, location, cafe_type, menu)
SELECT DISTINCT
    rds.cafe_name,
	ST_Point(rds.longitude, rds.latitude),
	rds.type::cafe.restaurant_type,
	rdm.menu
FROM raw_data.sales AS rds
LEFT JOIN raw_data.menu AS rdm ON rdm.cafe_name = rds.cafe_name;




CREATE TABLE cafe.managers (
    manager_uuid uuid PRIMARY KEY DEFAULT GEN_RANDOM_UUID(),
	manager_name varchar(50),
	manager_phone varchar(20)
);



INSERT INTO cafe.managers (manager_name, manager_phone)
SELECT DISTINCT
    rds.manager,
	rds.manager_phone
FROM raw_data.sales AS rds;
    



CREATE TABLE cafe.restaurant_manager_work_dates (
    restaurant_uuid uuid REFERENCES cafe.restaurants (restaurant_uuid),
	manager_uuid uuid REFERENCES cafe.managers (manager_uuid),
	start_work_date DATE,
	end_work_date DATE,
	PRIMARY KEY (restaurant_uuid, manager_uuid)
);



INSERT INTO cafe.restaurant_manager_work_dates (restaurant_uuid, manager_uuid, start_work_date, end_work_date)
SELECT
    cr.restaurant_uuid,
	cm.manager_uuid,
	MIN(rds.report_date) AS start_work_date,
	MAX(rds.report_date) AS end_work_date
FROM raw_data.sales AS rds
JOIN cafe.restaurants AS cr ON cr.cafe_name = rds.cafe_name
JOIN cafe.managers AS cm ON cm.manager_name = rds.manager
GROUP BY cr.restaurant_uuid, cm.manager_uuid;



CREATE TABLE cafe.sales (
    date DATE,
	restaurant_uuid uuid REFERENCES cafe.restaurants (restaurant_uuid),
	avg_check NUMERIC(6, 2),
	PRIMARY KEY (date, restaurant_uuid)
);



INSERT INTO cafe.sales (date, restaurant_uuid, avg_check)
SELECT DISTINCT
    rds.report_date,
	cr.restaurant_uuid,
	rds.avg_check
FROM raw_data.sales AS rds
JOIN cafe.restaurants AS cr ON cr.cafe_name = rds.cafe_name;



WITH
a AS (
    SELECT
        restaurant_uuid,
        ROUND(AVG(avg_check), 2) AS avg_check
    FROM cafe.sales
    GROUP BY restaurant_uuid
),
b AS (
    SELECT 
	    cr.restaurant_uuid,
        cr.cafe_name,
        cr.cafe_type,
        ROW_NUMBER() OVER (PARTITION BY cr.cafe_type ORDER BY a.avg_check DESC) AS rung
    FROM cafe.restaurants AS cr
    JOIN a ON a.restaurant_uuid = cr.restaurant_uuid
)
SELECT 
    b.cafe_name AS "Название заведения",
    b.cafe_type AS "Тип заведения",
	a.avg_check AS "Средний чек"
FROM a 
JOIN b ON a.restaurant_uuid = b.restaurant_uuid
WHERE rung <= 3;



CREATE MATERIALIZED VIEW cafe.avg_table AS
WITH
a AS (
    SELECT 
        EXTRACT(YEAR FROM date) AS extract_year,  
    	cafe_name,
    	cafe_type,
    	ROUND(AVG(avg_check), 2) AS avg_thisyear,
    	LAG(ROUND(AVG(avg_check), 2)) OVER (PARTITION BY cafe_name ORDER BY (EXTRACT(YEAR FROM date))) AS avg_lastyear
    FROM cafe.sales AS cs
    JOIN cafe.restaurants AS cr ON cr.restaurant_uuid = cs.restaurant_uuid
    GROUP BY extract_year, cafe_name, cafe_type
    ORDER BY cafe_name, extract_year
)
SELECT 
    	extract_year AS "Год",
    	cafe_name AS "Название заведения",
    	cafe_type AS "Тип заведения",
    	avg_thisyear AS "Средний чек в этом году",
    	avg_lastyear AS "Средний чек в предыдущем году",
	    ROUND(((avg_thisyear - avg_lastyear) / avg_lastyear) * 100, 2) AS "Изменение среднего чека в %"
FROM a
WHERE extract_year != 2023;



WITH
a AS (
    SELECT
        cafe_name,
        COUNT(DISTINCT(manager_uuid)) AS count_manager
    FROM cafe.restaurants AS cr
    JOIN cafe.restaurant_manager_work_dates AS crmwd ON crmwd.restaurant_uuid = cr.restaurant_uuid
    GROUP BY cafe_name
    ORDER BY count_manager DESC
    LIMIT 3
)
SELECT 
    cafe_name AS "Название заведения",
    count_manager AS "Сколько раз менялся менеджер"
FROM a;



SELECT 
    cafe_name AS "Название заведения",
    COUNT(pizza_name) AS "Количество пицц в меню"
FROM (
    SELECT 
        cafe_name,
        (jsonb_each_text(pizza)).key as pizza_name
	FROM (
        SELECT 
            cafe_name,
            menu->'Пицца' as pizza
        FROM cafe.restaurants
        ) AS pizza_1
	) AS pizza_2
GROUP BY cafe_name
ORDER BY "Количество пицц в меню" DESC
LIMIT 3;



WITH
a AS (
SELECT
	cafe_name,
	type_food,
	pizza_name,
	pizza_price,
	ROW_NUMBER() OVER (PARTITION BY cafe_name ORDER BY pizza_price DESC) AS runk
FROM (
SELECT
    cafe_name,
	type_food,
    (jsonb_each_text(pizza)).key AS pizza_name,
    CAST((jsonb_each_text(pizza)).value AS INT) AS pizza_price
FROM (
	SELECT
	    cafe_name,
	    'Пицца' AS type_food,
	    menu->'Пицца' AS pizza
	FROM cafe.restaurants
) AS pizza_1
GROUP BY cafe_name, type_food, pizza_name, pizza_price
ORDER BY cafe_name, pizza_price DESC
	) AS pizza_2
)
SELECT 
	cafe_name AS "Название заведения",
	type_food AS "Тип блюда",
	pizza_name AS "Название пиццы",
	pizza_price AS "Цена"
FROM a
WHERE runk = 1;



SELECT
	cafe_a AS "Название Заведения 1",
	cafe_b AS "Название Заведения 2",
	a_type AS "Тип Заведения",
	ST_Distance( ST_Transform(location_a, 3857), ST_Transform(location_b, 3857)) AS "Расстояние"
FROM (
SELECT
	a.cafe_name AS cafe_a,
	b.cafe_name AS cafe_b,
	a.cafe_type AS a_type,
	b.cafe_type AS b_type,
	a.location AS location_a,
	b.location AS location_b
FROM cafe.restaurants as a
JOIN cafe.restaurants as b ON a.cafe_type = b.cafe_type
WHERE a.cafe_name != b.cafe_name
	) AS dist_1
WHERE a_type = b_type
GROUP BY cafe_a, a_type, cafe_b, b_type, "Расстояние"
ORDER BY "Расстояние" ASC
LIMIT 1;



WITH
a AS (
    SELECT  
        d.district_name AS "Название района", 
        COUNT(*) AS "Количество заведений"
    FROM cafe.restaurants AS r 
    JOIN cafe.districts AS d ON ST_Within(r.location, d.district_geom)
    GROUP BY d.district_name 
    ORDER BY "Количество заведений" ASC
    LIMIT 1
),
b AS (
    SELECT 
	    d.district_name as "Название района", 
        COUNT(*) AS "Количество заведений" 
    FROM cafe.restaurants AS r 
    JOIN cafe.districts AS d ON ST_Within(r.location, d.district_geom)
    GROUP BY d.district_name 
    ORDER BY "Количество заведений" DESC
    LIMIT 1
)
SELECT 
	'Район с самым маленьким количеством заведений' AS "Вычисления",
	* 
FROM a
UNION
SELECT 
	'Район с самым большим количеством заведений' AS "Вычисления",
	* 
FROM b;
