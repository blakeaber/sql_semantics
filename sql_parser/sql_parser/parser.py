
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
        handler = l.HANDLER_MAPPING.get(handler_key, l.HANDLER_MAPPING['other'])
        handler.handle(token, parent, self, context)

    def get_handler_key(self, token, context):
        """This is where the CONTROL FLOW should be located..."""
        if l.is_subquery(token):
            return 'subquery'
        elif l.is_table(token, context.last_keyword):
            return 'table'
        # other conditions...
        else:
            return 'other'
