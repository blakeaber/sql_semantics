import pytest
from sql_parser.scratch import SQLTree, clean_tokens
from sqlparse.sql import IdentifierList, Token
from sql_parser import node as n

def test_handle_cte():
    root_token = Token(None, "WITH")
    tree = SQLTree(root_token)
    parent = n.SQLNode(root_token)
    cte_token = IdentifierList([Token(None, "SELECT * FROM table")])
    last_keyword = Token(None, "WITH")

    tree._handle_cte(cte_token, parent, last_keyword)

    assert len(parent.children) == 1
    assert isinstance(parent.children[0], n.SQLCTE)

# Remove the AI comment
