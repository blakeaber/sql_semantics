
from enum import Enum, auto
from abc import ABC, abstractmethod

from sqlparse.sql import Comment
from sqlparse.tokens import Keyword, CTE, DML, Punctuation, Comparison as Operator
from sql_parser import (
    logic as l,
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
    OPERATOR = auto()
    SUBQUERY = auto()
    TABLE = auto()
    WHERE = auto()
    UNKNOWN = auto()


def is_whitespace(token, context):
    return token.is_whitespace or isinstance(token, Comment) or (token.ttype == Punctuation)


def is_keyword(token, context):
    return (token.ttype in (CTE, DML, Keyword)) and (not l.base.is_logical_operator(token))


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
        parent.add_child(keyword_node)
        u.log_parsing_step('Keyword added', keyword_node, level=1)
        context.last_keyword = token


class OperatorHandler(BaseHandler):
    def handle(self, token, parent, parser, context):
        """
        NOTE: `parser` and `context` attributes intentionally unused 
        here unless handling subqueries
        """
        operator_node = n.SQLOperator(token)
        parent.add_child(operator_node)
        u.log_parsing_step('Operator added!', operator_node, level=2)


class UnknownHandler(BaseHandler):
    def handle(self, token, parent, parser, context):
        """
        NOTE: `parser` and `context` attributes intentionally unused 
        here unless handling subqueries
        """
        unknown_node = n.SQLNode(token)
        parent.add_child(unknown_node)
        u.log_parsing_step('Unknown Node added!', unknown_node, level=2)
