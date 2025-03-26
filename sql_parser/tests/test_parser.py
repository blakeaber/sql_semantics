import pytest
from sqlparse.tokens import Keyword
from sqlparse.sql import Token
from sql_parser.parser import SQLTree
from sql_parser.context import ParsingContext
from sql_parser.nodes import SQLNode


@pytest.fixture
def setup_token():
    return Token(Keyword, 'SELECT')


@pytest.fixture
def setup_tree(setup_token):
    return SQLTree(setup_token)


@pytest.fixture
def setup_context():
    return ParsingContext()


@pytest.fixture
def setup_parent():
    return SQLNode(setup_token)


def test_sql_tree_initialization(setup_tree):
    assert setup_tree.root.token == setup_tree.root.token
    assert setup_tree.root.type == 'SQLQuery'


def test_parse_tokens_with_valid_tokens(setup_tree, setup_parent, setup_context):
    tokens = [Token(Keyword, 'SELECT'), Token(Keyword, 'FROM'), Token(Keyword, 'my_table')]
    setup_tree.parse_tokens(tokens, setup_parent, setup_context)

    assert len(setup_parent.children) > 0


def test_parse_tokens_with_empty_tokens(setup_tree, setup_parent, setup_context):
    tokens = []
    setup_tree.parse_tokens(tokens, setup_parent, setup_context)

    assert len(setup_parent.children) == 0


def test_dispatch_handler_with_keyword(setup_tree, setup_parent, setup_context):
    token = Token(Keyword, 'SELECT')
    setup_tree.dispatch_handler(token, setup_parent, setup_context)

    assert len(setup_parent.children) > 0


def test_get_handler_key_with_valid_keyword(setup_context):
    token = Token(Keyword, 'SELECT')
    tree = SQLTree(token)
    handler_key = tree.get_handler_key(token, setup_context)

    assert handler_key is not None


def test_get_handler_key_with_invalid_token(setup_context):
    token = Token(Keyword, 'INVALID')
    tree = SQLTree(token)
    handler_key = tree.get_handler_key(token, setup_context)

    assert handler_key is not None
