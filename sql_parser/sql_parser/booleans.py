
from sqlparse.sql import Identifier, IdentifierList, Function, Comparison, Case, Where, Parenthesis, Comment
from sqlparse.tokens import Keyword, Punctuation, CTE, DML, Comparison as Operator
from sql_parser import utils as u


def is_whitespace(token):
    return token.is_whitespace or isinstance(token, Comment) or (token.ttype == Punctuation)


def is_keyword(token):
    return (token.ttype in (CTE, DML, Keyword)) and (not is_logical_operator(token))


def is_cte_name(last_keyword):
    return (last_keyword.match(CTE, ["WITH"]) or last_keyword.match(Keyword, ["RECURSIVE"]))


def is_cte(token, last_keyword):
    return is_cte_name(last_keyword) and isinstance(token, IdentifierList)


def is_subquery(token):
    return (
        isinstance(token, Parenthesis) and
        any(t.match(DML, "SELECT") for t in token.tokens)
    )


def is_column(token=None, last_keyword=None):
    return (
        last_keyword.match(DML, ["SELECT"]) or 
        last_keyword.match(Keyword, ["GROUP BY", "ORDER BY"])
    )


def is_table(token, last_keyword):
    if not last_keyword:
        return False
    return (
        last_keyword.match(Keyword, ["FROM", "UPDATE", "INTO"]) or 
        is_cte_name(last_keyword) or 
        ("JOIN" in last_keyword.value)
    )


def is_window(token):
    return isinstance(token, Function) and "OVER" in token.value.upper()


def is_function(token):
    return (
        isinstance(token, Identifier) and 
        any(
            (t.is_keyword or isinstance(t, Function)) 
            for t in u.clean_tokens(token.tokens)
        )
    )


def is_comparison(token):
    return isinstance(token, Comparison)


def is_logical_operator(token):
    return (token.ttype == Operator)


def is_connection(token, last_keyword):
    return last_keyword.match(Keyword, ["ON", "HAVING"])


def is_where(token):
    return isinstance(token, Where)
