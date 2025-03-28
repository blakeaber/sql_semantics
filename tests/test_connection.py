import pytest
from sqlparse.tokens import Keyword, Name, Operator
from sqlparse.sql import Comparison, Token
from sqlflow.handlers.connection import is_comparison, is_connection, ComparisonHandler, ConnectionHandler
from sqlflow.context import ParsingContext
from sqlflow.parser import SQLTree
from sqlflow.nodes import SQLNode


@pytest.fixture
def setup_context():
    return ParsingContext()


@pytest.fixture
def setup_comparison_token():
    return Comparison([
        Token(Name, 'column1'),
        Token(Operator, '='),
        Token(Name, 'column2')
    ])


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
    root = Token(Keyword, 'ROOT')
    parser = SQLTree(root)
    handler = ComparisonHandler()
    handler.handle(setup_comparison_token, setup_parent, parser, setup_context)

    assert len(setup_parent.children) == 3
    assert isinstance(setup_parent.children[0], SQLNode)


def test_connection_handler_with_on(setup_connection_token, setup_parent, setup_context):
    setup_context.last_keyword = setup_connection_token
    root = Token(Keyword, 'ROOT')
    parser = SQLTree(root)
    handler = ConnectionHandler()
    handler.handle(setup_connection_token, setup_parent, parser, setup_context)

    assert len(setup_parent.children) == 1
    assert isinstance(setup_parent.children[0], SQLNode)
