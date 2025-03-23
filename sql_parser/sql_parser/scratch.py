from collections.abc import Iterable

from sqlparse.sql import Identifier, IdentifierList, Function, Comparison, Case, Where, Parenthesis, Comment, TokenList
from sqlparse.tokens import CTE, DML, Keyword, Punctuation, Name
from itertools import tee

from sql_parser import node as n


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

def extract_comparison(token):
    """
    Extracts structured information from a SQL comparison (e.g., WHERE, JOIN).
    
    Example:
        - WHERE age >= 21 -> ("age", ">=", "21")
        - ON users.id = orders.user_id -> ("users.id", "=", "orders.user_id")
    """
    left, operator, right = None, None, None
    for sub_token in token.tokens:
        if isinstance(sub_token, Identifier):
            if left is None:
                left = sub_token.get_real_name()
            else:
                right = sub_token.get_real_name()
        elif sub_token.ttype in (Comparison, Keyword):
            operator = sub_token.value
    return left, operator, right

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
        last_keyword.match(Keyword, ["GROUP BY", "ORDER BY"])
    )

def is_table(token=None, last_keyword=None):
    if not last_keyword:
        return
    return last_keyword.match(Keyword, ["WITH", "FROM", "UPDATE", "INTO"]) or ("JOIN" in last_keyword.value)

def is_window(token):
    """
    Checks if a function is a window function (e.g., RANK() OVER ...).
    """
    return isinstance(token, Function) and "OVER" in token.value.upper()

def is_comparison(token, last_keyword=None):
    """Identifies if the token is a comparison."""
    return isinstance(token, Comparison)

def is_logical_operator(token, last_keyword=None):
    """Identifies if the token is a comparison."""
    # AI! write a function that identifies logical operators
    pass

def is_where_or_having(token, last_keyword=None):
    """Identifies if the token is a WHERE or HAVING clause."""
    return isinstance(token, Where) or last_keyword.match(Keyword, ["HAVING"])


class SQLTree:
    def __init__(self, root_token):
        self.root = n.SQLNode(root_token)

    def parse_tokens(self, tokens, parent, last_keyword=None):
        """Recursively parses SQL tokens into a structured tree, using token peeking."""
        # TODO: add identification of subqueries when used as tables
        # TODO: Add where clauses, case statements, functions

        def parse_control_flow(token, last_keyword):
            if is_keyword(token):
                last_keyword = token
                self._handle_keyword(token, parent)

            elif is_cte(token, last_keyword):
                self._handle_cte(token, parent, last_keyword)

            elif is_subquery(token):
                self._handle_subquery(token, parent)

            elif is_window(token):
                self._handle_window(token, parent)

            elif is_where_or_having(token, last_keyword):
                self._handle_where_or_having(token, parent)

            elif is_comparison(token, last_keyword):
                self._handle_comparison(token, parent)

            elif is_column(token, last_keyword):
                self._handle_column_ref(token, parent)

            elif is_table(token, last_keyword):
                self._handle_table_ref(token, parent)

            elif isinstance(token, IdentifierList):
                self._handle_identifier_list(token, parent, last_keyword)

            elif isinstance(token, Identifier):
                self._handle_identifier(token, parent, last_keyword)

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

        if is_table(token, last_keyword):
            node = n.SQLTable(token)
        elif is_column(token, last_keyword):
            node = n.SQLColumn(token)
        elif is_subquery(token):
            node = n.SQLSubquery(token)
            self.parse_tokens(token, node)
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
        left, operator, right = extract_comparison(token)
        comparison_node = n.SQLComparison(token)
        parent.add_child(comparison_node)
        comparison_node.add_child(n.SQLNode(left))
        comparison_node.add_child(n.SQLNode(operator))
        comparison_node.add_child(n.SQLNode(right))

    def _handle_where_or_having(self, where_token, context_node):
        """Handles WHERE or HAVING clauses."""
        condition_node = n.SQLSegment("WHERE", "Where")

        def extract_conditions(token, parent_node):
            if is_comparison(token):
                left, operator, right = extract_comparison(token)
                comparison_node = n.SQLSegment(f"{left} {operator} {right}", "Comparison")
                parent_node.add_child(comparison_node)
            elif token.is_keyword and token.value.upper() in {"AND", "OR", "NOT"}:
                logical_node = n.SQLSegment(token.value.upper(), "LogicalCondition")
                parent_node.add_child(logical_node)
            elif is_subquery(token):
                nested_node = n.SQLSubquery(token)
                parent_node.add_child(nested_node)
                self.parse_tokens(token, nested_node)  # Recursively process nested subquery

        for token in where_token.tokens:
            extract_conditions(token, condition_node)

        context_node.add_child(condition_node)

    def _handle_case(self, case_token, context_node):
        # update this function to parse the WINDOW clause, based on conditions below:
        # if the last Keyword is "WHEN", then it is a SQLCondition object
        # if the last Keyword is "THEN" or "ELSE" , then it is a SQLLiteral object
        # else, it is a SQLNode object
        case_node = n.SQLFeature("CASE", "Feature")

        for sub_token in case_token.get_sublists():  # Ensure sub-token traversal
            if sub_token.match(Keyword, "WHEN"):
                when_condition = extract_comparison(sub_token)
                when_node = n.SQLCondition()
                case_node.add_child(when_node)
            elif sub_token.match(Keyword, "THEN"):
                then_value = sub_token.get_real_name()
                then_node = n.SQLCondition()
                case_node.add_child(then_node)
            elif sub_token.match(Keyword, "ELSE"):
                else_value = sub_token.get_real_name()
                else_node = n.SQLCondition()
                case_node.add_child(else_node)

        context_node.add_child(case_node)

    def _handle_window(self, function_token, context_node):
        # update this function to parse the WINDOW clause, based on conditions below:
        # if the last Keyword is "PARTITION BY" or "ORDER BY", then it is a SQLColumn object
        # else, it is a SQLNode object
        function_name = function_token.get_real_name()
        window_node = n.SQLFeature(function_name, "WindowFunction")

        for sub_token in function_token.tokens:
            if sub_token.match(Keyword, "PARTITION BY"):
                partition_node = n.SQLSegment("PARTITION BY", "WindowPartition")
                window_node.add_child(partition_node)
            elif sub_token.match(Keyword, "ORDER BY"):
                order_node = n.SQLSegment("ORDER BY", "WindowOrdering")
                window_node.add_child(order_node)

        context_node.add_child(window_node)

    def _handle_having(self, having_token, context_node):
        # update this function to parse the HAVING clause
        # add three children for the left, operator and right tokens
        having_node = n.SQLSegment("HAVING", "Having")

        for token in having_token.tokens:
            if isinstance(token, Comparison):
                left, operator, right = extract_comparison(token)
                condition_node = n.SQLSegment(f"{left} {operator} {right}", "Comparison")
                having_node.add_child(condition_node)

        context_node.add_child(having_node)

    def _handle_order_limit_offset(self, statement, context_node):
        # write logic that adds objects to the tree, based on conditions below:
        # if the last Keyword is "ORDER BY", then it is a SQLColumn object
        # else, it is a SQLNode object
        pass

    def _handle_other(self, token, parent):
        """Handles unclassified tokens (e.g., literals, operators)."""
        print("Other:", token)
        parent.add_child(n.SQLNode(token))
