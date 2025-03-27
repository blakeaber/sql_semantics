import pytest
from sqlparse.tokens import Keyword, DML
from sqlparse.sql import Identifier, IdentifierList, Token
from sqlflow.handlers.column import is_column, ColumnHandler
from sqlflow.context import ParsingContext
from sqlflow.nodes import SQLNode


@pytest.fixture
def setup_context():
    return ParsingContext()


@pytest.fixture
def setup_token_identifier():
    return Token(None, 'column_name')


@pytest.fixture
def setup_token_identifier_list():
    return IdentifierList([Token(None, 'column1'), Token(None, 'column2')])


@pytest.fixture
def setup_parent():
    return SQLNode(Token(Keyword, 'ROOT'))


def test_is_column_with_select(setup_context):
    setup_context.last_keyword = Token(DML, 'SELECT')
    token = Token(Keyword, 'column_name')
    assert is_column(token, setup_context) is True


def test_is_column_with_group_by(setup_context):
    setup_context.last_keyword = Token(Keyword, 'GROUP BY')
    token = Token(Keyword, 'column_name')
    assert is_column(token, setup_context) is True


def test_is_column_with_other_keyword(setup_context):
    setup_context.last_keyword = Token(Keyword, 'INSERT')
    token = Token(Keyword, 'column_name')
    assert is_column(token, setup_context) is False


def test_column_handler_with_identifier(setup_token_identifier, setup_parent):
    handler = ColumnHandler()
    handler.handle(setup_token_identifier, setup_parent, None, None)

    assert len(setup_parent.children) == 1
    assert isinstance(setup_parent.children[0], SQLNode)


def test_column_handler_with_identifier_list(setup_token_identifier_list, setup_parent):
    handler = ColumnHandler()
    handler.handle(setup_token_identifier_list, setup_parent, None, None)

    assert len(setup_parent.children) == 2
    assert all(isinstance(child, SQLNode) for child in setup_parent.children)
