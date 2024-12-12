-- Запрос 1:

-- Отобразите все записи из таблицы *company* по компаниям, которые закрылись.

SELECT *
FROM company
WHERE status = 'closed'
GROUP BY id, name;

-- Запрос 2:

-- Отобразите количество привлечённых средств для новостных компаний США. Используйте данные из таблицы *company*. Отсортируйте таблицу по убыванию значений в поле *funding_total*.

SELECT funding_total
FROM company
WHERE category_code = 'news'
AND country_code = 'USA'
ORDER BY funding_total DESC;

-- Запрос 3:

-- Найдите общую сумму сделок по покупке одних компаний другими в долларах. Отберите сделки, которые осуществлялись только за наличные с 2011 по 2013 год включительно.

SELECT SUM(price_amount)
FROM acquisition
WHERE term_code = 'cash'
AND EXTRACT(YEAR FROM acquired_at) IN (2011, 2012, 2013);

-- Запрос 4:

-- Отобразите имя, фамилию и названия аккаунтов людей в поле *network_username*, у которых названия аккаунтов начинаются на 'Silver'.

SELECT first_name,
       last_name,
       network_username
FROM people
WHERE network_username LIKE 'Silver%';

-- Запрос 5:

-- Выведите на экран всю информацию о людях, у которых названия аккаунтов в поле network_username содержат подстроку 'money', а фамилия начинается на 'K'.

SELECT *
FROM people
WHERE network_username LIKE '%money%'
AND last_name LIKE 'K%';

-- Запрос 6:

-- Для каждой страны отобразите общую сумму привлечённых инвестиций, которые получили компании, зарегистрированные в этой стране. 
-- Страну, в которой зарегистрирована компания, можно определить по коду страны. 
-- Отсортируйте данные по убыванию суммы.

SELECT country_code,
       SUM(funding_total) AS fun_total
FROM company
GROUP BY country_code
ORDER BY fun_total DESC;
