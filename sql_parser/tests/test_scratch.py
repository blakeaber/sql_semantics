import sqlparse
from sql_parser.scratch import SQLTree, clean_tokens
from sqlparse.sql import IdentifierList, Token, TokenList
from sql_parser import (
    node as n,
    scratch as s
    )


def test_handle_cte():
    # AI? suggest a simpler SQL query that could be hard-coded inside this function to test it?
    with open('sql_parser/scripts/testing.sql', 'r') as file:
        sql_code = file.read()
        parsed = sqlparse.parse(sql_code)
    
    root_token = Token(None, "WITH")
    tree = SQLTree(root_token)
    parent = n.SQLNode(root_token)
    cte_token = TokenList(s.clean_tokens(parsed[0].tokens)[1])

    tree._handle_cte(cte_token, parent=parent, last_keyword=root_token)

    assert len(parent.children) == 2
    assert isinstance(parent.children[0], n.SQLCTE)

    cte_node = parent.children[0]
    assert len(cte_node.children) > 0  # Ensure it has children



def test_parse_tokens():
    sql_code = """
    SELECT name, age FROM users WHERE age > 21;
    """
    parsed = sqlparse.parse(sql_code)
    root_token = Token(None, "SELECT")
    tree = SQLTree(root_token)
    parent = n.SQLNode(root_token)

    tree.parse_tokens(parsed[0].tokens, parent)

    print(parent.children)

    assert len(parent.children) > 0  # Ensure there are children
    assert isinstance(parent.children[0], n.SQLKeyword)  # Check for keyword
    assert isinstance(parent.children[1], n.SQLColumn)  # Check for table reference
    assert isinstance(parent.children[4], n.SQLTable)  # Check for column reference

