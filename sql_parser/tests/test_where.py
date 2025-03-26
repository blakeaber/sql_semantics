import pytest
from sqlparse.tokens import Keyword
from sqlparse.sql import Where, Token
from sql_parser.logic.where import is_where, WhereHandler
from sql_parser.context import ParsingContext
from sql_parser.nodes import SQLNode


@pytest.fixture
def setup_context():
    return ParsingContext()


@pytest.fixture
def setup_where_token():
    return Where([Token(Keyword, 'column1 = value')])


@pytest.fixture
def setup_non_where_token():
    return Token(Keyword, 'SELECT')


@pytest.fixture
def setup_parent():
    return SQLNode(Token(Keyword, 'ROOT'))


def test_is_where_with_valid_token(setup_where_token, setup_context):
    assert is_where(setup_where_token, setup_context) is True


def test_is_where_with_invalid_token(setup_non_where_token, setup_context):
    assert is_where(setup_non_where_token, setup_context) is False


def test_where_handler(setup_where_token, setup_parent, setup_context):
    handler = WhereHandler()
    handler.handle(setup_where_token, setup_parent, None, setup_context)

    assert len(setup_parent.children) == 1
    assert isinstance(setup_parent.children[0], SQLNode)
