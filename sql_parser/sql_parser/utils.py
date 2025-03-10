
import hashlib
import logging
import sqlparse
from sqlparse.sql import Identifier, Function, Case, Where, Parenthesis
from sqlparse.tokens import Keyword, Comparison

from sql_parser import node as n

# Configure logging
logging.basicConfig(
    level=logging.DEBUG, 
    format="%(asctime)s [%(levelname)s] - %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S"
)
logger = logging.getLogger(__name__)


def log_parsing_step(step_name, node):
    """Logs structured information about the current parsing step."""
    logger.debug(f"{step_name}: {node.node_type} -> {node.name} [UID: {node.uid}]")


def generate_uid(node_type, name, table_prefix=None, function=None):
    """
    Generates a unique identifier (UID) for a SQL node.
    Ensures deduplication across queries.
    """
    base_str = f"{node_type}:{table_prefix}:{name}:{function}"
    return hashlib.md5(base_str.encode()).hexdigest()[:10]  # Short hash


def hash_value(value):
    """
    Generates a short hash for a given value (e.g., WHERE condition values).
    
    Example:
        hash_value("users.status='active'") -> "comp_a3f9c2b1"
    """
    return f"comp_{hashlib.md5(value.encode()).hexdigest()[:10]}"

def normalize_sql(sql):
    """
    Preprocesses and normalizes SQL queries to remove formatting inconsistencies.
    
    Example:
        - Removes extra spaces, newlines.
        - Converts to lowercase (optional, if case-insensitive parsing is needed).
    """
    parsed = sqlparse.format(sql, reindent=True, keyword_case='upper')
    return parsed.strip()

def extract_comparison(token):
    """
    Extracts structured information from a SQL comparison (e.g., WHERE, JOIN).
    
    Example:
        - WHERE age >= 21 -> ("age", ">=", "21")
        - ON users.id = orders.user_id -> ("users.id", "=", "orders.user_id")
    """
    left, operator, right = None, None, None
    for sub_token in token.tokens:
        if isinstance(sub_token, sqlparse.sql.Identifier):
            if left is None:
                left = sub_token.get_real_name()
            else:
                right = sub_token.get_real_name()
        elif sub_token.ttype in (sqlparse.tokens.Comparison, sqlparse.tokens.Keyword):
            operator = sub_token.value
    return left, operator, right

def is_subquery(token):
    """
    Checks if a token represents a subquery (nested SELECT inside parentheses).
    """
    return isinstance(token, sqlparse.sql.Parenthesis) and any(
        t.ttype is sqlparse.tokens.DML and t.value.upper() == "SELECT" for t in token.tokens
    )

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

def log_parsing_step(step_name, node):
    """
    Logs structured information about the current parsing step.
    
    Example:
        log_parsing_step("Processing WHERE clause", node)
    """
    logger.info(f"{step_name}: {node.node_type} -> {node.name}")


def parse_where_conditions(where_token, context_node):
    """Parses WHERE clauses, including nested AND/OR conditions."""
    condition_node = n.SQLSegment("WHERE", "Where")

    def extract_conditions(token, parent_node):
        if isinstance(token, n.Comparison):
            left, operator, right = extract_comparison(token)
            comparison_node = n.SQLSegment(f"{left} {operator} {right}", "Comparison")
            parent_node.add_child(comparison_node)
        elif token.is_keyword and token.value.upper() in {"AND", "OR"}:
            logical_node = n.SQLSegment(token.value.upper(), "LogicalCondition")
            parent_node.add_child(logical_node)
        elif isinstance(token, Parenthesis):
            nested_node = n.SQLSegment("NestedCondition", "Where")
            extract_conditions(token, nested_node)
            parent_node.add_child(nested_node)

    for token in where_token.tokens:
        extract_conditions(token, condition_node)

    context_node.add_child(condition_node)


def parse_case_statement(case_token, context_node):
    """
    Parses SQL CASE statements, extracting WHEN/THEN/ELSE conditions.
    """
    case_node = n.SQLFeature("CASE", "Feature")

    for sub_token in case_token.get_sublists():  # Ensure sub-token traversal
        if sub_token.match(Keyword, "WHEN"):
            when_condition = extract_comparison(sub_token)
            when_node = n.SQLSegment(f"WHEN {when_condition}", "CaseCondition")
            case_node.add_child(when_node)
        elif sub_token.match(Keyword, "THEN"):
            then_value = sub_token.get_real_name()
            then_node = n.SQLSegment(f"THEN {then_value}", "CaseResult")
            case_node.add_child(then_node)
        elif sub_token.match(Keyword, "ELSE"):
            else_value = sub_token.get_real_name()
            else_node = n.SQLSegment(f"ELSE {else_value}", "CaseDefault")
            case_node.add_child(else_node)

    context_node.add_child(case_node)


def parse_window_function(function_token, context_node):
    """
    Parses SQL window functions (e.g., ROW_NUMBER(), RANK()).
    """
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


def parse_cte_recursive(token, context_node):
    """
    Parses recursive CTEs (WITH RECURSIVE).
    """
    cte_node = n.SQLSegment("CTE", "CTE")

    for sub_token in token.tokens:
        if sub_token.match(Keyword, "RECURSIVE"):
            recursive_node = n.SQLSegment("RECURSIVE", "CTE")
            cte_node.add_child(recursive_node)
        elif isinstance(sub_token, Parenthesis):
            subquery_node = n.SQLSegment("SubQuery", "Subquery")
            parse_query(sub_token, subquery_node)
            cte_node.add_child(subquery_node)

    context_node.add_child(cte_node)


def parse_having_clause(having_token, context_node):
    """
    Parses HAVING conditions after GROUP BY.
    """
    having_node = n.SQLSegment("HAVING", "Having")

    for token in having_token.tokens:
        if isinstance(token, Comparison):
            left, operator, right = extract_comparison(token)
            condition_node = n.SQLSegment(f"{left} {operator} {right}", "Comparison")
            having_node.add_child(condition_node)

    context_node.add_child(having_node)


def parse_order_limit_offset(statement, context_node):
    """
    Parses ORDER BY, LIMIT, and OFFSET clauses.
    """
    for token in statement.tokens:
        if token.match(Keyword, "ORDER BY") or token.match(Keyword, "LIMIT") or token.match(Keyword, "OFFSET"):
            clause_node = n.SQLSegment(token.value.upper(), "Clause")
            context_node.add_child(clause_node)
