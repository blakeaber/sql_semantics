
from sqlparse.sql import Comparison
from sqlparse.tokens import Keyword
from sql_parser import (
    logic as l,
    nodes as n,
    utils as u
)

def is_comparison(token, context):
    return isinstance(token, Comparison)


def is_connection(token, context):
    return context.last_keyword.match(Keyword, ["ON", "HAVING"])


class ComparisonHandler(l.base.BaseHandler):
    def handle(self, token, parent, parser, context):
        for sub_token in u.clean_tokens(token.tokens):
            if u.contains_quotes(sub_token) or u.is_numeric(sub_token):
                node = n.SQLLiteral(sub_token)
                parent.add_child(node)
                u.log_parsing_step('Comparison:Literal added', node, level=1)
            elif l.is_logical_operator(sub_token):
                node = n.SQLOperator(sub_token)
                parent.add_child(node)
                u.log_parsing_step('Comparison:Operator added', node, level=1)
            elif l.is_subquery(sub_token):
                u.log_parsing_step('Entering Comparison:Subquery...', parent, level=1)
                subquery_handler = parser.handler_mapping[l.base.HandlerType.SUBQUERY]
                subquery_context = context.copy(depth=context.depth + 1)
                subquery_handler.handle(sub_token, parent, parser, subquery_context)
                u.log_parsing_step('...Exiting Comparison:Subquery', parent, level=1)
            else:
                node = n.SQLColumn(sub_token)
                parent.add_child(node)
                u.log_parsing_step('Comparison:Column added', node, level=1)


class ConnectionHandler(l.base.BaseHandler):
    def handle(self, token, parent, parser, context):
        if context.last_keyword and context.last_keyword.match(Keyword, ["ON"]):
            comparison_type = n.SQLRelationship
        elif context.last_keyword and context.last_keyword.match(Keyword, ["HAVING"]):
            comparison_type = n.SQLSegment
        else:
            u.log_parsing_step('Connection:{token} Failed!', token, level=2)
            return

        if l.is_comparison(token):
            connection_node = comparison_type(token)
            comparison_handler = l.HANDLER_MAPPING[l.base.HandlerType.COMPARISON]
            comparison_handler.handle(token, connection_node, parser, context.copy())
            parent.add_child(connection_node)
            u.log_parsing_step('Connection added', connection_node, level=1)
        else:
            unknown_handler = l.HANDLER_MAPPING[l.base.HandlerType.UNKNOWN]
            unknown_handler.handle(token, parent, parser, context.copy())
