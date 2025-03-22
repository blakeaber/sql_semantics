import sqlparse
from sql_parser.scratch import SQLTree, clean_tokens
from sqlparse.sql import IdentifierList, Token
from sql_parser import node as n

def sql_test():
    # AI this code can be used for CTE test case
    snippet = """
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
    ), 
    project_counts AS (
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
    """
    parsed = sqlparse.parse(snippet)
    return parsed[0]

def test_handle_cte():
    # AI! update this test case by ingesting the `testing.sql` code
    sql_statement = sql_test()
    root_token = Token(None, "WITH")
    tree = SQLTree(root_token)
    parent = n.SQLNode(root_token)
    cte_token = IdentifierList([Token(None, sql_statement)])
    last_keyword = Token(None, "WITH")

    tree._handle_cte(cte_token, parent, last_keyword)

    assert len(parent.children) == 1
    assert isinstance(parent.children[0], n.SQLCTE)
