
from sqlparse.sql import Identifier, Function
from sql_parser.logic.base import BaseHandler
from sql_parser import (
    nodes as n,
    utils as u
)


def is_function(token, context):
    return (
        isinstance(token, Identifier) and 
        any(
            (t.is_keyword or isinstance(t, Function)) 
            for t in u.clean_tokens(token.tokens)
        )
    )

def is_window(token, context):
    return isinstance(token, Function) and "OVER" in token.value.upper()


class FeatureHandler(BaseHandler):
    def handle(self, token, parent, parser, context):
        """
        NOTE: `parser` and `context` attributes intentionally unused 
        here unless handling subqueries
        """
        feature_node = n.SQLFeature(token)
        parent.add_child(feature_node)
        u.log_parsing_step('Feature Node added', feature_node, level=2)
