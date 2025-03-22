from collections.abc import Iterable

from sqlparse.sql import Identifier, IdentifierList, Function, Comparison, Case, Where, Parenthesis, Comment, TokenList
from sqlparse.tokens import CTE, DML, Keyword, Punctuation, Name
from itertools import tee

from sql_parser import node as n
from sql_parser.utils import log_parsing_step, extract_comparison  # Removed is_window_function and is_aggregate_function imports


def peekable(iterable):
    """Helper function to create a look-ahead iterator."""
    items, next_items = tee(iterable)
    next(next_items, None)  # Advance second iterator to get lookahead capability
    return zip(items, next_items)

def clean_tokens(tokens):
    return TokenList([
        token for token in tokens 
        if (
            not token.is_whitespace and 
            not isinstance(token, Comment) and 
            not (token.ttype == Punctuation)
        )
    ])

def is_whitespace(token=None):
    return token.is_whitespace or isinstance(token, Comment) or (token.ttype == Punctuation)

def is_keyword(token=None):
    return token.ttype in (CTE, DML, Keyword)

def is_cte(token=None, last_keyword=None):
    return last_keyword.match(CTE, ["WITH"]) and isinstance(token, IdentifierList)

def is_subquery(token=None):
    return (
        isinstance(token, Parenthesis) and 
        any(t.match(DML, "SELECT") for t in token.tokens)
    )

def is_column(token=None, last_keyword=None):
    return (
        last_keyword.match(DML, ["SELECT"]) or 
        last_keyword.match(Keyword, ["HAVING", "GROUP BY", "ORDER BY"]) or 
        isinstance(last_keyword, Where)
    )

def is_table(token=None, last_keyword=None):
    return last_keyword.match(Keyword, ["FROM", "UPDATE", "INTO"]) or ("JOIN" in last_keyword.value)

def is_window_function(token):
    """
    Checks if a function is a window function (e.g., RANK() OVER ...).
    """
    return isinstance(token, sqlparse.sql.Function) and "OVER" in token.value.upper()

def is_aggregate_function(token):
    """
    Detects if a token represents an aggregate function (e.g., SUM, COUNT).
    """
    return isinstance(token, sqlparse.sql.Function) and token.get_real_name() in {"SUM", "COUNT", "AVG", "MIN", "MAX"}


class SQLTree:
    def __init__(self, root_token):
        self.root = n.SQLNode(root_token)

    def parse_tokens(self, tokens, parent, last_keyword=None):
        """Recursively parses SQL tokens into a structured tree, using token peeking."""
        # TODO: add identification of subqueries when used as tables
        # TODO: Add comparisons, where clauses, case statements, functions

        def parse_control_flow(token, last_keyword):
            if is_keyword(token):
                last_keyword = token
                self._handle_keyword(token, parent)

            elif is_cte(token, last_keyword):
                self._handle_cte(token, parent, last_keyword)

            elif is_subquery(token):
                self._handle_subquery(token, parent)

            elif is_window_function(token):  # Added handling for window functions
                self._handle_window_function(token, parent)

            elif is_aggregate_function(token):  # Added handling for aggregate functions
                self._handle_aggregate_function(token, parent)

            elif is_column(token, last_keyword=last_keyword):
                self._handle_column_ref(token, parent)

            elif is_table(token, last_keyword=last_keyword):
                self._handle_table_ref(token, parent)

            elif isinstance(token, IdentifierList):
                self._handle_identifier_list(token, parent, last_keyword)

            elif isinstance(token, Identifier):
                self._handle_identifier(token, parent, last_keyword)

            elif (token.ttype == Name):
                self._handle_name(token, parent, last_keyword)

            else:
                self._handle_other(token, parent)
            
            return last_keyword

        for token, next_token in peekable(clean_tokens(tokens)):
            print("token:", token)
            last_keyword = parse_control_flow(token, last_keyword)

        # ensure last token gets processed...
        print("next:", next_token)
        last_keyword = parse_control_flow(next_token, last_keyword)


    def _handle_keyword(self, token, parent):
        """Handles SQL keywords (e.g., SELECT, FROM, WHERE)."""
        print("Keyword:", token)
        keyword_node = n.SQLKeyword(token)
        parent.add_child(keyword_node)

    def _handle_cte(self, token, parent, last_keyword):
        """Handles SQL CTEs"""
        for cte in clean_tokens(token.tokens):
            print("CTE:", cte)
            cte_node = n.SQLCTE(cte)
            parent.add_child(cte_node)
            self.parse_tokens(cte, cte_node, last_keyword)

    def _handle_identifier_list(self, token, parent, last_keyword):
        """Handles lists of identifiers (e.g., column lists)."""
        print("Identifier List:", token)
        id_list_node = n.SQLIdentifierList(token)
        parent.add_child(id_list_node)

        for id_token in token.get_identifiers():
            self.parse_tokens([id_token], parent, last_keyword)

    def _handle_identifier(self, token, parent, last_keyword):
        """Handles identifiers, determining if they are columns, tables, aliases, or functions."""
        print("Identifier:", token)

        if last_keyword and (
            last_keyword.match(CTE, ["WITH"]) or 
            last_keyword.match(Keyword, ["FROM", "JOIN", "UPDATE", "INTO"])):
            node = n.SQLTable(token)
        elif last_keyword.match(Keyword, ["SELECT", "WHERE", "HAVING", "GROUP BY", "ORDER BY"]):
            node = n.SQLColumn(token)
        elif last_keyword.match(Keyword, ["AS"]) and is_subquery(token):
            node = n.SQLSubquery(token)
            self.parse_tokens(token, node)
        else:
            node = n.SQLNode(token)  # Generic fallback

        parent.add_child(node)

    def _handle_name(self, token, parent, last_keyword):
        """Handles names, determining if they are columns, tables, aliases, or functions."""
        print("Name:", token)
        if last_keyword.match(CTE, ["WITH"]):
            node = n.SQLTable(token)
        else:
            node = n.SQLNode(token)  # Generic fallback

        parent.add_child(node)

    def _handle_table_ref(self, token, parent):
        """Handles SQL tables"""
        print("Table:", token)
        table_node = n.SQLTable(token)
        parent.add_child(table_node)

    def _handle_column_ref(self, token, parent):
        """Handles SQL columns"""
        if isinstance(token, IdentifierList):
            for token in clean_tokens(token.tokens):
                col_node = n.SQLColumn(token)
                parent.add_child(col_node)
        elif isinstance(token, Identifier):
            col_node = n.SQLColumn(token)
            parent.add_child(col_node)
        elif isinstance(token, Case) or isinstance(token, Function):
            feature_node = n.SQLFeature(token)
            parent.add_child(feature_node)
            self.parse_tokens(token, feature_node)  # Process feature arguments
        else:
            col_node = n.SQLNode(token)
            parent.add_child(col_node)

    def _handle_subquery(self, token, parent):
        """Handles subqueries (enclosed in parentheses)."""
        print("Subquery:", token)
        subquery_node = n.SQLSubquery(token)
        parent.add_child(subquery_node)
        self.parse_tokens(token, subquery_node)  # Recursively process subquery

    def _handle_comparison(self, token, parent):
        """Handles comparison operators (e.g., col = value)."""
        print("Comparison:", token)
        cmp_node = n.SQLComparison(token)
        parent.add_child(cmp_node)

    def _handle_other(self, token, parent):
        """Handles unclassified tokens (e.g., literals, operators)."""
        print("Other:", token)
        parent.add_child(n.SQLNode(token))
