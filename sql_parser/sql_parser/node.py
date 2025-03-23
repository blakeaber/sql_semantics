
from sql_parser import utils as u

CHAR_DISPLAY_LIMIT = 40


class SQLNode:
    """Base class representing a node in the SQL parse tree."""
    
    __slots__ = ["token", "children", "name", "parent", "alias"]

    def __init__(self, token):
        self.token = token
        self.children = []

        try:
            self.name = token.get_real_name()
            self.parent = token.get_parent_name()
            self.alias = token.get_alias()
        except:
            pass

    def add_child(self, child_node):
        """Adds a child node to the current node."""
        self.children.append(child_node)

    def traverse(self, depth=0):
        print('  ' * depth + repr(self))
        for child in self.children:
            child.traverse(depth + 1)

    def __repr__(self):
        """Returns a string representation of the node."""
        display_value = self.token.value.replace('\n', ' ')[:CHAR_DISPLAY_LIMIT]
        ellipses = "..." if len(display_value) == 40 else ""
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