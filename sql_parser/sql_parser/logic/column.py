
from sqlparse.sql import Identifier, IdentifierList, Function, Comparison, Case, Where, Parenthesis, Comment
from sqlparse.tokens import Keyword, Punctuation, CTE, DML, Comparison as Operator
from sql_parser import utils as u


def is_column(token=None, last_keyword=None):
    return (
        last_keyword.match(DML, ["SELECT"]) or 
        last_keyword.match(Keyword, ["GROUP BY", "ORDER BY"])
    )
