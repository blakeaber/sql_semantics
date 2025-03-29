
from collections import ChainMap

class AliasResolver:
    def __init__(self, parent=None):
        self.alias_map = {}
        self.parent = parent
        self.chain = ChainMap(self.alias_map, parent.chain if parent else {})

    def define(self, alias: str, table_uri: str):
        self.alias_map[alias] = table_uri

    def resolve(self, alias: str):
        return self.chain.get(alias)

    def copy_for_child(self):
        return AliasResolver(parent=self)


class ParsingContext:

    __slots__ = ["last_keyword", "depth", "visited", "alias_resolver", "triples"]

    def __init__(self, last_keyword=None, depth=0, visited=None, triples=None, alias_resolver=None):
        self.last_keyword = last_keyword
        self.depth = depth
        self.visited = visited or set()
        self.alias_resolver = alias_resolver or AliasResolver()
        self.triples = triples if triples is not None else set()

    def copy(self, **kwargs):
        return ParsingContext(
            last_keyword=kwargs.get('last_keyword', self.last_keyword),
            depth=kwargs.get('depth', self.depth),
            visited=self.visited.copy(),
            alias_resolver=self.alias_resolver.copy_for_child(),
            triples=self.triples
        )

    def add_triple(self, subject, predicate, object_):
        self.triples.add((subject, predicate, object_))

    def define_alias(self, alias, table_node):
        uri = table_node.uri()
        self.alias_resolver.define(alias, uri)

    def resolve_alias(self, alias):
        return self.alias_resolver.resolve(alias)
