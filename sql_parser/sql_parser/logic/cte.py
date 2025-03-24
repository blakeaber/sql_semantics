
from sqlparse.sql import Identifier, IdentifierList, Function, Comparison, Case, Where, Parenthesis, Comment
from sqlparse.tokens import Keyword, Punctuation, CTE, DML, Comparison as Operator
from sql_parser import utils as u


def is_cte_name(last_keyword):
    return (last_keyword.match(CTE, ["WITH"]) or last_keyword.match(Keyword, ["RECURSIVE"]))


def is_cte(token, last_keyword):
    return is_cte_name(last_keyword) and isinstance(token, IdentifierList)

def _handle_cte(token, parent, last_keyword):
    for cte in u.clean_tokens(token.tokens):
        cte_node = n.SQLCTE(cte)
        parent.add_child(cte_node)
        u.log_parsing_step('CTE added', cte_node, level=1)
        u.log_parsing_step('Entering CTE...', cte_node, level=2)
        parse_tokens(cte, cte_node, last_keyword)
        u.log_parsing_step('... Exiting CTE', cte_node, level=2)
