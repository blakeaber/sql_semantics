
from sql_parser import utils as u


class SQLNode:
    """Base class representing a node in the SQL parse tree."""
    
    CHAR_DISPLAY_LIMIT = 40
    __slots__ = [
        "token", "type", "level", "children", 
        "parent", "name", "alias"
        ]

    def __init__(self, token, level=None):

        # ensures no "reference before assignment" logging errors
        for attr in self.__slots__:
            setattr(self, attr, None)

        self.token = token
        self.type = self.__class__.__name__
        self.level = level or 0

        self.parent = u.get_node_parent(self, token)
        self.name = u.get_node_name(self, token) or self.display_value
        self.alias = u.get_node_alias(self, token)

        self.children = []

    def add_child(self, child_node, context=None):
        """Adds a child node to the current node."""
        child_node.level = self.level + 1
        self.children.append(child_node)

        if context:
            context.add_triple(
                subject=self.uri(),
                predicate=f"has{child_node.type}",
                object_=child_node.uri()
            )

    def traverse(self, depth=0):
        print('  ' * depth + repr(self))
        for child in self.children:
            child.traverse(depth + 1)

    @property
    def uri(self):
        return f"{self.type.lower()}://{self.parent}/{self.name}/{self.alias}".replace(" ", "_")

    @property
    def display_value(self):
        return self.token.value.replace('\n', ' ')[:self.CHAR_DISPLAY_LIMIT]

    def __hash__(self):
        return u.get_short_hash(self.uri)

    def __repr__(self):
        """Returns a string representation of the node."""
        display_value = self.display_value
        ellipses = "..." if len(display_value) == self.CHAR_DISPLAY_LIMIT else ""
        return f"{self.__class__.__name__}({display_value}{ellipses})"


# --- Specialized SQL Node Classes ---
class SQLKeyword(SQLNode):
    """Represents a SQL keyword (e.g., SELECT, FROM, WHERE)."""
    pass


class SQLLiteral(SQLNode):
    """Represents a literal (e.g. 'Green' or 123)"""
    pass


class SQLOperator(SQLNode):
    """Represents a logical operator (e.g. AND, OR, <, =)"""
    pass


class SQLColumn(SQLNode):
    """Represents a column in a SQL statement."""
    pass


class SQLFeature(SQLNode):
    """Represents a calculated feature, such as a function or case statement."""
    pass


class SQLTable(SQLNode):
    """Represents a table in a SQL statement."""
    pass


class SQLRelationship(SQLNode):
    """Represents a relational clause between tables (e.g., JOIN conditions)."""
    pass


class SQLSegment(SQLNode):
    """Represents a filtered segment of the population (e.g. WHERE or HAVING conditions)."""
    pass


class SQLSubquery(SQLNode):
    """Represents a subquery enclosed in parentheses."""
    pass


class SQLCTE(SQLNode):
    """Represents a CTE in a SQL statement."""
    pass


class SQLQuery(SQLNode):
    """Represents a complete SQL statement."""
    pass