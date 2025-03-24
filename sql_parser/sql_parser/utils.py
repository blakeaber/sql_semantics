import hashlib
import logging
from itertools import tee

import sqlparse
from sqlparse.tokens import Punctuation
from sqlparse.sql import Comment, TokenList


logging.basicConfig(
    level=logging.DEBUG, 
    format="%(asctime)s [%(levelname)s] - %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S"
)
logger = logging.getLogger(__name__)


def log_parsing_step(step_name, node):
    logger.debug(f"{step_name}: {node.node_type} -> {node.name} [UID: {node.uid}]")

def generate_uid(node_type, name, table_prefix=None):
    value = f"{node_type}:{table_prefix}:{name}"
    return get_short_hash(value)

def get_short_hash(value):
    return f"comp_{hashlib.md5(value.encode()).hexdigest()[:10]}"

def normalize_sql(sql):
    parsed = sqlparse.format(sql, reindent=True, keyword_case='upper')
    return parsed.strip()

def contains_quotes(token):
    return ("'" in token.value) or ('"' in token.value)

def is_numeric(token):
    try:
        float(token.value)
        return True
    except ValueError:
        return False

def peekable(iterable):
    items, next_items = tee(iterable)
    next(next_items, None)
    return zip(items, next_items)

def clean_tokens(tokens):
    return TokenList([
        token for token in tokens 
        if (
            not token.is_whitespace and 
            not isinstance(token, Comment) and 
            not (token.ttype == Punctuation) and
            not (token.value == "AS")  # confuses sequential parsing; taken care of by sqlparse aliasing
        )
    ])
