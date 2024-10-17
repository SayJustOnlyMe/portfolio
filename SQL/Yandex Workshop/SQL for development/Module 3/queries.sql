-- Задание 1:

-- Создание процедуры:

CREATE OR REPLACE PROCEDURE update_employees_rate(rate_change JSON)
LANGUAGE plpgsql
AS $$
    DECLARE
        _new_rate INTEGER;
        _employee_id UUID;
        _rate_change INTEGER;
        _rec JSON;
    BEGIN
    FOR _rec in 
	SELECT JSON_ARRAY_ELEMENTS(rate_change) 
	LOOP
        _employee_id := (_rec::JSON ->> 'employee_id')::UUID;
 
		_rate_change := (_rec::JSON ->> 'rate_change')::INTEGER;
 
		SELECT (rate * ((100 + _rate_change) / 100::NUMERIC))::INTEGER
        INTO _new_rate
        FROM employees
        WHERE employees.id = _employee_id;

        SELECT GREATEST(500, _new_rate)
        INTO _new_rate
        FROM employees
        WHERE employees.id = _employee_id;

        UPDATE employees SET rate = _new_rate 
		WHERE employees.id = _employee_id;
 
	END LOOP;
    END;
$$;

--Пример вызова процедуры:

CALL update_employees_rate(
    '[
        {"employee_id": "181b2307-9e97-4cde-8b9e-b2d9d3d79f09", "rate_change": -5}, 
        {"employee_id": "342eca8b-d6d6-424d-9499-a498cb7cbf89", "rate_change": -10},
	    {"employee_id": "3fad62fa-3035-46a8-a91f-2864d6304cc5", "rate_change": 25}
    ]'::JSON
); 



-- Задание 2:

-- Создание процедуры:

CREATE OR REPLACE PROCEDURE indexing_salary(p INTEGER)
LANGUAGE plpgsql
AS $$
    DECLARE
        _avg_rate NUMERIC;
    BEGIN
        SELECT AVG(rate) 
		INTO _avg_rate
        FROM employees;

    UPDATE employees
	SET rate =
		CASE
		   WHEN rate < _avg_rate
		   THEN ROUND(rate * (100 + (p + 2)) / 100)
		   ELSE ROUND(rate * (100 + p) / 100)
        END;
    END;
$$;

--Пример вызова процедуры:

CALL indexing_salary(10);



-- Задание 3:

-- Создание процедуры:

CREATE OR REPLACE PROCEDURE close_project(p_id UUID)
LANGUAGE plpgsql
AS $$
    DECLARE
	    _is_active BOOLEAN;
        _estimated_time INTEGER;
        _sum_work_hours INTEGER;
        _bonus_time INTEGER;
        _count_project_participants INTEGER;
        _max_bonus INTEGER := 16; 
    BEGIN
       IF (SELECT EXISTS(SELECT * FROM projects WHERE id = p_id)) = FALSE THEN RAISE EXCEPTION 'Проект не найден: id = %', p_id;
       END IF;
        
        _is_active := (SELECT is_active FROM projects WHERE id = p_id);
 
        IF NOT _is_active THEN
            RAISE EXCEPTION 'Проект уже закрыт: id = %', p_id;
        END IF;
 
        SELECT
        	SUM(work_hours),
        	COUNT(DISTINCT employee_id)
        INTO
        	_sum_work_hours,
        	_count_project_participants
     	FROM logs 
     	WHERE project_id = p_id;
 
        UPDATE projects SET is_active = FALSE WHERE id = p_id
        returning estimated_time INTO _estimated_time; 
 
        IF _estimated_time IS NOT NULL AND _estimated_time  > _sum_work_hours THEN 
            _bonus_time := ROUND(0.75 * (_estimated_time - _sum_work_hours) / _count_project_participants);
            IF _bonus_time > _max_bonus THEN
                _bonus_time := _max_bonus;
            END IF;
        END IF;
 
        IF _bonus_time > 0 THEN
            INSERT INTO logs(employee_id, project_id, work_date, work_hours)
            SELECT r.empl_id, p_id, CURRENT_DATE, _bonus_time
            FROM (
                SELECT DISTINCT employee_id AS empl_id
                FROM logs 
                WHERE project_id = p_id
            ) AS r;
         END IF;        
    END;
$$
;

-- Примеры вызова процедуры:

CALL close_project('3dfffa75-7cd9-4426-922c-95046f3d06a0');

CALL close_project('2dfffa75-7cd9-4426-922c-95046f3d06a0');

CALL close_project('4abb5b99-3889-4c20-a575-e65886f266f9');



-- Задание 4:

-- Создание процедуры:

CREATE OR REPLACE PROCEDURE log_work(p_employee UUID, p_project UUID, p_work_date DATE, p_worked_hours INTEGER)
LANGUAGE plpgsql
AS $$
DECLARE
	_is_active BOOLEAN;
	_required_review BOOLEAN;
	_cur_time DATE;
BEGIN
 
	SELECT is_active
	INTO _is_active
	FROM projects
	WHERE id = p_project;
 
    IF NOT _is_active THEN
        RAISE NOTICE 'Проект уже закрыт: id = %', p_project;
        RETURN;
    END IF;
 
    IF p_worked_hours < 1 THEN
        RAISE NOTICE 'Нельзя внести меньше 1 часа';
        RETURN;
    END IF;
 
    IF p_worked_hours > 24 THEN
        RAISE NOTICE 'Нельзя внести больше 24 часов';
        RETURN;
    END IF;
 
	SELECT CURRENT_DATE - 7
	INTO _cur_time;
 
    IF
    	p_worked_hours > 16 THEN _required_review = true;
    ELSEIF 
		p_work_date > CURRENT_DATE THEN _required_review = true;
	ELSEIF 
		p_work_date < _cur_time THEN _required_review = true;
    ELSE 
		_required_review = false;
    END IF;
 
	INSERT INTO logs(employee_id, project_id, work_date, work_hours, required_review)
	VALUES(p_employee, p_project, p_work_date, p_worked_hours, _required_review);
END;
$$; 

-- Примеры вызова процедуры:

CALL log_work(
    '6db4f4a3-239b-4085-a3f9-d1736040b38c',
    '35647af3-2aac-45a0-8d76-94bc250598c2',
    '2023-10-22',
    4                      
); 

CALL log_work(
    'b15bb4c0-1ee1-49a9-bc58-25a014eebe36',
    '4abb5b99-3889-4c20-a575-e65886f266f9',
    '2023-10-22',
    17
); 



-- Задание 5:

-- Создание и наполнение новой таблицы:

CREATE TABLE employee_rate_history (
	id UUID PRIMARY KEY DEFAULT GEN_RANDOM_UUID(),
	employee_id UUID REFERENCES employees (id),
	rate INTEGER,
	from_date DATE
);

INSERT INTO employee_rate_history (
	employee_id,
	rate,
	from_date
)
SELECT
	id,
	rate,
	'2020-12-26'::DATE
FROM employees;

-- Создание триггерной функции и триггера:

CREATE OR REPLACE FUNCTION save_employee_rate_history()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN	
    IF OLD.rate <> NEW.rate OR OLD.rate IS NULL THEN
        INSERT INTO employee_rate_history(employee_id, rate, from_date)
        VALUES (NEW.id, NEW.rate, CURRENT_DATE);
    END IF;
    RETURN NULL;
END;
$$;
 
CREATE OR REPLACE TRIGGER change_employee_rate
AFTER INSERT OR UPDATE ON employees
FOR EACH ROW
EXECUTE FUNCTION save_employee_rate_history();

-- Проверим работу триггера и функции:

INSERT INTO employees (name, email, rate)
VALUES ('Дёмин Евгений Сергеевич', 'zexserg@gmail.com', 550);

SELECT * 
FROM employee_rate_history
WHERE from_date = '2024-09-13';



-- Задание 6:

-- Создание функции:

CREATE OR REPLACE FUNCTION best_project_workers(p_id UUID)
RETURNS TABLE ("Имя сотрудника" TEXT, "Количество часов" INTEGER)
LANGUAGE plpgsql
AS $$
BEGIN
	RETURN QUERY
    SELECT
	    e.name AS "Имя сотрудника",
        CAST(SUM(l.work_hours) AS INTEGER) AS "Количество часов"
    FROM employees AS e
    INNER JOIN logs AS l ON e.id = l.employee_id
    GROUP BY "Имя сотрудника"
    ORDER BY "Количество часов" DESC
    LIMIT 3;
END;
$$;

-- Проверим работу функции:

SELECT * 
FROM best_project_workers('4abb5b99-3889-4c20-a575-e65886f266f9'); 



-- Задание 7:

-- Создание функции:

CREATE OR REPLACE FUNCTION calculate_month_salary(start_date DATE, end_date DATE)
RETURNS table (id_e TEXT, employee TEXT, worked_hours INTEGER, salary INTEGER)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
 
    WITH 
	p1 AS(
      SELECT
        l.employee_id,
        e.name,
        SUM(work_hours) AS sum_work_hours
      FROM logs AS l
      INNER JOIN employees AS e ON l.employee_id = e.id
      WHERE l.work_date BETWEEN $1 AND $2
      AND l.required_review IS FALSE AND l.is_paid IS FALSE
      GROUP BY l.employee_id, e.name
    ),
    p2 AS (
      SELECT
        id,
        rate
      FROM employees
    ),
    p3 AS (
      SELECT
        p1.employee_id::TEXT AS id_e,
        p1.name AS name,
        p1.sum_work_hours::INTEGER AS sum_work_hours,
        (p1.sum_work_hours * p2.rate)::INTEGER AS init_salary,
        p2.rate AS rate
      FROM p1
      INNER JOIN p2 ON p1.employee_id = p2.id
    )
    SELECT
      p3.id_e,
      p3.name,
      p3.sum_work_hours,
      CASE
        WHEN p3.sum_work_hours > 160
          THEN (p3.init_salary + ROUND(((p3.sum_work_hours - 160) * 0.25) * p3.rate))::INTEGER
        ELSE p3.init_salary
      END AS salary
    FROM p3;
END;
$$;

-- Проверим работу функции:

SELECT * 
FROM calculate_month_salary('2023-10-01','2023-10-31'); 
