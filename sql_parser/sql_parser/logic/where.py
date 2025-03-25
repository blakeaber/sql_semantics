
from sqlparse.sql import Where
from sql_parser import (
    logic as l, 
    nodes as n, 
    utils as u
)


def is_where(token, context):
    return isinstance(token, Where)


class WhereHandler(l.base.BaseHandler):
    def handle(self, token, parent, parser, context):
        for sub_token in u.clean_tokens(token.tokens):
            if l.is_comparison(sub_token):
                comparison_node = n.SQLSegment(sub_token)
                comparison_context = context.copy(depth=context.depth + 1)
                comparison_handler = l.HANDLER_MAPPING[l.base.HandlerType.COMPARISON]
                comparison_handler.handle(sub_token, comparison_node, parser, comparison_context)
                parent.add_child(comparison_node)
                u.log_parsing_step('Where:Segment added', comparison_node, level=1)

            elif l.is_keyword(sub_token):
                keyword_handler = l.HANDLER_MAPPING[l.base.HandlerType.KEYWORD]
                keyword_handler.handle(sub_token, parent, parser, context.copy())

            elif l.is_logical_operator(sub_token):
                operator_handler = l.HANDLER_MAPPING[l.base.HandlerType.OPERATOR]
                operator_handler.handle(sub_token, parent, parser, context.copy())

            else:
                unknown_handler = l.HANDLER_MAPPING[l.base.HandlerType.UNKNOWN]
                unknown_handler.handle(sub_token, parent, parser, context.copy())
