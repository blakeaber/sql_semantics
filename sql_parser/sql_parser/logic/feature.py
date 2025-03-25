
from sqlparse.sql import Identifier, IdentifierList, Function, Comparison, Case, Where, Parenthesis, Comment
from sqlparse.tokens import Keyword, Punctuation, CTE, DML, Comparison as Operator
from sql_parser import utils as u


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
