import pytest
from sqlparse.tokens import Keyword
from sqlparse.sql import Comparison, Token
from sql_parser.logic.connection import is_comparison, is_connection, ComparisonHandler, ConnectionHandler
from sql_parser.context import ParsingContext
from sql_parser.nodes import SQLNode


@pytest.fixture
def setup_context():
    return ParsingContext()


@pytest.fixture
def setup_comparison_token():
    return Comparison('column1 = column2')


@pytest.fixture
def setup_connection_token():
    return Token(Keyword, 'ON')


@pytest.fixture
def setup_parent():
    return SQLNode(Token(Keyword, 'ROOT'))


def test_is_comparison(setup_comparison_token, setup_context):
    assert is_comparison(setup_comparison_token, setup_context) is True


def test_is_not_comparison(setup_connection_token, setup_context):
    assert is_comparison(setup_connection_token, setup_context) is False


def test_is_connection_with_on(setup_connection_token, setup_context):
    setup_context.last_keyword = setup_connection_token
    assert is_connection(setup_connection_token, setup_context) is True


def test_is_connection_with_having(setup_context):
    setup_context.last_keyword = Token(Keyword, 'HAVING')
    assert is_connection(Token(Keyword, 'HAVING'), setup_context) is True


def test_is_connection_with_other_keyword(setup_context):
    setup_context.last_keyword = Token(Keyword, 'SELECT')
    assert is_connection(Token(Keyword, 'SELECT'), setup_context) is False


def test_comparison_handler(setup_comparison_token, setup_parent, setup_context):
    handler = ComparisonHandler()
    handler.handle(setup_comparison_token, setup_parent, None, setup_context)

    assert len(setup_parent.children) == 1
    assert isinstance(setup_parent.children[0], SQLNode)


def test_connection_handler_with_on(setup_connection_token, setup_parent, setup_context):
    setup_context.last_keyword = setup_connection_token
    handler = ConnectionHandler()
    handler.handle(setup_connection_token, setup_parent, None, setup_context)

    assert len(setup_parent.children) == 1
    assert isinstance(setup_parent.children[0], SQLNode)
