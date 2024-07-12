from sqlparse.sql import Identifier, IdentifierList, Parenthesis, Function
from sqlparse.tokens import Keyword, DML, Punctuation


def is_identifier(self):
    return isinstance(self.token, (Identifier, IdentifierList))

def contains_column(token):
    return (
        token.is_keyword and 
        (
            (token.value.upper() == 'SELECT') or
            (token.value.upper() == 'GROUP BY') or
            (token.value.upper() == 'ORDER BY')
        )
    )

def contains_table(token):
    return (
        token.is_keyword and 
        (
            (token.value.upper() == 'FROM') or 
            (token.value.upper() == 'WITH') or
            ('JOIN' in token.value.upper())
        )
    )

def contains_relationship(token):
    return (
        token.is_keyword and 
        (token.value.upper() == 'ON')
    )

def contains_segment(token):
    return (
        token.is_keyword and 
        (token.value.upper() == 'WHERE')
    )

def contains_cte(token):
    return (
        token.is_keyword and 
        (token.value.upper() == 'WITH')
    )

def contains_subquery(token):
    return (
        token.is_keyword and 
        (token.value.upper() == 'AS')
    )

def is_subquery(token):
    return (
        isinstance(token, Parenthesis) and 
        any(t.ttype is DML and t.value.upper() == 'SELECT' for t in token.tokens)
    )

def contains_function(token):
    return (
        isinstance(token, Identifier) and 
        any(
            (t.is_keyword or isinstance(t, Function)) 
            for t in token.tokens 
            if t.value.upper() != 'AS')
    )

def is_insert(token):
    return (
        token.is_keyword and 
        (token.value.upper() == 'INTO')
    )

def contains_table_definition(token):
    return (
        isinstance(token, Function) and 
        any(isinstance(t, Parenthesis) for t in token.tokens)
    )


class SQLNode:
    def __init__(self, token):
        self.token = token
        self.children = []
        self.parent = None

    def add_child(self, node):
        node.parent = self
        self.children.append(node)

    def traverse(self, depth=0):
        print('  ' * depth + repr(self))
        for child in self.children:
            child.traverse(depth + 1)

    def extract_structure(self):
        NotImplementedError


class SQLKeyword(SQLNode):
    def __init__(self, token):
        super().__init__(token)

    def __repr__(self):
        return f"SQLKeyword({self.token.value[:10], self.token.ttype})"

    
class SQLColumn(SQLNode):
    def __init__(self, token):
        super().__init__(token)
        try:
            self.name = token.get_real_name()
            self.alias = token.get_alias() or self.name
        except:
            self.name = token.value
            self.alias = None

    def __repr__(self):
        return f"SQLColumn({self.name, self.alias})"


class SQLTable(SQLNode):
    def __init__(self, token):
        super().__init__(token)
        try:
            self.name = token.get_real_name()
            self.alias = token.get_alias() or self.name
        except:
            self.name = token.value
            self.alias = None

    def __repr__(self):
        return f"SQLTable({self.name, self.alias})"


class SQLTableDefinition(SQLNode):
    def __init__(self, token):
        super().__init__(token)
        self.name, self.columns = [i for i in token.tokens if not i.is_whitespace]
        self.name = self.name.get_real_name()
        self.columns = [
            i.value for i in self.columns.flatten() 
            if (
                (not i.is_whitespace) and 
                (not i.ttype == Punctuation)
                )
            ]

    def __repr__(self):
        return f"SQLTableDefinition({self.name, self.columns})"


class SQLFeature(SQLNode):
    def __init__(self, token):
        super().__init__(token)
        self.value = ''.join([str(t) for t in token.tokens])

    def __repr__(self):
        return f"SQLFeature({self.value})"


class SQLRelationship(SQLNode):
    def __init__(self, token):
        super().__init__(token)
        self.left, self.operator, self.right = [i for i in token.tokens if not i.is_whitespace]
        self.left_table = self.left.get_parent_name()
        self.left_column = self.left.get_real_name()
        self.right_table = self.right.get_parent_name()
        self.right_column = self.right.get_real_name()

    def __repr__(self):
        return f"SQLRelationship({self.left_table, self.left_column, self.right_table, self.right_column})"


class SQLSegment(SQLNode):
    def __init__(self, token):
        super().__init__(token)

    def __repr__(self):
        return f"SQLSegment({self.token.value})"
