import sqlparse
from sqlparse.tokens import Keyword
from sqlparse.sql import IdentifierList, Identifier, Where, Parenthesis

import sqlsim.structure as m


def parse_sql_query(query, statement_idx=0):
    parsed = sqlparse.parse(query)
    if not parsed:
        return None
    
    tokens = parsed[statement_idx].tokens
    tree = m.SQLTree(tokens)
    tree.parse_tokens(tokens, tree.root)
    return tree
