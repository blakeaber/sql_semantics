import pytest
from sqlparse.tokens import Keyword, DML
from sql_parser.logic.base import (
    is_whitespace,
    is_keyword,
    is_literal,
    is_logical_operator
)
from sqlparse.sql import Token


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
