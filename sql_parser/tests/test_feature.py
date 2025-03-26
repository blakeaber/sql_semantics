import pytest
from sqlparse.tokens import Keyword
from sqlparse.sql import Identifier, Function, Case, Token
from sql_parser.logic.feature import is_function, is_case, is_window, is_feature, FeatureHandler
from sql_parser.context import ParsingContext
from sql_parser.nodes import SQLNode


@pytest.fixture
def setup_context():
    return ParsingContext()


@pytest.fixture
def setup_function_token():
    return Identifier('my_function()')


@pytest.fixture
def setup_case_token():
    return Identifier('CASE WHEN condition THEN result END')


@pytest.fixture
def setup_window_token():
    return Identifier('my_function() OVER (PARTITION BY column_name)')


@pytest.fixture
def setup_parent():
    return SQLNode(Token(Keyword, 'ROOT'))


def test_is_function(setup_function_token, setup_context):
    assert is_function(setup_function_token, setup_context) is True


def test_is_not_function(setup_case_token, setup_context):
    assert is_function(setup_case_token, setup_context) is False


def test_is_case(setup_case_token, setup_context):
    assert is_case(setup_case_token, setup_context) is True


def test_is_not_case(setup_function_token, setup_context):
    assert is_case(setup_function_token, setup_context) is False


def test_is_window(setup_window_token, setup_context):
    assert is_window(setup_window_token, setup_context) is True


def test_is_not_window(setup_case_token, setup_context):
    assert is_window(setup_case_token, setup_context) is False


def test_is_feature_with_function(setup_function_token, setup_context):
    assert is_feature(setup_function_token, setup_context) is True


def test_is_feature_with_case(setup_case_token, setup_context):
    assert is_feature(setup_case_token, setup_context) is True


def test_is_feature_with_window(setup_window_token, setup_context):
    assert is_feature(setup_window_token, setup_context) is True


def test_feature_handler(setup_function_token, setup_parent, setup_context):
    handler = FeatureHandler()
    handler.handle(setup_function_token, setup_parent, None, setup_context)

    assert len(setup_parent.children) == 1
    assert isinstance(setup_parent.children[0], SQLNode)
