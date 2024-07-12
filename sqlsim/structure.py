from sqlparse.sql import Identifier, IdentifierList, Comment, Comparison, Function
from sqlparse.tokens import Keyword, DML, Punctuation, Name

from sqlsim import node as n


class SQLTree:
    def __init__(self, root_token):
        self.root = n.SQLNode(root_token)
        self.current_node = self.root

    def parse_tokens(self, tokens, parent, previous_keyword=None):

        for token in tokens:

            if (token.is_whitespace or isinstance(token, Comment)):
                continue

            elif token.is_keyword:
                print('keyword', token)
                keyword_node = n.SQLKeyword(token)
                parent.add_child(keyword_node)
                previous_keyword = keyword_node

            elif previous_keyword:

                if isinstance(token, Comparison):
                    print('comparison', token)
                    if n.contains_relationship(previous_keyword.token):
                        previous_keyword.add_child(n.SQLRelationship(token))
                    elif n.contains_segment(previous_keyword.token):
                        previous_keyword.add_child(n.SQLSegment(token))

                elif isinstance(token, Identifier):
                    print('id_single', token)
                    if token.is_group and n.contains_cte(previous_keyword.token):
                        self.parse_tokens(token, previous_keyword, previous_keyword)
                    elif n.contains_function(token):
                        previous_keyword.add_child(n.SQLFeature(token))
                    elif n.contains_column(previous_keyword.token):
                        previous_keyword.add_child(n.SQLColumn(token))
                    elif n.contains_table(previous_keyword.token):
                        previous_keyword.add_child(n.SQLTable(token))

                elif isinstance(token, IdentifierList):
                    print('id_list', token)
                    self.parse_tokens(token, previous_keyword, previous_keyword)

                elif n.is_insert(previous_keyword.token) and n.contains_table_definition(token):
                    print('ddl', token)
                    previous_keyword.add_child(n.SQLTableDefinition(token))

                elif (token.ttype == Name) and n.contains_cte(previous_keyword.token):
                    print('cte', token)
                    previous_keyword.add_child(n.SQLTable(token))

                elif n.contains_subquery(previous_keyword.token) and n.is_subquery(token):
                    print('subquery', token)
                    self.parse_tokens(token, previous_keyword, previous_keyword)

            elif token.is_group:
                print('group', token)
                self.parse_tokens(token, parent, previous_keyword)

            else:
                print('other', token)
                parent.add_child(n.SQLNode(token))
                previous_keyword = None
