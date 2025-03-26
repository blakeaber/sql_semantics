
from sqlparse.tokens import Keyword
from sql_parser.logic.base import HandlerType, BaseHandler
from sql_parser.logic.cte import is_cte_name
from sql_parser.logic.subquery import is_subquery
from sql_parser import (
    nodes as n, 
    utils as u
)


def is_table(token, context):
    if not context.last_keyword:
        return False
    return (
        context.last_keyword.match(Keyword, ["FROM", "UPDATE", "INTO"]) or 
        is_cte_name(token, context) or 
        ("JOIN" in context.last_keyword.value)
    )


class TableHandler(BaseHandler):
    def handle(self, token, parent, parser, context):
        """
        NOTE: `parser` and `context` attributes intentionally unused 
        here unless handling subqueries
        """
        if token.is_group and any(is_subquery(t, context) for t in token.tokens):
            subquery_context = context.copy(depth=context.depth + 1)
            parser.assign_handler(token, parent, subquery_context, HandlerType.SUBQUERY)

        else:
            table_node = n.SQLTable(token)
            parent.add_child(table_node)
            u.log_parsing_step('Table added', table_node, level=1)
