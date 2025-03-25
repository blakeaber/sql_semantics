
from sqlparse.sql import Where
from sql_parser.logic.base import BaseHandler, HandlerType, is_keyword, is_logical_operator
from sql_parser.logic.connection import is_comparison
from sql_parser import (
    nodes as n, 
    utils as u
)


def is_where(token, context):
    return isinstance(token, Where)


class WhereHandler(BaseHandler):
    def handle(self, token, parent, parser, context):
        for sub_token in u.clean_tokens(token.tokens):
            if is_comparison(sub_token, context):
                comparison_node = n.SQLSegment(sub_token)
                parent.add_child(comparison_node)
                comparison_context = context.copy(depth=context.depth + 1)
                parser.assign_handler(sub_token, comparison_node, comparison_context, HandlerType.COMPARISON)
                u.log_parsing_step('Where:Segment added', comparison_node, level=1)

            elif is_keyword(sub_token, context):
                parser.assign_handler(sub_token, parent, context.copy(), HandlerType.KEYWORD)

            elif is_logical_operator(sub_token, context):
                parser.assign_handler(sub_token, parent, context.copy(), HandlerType.OPERATOR)

            else:
                parser.assign_handler(sub_token, parent, context.copy(), HandlerType.UNKNOWN)
