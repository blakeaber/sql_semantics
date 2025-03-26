# SQL Parser Framework

A modular, extensible framework for parsing SQL queries into rich semantic trees. Designed for advanced SQL analysis, transformation, and lineage extraction.

## 🧠 Overview

This project parses SQL statements into a tree of semantically meaningful nodes, each with type-safe representation (`SQLTable`, `SQLColumn`, `SQLKeyword`, etc.). It supports flexible dispatching of handlers for each type of token, and allows building structured, query-aware data representations (e.g., graphs or triple stores).

## 📦 Modules

### `parser.py`
Defines the main parsing engine through the `SQLTree` class:
- Traverses cleaned SQL tokens.
- Dispatches to appropriate handlers using `HANDLER_MAPPING`.
- Constructs a hierarchical parse tree with typed SQL nodes.

### `nodes.py`
Contains all node classes used to construct the SQL parse tree:
- Base class: `SQLNode`
- Specializations: `SQLTable`, `SQLColumn`, `SQLKeyword`, `SQLQuery`, `SQLCTE`, etc.
- Nodes manage metadata (`token`, `alias`, `uri`, etc.) and parent-child relationships.

### `context.py`
Tracks parsing state with `ParsingContext`:
- Records depth, visited tokens, and semantic triples (subject-predicate-object).
- Enables lineage tracking or conversion to RDF/triple stores.

### `registry.py`
Maps `HandlerType` enums to actual handler implementations.
- Clean separation of concerns.
- Easily extendable with custom handlers.

### `utils.py`
Various utilities for:
- Logging node construction and metadata.
- Cleaning tokens (removes punctuation, whitespace, and problematic keywords like `AS`).
- Short UID hash generation for nodes.
- SQL normalization (via `sqlparse`).

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

## 🧰 Dependencies

- Python 3.7+
- [`sqlparse`](https://github.com/andialbrecht/sqlparse)

```bash
pip install sqlparse
