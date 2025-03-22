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
