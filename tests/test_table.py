import pytest
from sqlparse.tokens import Keyword
from sqlparse.sql import Token
from sqlflow.handlers.table import is_table, TableHandler
from sqlflow.context import ParsingContext
from sqlflow.nodes import SQLNode


@pytest.fixture
def setup_context():
    return ParsingContext()


@pytest.fixture
def setup_table_token():
    return Token(Keyword, 'my_table')


@pytest.fixture
def setup_non_table_token():
    return Token(Keyword, 'SELECT')


@pytest.fixture
def setup_parent():
    return SQLNode(Token(Keyword, 'ROOT'))


def test_is_table_with_from(setup_context):
    setup_context.last_keyword = Token(Keyword, 'FROM')
    assert is_table(setup_table_token, setup_context) is True


def test_is_table_with_update(setup_context):
    setup_context.last_keyword = Token(Keyword, 'UPDATE')
    assert is_table(setup_table_token, setup_context) is True


def test_is_table_with_insert(setup_context):
    setup_context.last_keyword = Token(Keyword, 'INTO')
    assert is_table(setup_table_token, setup_context) is True


def test_is_table_with_other_keyword(setup_context):
    setup_context.last_keyword = Token(Keyword, 'SELECT')
    assert is_table(setup_non_table_token, setup_context) is False


def test_table_handler(setup_table_token, setup_parent, setup_context):
    handler = TableHandler()
    handler.handle(setup_table_token, setup_parent, None, setup_context)

    assert len(setup_parent.children) == 1
    assert isinstance(setup_parent.children[0], SQLNode)
