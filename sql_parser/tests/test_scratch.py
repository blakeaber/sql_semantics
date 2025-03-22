import sqlparse
from sql_parser.scratch import SQLTree, clean_tokens
from sqlparse.sql import IdentifierList, Token, TokenList
from sqlparse.tokens import CTE
from sql_parser import node as n

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
    cte_token = TokenList(clean_tokens(statement.tokens)[1:2])

    tree._handle_cte(cte_token, parent=parent, last_keyword=root_token)

    assert len(parent.children) == 1  # Ensure there is one child (CTE)
    assert isinstance(parent.children[0], n.SQLCTE)  # Check that the first child is a CTE

    cte_node = parent.children[0]
    print(cte_node.children)

    assert len(cte_node.children) > 0  # Ensure it has children

    # Additional assertions
    assert len(cte_node.children) == 3  # Check for the number of columns in the CTE
    assert isinstance(cte_node.children[0], n.SQLTable)  # Check first child is a table
    assert isinstance(cte_node.children[2], n.SQLSubquery)  # Check second child is a column
