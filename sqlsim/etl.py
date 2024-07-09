import sqlparse
from sqlparse.tokens import Keyword
from sqlparse.sql import IdentifierList, Identifier, Where, Parenthesis

import sqlsim.main as m


def parse_tokens(tokens, parent):
    previous_keyword = None

    for token in tokens:
        if token.is_whitespace:
            continue
        elif token.is_group:
            new_node = m.SQLNode(token)
            parent.add_child(new_node)
            parse_tokens(token.tokens, new_node)
        elif token.ttype in Keyword:
            keyword_node = m.SQLNode(token)
            parent.add_child(keyword_node)
            previous_keyword = keyword_node
        elif isinstance(token, IdentifierList):
            identifier_list_node = m.SQLNode(token)
            if previous_keyword:
                previous_keyword.add_child(identifier_list_node)
            else:
                parent.add_child(identifier_list_node)
            for identifier in token.get_identifiers():
                parse_tokens([identifier], identifier_list_node)
        elif isinstance(token, Identifier):
            identifier_node = m.SQLNode(token)
            if previous_keyword:
                previous_keyword.add_child(identifier_node)
                previous_keyword = None
            else:
                parent.add_child(identifier_node)
        elif isinstance(token, Where):
            where_node = m.SQLNode(token)
            parent.add_child(where_node)
            parse_tokens(token.tokens, where_node)
        elif isinstance(token, Parenthesis):
            parenthesis_node = m.SQLNode(token)
            parent.add_child(parenthesis_node)
            parse_tokens(token.tokens, parenthesis_node)
        else:
            general_node = m.SQLNode(token)
            if previous_keyword:
                previous_keyword.add_child(general_node)
                previous_keyword = None
            else:
                parent.add_child(general_node)


def parse_sql_query(query, statement_idx=0):
    parsed = sqlparse.parse(query)
    if not parsed:
        return None
    
    tokens = parsed[statement_idx].tokens
    tree = m.SQLTree()
    parse_tokens(tokens, tree.root)
    return tree
