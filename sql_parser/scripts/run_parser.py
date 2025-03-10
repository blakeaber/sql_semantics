
import json
import argparse

from sql_parser.utils import normalize_sql
from sql_parser.parser import parse_sql_to_tree
from sql_parser.extractor import SQLTripleExtractor


def main():
    sql_query = normalize_sql(sql_query)  # Clean the SQL query

    if not sql_query:
        print("Error: Empty or invalid SQL query.")
        return


def main():
    parser = argparse.ArgumentParser(description="SQL Query Parser CLI")
    parser.add_argument("sql_file", type=str, help="Path to SQL file to parse")
    parser.add_argument("--output", type=str, default="output.json", help="Output file for extracted triples")
    parser.add_argument("--verbose", action="store_true", help="Enable verbose mode for debugging")

    args = parser.parse_args()

    # Read SQL query from file
    try:
        with open(args.sql_file, "r") as file:
            sql_query = file.read().strip()

        sql_query = normalize_sql(sql_query)  # Clean the SQL query

        if not sql_query:
            print("Error: Empty or invalid SQL query.")
            return
    except FileNotFoundError:
        print(f"Error: File {args.sql_file} not found.")
        return

    if args.verbose:
        print(f"\nParsing SQL Query from {args.sql_file}...\n")
        print(sql_query)
        print("\nGenerating Parse Tree...\n")

    # Parse SQL
    parsed_tree = parse_sql_to_tree(sql_query)

    if args.verbose:
        print(parsed_tree)  # Print the hierarchical tree representation

    # Extract RDF-style triples
    extractor = SQLTripleExtractor()
    triples = extractor.extract_triples_from_tree(parsed_tree)

    if args.verbose:
        print("\nExtracted Relationships (Triples):")
        for triple in triples:
            print(" - ".join(triple))

    # Save triples to JSON
    output_data = {
        "sql_query": sql_query,
        "triples": triples
    }

    with open(args.output, "w") as outfile:
        json.dump(output_data, outfile, indent=4)

    print(f"\nParsing complete. Results saved to {args.output}")

if __name__ == "__main__":
    main()
