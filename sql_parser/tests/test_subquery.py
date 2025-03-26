import pytest
from sqlparse.tokens import DML, Keyword
from sqlparse.sql import Parenthesis, Token
from sql_parser.logic.subquery import is_subquery, SubqueryHandler
from sql_parser.context import ParsingContext
from sql_parser.nodes import SQLNode


@pytest.fixture
def setup_context():
    return ParsingContext()


@pytest.fixture
def setup_subquery_token():
    return Parenthesis([Token(DML, 'SELECT'), Token(Keyword, 'FROM')])


@pytest.fixture
def setup_non_subquery_token():
    return Token(Keyword, 'SELECT')


@pytest.fixture
def setup_parent():
    return SQLNode(Token(Keyword, 'ROOT'))


def test_is_subquery_with_valid_token(setup_subquery_token, setup_context):
    assert is_subquery(setup_subquery_token, setup_context) is True


def test_is_subquery_with_invalid_token(setup_non_subquery_token, setup_context):
    assert is_subquery(setup_non_subquery_token, setup_context) is False


def test_subquery_handler(setup_subquery_token, setup_parent, setup_context):
    handler = SubqueryHandler()
    handler.handle(setup_subquery_token, setup_parent, None, setup_context)

    assert len(setup_parent.children) == 1
    assert isinstance(setup_parent.children[0], SQLNode)
