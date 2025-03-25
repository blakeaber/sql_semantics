
from sqlparse.sql import Comparison
from sqlparse.tokens import Keyword
from sql_parser.logic.base import HandlerType, BaseHandler, is_literal, is_logical_operator
from sql_parser.logic.subquery import is_subquery
from sql_parser import (
    nodes as n,
    utils as u
)

def is_comparison(token, context):
    return isinstance(token, Comparison)


def is_connection(token, context):
    return context.last_keyword.match(Keyword, ["ON", "HAVING"])


class ComparisonHandler(BaseHandler):
    def handle(self, token, parent, parser, context):
        for sub_token in u.clean_tokens(token.tokens):
            if is_literal(sub_token, context):
                parser.assign_handler(sub_token, parent, context.copy(), HandlerType.LITERAL)
            elif is_logical_operator(sub_token, context):
                parser.assign_handler(sub_token, parent, context.copy(), HandlerType.OPERATOR)
            elif is_subquery(sub_token, context):
                u.log_parsing_step('Entering Comparison:Subquery...', parent, level=1)
                subquery_context = context.copy(depth=context.depth + 1)
                parser.assign_handler(sub_token, parent, subquery_context, HandlerType.SUBQUERY)
                u.log_parsing_step('...Exiting Comparison:Subquery', parent, level=1)
            else:
                parser.assign_handler(sub_token, parent, context.copy(), HandlerType.COLUMN)


class ConnectionHandler(BaseHandler):
    def handle(self, token, parent, parser, context):
        if context.last_keyword and context.last_keyword.match(Keyword, ["ON"]):
            comparison_type = n.SQLRelationship
        elif context.last_keyword and context.last_keyword.match(Keyword, ["HAVING"]):
            comparison_type = n.SQLSegment
        else:
            u.log_parsing_step('Connection:{token} Failed!', token, level=2)
            return
        
        connection_node = comparison_type(token)

        if is_comparison(token, context):
            parent.add_child(connection_node)
            connection_context = context.copy(depth=context.depth + 1)
            parser.assign_handler(token, connection_node, connection_context, HandlerType.COMPARISON)
        else:
            parent.add_child(connection_node)
            parser.assign_handler(token, connection_node, connection_context, HandlerType.UNKNOWN)
