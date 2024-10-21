-- Этап 1

-- Создаём схему raw_data

CREATE SCHEMA raw_date;

-- Создаём таблицу sales для загрузки сырых данных в этой схеме

CREATE TABLE raw_date.sales (
	id INTEGER,
    auto VARCHAR(50),
    gasoline_consumption NUMERIC(3,1),
    price NUMERIC(9,2),
    date DATE,
    person VARCHAR(50),
    phone VARCHAR(30),
    discount INTEGER,
    brand_origin VARCHAR(50)
);

-- Заполним таблицу sales данными, используя команду COPY в менеджере БД

COPY raw_date.sales (id, auto, gasoline_consumption, price, date, person, phone, discount, brand_origin)
FROM 'C:\Temp\cars.csv'
	DELIMITER ','
	NULL AS 'null'
	CSV HEADER;

-- Создаём схему car_shop

CREATE SCHEMA IF NOT EXISTS car_shop;

-- Создаём, связываем и заполняем данными таблицы

CREATE TABLE car_shop.brand_origin ( 
    origin_id SERIAL PRIMARY KEY, 	
    brand_origin_name VARCHAR(30)       -- для стран происхождения бренда подойдёт VARCHAR(30)
	);



INSERT INTO car_shop.brand_origin (brand_origin_name)
SELECT DISTINCT rds.brand_origin
FROM raw_date.sales rds
WHERE rds.brand_origin IS NOT NULL
ORDER BY brand_origin ASC;




CREATE TABLE car_shop.brands ( 
    brand_id SERIAL PRIMARY KEY, 
    brand_names VARCHAR(50),  -- любые бренды автомобилей влезут в VARCHAR(50)
    brand_origin_id INTEGER REFERENCES car_shop.brand_origin(origin_id)
);




INSERT INTO car_shop.brands (brand_names, brand_origin_id)
SELECT DISTINCT
  SPLIT_PART(auto, ' ', 1),
  csbo.origin_id
FROM raw_date.sales rds
LEFT JOIN car_shop.brand_origin csbo 
      ON rds.brand_origin = csbo.brand_origin_name;



CREATE TABLE car_shop.models ( 
    model_id SERIAL PRIMARY KEY, 
    model_name VARCHAR(50),         -- любые названия моделей автомобилей влезут в VARCHAR(50)
    brand_id INTEGER REFERENCES car_shop.brands (brand_id),
    gasoline_consumption NUMERIC(4, 1)  --потребление бензина, по условию не может быть трёхзначным значением, сделаем 3-х – для возможной продажи грузовых в будущем
);



INSERT INTO car_shop.models (model_name, brand_id, gasoline_consumption )
SELECT DISTINCT 
SPLIT_PART(substr(auto,strpos(auto,' ')+1),',',1),
csb.brand_id,
rds.gasoline_consumption
FROM raw_date.sales AS rds
LEFT JOIN car_shop.brands AS csb 
      ON SPLIT_PART(auto, ' ', 1) = csb.brand_names;



CREATE TABLE car_shop.person ( 
    person_id SERIAL PRIMARY KEY, 
    person_name VARCHAR(50) NOT NULL,     -- для ФИО клиента прекрасно подойдёт VARCHAR(50)
    phone VARCHAR(50)      -- в тел. номерах может присутствовать “+ “код страны, а так же
);	                       -- он может быть не один



INSERT INTO car_shop.person (person_name, phone) 
SELECT DISTINCT rds.person, rds.phone
FROM raw_date.sales AS rds;



CREATE TABLE car_shop.colors ( 
    colors_id SERIAL PRIMARY KEY, 
    colors_name VARCHAR(30)           -- названия цветов прекрасно поместятся в VARCHAR(30)
);



INSERT INTO car_shop.colors (colors_name)
SELECT DISTINCT SPLIT_PART(substr(auto,strpos(auto,' ')+1),',',2)
FROM raw_date.sales;



CREATE TABLE car_shop.sales (
    sales_id SERIAL PRIMARY KEY,
    model_id INTEGER REFERENCES car_shop.models (model_id),
    color_id INTEGER REFERENCES car_shop.colors (colors_id),
    price NUMERIC(9, 2) NOT NULL,        -- цена, по условию не больше семизначной суммы, а так же может содержать только сотые. NUMERIC прекрасно подойдёт.
    date DATE NOT NULL,                  -- дата покупки (без времени) – поэтому DATE
    person_id INTEGER REFERENCES car_shop.person (person_id),
    discount INTEGER         -- размер скидки (число в %), INTEGER
);



INSERT INTO car_shop.sales ( model_id, color_id, price, date, person_id, discount)
SELECT 
csm.model_id,
csc.colors_id,
rds.price,
rds.date,
csp.person_id,
rds.discount
FROM raw_date.sales AS rds
LEFT JOIN car_shop.models AS csm 
      ON SPLIT_PART(substr(auto,strpos(auto,' ')+1),',',1) = csm.model_name
LEFT JOIN car_shop.colors AS csc 
      ON SPLIT_PART(substr(auto,strpos(auto,' ')+1),',',2) = csc.colors_name
LEFT JOIN car_shop.person AS csp 
      ON rds.person = csp.person_name 
      AND rds.phone = csp.phone;

-- Задание 1
-- Требуется написать запрос, который выведет процент моделей машин, у которых нет параметра gasoline_consumption.

SELECT ROUND((SUM(CASE WHEN gasoline_consumption IS NULL THEN 1 ELSE 0 END) * 100.0) / COUNT(*)) AS nulls_percentage_gasoline_consumption
FROM car_shop.models;

-- Задание 2
-- Требуется написать запрос, который покажет название бренда и среднюю цену его автомобилей в разбивке по всем годам с учётом скидки.

SELECT brand_names AS brand_name, EXTRACT(YEAR FROM css.date) AS year, ROUND(AVG(css.price) , 2) AS price_avg
FROM car_shop.brands AS csb
	JOIN car_shop.models AS csm ON csm.brand_id = csb.brand_id
	JOIN car_shop.sales AS css ON css.model_id = csm.model_id
GROUP BY brand_names, EXTRACT(YEAR FROM css.date)
ORDER BY brand_names, EXTRACT(YEAR FROM css.date) ASC;

-- Задание 3
-- Требуется посчитать среднюю цену всех автомобилей с разбивкой по месяцам в 2022 году с учётом скидки.

SELECT EXTRACT(MONTH FROM css.date) AS month, EXTRACT(YEAR FROM css.date) AS year, ROUND(AVG(css.price) , 2) AS price_avg
FROM car_shop.sales AS css
	WHERE EXTRACT(YEAR FROM css.date) = '2022'
GROUP BY EXTRACT(MONTH FROM css.date), EXTRACT(YEAR FROM css.date)
ORDER BY EXTRACT(YEAR FROM css.date), EXTRACT(MONTH FROM css.date) ASC;

-- Задание 4
-- Используя функцию STRING_AGG.
-- Требуется написать запрос, который выведет список купленных машин у каждого пользователя через запятую.

SELECT csp.person_name AS person, STRING_AGG((csb.brand_names || ' ' || csm.model_name), ',' ) AS cars
FROM car_shop.person AS csp 
JOIN car_shop.sales AS css ON csp.person_id = css.person_id
JOIN car_shop.models AS csm ON csm.model_id = css.model_id
JOIN car_shop.brands AS csb ON csb.brand_id = csm.brand_id
GROUP BY csp.person_name
ORDER BY csp.person_name;

-- Задание 5
-- Требуется написать запрос, который вернёт самую большую и самую маленькую цену продажи автомобиля с разбивкой по стране без учёта скидки.

SELECT csbo.brand_origin_name AS brand_origin, ROUND(MAX(price * 100 / (100 - discount))) AS price_max, ROUND(MIN(price * 100 / (100 - discount))) AS price_min
FROM car_shop.brand_origin AS csbo
JOIN car_shop.brands AS csb ON csb.brand_origin_id = csbo.origin_id
JOIN car_shop.models AS csm ON csm.brand_id = csb.brand_id	
JOIN car_shop.sales AS css ON css.model_id = csm.model_id
GROUP BY csbo.brand_origin_name;

-- Задание 6
-- Требуется написать запрос, который покажет количество всех пользователей из США.

SELECT COUNT(csp.person_name) AS persons_from_usa_count
FROM car_shop.person AS csp
WHERE csp.phone LIKE '+1%';
