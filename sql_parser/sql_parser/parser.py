
from sqlparse.sql import Identifier, IdentifierList, Function, Comparison, Case, Where, Parenthesis, Comment
from sqlparse.tokens import Keyword, Punctuation, CTE, DML, Comparison as Operator
from sql_parser import (
    nodes as n, 
    utils as u
)


def is_whitespace(token):
    return token.is_whitespace or isinstance(token, Comment) or (token.ttype == Punctuation)

def is_keyword(token):
    return (token.ttype in (CTE, DML, Keyword)) and (not is_logical_operator(token))

def is_cte_name(last_keyword):
    return (last_keyword.match(CTE, ["WITH"]) or last_keyword.match(Keyword, ["RECURSIVE"]))

def is_cte(token, last_keyword):
    return is_cte_name(last_keyword) and isinstance(token, IdentifierList)

def is_subquery(token):
    return (
        isinstance(token, Parenthesis) and
        any(t.match(DML, "SELECT") for t in token.tokens)
    )

def is_column(token=None, last_keyword=None):
    return (
        last_keyword.match(DML, ["SELECT"]) or 
        last_keyword.match(Keyword, ["GROUP BY", "ORDER BY"])
    )

def is_table(token, last_keyword):
    print('table', token)
    if not last_keyword:
        return False
    return (
        last_keyword.match(Keyword, ["FROM", "UPDATE", "INTO"]) or 
        is_cte_name(last_keyword) or 
        ("JOIN" in last_keyword.value)
    )

def is_window(token):
    return isinstance(token, Function) and "OVER" in token.value.upper()

def is_function(token):
    return (
        isinstance(token, Identifier) and 
        any(
            (t.is_keyword or isinstance(t, Function)) 
            for t in u.clean_tokens(token.tokens)
        )
    )

def is_comparison(token):
    return isinstance(token, Comparison)

def is_logical_operator(token):
    return (token.ttype == Operator)

def is_connection(token, last_keyword):
    return last_keyword.match(Keyword, ["ON", "HAVING"])

def is_where(token):
    return isinstance(token, Where)


class SQLTree:
    def __init__(self, root_token):
        self.root = n.SQLQuery(root_token)

    # TODO: why is ORDER BY / GROUP BY not identify columns (e.g. "d" and "d.department_name" as SQLNode objects)??

    def parse_tokens(self, tokens, parent, last_keyword=None):
        def parse_control_flow(token, last_keyword):
            if is_keyword(token):
                print('keyword', token)
                last_keyword = token
                self._handle_keyword(token, parent, last_keyword)

            elif is_cte(token, last_keyword):
                print('cte', token)
                self._handle_cte(token, parent, last_keyword)

            elif is_subquery(token):
                print('subquery', token)
                self._handle_subquery(token, parent, last_keyword)

            elif is_where(token):
                print('where', token)
                self._handle_where(token, parent, last_keyword)

            elif is_connection(token, last_keyword):
                self._handle_connection(token, parent, last_keyword)

            elif is_comparison(token):
                print('comparison', token)
                self._handle_comparison(token, parent, last_keyword)

            # elif is_window(token):
            #     self._handle_window(token, parent)

            elif is_column(token, last_keyword):
                print('column', token)
                self._handle_column_ref(token, parent, last_keyword)

            elif is_table(token, last_keyword):
                print('table', token)
                self._handle_table_ref(token, parent, last_keyword)

            elif isinstance(token, IdentifierList):
                print('identifier list', token)
                self._handle_identifier_list(token, parent, last_keyword)

            elif isinstance(token, Identifier):
                print('identifier', token)
                self._handle_identifier(token, parent, last_keyword)

            else:
                print('other', token)
                self._handle_other(token, parent, last_keyword)
            
            return last_keyword

        for token, next_token in u.peekable(u.clean_tokens(tokens)):
            last_keyword = parse_control_flow(token, last_keyword)
        last_keyword = parse_control_flow(next_token, last_keyword)


    def _handle_keyword(self, token, parent, last_keyword=None):
        keyword_node = n.SQLKeyword(token)
        parent.add_child(keyword_node)

    def _handle_cte(self, token, parent, last_keyword):
        for cte in u.clean_tokens(token.tokens):
            cte_node = n.SQLCTE(cte)
            parent.add_child(cte_node)
            self.parse_tokens(cte, cte_node, last_keyword)

    def _handle_identifier_list(self, token, parent, last_keyword):
        # id_list_node = n.SQLIdentifierList(token)
        # parent.add_child(id_list_node)

        for token in u.clean_tokens(token.get_identifiers()):
            self.parse_tokens([token], parent, last_keyword)

    def _handle_identifier(self, token, parent, last_keyword):
        if is_subquery(token):
            node = n.SQLSubquery(token)
            self.parse_tokens(token, node, last_keyword)
        elif is_table(token, last_keyword):
            node = n.SQLTable(token)
        elif is_column(token, last_keyword):
            node = n.SQLColumn(token)
        else:
            node = n.SQLNode(token)

        parent.add_child(node)

    def _handle_table_ref(self, token, parent, last_keyword):
        if token.is_group and any(is_subquery(t) for t in token.tokens):
            subquery_node = n.SQLSubquery(token)
            parent.add_child(subquery_node)
            self.parse_tokens(token, subquery_node, last_keyword)
        else:
            table_node = n.SQLTable(token)
            parent.add_child(table_node)


    def _handle_column_ref(self, token, parent, last_keyword):
        if isinstance(token, IdentifierList):
            for token in u.clean_tokens(token.tokens):
                col_node = n.SQLColumn(token)
                parent.add_child(col_node)
        # elif isinstance(token, Case) or isinstance(token, Function):
        #     feature_node = n.SQLFeature(token)
        #     parent.add_child(feature_node)
        #     self.parse_tokens(token, feature_node, last_keyword)
        elif isinstance(token, Identifier):
            col_node = n.SQLColumn(token)
            parent.add_child(col_node)
            # if token.is_group:
            #     print("!!!!!!!!!!!!!", last_keyword, token.tokens)
            #     self.parse_tokens(token, parent, last_keyword)
            # else:
            #     col_node = n.SQLColumn(token)
            #     parent.add_child(col_node)
        else:
            col_node = n.SQLNode(token)
            parent.add_child(col_node)

    def _handle_subquery(self, token, parent, last_keyword):
        subquery_node = n.SQLSubquery(token)
        parent.add_child(subquery_node)
        self.parse_tokens(token, subquery_node, last_keyword)

    def _handle_comparison(self, token, parent, last_keyword):
        for sub_token in u.clean_tokens(token.tokens):
            if u.contains_quotes(sub_token) or u.is_numeric(sub_token):
                parent.add_child(n.SQLLiteral(sub_token))
            elif is_logical_operator(sub_token):
                parent.add_child(n.SQLOperator(sub_token))
            elif is_subquery(sub_token):
                self._handle_subquery(sub_token, parent, last_keyword)
            else:
                parent.add_child(n.SQLColumn(sub_token))

    def _handle_connection(self, token, parent, last_keyword):

        if last_keyword.match(Keyword, ["ON"]):
            print('relationship', token)
            comparison_type = n.SQLRelationship
        elif last_keyword.match(Keyword, ["HAVING"]):
            print('segment', token)
            comparison_type = n.SQLSegment

        if is_comparison(token):
            connection_node = comparison_type(token)
            self._handle_comparison(token, connection_node, last_keyword)
            parent.add_child(connection_node)
        else:
            node = n.SQLNode(token)
            parent.add_child(node)

    def _handle_where(self, token, parent, last_keyword=None):

        for token in u.clean_tokens(token.tokens):
            if is_comparison(token):
                connection_node = n.SQLSegment(token)
                self._handle_comparison(token, connection_node, last_keyword)
                parent.add_child(connection_node)
            elif is_keyword(token):
                keyword_node = n.SQLKeyword(token)
                parent.add_child(keyword_node)
            elif is_logical_operator(token):
                logical_node = n.SQLOperator(token)
                parent.add_child(logical_node)
            else:
                node = n.SQLNode(token)
                parent.add_child(node)

    # def _handle_case(self, case_token, context_node):
    #     # this needs experimentation to figure out how it works
    #     case_node = n.SQLFeature("CASE", "Feature")

    #     for sub_token in case_token.get_sublists():
    #         if sub_token.match(Keyword, "WHEN"):
    #             when_condition = extract_comparison(sub_token)
    #             when_node = n.SQLCondition()
    #             case_node.add_child(when_node)
    #         elif sub_token.match(Keyword, "THEN"):
    #             then_value = sub_token.get_real_name()
    #             then_node = n.SQLCondition()
    #             case_node.add_child(then_node)
    #         elif sub_token.match(Keyword, "ELSE"):
    #             else_value = sub_token.get_real_name()
    #             else_node = n.SQLCondition()
    #             case_node.add_child(else_node)

    #     context_node.add_child(case_node)

    # def _handle_window(self, function_token, context_node):
    #     function_name = function_token.get_real_name()
    #     window_node = n.SQLFeature(function_name, "WindowFunction")

    #     for sub_token in function_token.tokens:
    #         if sub_token.match(Keyword, "PARTITION BY"):
    #             partition_node = n.SQLSegment("PARTITION BY", "WindowPartition")
    #             window_node.add_child(partition_node)
    #         elif sub_token.match(Keyword, "ORDER BY"):
    #             order_node = n.SQLSegment("ORDER BY", "WindowOrdering")
    #             window_node.add_child(order_node)

    #     context_node.add_child(window_node)

    # def _handle_having(self, having_token, context_node):
    #     having_node = n.SQLSegment("HAVING", "Having")

    #     for token in having_token.tokens:
    #         if isinstance(token, Comparison):
    #             left, operator, right = extract_comparison(token)
    #             condition_node = n.SQLSegment(f"{left} {operator} {right}", "Comparison")
    #             having_node.add_child(condition_node)

    #     context_node.add_child(having_node)

    # def _handle_order_limit_offset(self, statement, context_node):
    #     pass

    def _handle_other(self, token, parent, last_keyword=None):
        parent.add_child(n.SQLNode(token))
