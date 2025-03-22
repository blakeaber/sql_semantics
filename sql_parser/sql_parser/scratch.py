
from collections.abc import Iterable

from sqlparse.sql import Identifier, IdentifierList, Function, Comparison, Case, Where, Parenthesis, Comment, TokenList
from sqlparse.tokens import CTE, DML, Keyword, Punctuation, Name
from itertools import tee

from sql_parser import node as n


EXAMPLE_SQL_QUERY = """
WITH department_salaries AS (
    SELECT 
        d.department_name,
        SUM(e.salary) AS total_salary
    FROM 
        employees e
    JOIN 
        departments d ON e.department_id = d.department_id
    GROUP BY 
        d.department_name
), 
project_counts AS (
    SELECT 
        e.employee_id,
        COUNT(ep.project_id) AS project_count
    FROM 
        employees e
    LEFT JOIN 
        employee_projects ep ON e.employee_id = ep.employee_id
    GROUP BY 
        e.employee_id
)

SELECT 
    e.employee_id,
    e.name AS employee_name,
    d.department_name,
    ds.total_salary,
    pc.project_count,
    subquery.customer_name,
    subquery.total_spent,
    
    -- CASE Statement: Categorize employees based on project count
    CASE 
        WHEN pc.project_count = 0 THEN 'No Projects'
        WHEN pc.project_count BETWEEN 1 AND 3 THEN 'Few Projects'
        ELSE 'Many Projects'
    END AS project_category,

    -- WINDOW Function: Running total of salaries within each department
    SUM(e.salary) OVER (PARTITION BY e.department_id ORDER BY e.salary DESC) AS running_department_salary

FROM employees e
JOIN department_salaries ds ON e.department_id = (
    SELECT d.department_id 
    FROM departments d 
    WHERE d.department_name = ds.department_name
)
JOIN project_counts pc ON e.employee_id = pc.employee_id
LEFT JOIN (
    SELECT 
        c.name AS customer_name, 
        SUM(o.amount) AS total_spent 
    FROM customers c 
    JOIN orders o ON c.id = o.customer_id
    GROUP BY c.name
    HAVING SUM(o.amount) > 1000  -- HAVING clause: Filter customers who spent more than $1000
) subquery ON e.customer_id = subquery.customer_name

-- WHERE clause: Only include employees with few projects
WHERE project_category = 'Few Projects'

-- HAVING clause: Only include employees from departments with a total salary exceeding $500,000
HAVING ds.total_salary > 500000

-- ORDER BY: Sort by highest total spent customers first
ORDER BY subquery.total_spent DESC
"""


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


class SQLTree:
    def __init__(self, root_token):
        self.root = n.SQLNode(root_token)

    def parse_tokens(self, tokens, parent, last_keyword=None):
        """Recursively parses SQL tokens into a structured tree, using token peeking."""
        # assert hasattr(tokens, "tokens") and (len(tokens.tokens) > 0), "Tokens are missing or not iterable!"

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
        # AI add a test case for this function
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
