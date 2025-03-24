import sqlparse
from sql_parser.parser import SQLTree
from sqlparse.sql import Token, TokenList
from sqlparse.tokens import CTE, DML
from sql_parser import node as n, utils as u

def test_handle_cte():
    sql_code = """
    WITH simple_cte AS (
        SELECT name, age FROM users
    )
    SELECT * FROM simple_cte;
    """
    statement = sqlparse.parse(sql_code)[0]
    tree = SQLTree(statement)

    root_token = Token(CTE, "WITH")
    parent = n.SQLNode(root_token)
    cte_token = TokenList(u.clean_tokens(statement.tokens)[1:2])

    tree._handle_cte(cte_token, parent=parent, last_keyword=root_token)

    assert len(parent.children) == 1  # Ensure there is one child (CTE)
    assert isinstance(parent.children[0], n.SQLCTE)  # Check that the first child is a CTE

    cte_node = parent.children[0]
    assert len(cte_node.children) > 0  # Ensure it has children

    # Additional assertions
    assert len(cte_node.children) == 3  # Check for the number of columns in the CTE
    assert isinstance(cte_node.children[0], n.SQLTable)  # Check first child is a table
    assert isinstance(cte_node.children[2], n.SQLSubquery)  # Check second child is a column

def test_parse_tokens():
    sql_code = """
    SELECT name, age FROM users WHERE age > 21;
    """
    parsed = sqlparse.parse(sql_code)
    root_token = Token(DML, "SELECT")
    tree = SQLTree(root_token)
    parent = n.SQLNode(root_token)

    tree.parse_tokens(parsed[0].tokens, parent)
    print(parent.children)

    assert len(parent.children) > 0  # Ensure there are children
    assert isinstance(parent.children[0], n.SQLKeyword)  # Check for keyword
    assert isinstance(parent.children[2], n.SQLColumn)  # Check for table reference
    assert isinstance(parent.children[4], n.SQLTable)  # Check for column reference
