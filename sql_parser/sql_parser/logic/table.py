
from sqlparse.tokens import Keyword
from sql_parser import (
    logic as l, 
    nodes as n, 
    utils as u
)


def is_table(token, context):
    if not context.last_keyword:
        return False
    return (
        context.last_keyword.match(Keyword, ["FROM", "UPDATE", "INTO"]) or 
        l.cte.is_cte_name(token, context.last_keyword) or 
        ("JOIN" in context.last_keyword.value)
    )


class TableHandler(l.base.BaseHandler):
    def handle(self, token, parent, parser, context):
        """
        NOTE: `parser` and `context` attributes intentionally unused 
        here unless handling subqueries
        """
        if token.is_group and any(l.is_subquery(t) for t in token.tokens):
            subquery_handler = l.HANDLER_MAPPING[l.base.HandlerType.SUBQUERY]
            subquery_handler.handle(token, parent, parser, context)
        else:
            table_node = n.SQLTable(token)
            parent.add_child(table_node)
            u.log_parsing_step('Table added', table_node, level=1)
