
from sqlparse.sql import Identifier, IdentifierList, Function, Comparison, Case, Where, Parenthesis, Comment
from sqlparse.tokens import Keyword, Punctuation, CTE, DML, Comparison as Operator
from sql_parser import utils as u


def is_subquery(token):
    return (
        isinstance(token, Parenthesis) and
        any(t.match(DML, "SELECT") for t in token.tokens)
    )
