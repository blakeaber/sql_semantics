
from sqlparse.sql import IdentifierList
from sqlflow.handlers.base import BaseHandler
from sqlflow import utils as u


class IdentifierHandler(BaseHandler):
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
            parser.dispatch_handler(token, parent, context.copy())
