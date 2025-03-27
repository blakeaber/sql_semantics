
from sqlflow.handlers.base import HandlerType, BaseHandler, KeywordHandler, OperatorHandler, LiteralHandler, UnknownHandler
from sqlflow.handlers.column import ColumnHandler
from sqlflow.handlers.connection import ComparisonHandler, ConnectionHandler
from sqlflow.handlers.cte import CTEHandler
from sqlflow.handlers.feature import FeatureHandler
from sqlflow.handlers.identifier import IdentifierHandler
from sqlflow.handlers.subquery import SubqueryHandler
from sqlflow.handlers.table import TableHandler
from sqlflow.handlers.where import WhereHandler


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
