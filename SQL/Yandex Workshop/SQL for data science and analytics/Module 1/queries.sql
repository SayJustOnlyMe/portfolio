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

-- Запрос 7:

-- Составьте таблицу, в которую войдёт дата проведения раунда, а также минимальное и максимальное значения суммы инвестиций, привлечённых в эту дату.
-- Оставьте в итоговой таблице только те записи, в которых минимальное значение суммы инвестиций не равно нулю и не равно максимальному значению.

SELECT funded_at,
       MIN(raised_amount),
       MAX(raised_amount)
FROM funding_round
GROUP BY funded_at
HAVING  MIN(raised_amount) != 0
AND MIN(raised_amount) != MAX(raised_amount);

-- Запрос 8:

-- Создайте поле с категориями: Для фондов, которые инвестируют в 100 и более компаний, назначьте категорию *high_activity*. 
-- Для фондов, которые инвестируют в 20 и более компаний до 100, назначьте категорию *middle_activity*. 
-- Если количество инвестируемых компаний фонда не достигает 20, назначьте категорию *low_activity*. Отобразите все поля таблицы *fund* и новое поле с категориями.

SELECT *,
       CASE
           WHEN invested_companies >= 100 THEN 'high_activity'
           WHEN invested_companies BETWEEN 20 AND 100 THEN 'middle_activity'
           WHEN invested_companies < 20 THEN 'low_activity'
       END
FROM fund;

-- Запрос 9:

-- Для каждой из категорий, назначенных в предыдущем задании, посчитайте округлённое до ближайшего целого числа среднее количество инвестиционных раундов, в которых фонд принимал участие. 
-- Выведите на экран категории и среднее число инвестиционных раундов. Отсортируйте таблицу по возрастанию среднего.

SELECT 
       CASE
           WHEN invested_companies>=100 THEN 'high_activity'
           WHEN invested_companies>=20 THEN 'middle_activity'
           ELSE 'low_activity'
       END AS activity,
       ROUND(AVG(investment_rounds)) AS avg
FROM fund
GROUP BY activity
ORDER BY avg ASC;

-- Запрос 10:

-- Проанализируйте, в каких странах находятся фонды, которые чаще всего инвестируют в стартапы. 
-- Для каждой страны посчитайте минимальное, максимальное и среднее число компаний, в которые инвестировали фонды этой страны, основанные с 2010 по 2012 год включительно. 
-- Исключите страны с фондами, у которых минимальное число компаний, получивших инвестиции, равно нулю. 
-- Выгрузите десять самых активных стран-инвесторов: отсортируйте таблицу по среднему количеству компаний от большего к меньшему. Затем добавьте сортировку по коду страны в лексикографическом порядке.

SELECT 
       country_code,
       MIN(invested_companies) AS min,
       MAX(invested_companies) AS max,
       AVG(invested_companies) AS avg
FROM fund
WHERE EXTRACT(YEAR FROM founded_at) BETWEEN 2010 AND 2012
GROUP BY country_code
HAVING MIN(invested_companies) > 0
ORDER BY avg DESC, country_code ASC
LIMIT 10;

-- Запрос 11:

-- Отобразите имя и фамилию всех сотрудников стартапов. Добавьте поле с названием учебного заведения, которое окончил сотрудник, если эта информация известна.

SELECT p.first_name,
       p.last_name,
       e.instituition
FROM people AS p
LEFT OUTER JOIN education AS e ON p.id = e.person_id;

-- Запрос 12:

-- Для каждой компании найдите количество учебных заведений, которые окончили её сотрудники. Выведите название компании и число уникальных названий учебных заведений. 
-- Составьте топ-5 компаний по количеству университетов.

SELECT c.name,
       COUNT(DISTINCT e.instituition) AS count
FROM company AS c
JOIN people AS p ON c.id = p.company_id
JOIN education AS e ON p.id = e.person_id
GROUP BY c.name
ORDER BY count DESC
LIMIT 5;

-- Запрос 13:

-- Составьте список с уникальными названиями закрытых компаний, для которых первый раунд финансирования оказался последним.

SELECT DISTINCT c.name
FROM company AS c
JOIN funding_round AS fr ON c.id = fr.company_id
WHERE status = 'closed'
AND (is_first_round = 1
AND is_last_round = 1);

-- Запрос 14:

-- Составьте список уникальных номеров сотрудников, которые работают в компаниях, отобранных в предыдущем задании.

SELECT DISTINCT p.id
FROM people AS p
WHERE company_id IN (
                      SELECT DISTINCT c.id
                      FROM company AS c
                      JOIN funding_round AS fr ON c.id = fr.company_id
                      WHERE status = 'closed'
                      AND (is_first_round = 1
                      AND is_last_round = 1)
 );

-- Запрос 15:

-- Составьте таблицу, куда войдут уникальные пары с номерами сотрудников из предыдущей задачи и учебным заведением, которое окончил сотрудник.

SELECT DISTINCT p.id,
                e.instituition
FROM people AS p
JOIN education AS e ON p.id = e.person_id
WHERE company_id IN (
                      SELECT DISTINCT c.id
                      FROM company AS c
                      JOIN funding_round AS fr ON c.id = fr.company_id
                      WHERE status = 'closed'
                      AND (is_first_round = 1
                      AND is_last_round = 1)
 );

-- Запрос 16:

-- Посчитайте количество учебных заведений для каждого сотрудника из предыдущего задания. При подсчёте учитывайте, что некоторые сотрудники могли окончить одно и то же заведение дважды.

SELECT p.id,
       COUNT(e.instituition)
FROM people AS p
JOIN education AS e ON p.id = e.person_id
WHERE p.id IN (
               SELECT DISTINCT p.id
               FROM people AS p
               WHERE company_id IN (
                                     SELECT DISTINCT c.id
                                     FROM company AS c
                                     JOIN funding_round AS fr ON c.id = fr.company_id
                                     WHERE status = 'closed'
                                     AND (is_first_round = 1
                                     AND is_last_round = 1)
 )
)
GROUP BY p.id
;

-- Запрос 17:

-- Дополните предыдущий запрос и выведите среднее число учебных заведений (всех, не только уникальных), которые окончили сотрудники разных компаний. Нужно вывести только одну запись, группировка здесь не понадобится.

SELECT AVG(ct.count)
FROM 
(SELECT p.id,
       COUNT(e.instituition) AS count
FROM people AS p
JOIN education AS e ON p.id = e.person_id
WHERE p.id IN (
               SELECT DISTINCT p.id
               FROM people AS p
               WHERE company_id IN (
                                     SELECT DISTINCT c.id
                                     FROM company AS c
                                     JOIN funding_round AS fr ON c.id = fr.company_id
                                     WHERE status = 'closed'
                                     AND (is_first_round = 1
                                     AND is_last_round = 1)
 )
)
GROUP BY p.id) AS ct
;

-- Запрос 18:

-- Напишите похожий запрос: выведите среднее число учебных заведений (всех, не только уникальных), которые окончили сотрудники Socialnet.

SELECT AVG(si.count)
FROM
(SELECT 
        COUNT(e.instituition) AS count
FROM education AS e
JOIN people AS p ON e.person_id = p.id
JOIN company AS c ON p.company_id = c.id
WHERE name = 'Socialnet'
GROUP BY p.id) AS si;

-- Запрос 19:

-- Составьте таблицу из полей:
-- *name_of_fund* — название фонда;
-- *name_of_company* — название компании;
-- *amount* — сумма инвестиций, которую привлекла компания в раунде.
-- В таблицу войдут данные о компаниях, в истории которых было больше шести важных этапов, а раунды финансирования проходили с 2012 по 2013 год включительно.

WITH
ar AS (
        SELECT f.name as fund_name, 
               c.name as company_name, 
               fr.raised_amount, 
               c.milestones, 
               c.funding_rounds, 
               fr.funded_at
FROM investment AS i
JOIN company AS c ON c.id = i.company_id
JOIN fund AS f ON i.fund_id = f.id
JOIN funding_round AS fr ON i.funding_round_id = fr.id)

SELECT fund_name AS name_of_fund,
       company_name AS name_of_company,
       raised_amount AS amount
FROM ar
WHERE ar.milestones > 6
AND EXTRACT(YEAR FROM funded_at) BETWEEN 2012 and 2013
GROUP BY name_of_fund, name_of_company, amount;

-- Запрос 20:

-- Выгрузите таблицу, в которой будут такие поля:
-- название компании-покупателя;
-- сумма сделки;
-- название компании, которую купили;
-- сумма инвестиций, вложенных в купленную компанию;
-- доля, которая отображает, во сколько раз сумма покупки превысила сумму вложенных в компанию инвестиций, округлённая до ближайшего целого числа.
-- Не учитывайте те сделки, в которых сумма покупки равна нулю. Если сумма инвестиций в компанию равна нулю, исключите такую компанию из таблицы. 
-- Отсортируйте таблицу по сумме сделки от большей к меньшей, а затем по названию купленной компании в лексикографическом порядке. Ограничьте таблицу первыми десятью записями.

SELECT c1.name AS acquiring,
       a.price_amount,
       c2.name AS acquired,
       c2.funding_total,
       ROUND(a.price_amount / c2.funding_total) AS persent
FROM acquisition AS a
INNER JOIN company c1 ON a.acquiring_company_id = c1.id
INNER JOIN company c2 ON a.acquired_company_id = c2.id
WHERE a.price_amount != 0 AND c2.funding_total != 0
ORDER BY a.price_amount DESC, c2.name ASC
LIMIT 10;

-- Запрос 21:

-- Выгрузите таблицу, в которую войдут названия компаний из категории *social*, получившие финансирование с 2010 по 2013 год включительно. 
-- Проверьте, что сумма инвестиций не равна нулю. Выведите также номер месяца, в котором проходил раунд финансирования.

SELECT
       c.name,
       EXTRACT(MONTH FROM fr.funded_at) AS month
FROM company AS c
JOIN funding_round AS fr ON c.id = fr.company_id
WHERE category_code = 'social'
AND fr.raised_amount > 0
AND EXTRACT(YEAR FROM fr.funded_at) IN (2010, 2011, 2012, 2013);

-- Запрос 22:

-- Отберите данные по месяцам с 2010 по 2013 год, когда проходили инвестиционные раунды. 
-- Сгруппируйте данные по номеру месяца и получите таблицу, в которой будут поля:
- номер месяца, в котором проходили раунды;
- количество уникальных названий фондов из США, которые инвестировали в этом месяце;
- количество компаний, купленных за этот месяц;
- общая сумма сделок по покупкам в этом месяце.

WITH
a1 AS (
SELECT EXTRACT(MONTH FROM fr.funded_at) AS month1, 
       COUNT(DISTINCT f.name) AS count_fund
FROM funding_round AS fr
JOIN investment AS i ON i.funding_round_id = fr.id
JOIN fund AS f ON i.fund_id = f.id 
WHERE EXTRACT(YEAR FROM fr.funded_at) IN ('2010','2011','2012','2013')
AND f.country_code = 'USA'
GROUP BY month1
),
a2 AS (
SELECT EXTRACT(MONTH FROM a.acquired_at) AS month2, 
       COUNT(a.acquired_company_id) AS count_acquired, 
       SUM(a.price_amount) AS sum_price_amount
FROM acquisition AS a
WHERE EXTRACT(YEAR FROM a.acquired_at) IN ('2010','2011','2012','2013')
GROUP BY month2
)

SELECT a1.month1, 
       a1.count_fund, 
       a2.count_acquired, 
       a2.sum_price_amount
FROM a1 
INNER JOIN a2 ON a1.month1 = a2.month2;

-- Запрос 23:

-- Составьте сводную таблицу и выведите среднюю сумму инвестиций для стран, в которых есть стартапы, зарегистрированные в 2011, 2012 и 2013 годах. 
-- Данные за каждый год должны быть в отдельном поле. Отсортируйте таблицу по среднему значению инвестиций за 2011 год от большего к меньшему.

WITH
inv_2011 AS (
             SELECT country_code AS code1,
                    AVG(c.funding_total) AS avg1
             FROM company AS c
             WHERE EXTRACT(YEAR FROM c.founded_at) = 2011
             GROUP BY code1
),
inv_2012 AS (
             SELECT country_code AS code2,
                    AVG(c.funding_total) AS avg2
             FROM company AS c
             WHERE EXTRACT(YEAR FROM c.founded_at) = 2012
             GROUP BY code2
),
inv_2013 AS (
             SELECT country_code AS code3,
                    AVG(c.funding_total) AS avg3
             FROM company AS c
             WHERE EXTRACT(YEAR FROM c.founded_at) = 2013
             GROUP BY code3
)

SELECT inv_2011.code1,
       inv_2011.avg1,
       inv_2012.avg2,
       inv_2013.avg3
FROM inv_2011
INNER JOIN inv_2012 ON inv_2011.code1 = inv_2012.code2
INNER JOIN inv_2013 ON inv_2012.code2 = inv_2013.code3
ORDER BY inv_2011.avg1 DESC;
