
from sqlparse.sql import IdentifierList
from sqlparse.tokens import Keyword, CTE, DML
from sql_parser import (
    logic as l,
    nodes as n,
    utils as u
)


def is_cte_name(last_keyword):
    return (last_keyword.match(CTE, ["WITH"]) or last_keyword.match(Keyword, ["RECURSIVE"]))


def is_cte(token, last_keyword):
    return is_cte_name(last_keyword) and isinstance(token, IdentifierList)


class CTEHandler(l.base.BaseHandler):
    def handle(self, token, parent, parser, context):
        for cte in u.clean_tokens(token.tokens):
            cte_node = n.SQLCTE(cte)
            parent.add_child(cte_node)
            u.log_parsing_step('CTE added', cte_node, level=1)

            if cte_node in context.visited:
                u.log_parsing_step('Cycle detected in CTE!', cte_node, level=2)
                continue

            context.visited.add(cte_node)

            u.log_parsing_step('Entering CTE...', cte_node, level=1)
            cte_context = context.copy(depth=context.depth + 1)
            parser.parse_tokens(cte, cte_node, cte_context)
            u.log_parsing_step('...Exiting CTE', cte_node, level=1)
