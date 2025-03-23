import hashlib
from sqlparse.sql import Comparison
from sql_parser.utils import generate_uid


class SQLNode:
    """Base class representing a node in the SQL parse tree."""
    
    def __init__(self, token):
        self.token = token
        self.children = []

    def add_child(self, child_node):
        """Adds a child node to the current node."""
        self.children.append(child_node)

    def __repr__(self):
        """Returns a string representation of the node."""
        return f"{self.__class__.__name__}({self.token})"


# --- Specialized SQL Node Classes ---
class SQLKeyword(SQLNode):
    """Represents a SQL keyword (e.g., SELECT, FROM, WHERE)."""
    pass


class SQLOperator(SQLNode):
    """Represents a calculated feature, such as a function or case statement."""
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
    """Represents a table in a SQL statement."""
    pass
