
from sqlparse.sql import Identifier, IdentifierList, Function, Comparison, Case, Where, Parenthesis, Comment
from sqlparse.tokens import Keyword, Punctuation, CTE, DML, Comparison as Operator
from sql_parser import utils as u


def is_whitespace(token):
    return token.is_whitespace or isinstance(token, Comment) or (token.ttype == Punctuation)

def is_logical_operator(token):
    return (token.ttype == Operator)

