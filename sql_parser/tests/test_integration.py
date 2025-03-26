import pytest
from sqlparse.sql import Token
from sqlparse.tokens import Keyword
from sql_parser.parser import SQLTree
from sql_parser.context import ParsingContext
from sql_parser.nodes import SQLNode
from sql_parser.logic.column import is_column
from sql_parser.logic.where import is_where
from sql_parser.logic.connection import is_connection


@pytest.fixture
def setup_context():
    return ParsingContext()


@pytest.fixture
def setup_tree():
    return SQLTree(Token(Keyword, 'SELECT'))


@pytest.fixture
def setup_parent():
    return SQLNode(Token(Keyword, 'ROOT'))


def test_integration_select_query(setup_tree, setup_parent, setup_context):
    sql_query = "SELECT column1, column2 FROM my_table WHERE column1 = 'value'"
    tokens = setup_tree.parse_tokens(sql_query, setup_parent, setup_context)

    assert len(setup_parent.children) > 0
    assert any(is_column(child.token, setup_context) for child in setup_parent.children)
    assert any(is_where(child.token, setup_context) for child in setup_parent.children)


def test_integration_join_query(setup_tree, setup_parent, setup_context):
    sql_query = "SELECT a.column1, b.column2 FROM table_a a JOIN table_b b ON a.id = b.id"
    tokens = setup_tree.parse_tokens(sql_query, setup_parent, setup_context)

    assert len(setup_parent.children) > 0
    assert any(is_connection(child.token, setup_context) for child in setup_parent.children)


def test_integration_cte_query(setup_tree, setup_parent, setup_context):
    sql_query = "WITH my_cte AS (SELECT * FROM my_table) SELECT * FROM my_cte"
    tokens = setup_tree.parse_tokens(sql_query, setup_parent, setup_context)

    assert len(setup_parent.children) > 0
    assert any(is_column(child.token, setup_context) for child in setup_parent.children)
