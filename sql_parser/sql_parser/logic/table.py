
from sqlparse.tokens import Keyword
from sql_parser import (
    logic as l, 
    nodes as n, 
    utils as u
)


def is_table(token, last_keyword):
    if not last_keyword:
        return False
    return (
        last_keyword.match(Keyword, ["FROM", "UPDATE", "INTO"]) or 
        l.cte.is_cte_name(last_keyword) or 
        ("JOIN" in last_keyword.value)
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
