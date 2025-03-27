import pytest
import hashlib
from sqlflow.utils import (
    log_parsing_step,
    get_node_parent,
    get_node_name,
    get_node_alias,
    get_short_hash,
    normalize_sql,
    clean_tokens
)
from sqlparse.sql import Token
from sqlparse.tokens import Keyword


@pytest.fixture
def setup_token():
    return Token(Keyword, 'SELECT')


def test_log_parsing_step(caplog, setup_token):
    log_parsing_step("Test log", setup_token, level=2)
    assert "Test log: SQLKeyword -> None SELECT [UID: sqlkeyword://None/SELECT/None]" in caplog.text


def test_get_node_parent(setup_token):
    class MockNode:
        pass

    node = MockNode()
    get_node_parent(node, setup_token)
    assert node.parent is None  # Assuming the mock does not set a parent


def test_get_node_name(setup_token):
    class MockNode:
        pass

    node = MockNode()
    get_node_name(node, setup_token)
    assert node.name is None  # Assuming the mock does not set a name


def test_get_node_alias(setup_token):
    class MockNode:
        pass

    node = MockNode()
    get_node_alias(node, setup_token)
    assert node.alias is None  # Assuming the mock does not set an alias


def test_get_short_hash():
    value = "test_string"
    hash_value = get_short_hash(value)
    assert isinstance(hash_value, int)


def test_normalize_sql():
    sql = "SELECT * FROM my_table"
    normalized_sql = normalize_sql(sql)
    assert normalized_sql == "SELECT * FROM my_table"  # Adjust based on actual normalization


def test_clean_tokens():
    tokens = [
        Token(Keyword, 'SELECT'),
        Token(Keyword, 'FROM'),
        Token(Keyword, 'my_table'),
        Token(Keyword, 'AS'),
        Token(Keyword, 'column_name')
    ]
    cleaned_tokens = clean_tokens(tokens)
    assert len(cleaned_tokens) == 4  # 'AS' should be removed
