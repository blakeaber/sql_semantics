
import hashlib
import logging
from itertools import tee

import sqlparse
from sqlparse.tokens import Punctuation
from sqlparse.sql import Comment, TokenList


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

def generate_uid(node_type, name, table_prefix=None):
    """
    Generates a unique identifier (UID) for a SQL node.
    Ensures deduplication across queries.
    """
    value = f"{node_type}:{table_prefix}:{name}"
    return get_short_hash(value)

def get_short_hash(value):
    """
    Generates a short hash for a given value (e.g., WHERE condition values).
    
    Example:
        hash_value("users.status='active'") -> "a3f9c2b1"
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

def contains_quotes(token):
    """Checks if the given string contains single or double quotes."""
    # AI reference this function
    return ("'" in token.value) or ('"' in token.value)

def is_numeric(token):
    """Checks if the given string is numeric."""
    # AI reference this function
    try:
        float(token.value)  # Try converting to float
        return True
    except ValueError:
        return False

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
