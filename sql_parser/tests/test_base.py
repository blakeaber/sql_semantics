import pytest
from sqlparse.tokens import Keyword, DML
from sqlparse.sql import Token
from sql_parser.logic.base import (
    is_whitespace,
    is_keyword,
    is_literal,
    is_logical_operator,
    HandlerType,
    ParsingContext
)
from sql_parser.registry import HANDLER_MAPPING
from sql_parser.nodes import SQLNode


def test_is_whitespace():
    token = Token(Keyword, ' ')
    assert is_whitespace(token, None) is True
    token = Token(Keyword, 'SELECT')
    assert is_whitespace(token, None) is False


def test_is_keyword():
    token = Token(Keyword, 'SELECT')
    assert is_keyword(token, None) is True
    token = Token(DML, 'INSERT')
    assert is_keyword(token, None) is True
    token = Token(Keyword, 'AND')
    assert is_keyword(token, None) is False


def test_is_literal():
    token = Token(Token.Literal.String.Single, "'test'")
    assert is_literal(token, None) is True
    token = Token(Token.Literal.Number.Integer, '123')
    assert is_literal(token, None) is True
    token = Token(Keyword, 'SELECT')
    assert is_literal(token, None) is False


def test_is_logical_operator():
    token = Token(Token.Operator, 'AND')
    assert is_logical_operator(token, None) is True
    token = Token(Keyword, 'SELECT')
    assert is_logical_operator(token, None) is False


@pytest.fixture
def setup_context():
    return ParsingContext()


@pytest.fixture
def setup_token():
    return Token(Keyword, 'SELECT')


@pytest.fixture
def setup_parent():
    return SQLNode(Token(Keyword, 'ROOT'))


def test_keyword_handler(setup_token, setup_parent, setup_context):
    handler = HANDLER_MAPPING[HandlerType.KEYWORD]
    handler.handle(setup_token, setup_parent, None, setup_context)

    assert len(setup_parent.children) == 1
    assert isinstance(setup_parent.children[0], SQLNode)
    assert setup_context.last_keyword == setup_token


def test_operator_handler(setup_token, setup_parent):
    handler = HANDLER_MAPPING[HandlerType.OPERATOR]
    handler.handle(setup_token, setup_parent, None, None)

    assert len(setup_parent.children) == 1
    assert isinstance(setup_parent.children[0], SQLNode)


def test_literal_handler(setup_token, setup_parent):
    handler = HANDLER_MAPPING[HandlerType.LITERAL]
    handler.handle(setup_token, setup_parent, None, None)

    assert len(setup_parent.children) == 1
    assert isinstance(setup_parent.children[0], SQLNode)


def test_unknown_handler(setup_token, setup_parent):
    handler = HANDLER_MAPPING[HandlerType.UNKNOWN]
    handler.handle(setup_token, setup_parent, None, None)

    assert len(setup_parent.children) == 1
    assert isinstance(setup_parent.children[0], SQLNode)
