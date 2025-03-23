
import sqlparse
from sql_parser import (
    parser as s, 
    utils as u,
    node as n
)

def main():

    with open("./sql_parser/scripts/testing.sql") as f:
        parsed = sqlparse.parse(u.normalize_sql(f.read()))
        if not parsed or not parsed[0].tokens:
            raise ValueError("Invalid or empty SQL query.")

    statement = parsed[0]
    tree = s.SQLTree(parsed[0])

    tree.parse_tokens(statement.tokens, tree.root)


if __name__ == "__main__":
    main()
