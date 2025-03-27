
from sqlparse.sql import Identifier, IdentifierList
from sqlparse.tokens import Keyword, DML
from sqlflow.handlers.base import HandlerType, BaseHandler
from sqlflow.handlers.feature import is_feature
from sqlflow import (
    nodes as n,
    utils as u
)


def is_column(token, context):
    return (
        context.last_keyword.match(DML, ["SELECT"]) or 
        context.last_keyword.match(Keyword, ["GROUP BY", "ORDER BY"])
    )


class ColumnHandler(BaseHandler):
    def handle(self, token, parent, parser, context):
        if is_feature(token, context):
            parser.assign_handler(token, parent, context.copy(), HandlerType.FEATURE)

        elif isinstance(token, IdentifierList):
            for sub_token in u.clean_tokens(token.tokens):
                col_node = n.SQLColumn(sub_token)
                parent.add_child(col_node)
                u.log_parsing_step('Column:IdentifierList added', col_node, level=1)
        elif isinstance(token, Identifier):
            col_node = n.SQLColumn(token)
            parent.add_child(col_node)
            u.log_parsing_step('Column:Identifier added', col_node, level=1)
        else:
            col_node = n.SQLColumn(token)
            parent.add_child(col_node)
            u.log_parsing_step('Column:Unknown added', col_node, level=1)
