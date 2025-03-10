
# example_queries.py
EXAMPLE_QUERIES = [
    # 1️⃣ Basic SELECT with WHERE clause
    """
    SELECT name, email FROM users WHERE status = 'active' AND age > 21;
    """,

    # 2️⃣ CASE Statement
    """
    SELECT 
        name, 
        CASE 
            WHEN age > 18 THEN 'Adult'
            ELSE 'Minor'
        END AS age_group 
    FROM users;
    """,

    # 3️⃣ Aggregations with GROUP BY and HAVING
    """
    SELECT department, COUNT(*) AS employee_count 
    FROM employees 
    GROUP BY department 
    HAVING COUNT(*) > 10;
    """,

    # 4️⃣ Window Function
    """
    SELECT name, salary, RANK() OVER (PARTITION BY department ORDER BY salary DESC) AS rank 
    FROM employees;
    """,

    # 5️⃣ JOIN with Conditions
    """
    SELECT u.name, o.total_amount 
    FROM users u 
    JOIN orders o ON u.id = o.user_id
    WHERE o.status = 'Completed';
    """,

    # 6️⃣ Recursive CTE
    """
    WITH RECURSIVE EmployeeHierarchy AS (
        SELECT id, name FROM employees WHERE manager_id IS NULL
        UNION ALL
        SELECT e.id, e.name FROM employees e JOIN EmployeeHierarchy eh ON e.manager_id = eh.id
    )
    SELECT * FROM EmployeeHierarchy;
    """,

    # 7️⃣ Subquery in WHERE clause
    """
    SELECT name FROM users 
    WHERE id IN (SELECT user_id FROM transactions WHERE amount > 100);
    """,

    # 8️⃣ LIMIT and OFFSET
    """
    SELECT * FROM products ORDER BY price DESC LIMIT 5 OFFSET 10;
    """,

    # 9️⃣ Complex Nested Query
    """
    SELECT customer_name, total_spent FROM (
        SELECT c.name AS customer_name, SUM(o.amount) AS total_spent 
        FROM customers c 
        JOIN orders o ON c.id = o.customer_id
        GROUP BY c.name
    ) subquery WHERE total_spent > 1000;
    """,

    # 🔟 Multi-Join Query with Filtering
    """
    SELECT c.name, COUNT(o.id) AS order_count, SUM(o.amount) AS total_spent
    FROM customers c
    JOIN orders o ON c.id = o.customer_id
    JOIN order_items oi ON o.id = oi.order_id
    WHERE o.status = 'Completed'
    GROUP BY c.name;
    """,

    # 🔟 CTE
    """
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
    """,

    # 🔟 Multi-JOIN
    """
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
    """
]

if __name__ == "__main__":
    print("Example Queries Loaded. Modify and use them for manual testing.")
