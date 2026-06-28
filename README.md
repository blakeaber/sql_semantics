# SQLFlow

A modular, extensible framework for parsing SQL queries into rich semantic trees. Designed for advanced SQL analysis, transformation, and lineage extraction.

## 🧠 Overview

This project parses SQL statements into a tree of semantically meaningful nodes, each with type-safe representation (`SQLTable`, `SQLColumn`, `SQLKeyword`, etc.). It supports flexible dispatching of handlers for each type of token, and allows building structured, query-aware data representations (e.g., graphs or triple stores).

## 📦 Installation
```bash
pip install sqlflow
```

## 🚀 Quick Start: Parse SQL into a Tree

```python
from sqlparse import parse
from sqlflow.parser import SQLTree

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
statement = parse(sql)[0]

# Build tree
tree = SQLTree(statement)
tree.parse_tokens(statement, tree.root)

# Traverse and print tree
tree.root.traverse()
```

#### Example Output
```python
SQLQuery( )
  SQLKeyword(WITH)
  SQLSubquery(top_customers AS (     SELECT customer_id, SUM(tot...)
    SQLTable(top_customers)
    SQLSubquery((     SELECT customer_id, SUM(total) as total_spen...)
      SQLKeyword(SELECT)
      SQLColumn(customer_id)
      SQLColumn(SUM(total) as total_spent)
      SQLKeyword(FROM)
      SQLTable(orders)
      ...
      SQLSegment(SUM(total) > 1000)
        SQLColumn(SUM(total))
        SQLColumn(>)
        SQLLiteral(1000)
  SQLKeyword(SELECT)
  ...
  SQLKeyword(JOIN)
  SQLTable(top_customers t)
  SQLKeyword(ON)
  SQLRelationship(c.id = t.customer_id)
    SQLColumn(c.id)
    SQLColumn(=)
    SQLColumn(t.customer_id)
```

## 🔗 Extract Semantic Triples
```python
from sqlflow.context import ParsingContext

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

### 📦 Modules

- **`parser.py`** – Parses cleaned SQL tokens into a tree.
- **`nodes.py`** – Typed node classes for various SQL components.
- **`context.py`** – Tracks parsing state and semantic triples.
- **`registry.py`** – Maps handler types to handler classes.
- **`utils.py`** – Helpers for token cleaning, hashing, and logging.

### ✅ Features

- Tree-based SQL parse structure.
- Custom handlers for query components (CTEs, WHERE clauses, joins, features, etc.).
- Semantic triple generation for graph-style analysis.
- Lightweight context tracking.
- Hashable node UIDs for traceability and reproducibility.

### ⚠️ Caveats

- Relies on `sqlparse`, which lacks full SQL grammar support (e.g., edge-case dialects may fail).
- Assumes sequential token handling — non-linear constructs (like lateral joins or certain recursive CTEs) may require custom handler extension.
- Token cleaning aggressively removes `AS` and `Punctuation`, which could interfere with edge-case parsing logic.
- No built-in support for dialect-specific parsing (e.g., BigQuery vs. PostgreSQL).
- Currently fails to parse `SQLFeatures` correctly (e.g. CASE, WINDOW, and FUNCTION statements, represented as SQLColumn)
- Currently fails to parse `SQLSegment` conditions in compound subqueries (e.g. UNION ALL, etc)

### 🧩 Extending the Parser
To add a custom handler:
- Add a new entry in HandlerType enum.
- Create a handler class that inherits from BaseHandler.
- Add it to HANDLER_MAPPING in registry.py.
- Add recognition logic in get_handler_key() in parser.py.

### 🧪 Testing
You can validate the tree structure, triples, and handlers by:
- Asserting node types and parent/child relationships.
- Logging parsing steps via log_parsing_step() in utils.py.
- Comparing outputs across multiple SQL dialects.

```bash
pytest
```

(Note: A test suite is only partially complete in this release.)

### 🧩 Optional Features
`sqlflow` supports modular extras for development, semantic graph embedding, and synthetic query generation. You can install these as needed using extras in pip.

#### Synthetic Query Generation
The `sqlgen` bash command is an entrypoint to `sqlflow.cli.generate_queries:main`, which generates queries based on an input prompt. 

Provide a schema.sql representing tables in a particular domain (e.g. healthcare) and generate SQL queries for testing.

```bash
sqlgen --n 500  
```

#### Embedding Generation
The `sqlembed` bash command is an entrypoint to `sqlflow.cli.train_embeddings:main`, which generates embeddings based on an input prompt. 

Provide a triples.txt representing semantic triples generated using the `sqlflow` package.

```bash
sqlembed --walksize 40 --numwalks 20 --window 8
```

#### Development
Includes testing tools for local development.

```bash
pip install "sqlflow[dev]"
```
Installs: 
    pytest – for running tests

#### Synthetic Query Generation
Includes tools for generating and managing synthetic SQL queries, often for fine-tuning or benchmarking.

```bash
pip install "sqlflow[synthetic]"
```
Installs: 
    openai – for GPT-based SQL generation
    python-dotenv – for managing API keys via .env

#### Semantic Graph Embeddings
Includes graph tools for working with semantic RDF-style outputs.

```bash
pip install "sqlflow[semantics]"
```
Installs:
    pecanpy – for fast graph embedding with node2vec-style algorithms

#### Combine Extras
You can install multiple extras together:

```bash
pip install "sqlflow[dev,synthetic,semantics]"
```

## 📄 License
MIT License. Contributions welcome!

## 🤝 Contributions
Feel free to open issues, fork the repo, or submit PRs to add dialect support, improve node disambiguation, or extend the semantic model.

## 📝 Writing

Deep-dives on the ideas behind this project: **[predicate.ventures/writing](https://www.predicate.ventures/writing)**.
