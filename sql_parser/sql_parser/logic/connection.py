
from sqlparse.sql import Identifier, IdentifierList, Function, Comparison, Case, Where, Parenthesis, Comment
from sqlparse.tokens import Keyword, Punctuation, CTE, DML, Comparison as Operator
from sql_parser import utils as u


def is_comparison(token):
    return isinstance(token, Comparison)


def is_connection(token, last_keyword):
    return last_keyword.match(Keyword, ["ON", "HAVING"])
