import sqlparse
from sql_parser.scratch import SQLTree, clean_tokens
from sqlparse.sql import IdentifierList, Token, TokenList
from sql_parser import (
    node as n,
    scratch as s
)

def test_handle_cte():
    sql_code = """
    WITH simple_cte AS (
        SELECT name, age FROM users
    )
    SELECT * FROM simple_cte;
    """
    parsed = sqlparse.parse(sql_code)
    
    root_token = Token(None, "WITH")
    tree = SQLTree(root_token)
    parent = n.SQLNode(root_token)
    cte_token = TokenList(s.clean_tokens(parsed[0].tokens)[1])

    tree._handle_cte(cte_token, parent=parent, last_keyword=root_token)

    assert len(parent.children) == 2  # Ensure there are two children (CTE and final query)
    assert isinstance(parent.children[0], n.SQLCTE)  # Check that the first child is a CTE

    cte_node = parent.children[0]
    assert len(cte_node.children) > 0  # Ensure it has children

    # Additional assertions
    assert len(cte_node.children) == 2  # Check for the number of columns in the CTE
    assert isinstance(cte_node.children[0], n.SQLColumn)  # Check first child is a column
    assert cte_node.children[0].name == "name"  # Check the name of the first column
    assert isinstance(cte_node.children[1], n.SQLColumn)  # Check second child is a column
    assert cte_node.children[1].name == "age"  # Check the name of the second column
