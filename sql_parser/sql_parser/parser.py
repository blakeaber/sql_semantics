from sqlparse.sql import Identifier, IdentifierList
from sqlparse.tokens import Keyword
from sql_parser import (
    logic as l,
    nodes as n, 
    utils as u
)

def parse_tokens(tokens, parent, last_keyword=None):
    def parse_control_flow(token, last_keyword):
        if l.is_keyword(token):
            last_keyword = token
            _handle_keyword(token, parent, last_keyword)

        elif l.is_cte(token, last_keyword):
            _handle_cte(token, parent, last_keyword)

        elif l.is_subquery(token):
            _handle_subquery(token, parent, last_keyword)

        elif l.is_where(token):
            _handle_where(token, parent, last_keyword)

        elif l.is_connection(token, last_keyword):
            _handle_connection(token, parent, last_keyword)

        elif l.is_comparison(token):
            _handle_comparison(token, parent, last_keyword)

        elif l.is_column(token, last_keyword):
            _handle_column_ref(token, parent, last_keyword)

        elif l.is_table(token, last_keyword):
            _handle_table_ref(token, parent, last_keyword)

        elif isinstance(token, IdentifierList):
            _handle_identifier_list(token, parent, last_keyword)

        elif isinstance(token, Identifier):
            _handle_identifier(token, parent, last_keyword)

        else:
            _handle_other(token, parent, last_keyword)
        
        return last_keyword

    for token, next_token in u.peekable(u.clean_tokens(tokens)):
        last_keyword = parse_control_flow(token, last_keyword)
    last_keyword = parse_control_flow(next_token, last_keyword)

def _handle_keyword(token, parent, last_keyword=None):
    keyword_node = n.SQLKeyword(token)
    parent.add_child(keyword_node)
    u.log_parsing_step('Keyword added', keyword_node, level=1)

def _handle_cte(token, parent, last_keyword):
    for cte in u.clean_tokens(token.tokens):
        cte_node = n.SQLCTE(cte)
        parent.add_child(cte_node)
        u.log_parsing_step('CTE added', cte_node, level=1)
        u.log_parsing_step('Entering CTE...', cte_node, level=2)
        parse_tokens(cte, cte_node, last_keyword)
        u.log_parsing_step('... Exiting CTE', cte_node, level=2)

def _handle_identifier_list(token, parent, last_keyword):
    u.log_parsing_step('IdentifierList seen', parent, level=1)
    u.log_parsing_step('Entering IdentifierList...', parent, level=2)
    for token in u.clean_tokens(token.get_identifiers()):
        parse_tokens([token], parent, last_keyword)
    u.log_parsing_step('... Exited IdentifierList', parent, level=2)

def _handle_identifier(token, parent, last_keyword):
    if l.is_subquery(token):
        node_type = "Subquery"
        node = n.SQLSubquery(token)
        u.log_parsing_step('Entering Subquery...', node, level=2)
        parse_tokens(token, node, last_keyword)
        u.log_parsing_step('...Exiting Subquery', node, level=2)
    elif l.is_table(token, last_keyword):
        node_type = "Table"
        node = n.SQLTable(token)
    elif l.is_column(token, last_keyword):
        node_type = "Column"
        node = n.SQLColumn(token)
    else:
        node_type = "Unknown"
        node = n.SQLNode(token)

    parent.add_child(node)
    log_level = (0 if node_type == "Unknown" else 1)
    u.log_parsing_step(f'{node_type} added', node, level=log_level)

def _handle_table_ref(token, parent, last_keyword):
    if token.is_group and any(l.is_subquery(t) for t in token.tokens):
        _handle_subquery(token, parent, last_keyword)
    else:
        table_node = n.SQLTable(token)
        parent.add_child(table_node)
        u.log_parsing_step('Table added', table_node, level=1)

def _handle_column_ref(token, parent, last_keyword):
    if isinstance(token, IdentifierList):
        for token in u.clean_tokens(token.tokens):
            col_node = n.SQLColumn(token)
            parent.add_child(col_node)
            u.log_parsing_step('Column (IdentifierList) added', col_node, level=1)
    elif isinstance(token, Identifier):
        col_node = n.SQLColumn(token)
        parent.add_child(col_node)
        u.log_parsing_step('Column (Identifier) added', col_node, level=1)
    else:
        col_node = n.SQLColumn(token)
        parent.add_child(col_node)
        u.log_parsing_step('Column (Unknown) added', col_node, level=1)

def _handle_subquery(token, parent, last_keyword):
    subquery_node = n.SQLSubquery(token)
    parent.add_child(subquery_node)
    u.log_parsing_step('Subquery added', subquery_node, level=1)
    u.log_parsing_step('Entering Subquery...', subquery_node, level=2)
    parse_tokens(token, subquery_node, last_keyword)
    u.log_parsing_step('...Exiting Subquery', subquery_node, level=2)

def _handle_comparison(token, parent, last_keyword):
    for sub_token in u.clean_tokens(token.tokens):
        if u.contains_quotes(sub_token) or u.is_numeric(sub_token):
            node = n.SQLLiteral(sub_token)
            parent.add_child(node)
            u.log_parsing_step('Comparison:Literal added', node, level=1)
        elif l.is_logical_operator(sub_token):
            node = n.SQLOperator(sub_token)
            parent.add_child(node)
            u.log_parsing_step('Comparison:Operator added', node, level=1)
        elif l.is_subquery(sub_token):
            u.log_parsing_step('Entering Comparison:Subquery...', parent, level=2)
            _handle_subquery(sub_token, parent, last_keyword)
            u.log_parsing_step('...Exiting Comparison:Subquery', parent, level=2)
        else:
            node = n.SQLColumn(sub_token)
            parent.add_child(node)
            u.log_parsing_step('Comparison:Column added', node, level=1)

def _handle_connection(token, parent, last_keyword):
    if last_keyword.match(Keyword, ["ON"]):
        comparison_type = n.SQLRelationship
    elif last_keyword.match(Keyword, ["HAVING"]):
        comparison_type = n.SQLSegment

    if l.is_comparison(token):
        connection_node = comparison_type(token)
        _handle_comparison(token, connection_node, last_keyword)
        parent.add_child(connection_node)
        u.log_parsing_step('Connection added', connection_node, level=1)
    else:
        connection_node = n.SQLNode(token)
        parent.add_child(connection_node)
        u.log_parsing_step('Connection:Unknown added', connection_node, level=0)

def _handle_where(token, parent, last_keyword=None):
    for token in u.clean_tokens(token.tokens):
        if l.is_comparison(token):
            connection_node = n.SQLSegment(token)
            _handle_comparison(token, connection_node, last_keyword)
            parent.add_child(connection_node)
            u.log_parsing_step('Where:Segment added', connection_node, level=1)
        elif l.is_keyword(token):
            keyword_node = n.SQLKeyword(token)
            parent.add_child(keyword_node)
            u.log_parsing_step('Where:Keyword added', keyword_node, level=1)
        elif l.is_logical_operator(token):
            logical_node = n.SQLOperator(token)
            parent.add_child(logical_node)
            u.log_parsing_step('Where:Operator added', logical_node, level=1)
        else:
            node = n.SQLNode(token)
            parent.add_child(node)
            u.log_parsing_step('Where:Unknown added', node, level=0)

def _handle_other(token, parent, last_keyword=None):
    node = n.SQLNode(token)
    parent.add_child(node)
    u.log_parsing_step('Other:Unknown added', node, level=0)

class SQLTree:
    def __init__(self, root_token):
        self.root = n.SQLQuery(root_token)

    def parse_tokens(self, tokens, parent, last_keyword=None):
        return parse_tokens(tokens, parent, last_keyword)
