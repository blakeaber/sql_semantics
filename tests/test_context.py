import pytest
from sqlflow.context import ParsingContext


@pytest.fixture
def setup_context():
    return ParsingContext()


def test_initialization(setup_context):
    assert setup_context.last_keyword is None
    assert setup_context.depth == 0
    assert setup_context.visited == set()
    assert setup_context.triples == set()


def test_copy_context(setup_context):
    new_context = setup_context.copy(last_keyword='SELECT', depth=1)
    assert new_context.last_keyword == 'SELECT'
    assert new_context.depth == 1
    assert new_context.visited == set()
    assert new_context.triples == set()


def test_add_triple(setup_context):
    setup_context.add_triple('subject', 'predicate', 'object')
    assert len(setup_context.triples) == 1
    assert ('subject', 'predicate', 'object') in setup_context.triples
