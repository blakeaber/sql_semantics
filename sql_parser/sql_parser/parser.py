
from sqlparse.sql import Identifier, IdentifierList
from sqlparse.tokens import Keyword
from sql_parser import (
    booleans as b,
    nodes as n, 
    utils as u
)


class SQLTree:
    def __init__(self, root_token):
        self.root = n.SQLQuery(root_token)

    # TODO: Inside Subquery, need to check for UNION, INTERSECT and SELECT keywords
    # TODO: when these exist, create individual (nested) subqueries (how?!)

    # TODO: need to identify how to handle IN expressions (within a WHERE condition)

    def parse_tokens(self, tokens, parent, last_keyword=None):
        def parse_control_flow(token, last_keyword):
            if b.is_keyword(token):
                last_keyword = token
                self._handle_keyword(token, parent, last_keyword)

            elif b.is_cte(token, last_keyword):
                self._handle_cte(token, parent, last_keyword)

            elif b.is_subquery(token):
                self._handle_subquery(token, parent, last_keyword)

            elif b.is_where(token):
                self._handle_where(token, parent, last_keyword)

            elif b.is_connection(token, last_keyword):
                self._handle_connection(token, parent, last_keyword)

            elif b.is_comparison(token):
                self._handle_comparison(token, parent, last_keyword)

            # elif is_window(token):
            #     self._handle_window(token, parent)

            elif b.is_column(token, last_keyword):
                self._handle_column_ref(token, parent, last_keyword)

            elif b.is_table(token, last_keyword):
                self._handle_table_ref(token, parent, last_keyword)

            elif isinstance(token, IdentifierList):
                self._handle_identifier_list(token, parent, last_keyword)

            elif isinstance(token, Identifier):
                self._handle_identifier(token, parent, last_keyword)

            else:
                self._handle_other(token, parent, last_keyword)
            
            return last_keyword

        for token, next_token in u.peekable(u.clean_tokens(tokens)):
            last_keyword = parse_control_flow(token, last_keyword)
        last_keyword = parse_control_flow(next_token, last_keyword)


    def _handle_keyword(self, token, parent, last_keyword=None):
        keyword_node = n.SQLKeyword(token)
        parent.add_child(keyword_node)
        u.log_parsing_step('Keyword added', keyword_node, level=1)

    def _handle_cte(self, token, parent, last_keyword):
        for cte in u.clean_tokens(token.tokens):
            cte_node = n.SQLCTE(cte)
            parent.add_child(cte_node)
            u.log_parsing_step('CTE added', cte_node, level=1)
            u.log_parsing_step('Entering CTE...', cte_node, level=2)
            self.parse_tokens(cte, cte_node, last_keyword)
            u.log_parsing_step('... Exiting CTE', cte_node, level=2)

    def _handle_identifier_list(self, token, parent, last_keyword):
        u.log_parsing_step('IdentifierList seen', parent, level=1)
        u.log_parsing_step('Entering IdentifierList...', parent, level=2)
        for token in u.clean_tokens(token.get_identifiers()):
            self.parse_tokens([token], parent, last_keyword)
        u.log_parsing_step('... Exited IdentifierList', parent, level=2)

    def _handle_identifier(self, token, parent, last_keyword):
        if b.is_subquery(token):
            node_type = "Subquery"
            node = n.SQLSubquery(token)
            u.log_parsing_step('Entering Subquery...', node, level=2)
            self.parse_tokens(token, node, last_keyword)
            u.log_parsing_step('...Exiting Subquery', node, level=2)
        elif b.is_table(token, last_keyword):
            node_type = "Table"
            node = n.SQLTable(token)
        elif b.is_column(token, last_keyword):
            node_type = "Column"
            node = n.SQLColumn(token)
        else:
            node_type = "Unknown"
            node = n.SQLNode(token)

        parent.add_child(node)
        log_level = (0 if node_type == "Unknown" else 1)
        u.log_parsing_step(f'{node_type} added', node, level=log_level)

    def _handle_table_ref(self, token, parent, last_keyword):
        if token.is_group and any(b.is_subquery(t) for t in token.tokens):
            self._handle_subquery(token, parent, last_keyword)
        else:
            table_node = n.SQLTable(token)
            parent.add_child(table_node)
            u.log_parsing_step('Table added', table_node, level=1)


    def _handle_column_ref(self, token, parent, last_keyword):
        if isinstance(token, IdentifierList):
            for token in u.clean_tokens(token.tokens):
                col_node = n.SQLColumn(token)
                parent.add_child(col_node)
                u.log_parsing_step('Column (IdentifierList) added', col_node, level=1)
        # elif isinstance(token, Case) or isinstance(token, Function):
        #     feature_node = n.SQLFeature(token)
        #     parent.add_child(feature_node)
        #     self.parse_tokens(token, feature_node, last_keyword)
        elif isinstance(token, Identifier):
            col_node = n.SQLColumn(token)
            parent.add_child(col_node)
            u.log_parsing_step('Column (Identifier) added', col_node, level=1)
            # if token.is_group:
            #     print("!!!!!!!!!!!!!", last_keyword, token.tokens)
            #     self.parse_tokens(token, parent, last_keyword)
            # else:
            #     col_node = n.SQLColumn(token)
            #     parent.add_child(col_node)
        else:
            col_node = n.SQLColumn(token)
            parent.add_child(col_node)
            u.log_parsing_step('Column (Unknown) added', col_node, level=1)

    def _handle_subquery(self, token, parent, last_keyword):
        subquery_node = n.SQLSubquery(token)
        parent.add_child(subquery_node)
        u.log_parsing_step('Subquery added', subquery_node, level=1)
        u.log_parsing_step('Entering Subquery...', subquery_node, level=2)
        self.parse_tokens(token, subquery_node, last_keyword)
        u.log_parsing_step('...Exiting Subquery', subquery_node, level=2)

    def _handle_comparison(self, token, parent, last_keyword):
        for sub_token in u.clean_tokens(token.tokens):
            if u.contains_quotes(sub_token) or u.is_numeric(sub_token):
                node = n.SQLLiteral(sub_token)
                parent.add_child(node)
                u.log_parsing_step('Comparison:Literal added', node, level=1)
            elif b.is_logical_operator(sub_token):
                node = n.SQLOperator(sub_token)
                parent.add_child(node)
                u.log_parsing_step('Comparison:Operator added', node, level=1)
            elif b.is_subquery(sub_token):
                u.log_parsing_step('Entering Comparison:Subquery...', parent, level=2)
                self._handle_subquery(sub_token, parent, last_keyword)
                u.log_parsing_step('...Exiting Comparison:Subquery', parent, level=2)
            else:
                node = n.SQLColumn(sub_token)
                parent.add_child(node)
                u.log_parsing_step('Comparison:Column added', node, level=1)

    def _handle_connection(self, token, parent, last_keyword):

        if last_keyword.match(Keyword, ["ON"]):
            comparison_type = n.SQLRelationship
        elif last_keyword.match(Keyword, ["HAVING"]):
            comparison_type = n.SQLSegment

        if b.is_comparison(token):
            connection_node = comparison_type(token)
            self._handle_comparison(token, connection_node, last_keyword)
            parent.add_child(connection_node)
            u.log_parsing_step('Connection added', connection_node, level=1)
        else:
            connection_node = n.SQLNode(token)
            parent.add_child(connection_node)
            u.log_parsing_step('Connection:Unknown added', connection_node, level=0)

    def _handle_where(self, token, parent, last_keyword=None):

        for token in u.clean_tokens(token.tokens):
            if b.is_comparison(token):
                connection_node = n.SQLSegment(token)
                self._handle_comparison(token, connection_node, last_keyword)
                parent.add_child(connection_node)
                u.log_parsing_step('Where:Segment added', connection_node, level=1)
            elif b.is_keyword(token):
                keyword_node = n.SQLKeyword(token)
                parent.add_child(keyword_node)
                u.log_parsing_step('Where:Keyword added', keyword_node, level=1)
            elif b.is_logical_operator(token):
                logical_node = n.SQLOperator(token)
                parent.add_child(logical_node)
                u.log_parsing_step('Where:Operator added', logical_node, level=1)
            else:
                node = n.SQLNode(token)
                parent.add_child(node)
                u.log_parsing_step('Where:Unknown added', node, level=0)

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
        node = n.SQLNode(token)
        parent.add_child(node)
        u.log_parsing_step('Other:Unknown added', node, level=0)
