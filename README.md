# SQL Parsing and Query Execution

This project provides tools for parsing SQL queries and executing them on a sample database schema. It includes Python code for parsing SQL queries into a tree structure and a sample SQL script for creating tables and executing queries.

## Files

The project is structured as a Python package named `sqlsim` with the following files:

1. **sqlsim/etl.py**: A Python script that parses SQL queries into a tree structure using the `sqlparse` library.
2. **sqlsim/main.py**: A Python script defining the `SQLNode` and `SQLTree` classes used for building and traversing the parsed SQL query tree.
3. **sqlsim/sample.sql**: A SQL script containing DDL, CTE, and DML statements for a sample database schema.
4. **run.py**: A Python script that utilizes the `sqlsim` package to parse and traverse a SQL query from the `sample.sql` file.

## Getting Started

### Prerequisites

- Python 3.x
- `sqlparse` library
- Any SQL database (e.g., SQLite, PostgreSQL, MySQL) to execute the SQL script

### Installation

1. Clone this repository:
    ```sh
    git clone https://github.com/yourusername/sql-parsing-query-execution.git
    cd sql-parsing-query-execution
    ```

2. Install the required Python package:
    ```sh
    pip install sqlparse
    ```

### Usage

1. **Python Package (sqlsim)**:
    - **sqlsim/etl.py**: The `etl.py` script contains functions to parse SQL queries into a tree structure. The main function is `parse_sql_query(query, statement_idx=0)` which takes a SQL query string as input and returns a parsed tree.

    ```python
    from sqlsim.etl import parse_sql_query

    query = "SELECT * FROM employees WHERE salary > 50000;"
    tree = parse_sql_query(query)
    print(tree)
    ```

    - **sqlsim/main.py**: The `main.py` script defines the `SQLNode` and `SQLTree` classes used for building and traversing the parsed SQL query tree.

    ```python
    from sqlsim.main import SQLNode, SQLTree

    # Example usage of SQLNode and SQLTree
    node = SQLNode("SELECT")
    tree = SQLTree()
    tree.add_node(node)
    tree.traverse()
    ```

2. **SQL Script (sqlsim/sample.sql)**:
    - The `sample.sql` script sets up a sample database schema with tables for `employees`, `departments`, `projects`, and `employee_projects`. It includes example queries and data manipulation statements.

    - To execute the SQL script, run it in your SQL database management tool or use a command-line interface:

    ```sh
    sqlite3 yourdatabase.db < sqlsim/sample.sql
    ```

3. **Run Script (run.py)**:
    - The `run.py` script reads the sample SQL query from `sqlsim/sample.sql`, parses it into a tree structure, and traverses the tree to output its structure.

    ```python
    from sqlsim.etl import parse_sql_query

    if __name__ == '__main__':
        # Read in the sample query
        with open('./sqlsim/sample.sql') as f:
            query = f.read()

        # Parse the statement into a tree
        sql_tree = parse_sql_query(query, statement_idx=0)

        # Output the parsed tree structure
        sql_tree.traverse()
    ```

    - To run the script:

    ```sh
    python run.py
    ```

## Project Structure

- **sqlsim/etl.py**: Contains the following functions:
  - `parse_tokens(tokens, parent)`: Recursively parses SQL tokens into a tree structure.
  - `parse_sql_query(query, statement_idx=0)`: Parses a SQL query string into a tree structure.

- **sqlsim/main.py**: Defines the `SQLNode` and `SQLTree` classes for constructing and traversing the parsed SQL query tree.

- **sqlsim/sample.sql**: Contains SQL statements to:
  - Create tables (`employees`, `departments`, `projects`, `employee_projects`)
  - Define Common Table Expressions (CTEs)
  - Insert data into tables
  - Select data from tables with various conditions and joins

- **run.py**: Utilizes the `sqlsim` package to read, parse, and traverse a SQL query from the `sample.sql` file.

## Contributing

Contributions are welcome! Please fork this repository and submit pull requests for any improvements or bug fixes.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
