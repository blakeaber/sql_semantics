
from sqlparse.sql import Identifier, IdentifierList, Function, Comparison, Case, Where, Parenthesis, Comment
from sqlparse.tokens import Keyword, Punctuation, CTE, DML, Comparison as Operator
from sql_parser.logic import cte
from sql_parser import utils as u


def is_table(token, last_keyword):
    if not last_keyword:
        return False
    return (
        last_keyword.match(Keyword, ["FROM", "UPDATE", "INTO"]) or 
        cte.is_cte_name(last_keyword) or 
        ("JOIN" in last_keyword.value)
    )
