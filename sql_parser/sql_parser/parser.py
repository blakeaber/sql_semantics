
from sqlparse.sql import Identifier, IdentifierList
from sql_parser.context import ParsingContext
from sql_parser.registry import HANDLER_MAPPING, HandlerType
from sql_parser.logic.base import is_keyword
from sql_parser.logic.cte import is_cte
from sql_parser.logic.connection import is_comparison, is_connection
from sql_parser.logic.feature import is_feature
from sql_parser.logic.column import is_column
from sql_parser.logic.table import is_table
from sql_parser.logic.where import is_where
from sql_parser.logic.subquery import is_subquery
from sql_parser import (
    nodes as n,
    utils as u
)


class SQLTree:
    def __init__(self, root_token):
        self.root = n.SQLQuery(root_token)

    def parse_tokens(self, tokens, parent, context=None):
        context = context or ParsingContext()
        for token, next_token in u.peekable(u.clean_tokens(tokens)):
            self.dispatch_handler(token, parent, context)
        self.dispatch_handler(next_token, parent, context)

    def assign_handler(self, token, parent, context, handler_type: HandlerType = HandlerType.UNKNOWN):
        assigned_handler = HANDLER_MAPPING[handler_type]
        assigned_handler.handle(token, parent, self, context)

    def dispatch_handler(self, token, parent, context):
        """Assigns a Handler based on the pre-defined, sequential control flow"""
        handler_key = self.get_handler_key(token, context)
        handler = HANDLER_MAPPING.get(handler_key, HandlerType.UNKNOWN)
        handler.handle(token, parent, self, context)

    def get_handler_key(self, token, context):
        if is_keyword(token, context):
            return HandlerType.KEYWORD

        elif is_cte(token, context):
            return HandlerType.CTE

        elif is_subquery(token, context):
            return HandlerType.SUBQUERY

        elif is_where(token, context):
            return HandlerType.WHERE

        elif is_connection(token, context):
            return HandlerType.CONNECTION

        elif is_comparison(token, context):
            return HandlerType.COMPARISON

        elif is_feature(token, context):
            return HandlerType.FEATURE

        elif is_column(token, context):
            return HandlerType.COLUMN

        elif is_table(token, context):
            return HandlerType.TABLE

        elif isinstance(token, IdentifierList) or isinstance(token, Identifier):
            return HandlerType.IDENTIFIER

        else:
            return HandlerType.UNKNOWN
