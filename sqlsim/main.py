from sqlparse.sql import Identifier
from sqlparse.tokens import Keyword


class SQLNode:
    def __init__(self, token):
        self.token = token
        self.children = []
        self.parent = None

    def add_child(self, node):
        node.parent = self
        self.children.append(node)

    def get_name(self):
        if isinstance(self.token, Identifier):
            return self.token.get_real_name()
        return self.token.value

    def is_keyword(self):
        return self.token.ttype in Keyword

    def __repr__(self):
        if ((not self.token) or (not self.token.value)):
            return ''
        else:
            return f"SQLNode(token={self.token.value[:15]}, ttype={self.token.ttype})"


class SQLTree:
    def __init__(self):
        self.root = SQLNode(None)
        self.current_node = self.root

    def add_node(self, node):
        self.current_node.add_child(node)

    def enter_node(self, node):
        self.add_node(node)
        self.current_node = node

    def leave_node(self):
        if self.current_node.parent:
            self.current_node = self.current_node.parent

    def traverse(self, node=None, level=0):
        if (node is None) or (node.token is None):
            node = self.root
        print("  " * level + str(node))
        for child in node.children:
            self.traverse(child, level + 1)
