import pytest
from sqlparse.tokens import Keyword
from sql_parser.nodes import (
    SQLNode,
    SQLKeyword,
    SQLLiteral,
    SQLOperator,
    SQLColumn,
    SQLFeature,
    SQLTable,
    SQLRelationship,
    SQLSegment,
    SQLSubquery,
    SQLCTE,
    SQLQuery
)
from sql_parser.sqlparse import Token


@pytest.fixture
def setup_token():
    return Token(Keyword, 'SELECT')


@pytest.fixture
def setup_node(setup_token):
    return SQLNode(setup_token)


def test_sql_node_initialization(setup_node):
    assert setup_node.token == setup_node.token
    assert setup_node.type == 'SQLNode'
    assert setup_node.level == 0
    assert setup_node.children == []
    assert setup_node.name == setup_node.display_value
    assert setup_node.alias is None


def test_sql_node_add_child(setup_node):
    child_node = SQLNode(Token(Keyword, 'child'))
    setup_node.add_child(child_node)

    assert len(setup_node.children) == 1
    assert setup_node.children[0] == child_node
    assert child_node.level == 1


def test_sql_keyword_initialization(setup_token):
    keyword_node = SQLKeyword(setup_token)
    assert keyword_node.type == 'SQLKeyword'


def test_sql_literal_initialization():
    literal_node = SQLLiteral(Token(Keyword, 'literal_value'))
    assert literal_node.type == 'SQLLiteral'


def test_sql_operator_initialization():
    operator_node = SQLOperator(Token(Keyword, 'AND'))
    assert operator_node.type == 'SQLOperator'


def test_sql_column_initialization():
    column_node = SQLColumn(Token(Keyword, 'column_name'))
    assert column_node.type == 'SQLColumn'


def test_sql_feature_initialization():
    feature_node = SQLFeature(Token(Keyword, 'my_function()'))
    assert feature_node.type == 'SQLFeature'


def test_sql_table_initialization():
    table_node = SQLTable(Token(Keyword, 'my_table'))
    assert table_node.type == 'SQLTable'


def test_sql_relationship_initialization():
    relationship_node = SQLRelationship(Token(Keyword, 'JOIN'))
    assert relationship_node.type == 'SQLRelationship'


def test_sql_segment_initialization():
    segment_node = SQLSegment(Token(Keyword, 'WHERE'))
    assert segment_node.type == 'SQLSegment'


def test_sql_subquery_initialization():
    subquery_node = SQLSubquery(Token(Keyword, 'SELECT'))
    assert subquery_node.type == 'SQLSubquery'


def test_sql_cte_initialization():
    cte_node = SQLCTE(Token(Keyword, 'WITH'))
    assert cte_node.type == 'SQLCTE'


def test_sql_query_initialization():
    query_node = SQLQuery(Token(Keyword, 'SELECT'))
    assert query_node.type == 'SQLQuery'
