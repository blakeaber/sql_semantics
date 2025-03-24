WITH RECURSIVE department_salaries AS (
    SELECT 
        d.department_name,
        SUM(e.salary) AS total_salary
    FROM 
        employees e
    JOIN 
        departments d ON e.department_id = d.department_id
    GROUP BY 
        d.department_name
), 
project_counts AS (
    SELECT 
        e.employee_id,
        COUNT(ep.project_id) AS project_count,
        RANK() OVER (PARTITION BY department ORDER BY salary DESC) AS rank 
    FROM 
        employees e
    LEFT JOIN 
        employee_projects ep ON e.employee_id = ep.employee_id
    GROUP BY 
        e.employee_id
),
employee_hierarchy AS (
    SELECT id, name FROM employees WHERE manager_id IS NULL
    UNION ALL
    SELECT e.id, e.name FROM employees e JOIN EmployeeHierarchy eh ON e.manager_id = eh.id
)
SELECT 
    e.employee_id,
    e.name AS employee_name,
    d.department_name,
    ds.total_salary,
    pc.project_count,
    subquery.customer_name,
    subquery.total_spent,
    
    -- CASE Statement: Categorize employees based on project count
    CASE 
        WHEN pc.project_count = 0 THEN 'No Projects'
        WHEN pc.project_count BETWEEN 1 AND 3 THEN 'Few Projects'
        ELSE 'Many Projects'
    END AS project_category,

    -- WINDOW Function: Running total of salaries within each department
    SUM(e.salary) OVER (PARTITION BY e.department_id ORDER BY e.salary DESC) AS running_department_salary

FROM employees e
JOIN department_salaries ds ON e.department_id = (
    SELECT d.department_id 
    FROM departments d 
    WHERE d.department_name = ds.department_name
)
JOIN project_counts pc ON e.employee_id = pc.employee_id
JOIN employee_hierarchy eh ON eh.id = e.employee_id
LEFT JOIN (
    SELECT 
        c.name AS customer_name, 
        SUM(o.amount) AS total_spent 
    FROM customers c 
    JOIN orders o ON c.id = o.customer_id
    GROUP BY c.name
    HAVING SUM(o.amount) > 1000  -- HAVING clause: Filter customers who spent more than $1000
) subquery ON e.customer_id = subquery.customer_name

-- WHERE clause: Only include employees with few projects
WHERE project_category = 'Few Projects' AND e.employee_id IN (SELECT user_id FROM transactions WHERE amount > 100);

-- HAVING clause: Only include employees from departments with a total salary exceeding $500,000
HAVING ds.total_salary > 500000

-- ORDER BY: Sort by highest total spent customers first
ORDER BY subquery.total_spent DESC

-- LIMIT & OFFSET: Slice the results arbitrarily for paging
LIMIT 5 OFFSET 10