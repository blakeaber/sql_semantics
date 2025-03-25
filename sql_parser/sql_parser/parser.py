
from sqlparse.sql import Identifier, IdentifierList
from sql_parser.context import ParsingContext
from sql_parser import (
    nodes as n, 
    logic as l, 
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

    def dispatch_handler(self, token, parent, context):
        handler_key = self.get_handler_key(token, context)
        handler = l.HANDLER_MAPPING.get(handler_key, l.HANDLER_MAPPING[l.base.HandlerType.UNKNOWN])
        handler.handle(token, parent, self, context)

    def get_handler_key(self, token, context):
        if l.base.is_keyword(token, context):
            return l.base.HandlerType.KEYWORD

        elif l.cte.is_cte(token, context):
            return l.base.HandlerType.CTE

        elif l.is_subquery(token, context):
            return l.base.HandlerType.SUBQUERY

        elif l.is_where(token, context):
            return l.base.HandlerType.WHERE

        elif l.is_connection(token, context):
            return l.base.HandlerType.CONNECTION

        elif l.is_comparison(token, context):
            return l.base.HandlerType.COMPARISON

        elif l.is_column(token, context):
            return l.base.HandlerType.COLUMN

        elif l.is_table(token, context):
            return l.base.HandlerType.TABLE

        elif isinstance(token, IdentifierList) or isinstance(token, Identifier):
            return l.base.HandlerType.IDENTIFER

        else:
            return l.base.HandlerType.UNKNOWN
