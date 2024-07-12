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
