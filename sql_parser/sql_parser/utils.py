
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


def log_parsing_step(log_step, node, level=0):
    verbose_options = [logging.WARN, logging.INFO, logging.DEBUG]
    output = f"{log_step}: {node.type} -> {node.alias} {node.name} [UID: {node.uid}]"
    if verbose_options[level] == logging.WARN:
        logger.warning(output)
    elif verbose_options[level] == logging.INFO:
        logger.info(output)
    elif verbose_options[level] == logging.DEBUG:
        logger.debug(output)
    else:
        pass

def get_node_parent(node, token):
    try:
        node.parent = token.get_parent_name()
    except AttributeError:
        pass
        

def get_node_name(node, token):
    try:
        node.name = token.get_real_name()
    except AttributeError:
        pass

def get_node_alias(node, token):
    try:
        node.alias = token.get_alias()
    except AttributeError:
        pass

def get_short_hash(value):
    return f"id_{hashlib.md5(value.encode()).hexdigest()[:20]}"

def generate_uid(node):
    return f"{node.type}:{node.parent}:{node.name}:{node.alias}"

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
