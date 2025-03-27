
from enum import Enum, auto
from abc import ABC, abstractmethod

from sqlparse.sql import Comment
from sqlparse.tokens import Token, Keyword, CTE, DML, Punctuation, Operator
from sqlflow import (
    nodes as n,
    utils as u
)


class HandlerType(Enum):
    COLUMN = auto()
    COMPARISON = auto()
    CONNECTION = auto()
    CTE = auto()
    FEATURE = auto()
    IDENTIFIER = auto()
    KEYWORD = auto()
    LITERAL = auto()
    OPERATOR = auto()
    SUBQUERY = auto()
    TABLE = auto()
    WHERE = auto()
    UNKNOWN = auto()


def is_whitespace(token, context):
    return token.is_whitespace or isinstance(token, Comment) or (token.ttype == Punctuation)


def is_keyword(token, context):
    return (token.ttype in (CTE, DML, Keyword)) and (not is_logical_operator(token, context))


def is_literal(token, context):
    return token.ttype in (Token.Literal.String.Single, Token.Literal.Number.Integer, Token.Literal.Number.Float)


def is_logical_operator(token, context):
    return (token.ttype == Operator)


class BaseHandler(ABC):
    @abstractmethod
    def handle(self, token, parent, parser, context):
        pass


class KeywordHandler(BaseHandler):
    def handle(self, token, parent, parser, context):
        """
        NOTE: `parser` and `context` attributes intentionally unused 
        here unless handling subqueries
        """
        keyword_node = n.SQLKeyword(token)
        parent.add_child(keyword_node, context)
        u.log_parsing_step('Keyword added', keyword_node, level=1)
        context.last_keyword = token


class OperatorHandler(BaseHandler):
    def handle(self, token, parent, parser, context):
        """
        NOTE: `parser` and `context` attributes intentionally unused 
        here unless handling subqueries
        """
        operator_node = n.SQLOperator(token)
        parent.add_child(operator_node, context)
        u.log_parsing_step('Operator added!', operator_node, level=2)


class LiteralHandler(BaseHandler):
    def handle(self, token, parent, parser, context):
        """
        NOTE: `parser` and `context` attributes intentionally unused 
        here unless handling subqueries
        """
        literal_node = n.SQLLiteral(token)
        parent.add_child(literal_node, context)
        u.log_parsing_step('Literal added!', literal_node, level=2)


class UnknownHandler(BaseHandler):
    def handle(self, token, parent, parser, context):
        """
        NOTE: `parser` and `context` attributes intentionally unused 
        here unless handling subqueries
        """
        unknown_node = n.SQLNode(token)
        parent.add_child(unknown_node, context)
        u.log_parsing_step('Unknown Node added!', unknown_node, level=2)
