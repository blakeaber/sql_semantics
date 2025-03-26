import pytest
from sqlparse.tokens import Keyword
from sqlparse.sql import Identifier, IdentifierList, Token
from sql_parser.logic.identifier import IdentifierHandler
from sql_parser.context import ParsingContext
from sql_parser.nodes import SQLNode


@pytest.fixture
def setup_context():
    return ParsingContext()


@pytest.fixture
def setup_identifier_token():
    return Identifier('column_name')


@pytest.fixture
def setup_identifier_list_token():
    # Example of creating an IdentifierList
    return IdentifierList([Identifier('column1'), Identifier('column2')])


@pytest.fixture
def setup_parent():
    return SQLNode(Token(Keyword, 'ROOT'))


def test_identifier_handler_with_single_identifier(setup_identifier_token, setup_parent, setup_context):
    handler = IdentifierHandler()
    handler.handle(setup_identifier_token, setup_parent, None, setup_context)

    assert len(setup_parent.children) == 1
    assert isinstance(setup_parent.children[0], SQLNode)


def test_identifier_handler_with_identifier_list(setup_identifier_list_token, setup_parent, setup_context):
    handler = IdentifierHandler()
    handler.handle(setup_identifier_list_token, setup_parent, None, setup_context)

    assert len(setup_parent.children) == 2
    assert all(isinstance(child, SQLNode) for child in setup_parent.children)
