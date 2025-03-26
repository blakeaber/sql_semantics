# SQL Parser Framework

A modular, extensible framework for parsing SQL queries into rich semantic trees. Designed for advanced SQL analysis, transformation, and lineage extraction.

## 🧠 Overview

This project parses SQL statements into a tree of semantically meaningful nodes, each with type-safe representation (`SQLTable`, `SQLColumn`, `SQLKeyword`, etc.). It supports flexible dispatching of handlers for each type of token, and allows building structured, query-aware data representations (e.g., graphs or triple stores).

## 📦 Modules

- **`parser.py`** – Parses cleaned SQL tokens into a tree.
- **`nodes.py`** – Typed node classes for various SQL components.
- **`context.py`** – Tracks parsing state and semantic triples.
- **`registry.py`** – Maps handler types to handler classes.
- **`utils.py`** – Helpers for token cleaning, hashing, and logging.

## ✅ Features

- Tree-based SQL parse structure.
- Custom handlers for query components (CTEs, WHERE clauses, joins, features, etc.).
- Semantic triple generation for graph-style analysis.
- Lightweight context tracking.
- Hashable node UIDs for traceability and reproducibility.

## ⚠️ Caveats

- Relies on `sqlparse`, which lacks full SQL grammar support (e.g., edge-case dialects may fail).
- Assumes sequential token handling — non-linear constructs (like lateral joins or certain recursive CTEs) may require custom handler extension.
- Token cleaning aggressively removes `AS` and `Punctuation`, which could interfere with edge-case parsing logic.
- No built-in support for dialect-specific parsing (e.g., BigQuery vs. PostgreSQL).
- Currently fails to parse `SQLFeatures` correctly (e.g. CASE, WINDOW, and FUNCTION statements, represented as SQLColumn)
- Currently fails to parse `SQLSegment` conditions in compound subqueries (e.g. UNION ALL, etc)

## 🚀 Quick Start: Parse SQL into a Tree

```python
from sqlparse import parse
from sql_parser.parser import SQLTree

sql = """
WITH top_customers AS (
    SELECT customer_id, SUM(total) as total_spent
    FROM orders
    GROUP BY customer_id
    HAVING SUM(total) > 1000
)
SELECT c.name, t.total_spent
FROM customers c
JOIN top_customers t ON c.id = t.customer_id
"""

# Parse SQL using sqlparse
tokens = parse(sql)[0].tokens

# Build tree
tree = SQLTree(tokens[0])
tree.parse_tokens(tokens, tree.root)

# Traverse and print tree
tree.root.traverse()
```

#### Example Output
```python
SQLQuery(WITH top_customers AS ( SELECT customer_id, SUM(tot...)
  SQLCTE(top_customers AS ( SELECT customer_id, SUM(total...
    SQLFeature(SUM(total)...)
  SQLKeyword(SELECT...)
  SQLTable(customers...)
  SQLRelationship(JOIN...)

```

## 🔗 Extract Semantic Triples
```python
from sql_parser.context import ParsingContext

context = ParsingContext()
tree.parse_tokens(tokens, tree.root, context)

# Inspect RDF-style triples
for triple in context.triples:
    print(triple)
```

#### Example Output
```python
('sqlquery://None/None/None', 'hasSQLCTE', 'sqlcte://None/top_customers/None')
('sqlcte://None/top_customers/None', 'hasSQLFeature', 'sqlfeature://orders/SUM/total_spent')
```

### 🧩 Extending the Parser
To add a custom handler:

Add a new entry in HandlerType enum.

Create a handler class that inherits from BaseHandler.

Add it to HANDLER_MAPPING in registry.py.

Add recognition logic in get_handler_key() in parser.py.

### 🧪 Testing
You can validate the tree structure, triples, and handlers by:

Asserting node types and parent/child relationships.

Logging parsing steps via log_parsing_step() in utils.py.

Comparing outputs across multiple SQL dialects.

(Note: A test suite is not yet included in this release.)

### 📄 License
MIT License. Contributions welcome!

### 🤝 Contributions
Feel free to open issues, fork the repo, or submit PRs to add dialect support, improve node disambiguation, or extend the semantic model.