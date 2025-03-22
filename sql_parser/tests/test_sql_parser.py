
import pytest
import sqlparse
from sql_parser import node as n
from sql_parser.sql_parser.parser_old import parse_sql_to_tree
from sql_parser.extractor import SQLTripleExtractor
from sql_parser.utils import (
    parse_where_conditions,
    parse_case_statement,
    parse_window_function,
    parse_cte_recursive,
    parse_having_clause,
    parse_order_limit_offset
)
from sqlparse.sql import Where, Case, Function
from sqlparse.tokens import Keyword, DML


# --------- Test WHERE Clause Parsing ---------
def test_parse_where_conditions():
    sql = "SELECT * FROM users WHERE age > 21 AND status = 'active';"
    parsed = sqlparse.parse(sql)[0]
    where_clause = next((token for token in parsed.tokens if isinstance(token, Where)), None)

    assert where_clause is not None, "WHERE clause not found"

    root_node = parse_sql_to_tree(sql)
    parse_where_conditions(where_clause, root_node)

    assert len(root_node.children) > 0
    where_node = root_node.children[0]
    assert where_node.name == "WHERE"
    assert any(child.name.startswith("Comparison") for child in where_node.children)


# --------- Test CASE Statement Parsing ---------
def test_parse_case_statement():
    sql = """
    SELECT name, 
        CASE 
            WHEN age > 18 THEN 'Adult'
            ELSE 'Minor'
        END AS age_group
    FROM users;
    """
    parsed = sqlparse.parse(sql)[0]
    case_stmt = next((token for token in parsed.tokens if isinstance(token, Case)), None)

    assert case_stmt is not None, "CASE statement not found"

    root_node = parse_sql_to_tree(sql)
    parse_case_statement(case_stmt, root_node)

    assert len(root_node.children) > 0
    case_node = root_node.children[0]
    assert case_node.name == "CASE"
    assert any(child.name.startswith("WHEN") for child in case_node.children)


# --------- Test Window Function Parsing ---------
def test_parse_window_function():
    sql = "SELECT name, RANK() OVER (PARTITION BY department ORDER BY salary DESC) AS rank FROM employees;"
    parsed = sqlparse.parse(sql)[0]
    function_stmt = next((token for token in parsed.tokens if isinstance(token, Function)), None)

    assert function_stmt is not None, "Window function not found"

    root_node = parse_sql_to_tree(sql)
    parse_window_function(function_stmt, root_node)

    assert len(root_node.children) > 0
    window_node = root_node.children[0]
    assert window_node.name == "RANK"
    assert any(child.name == "PARTITION BY" for child in window_node.children)


# --------- Test Recursive CTE Parsing ---------
def test_parse_cte_recursive():
    sql = """
    WITH RECURSIVE EmployeeHierarchy AS (
        SELECT id, name FROM employees WHERE manager_id IS NULL
        UNION ALL
        SELECT e.id, e.name FROM employees e JOIN EmployeeHierarchy eh ON e.manager_id = eh.id
    )
    SELECT * FROM EmployeeHierarchy;
    """
    parsed = sqlparse.parse(sql)[0]
    cte_stmt = next((token for token in parsed.tokens if token.match(Keyword, "RECURSIVE")), None)

    assert cte_stmt is not None, "Recursive CTE not found"

    root_node = parse_sql_to_tree(sql)
    parse_cte_recursive(cte_stmt, root_node)

    assert len(root_node.children) > 0
    cte_node = root_node.children[0]
    assert cte_node.name == "CTE"
    assert any(child.name == "RECURSIVE" for child in cte_node.children)


# --------- Test HAVING Clause Parsing ---------
def test_parse_having_clause():
    sql = "SELECT department, COUNT(*) FROM employees GROUP BY department HAVING COUNT(*) > 5;"
    parsed = sqlparse.parse(sql)[0]
    having_clause = next((token for token in parsed.tokens if token.match(Keyword, "HAVING")), None)

    assert having_clause is not None, "HAVING clause not found"

    root_node = parse_sql_to_tree(sql)
    parse_having_clause(having_clause, root_node)

    assert len(root_node.children) > 0
    having_node = root_node.children[0]
    assert having_node.name == "HAVING"
    assert any(child.name.startswith("Comparison") for child in having_node.children)


# --------- Test ORDER BY, LIMIT, OFFSET Parsing ---------
def test_parse_order_limit_offset():
    sql = "SELECT * FROM employees ORDER BY salary DESC LIMIT 10 OFFSET 5;"
    parsed = sqlparse.parse(sql)[0]

    root_node = parse_sql_to_tree(sql)
    parse_order_limit_offset(parsed, root_node)

    assert len(root_node.children) > 0
    assert any(child.name.startswith("ORDER BY") for child in root_node.children)
    assert any(child.name.startswith("LIMIT") for child in root_node.children)
    assert any(child.name.startswith("OFFSET") for child in root_node.children)


# --------- Test Triple Extraction with Unique Identifiers ---------
def test_triple_extraction():
    sql = """
    SELECT u.id, u.name, COUNT(o.id) AS order_count 
    FROM users u 
    JOIN orders o ON u.id = o.user_id
    WHERE u.status = 'active'
    GROUP BY u.id, u.name;
    """
    tree = parse_sql_to_tree(sql)
    extractor = SQLTripleExtractor()
    triples = extractor.extract_triples_from_tree(tree)

    assert len(triples) > 0, "No triples extracted"
    assert any("Query - has - Table" in " - ".join(triple) for triple in triples)
    assert any("Feature - has - Function" in " - ".join(triple) for triple in triples)
    assert any("Comparison - has - Value" in " - ".join(triple) for triple in triples)


def test_cli_parsing():
    """Test that CLI correctly reads and processes a SQL file."""
    import subprocess
    result = subprocess.run(["python", "scripts/run_parser.py", "tests/example.sql"], capture_output=True, text=True)
    assert "Parsing complete" in result.stdout, "CLI parsing failed."


def test_logging_output(caplog):
    """Ensure logs are correctly formatted during SQL parsing."""
    from sql_parser.utils import log_parsing_step
    caplog.clear()
    
    node = n.SQLNode("test_column", "Column")
    log_parsing_step("Processing Test Column", node)
    
    assert "Processing Test Column" in caplog.text, "Logging output missing expected text."


def test_invalid_sql():
    """Ensure invalid SQL queries are handled gracefully."""
    from sql_parser.sql_parser.parser_old import SQLParser
    
    parser = SQLParser()
    result = parser.parse_sql("INVALID SQL SYNTAX")
    
    assert result is None, "Parser did not handle invalid SQL correctly."


def test_uid_deduplication():
    """Ensure multiple queries referencing the same column generate the same UID."""
    from sql_parser.node import SQLColumn
    from sql_parser.utils import generate_uid

    uid1 = generate_uid("Column", "users.id")
    uid2 = generate_uid("Column", "users.id")

    assert uid1 == uid2, "UIDs should be the same for identical columns."



# --------- Run Tests ---------
if __name__ == "__main__":
    pytest.main()
