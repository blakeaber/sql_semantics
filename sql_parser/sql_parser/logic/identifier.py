
from sqlparse.sql import IdentifierList
from sql_parser import (
    logic as l,
    nodes as n,
    utils as u
)


class IdentifierHandler(l.base.BaseHandler):
    def handle(self, token, parent, parser, context):
        if isinstance(token, IdentifierList):
            u.log_parsing_step('Entering IdentifierList...', parent, level=2)
            nested_context = context.copy(depth=context.depth + 1)
            for identifier in u.clean_tokens(token.get_identifiers()):
                parser.parse_tokens([identifier], parent, nested_context)
            u.log_parsing_step('...Exited IdentifierList', parent, level=2)

        elif token.is_group:
            u.log_parsing_step('Identifier group entered', parent, level=2)
            nested_context = context.copy(depth=context.depth + 1)
            parser.parse_tokens(token, parent, nested_context)
            u.log_parsing_step('Identifier group exited', parent, level=2)

        else:
            if l.is_subquery(token):
                handler = l.HANDLER_MAPPING[l.base.HandlerType.SUBQUERY]
            elif l.is_table(token, context.last_keyword):
                handler = l.HANDLER_MAPPING[l.base.HandlerType.TABLE]
            elif l.is_column(token, context.last_keyword):
                handler = l.HANDLER_MAPPING[l.base.HandlerType.COLUMN]
            else:
                handler = l.HANDLER_MAPPING[l.base.HandlerType.UNKNOWN]

            handler.handle(token, parent, parser, context)
