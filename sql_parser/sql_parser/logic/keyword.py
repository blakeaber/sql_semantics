
from sqlparse.sql import Identifier, IdentifierList, Function, Comparison, Case, Where, Parenthesis, Comment
from sqlparse.tokens import Keyword, Punctuation, CTE, DML, Comparison as Operator
from sql_parser.logic import other
from sql_parser import utils as u


def is_keyword(token):
    return (token.ttype in (CTE, DML, Keyword)) and (not other.is_logical_operator(token))


def handle_keyword(token, parent, last_keyword=None):
    keyword_node = n.SQLKeyword(token)
    parent.add_child(keyword_node)
    u.log_parsing_step('Keyword added', keyword_node, level=1)
