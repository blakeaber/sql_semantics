    
class ParsingContext:

    __slots__ = ["last_keyword", "depth", "visited", "triples"]

    def __init__(self, last_keyword=None, depth=0, visited=None, triples=None):
        self.last_keyword = last_keyword
        self.depth = depth
        self.visited = visited or set()
        self.triples = triples if triples is not None else set()

    def copy(self, **kwargs):
        return ParsingContext(
            last_keyword=kwargs.get('last_keyword', self.last_keyword),
            depth=kwargs.get('depth', self.depth),
            visited=self.visited.copy(),
            triples=self.triples
        )

    def add_triple(self, subject, predicate, object_):
        self.triples.add((subject, predicate, object_))
