
from sql_parser import logic as l


HANDLER_MAPPING: dict[l.base.HandlerType, l.base.BaseHandler] = {
    l.base.HandlerType.COLUMN: l.keyword.ColumnHandler(),
    l.base.HandlerType.COMPARISON: l.connection.ComparisonHandler(),
    l.base.HandlerType.CONNECTION: l.connection.ConnectionHandler(),
    l.base.HandlerType.CTE: l.cte.CTEHandler(),
    l.base.HandlerType.FEATURE: l.feature.FeatureHandler(),
    l.base.HandlerType.IDENTIFIER: l.identifier.IdentifierHandler(),
    l.base.HandlerType.KEYWORD: l.base.KeywordHandler(),
    l.base.HandlerType.OPERATOR: l.base.OperatorHandler(),
    l.base.HandlerType.SUBQUERY: l.subquery.SubqueryHandler(),
    l.base.HandlerType.TABLE: l.table.TableHandler(),
    l.base.HandlerType.WHERE: l.where.WhereHandler(),
    l.base.HandlerType.UNKNOWN: l.base.UnknownHandler()
}
