
from sql_parser.logic.base import HandlerType, BaseHandler, KeywordHandler, OperatorHandler, LiteralHandler, UnknownHandler
from sql_parser.logic.column import ColumnHandler
from sql_parser.logic.connection import ComparisonHandler, ConnectionHandler
from sql_parser.logic.cte import CTEHandler
from sql_parser.logic.feature import FeatureHandler
from sql_parser.logic.identifier import IdentifierHandler
from sql_parser.logic.subquery import SubqueryHandler
from sql_parser.logic.table import TableHandler
from sql_parser.logic.where import WhereHandler


HANDLER_MAPPING = {
    HandlerType.COLUMN: ColumnHandler(),
    HandlerType.COMPARISON: ComparisonHandler(),
    HandlerType.CONNECTION: ConnectionHandler(),
    HandlerType.CTE: CTEHandler(),
    HandlerType.FEATURE: FeatureHandler(),
    HandlerType.IDENTIFIER: IdentifierHandler(),
    HandlerType.KEYWORD: KeywordHandler(),
    HandlerType.LITERAL: LiteralHandler(),
    HandlerType.OPERATOR: OperatorHandler(),
    HandlerType.SUBQUERY: SubqueryHandler(),
    HandlerType.TABLE: TableHandler(),
    HandlerType.WHERE: WhereHandler(),
    HandlerType.UNKNOWN: UnknownHandler()
}
