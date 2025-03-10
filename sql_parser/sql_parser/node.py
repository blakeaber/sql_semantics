import hashlib
from sqlparse.sql import Comparison
from sql_parser.utils import generate_uid

class SQLNode:
    """Base class representing a SQL tree node."""
    def __init__(self, name, node_type, relation=None, alias=None, function=None, table_prefix=None):
        self.name = name
        self.node_type = node_type  # 'Table', 'Column', 'Feature', 'Join', 'Where', etc.
        self.children = []  # Nested nodes
        self.relation = relation  # Relationships (e.g., 'JOIN ON', 'FILTER')
        self.alias = alias  # Table or column alias
        self.function = function  # SQL function name if applicable
        self.table_prefix = table_prefix  # Table qualifier for columns
        self.uid = generate_uid(node_type, name, table_prefix, function)  # Ensure consistent UID

    def _generate_uid(self):
        """Generates a unique identifier for the node based on its type and properties."""
        base_str = f"{self.node_type}:{self.name}:{self.relation}:{self.alias}:{self.function}:{self.table_prefix}"
        return hashlib.md5(base_str.encode()).hexdigest()[:10]  # Short hash

    def add_child(self, node):
        """Attach a child node to this node."""
        node.parent = self
        self.children.append(node)

    def __repr__(self, level=0):
        indent = "  " * level
        uid_str = f" [UID: {self.uid}]"
        return f"{indent}{self.node_type}: {self.name}{uid_str}\n"


# ---------- Specialized Node Classes ----------

class SQLTable(SQLNode):
    """Represents a table in a SQL query."""
    def __init__(self, token):
        super().__init__(token.get_real_name() or token.value, "Table", alias=token.get_alias())

class SQLColumn(SQLNode):
    """Represents a column reference in a SQL query."""
    def __init__(self, token):
        super().__init__(
            token.get_real_name() or token.value, "Column",
            table_prefix=token.get_parent_name(), alias=token.get_alias()
        )

class SQLFeature(SQLNode):
    """Represents a computed field or function in a SQL query."""
    def __init__(self, token):
        super().__init__(
            token.get_real_name() or "Computed", "Feature",
            function=token.get_real_name()
        )

class SQLComparison(SQLNode):
    """Represents SQL comparison operations (e.g., WHERE conditions, JOIN ON)."""
    def __init__(self, token):
        super().__init__(token.value, "Comparison")


class SQLRelationship(SQLNode):
    """Represents a JOIN or WHERE condition."""
    def __init__(self, token):
        left, operator, right = [t for t in token.tokens if not t.is_whitespace]
        super().__init__(f"{left.get_real_name()} {operator.value} {right.get_real_name()}", "Relationship")
        self.add_child(SQLColumn(left))
        self.add_child(SQLColumn(right))

class SQLSegment(SQLNode):
    """Represents SQL segments like WHERE, HAVING, ORDER BY."""
    def __init__(self, name, node_type):
        super().__init__(name, node_type)
