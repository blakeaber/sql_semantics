import pytest
from sqlparse.tokens import Keyword
from sqlparse.sql import IdentifierList, Token
from sqlflow.handlers.cte import is_cte, is_cte_name, CTEHandler
from sqlflow.context import ParsingContext
from sqlflow.nodes import SQLNode


@pytest.fixture
def setup_context():
    return ParsingContext()


@pytest.fixture
def setup_cte_token():
    return IdentifierList([Token(Keyword, 'cte_name')])


@pytest.fixture
def setup_non_cte_token():
    return Token(Keyword, 'SELECT')


@pytest.fixture
def setup_parent():
    return SQLNode(Token(Keyword, 'ROOT'))


def test_is_cte_name_with_with(setup_context):
    setup_context.last_keyword = Token(Keyword, 'WITH')
    token = Token(Keyword, 'cte_name')
    assert is_cte_name(token, setup_context) is True


def test_is_cte_name_with_recursive(setup_context):
    setup_context.last_keyword = Token(Keyword, 'RECURSIVE')
    token = Token(Keyword, 'cte_name')
    assert is_cte_name(token, setup_context) is True


def test_is_cte_name_with_other_keyword(setup_context):
    setup_context.last_keyword = Token(Keyword, 'SELECT')
    token = Token(Keyword, 'cte_name')
    assert is_cte_name(token, setup_context) is False


def test_is_cte_with_valid_cte(setup_cte_token, setup_context):
    setup_context.last_keyword = Token(Keyword, 'WITH')
    assert is_cte(setup_cte_token, setup_context) is True


def test_is_cte_with_invalid_cte(setup_non_cte_token, setup_context):
    setup_context.last_keyword = Token(Keyword, 'SELECT')
    assert is_cte(setup_non_cte_token, setup_context) is False


def test_cte_handler(setup_cte_token, setup_parent, setup_context):
    handler = CTEHandler()
    handler.handle(setup_cte_token, setup_parent, None, setup_context)

    assert len(setup_parent.children) == 1
    assert isinstance(setup_parent.children[0], SQLNode)
