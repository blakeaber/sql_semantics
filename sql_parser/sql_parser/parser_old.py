import logging
import sqlparse
from sqlparse.sql import Identifier, Function, Case, Where, Parenthesis
from sqlparse.tokens import Keyword, DML
from .node import SQLNode, SQLTable, SQLColumn, SQLFeature, SQLSegment
from .utils import extract_comparison

logger = logging.getLogger(__name__)


def parse_sql_to_tree(sql):
    """Ensures function matches test imports."""
    parser = SQLParser()
    return parser.parse_sql(sql)


class SQLParser:
    """Parses SQL queries into a structured tree representation."""

    def __init__(self):
        self.query_counter = 0  # Track unique queries

    def parse_sql(self, sql):
        """Parses an SQL query into a hierarchical tree, handling exceptions."""
        try:
            parsed = sqlparse.parse(sql)
            if not parsed or not parsed[0].tokens:
                raise ValueError("Invalid or empty SQL query.")

            root = SQLSegment(f"query_{self.query_counter}", "Query")
            self.query_counter += 1
            for statement in parsed:
                self.parse_tokens(statement.tokens, root)

            return root
        except Exception as e:
            logger.error(f"Error parsing SQL: {e}")
            return None

    def parse_tokens(self, tokens, context_node):
        """Traverses and parses SQL tokens into structured nodes."""
        current_keyword_node = None
        for token in tokens:
            if token.is_whitespace or token.ttype is None:
                continue

            if token.is_keyword:
                current_keyword_node = n.SQLKeyword(token)
                context_node.add_child(current_keyword_node)
                continue

            if token.match(DML, "SELECT"):
                self.handle_select(token, context_node)
            elif token.match(Keyword, "FROM"):
                self.handle_from(token, context_node)
            elif token.match(Keyword, "WHERE"):
                self.handle_where(token, context_node)
            elif token.match(Keyword, "HAVING"):
                self.handle_having(token, context_node)
            elif token.match(Keyword, "WITH"):
                self.handle_cte(token, context_node)
            elif token.match(Keyword, "ORDER BY") or token.match(Keyword, "LIMIT") or token.match(Keyword, "OFFSET"):
                self.handle_order_limit_offset(token, context_node)
            elif isinstance(token, Function) and "OVER" in token.value:
                self.handle_window_function(token, context_node)
            elif isinstance(token, Case):
                self.handle_case_statement(token, context_node)
            elif isinstance(token, Parenthesis):
                self.handle_subquery(token, context_node)
            elif token.is_group:
                self.parse_tokens(token.tokens, context_node)
            else:
                context_node.add_child(SQLNode(token.value, "Unknown"))

    def handle_select(self, token, context_node):
        """Handles SELECT statements and extracts columns."""
        select_node = SQLSegment("SELECT", "Select")
        context_node.add_child(select_node)
        for sub_token in token.tokens:
            if isinstance(sub_token, Identifier):
                column_node = SQLColumn(sub_token)
                select_node.add_child(column_node)

    def handle_from(self, token, context_node):
        """Handles FROM clause and extracts table references."""
        from_node = SQLSegment("FROM", "FromClause")
        context_node.add_child(from_node)
        for sub_token in token.tokens:
            if isinstance(sub_token, Identifier):
                table_node = SQLTable(sub_token)
                from_node.add_child(table_node)

    def handle_where(self, token, context_node):
        """Handles WHERE clauses and extracts conditions."""
        where_node = SQLSegment("WHERE", "WhereClause")
        context_node.add_child(where_node)
        for sub_token in token.tokens:
            if isinstance(sub_token, Where):
                comparison = extract_comparison(sub_token)
                condition_node = SQLSegment(f"{comparison}", "Condition")
                where_node.add_child(condition_node)

    def handle_having(self, token, context_node):
        """Handles HAVING clauses and extracts conditions."""
        having_node = SQLSegment("HAVING", "HavingClause")
        context_node.add_child(having_node)
        for sub_token in token.tokens:
            if isinstance(sub_token, Where):
                comparison = extract_comparison(sub_token)
                condition_node = SQLSegment(f"{comparison}", "Condition")
                having_node.add_child(condition_node)

    def handle_cte(self, token, context_node):
        """Handles Common Table Expressions (CTEs)."""
        cte_node = SQLSegment("CTE", "CTE")
        context_node.add_child(cte_node)
        for sub_token in token.tokens:
            if isinstance(sub_token, Parenthesis):
                self.handle_subquery(sub_token, cte_node)

    def handle_window_function(self, token, context_node):
        """Handles window functions (e.g., ROW_NUMBER(), RANK())."""
        function_name = token.get_real_name()
        window_node = SQLFeature(function_name, "WindowFunction")
        context_node.add_child(window_node)
        for sub_token in token.tokens:
            if sub_token.match(Keyword, "PARTITION BY"):
                partition_node = SQLSegment("PARTITION BY", "PartitionClause")
                window_node.add_child(partition_node)
            elif sub_token.match(Keyword, "ORDER BY"):
                order_node = SQLSegment("ORDER BY", "OrderingClause")
                window_node.add_child(order_node)

    def handle_case_statement(self, token, context_node):
        """Handles CASE statements and extracts conditions."""
        case_node = SQLFeature("CASE", "CaseStatement")
        context_node.add_child(case_node)
        for sub_token in token.tokens:
            if sub_token.match(Keyword, "WHEN"):
                when_condition = extract_comparison(sub_token)
                when_node = SQLSegment(f"WHEN {when_condition}", "CaseCondition")
                case_node.add_child(when_node)
            elif sub_token.match(Keyword, "THEN"):
                then_value = sub_token.get_real_name()
                then_node = SQLSegment(f"THEN {then_value}", "CaseResult")
                case_node.add_child(then_node)
            elif sub_token.match(Keyword, "ELSE"):
                else_value = sub_token.get_real_name()
                else_node = SQLSegment(f"ELSE {else_value}", "CaseDefault")
                case_node.add_child(else_node)

    def handle_subquery(self, token, context_node):
        """Handles nested subqueries."""
        subquery_node = SQLSegment("SubQuery", "Subquery")
        context_node.add_child(subquery_node)
        self.parse_tokens(token.tokens, subquery_node)

    def handle_order_limit_offset(self, token, context_node):
        """Handles ORDER BY, LIMIT, and OFFSET clauses."""
        for sub_token in token.tokens:
            if sub_token.match(Keyword, "ORDER BY"):
                order_node = SQLSegment("ORDER BY", "OrderingClause")
                context_node.add_child(order_node)
            elif sub_token.match(Keyword, "LIMIT"):
                limit_node = SQLSegment(f"LIMIT {sub_token.get_real_name()}", "LimitClause")
                context_node.add_child(limit_node)
            elif sub_token.match(Keyword, "OFFSET"):
                offset_node = SQLSegment(f"OFFSET {sub_token.get_real_name()}", "OffsetClause")
                context_node.add_child(offset_node)
