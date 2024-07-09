-- DDL: Create tables
CREATE TABLE employees (
    employee_id INT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    department_id INT,
    salary DECIMAL(10, 2)
);

CREATE TABLE departments (
    department_id INT PRIMARY KEY,
    department_name VARCHAR(50)
);

CREATE TABLE projects (
    project_id INT PRIMARY KEY,
    project_name VARCHAR(100),
    start_date DATE,
    end_date DATE
);

CREATE TABLE employee_projects (
    employee_id INT,
    project_id INT,
    assignment_date DATE,
    PRIMARY KEY (employee_id, project_id)
);

-- CTE: Common Table Expressions
WITH department_salaries AS (
    SELECT 
        d.department_name,
        SUM(e.salary) AS total_salary
    FROM 
        employees e
    JOIN 
        departments d ON e.department_id = d.department_id
    GROUP BY 
        d.department_name
), project_counts AS (
    SELECT 
        e.employee_id,
        COUNT(ep.project_id) AS project_count
    FROM 
        employees e
    LEFT JOIN 
        employee_projects ep ON e.employee_id = ep.employee_id
    GROUP BY 
        e.employee_id
)

-- DML: Insert and Select Statements
INSERT INTO employee_projects (employee_id, project_id, assignment_date)
VALUES (1, 1, '2023-01-01'),
       (2, 1, '2023-01-01'),
       (1, 2, '2023-02-01'),
       (3, 3, '2023-03-01');

SELECT 
    e.first_name,
    e.last_name,
    d.department_name,
    ps.total_salary,
    pc.project_count
FROM 
    employees e
JOIN 
    departments d ON e.department_id = d.department_id
LEFT JOIN 
    department_salaries ps ON d.department_name = ps.department_name
LEFT JOIN 
    project_counts pc ON e.employee_id = pc.employee_id
WHERE 
    e.salary > 50000
ORDER BY 
    e.last_name;