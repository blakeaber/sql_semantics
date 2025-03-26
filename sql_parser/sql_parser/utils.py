
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
    output = f"{log_step}: {node.type} -> {node.alias} {node.name} [UID: {node.uri}]"
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
    hash_object = hashlib.sha256(value.encode("utf-8"))
    hash_bytes = hash_object.digest()
    return int.from_bytes(hash_bytes, byteorder="big")

def generate_uid(node):
    return f"{node.type}:{node.parent}:{node.name}:{node.alias}"

def normalize_sql(sql):
    parsed = sqlparse.format(sql, reindent=True, keyword_case='upper')
    return parsed.strip()

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
