
from sqlparse.sql import Parenthesis
from sqlparse.tokens import DML
from sql_parser.logic.base import BaseHandler
from sql_parser import (
    nodes as n,
    utils as u
)


def is_subquery(token, context):
    return (
        isinstance(token, Parenthesis) and
        any(t.match(DML, "SELECT") for t in token.tokens)
    )


class SubqueryHandler(BaseHandler):
    def handle(self, token, parent, parser, context):
        """
        NOTE: `parser` and `context` attributes intentionally unused 
        here unless handling subqueries
        """
        subquery_node = n.SQLSubquery(token)
        parent.add_child(subquery_node)
        u.log_parsing_step('Subquery added', subquery_node, level=1)

        if subquery_node in context.visited:
            u.log_parsing_step('Cycle detected in Subquery!', subquery_node, level=2)
            return

        context.visited.add(subquery_node)
        
        u.log_parsing_step('Entering Subquery...', subquery_node, level=1)
        subquery_context = context.copy(depth=context.depth + 1)
        parser.parse_tokens(token, subquery_node, subquery_context)
        u.log_parsing_step('...Exiting Subquery', subquery_node, level=1)
