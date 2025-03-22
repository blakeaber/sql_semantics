import sqlparse
from sql_parser.scratch import SQLTree, clean_tokens
from sqlparse.sql import IdentifierList, Token, TokenList
from sql_parser import (
    node as n,
    scratch as s
    )


def test_handle_cte():
    # AI use this as an example for future test cases
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
    # AI create a test case
    pass
