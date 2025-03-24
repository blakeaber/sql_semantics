
import os
import json
import pytest
import subprocess

from sql_parser.sql_parser.parser_old import SQLParser
from sql_parser.extractor import SQLTripleExtractor
from sql_parser.utils import generate_uid, normalize_sql

# Sample SQL queries for integration tests
SQL_TEST_QUERIES = [
    {
        "query": "SELECT name, email FROM users WHERE age > 21;",
        "expected_triples": [
            ("query_1", "has", "table:users"),
            ("query_1", "has", "column:users:name"),
            ("query_1", "has", "column:users:email"),
            ("query_1", "has", "comp_123abc"),  # UID will be dynamically generated
        ]
    },
    {
        "query": """
        WITH Sales AS (
            SELECT user_id, SUM(amount) AS total_spent FROM transactions GROUP BY user_id
        )
        SELECT name, total_spent FROM users u JOIN Sales s ON u.id = s.user_id;
        """,
        "expected_triples": [
            ("query_2", "contains", "cte_1"),
            ("cte_1", "has", "table:transactions"),
            ("query_2", "has", "table:users"),
            ("query_2", "has", "table:Sales"),
            ("query_2", "has", "rel_column:users:id_column:Sales:user_id"),
        ]
    }
]


@pytest.mark.parametrize("test_case", SQL_TEST_QUERIES)
def test_end_to_end_sql_parsing(test_case):
    """Tests the full SQL parsing pipeline from tree parsing to triple extraction."""
    sql_query = test_case["query"]
    expected_triples = test_case["expected_triples"]

    # Normalize SQL to remove inconsistencies
    sql_query = normalize_sql(sql_query)

    # Parse SQL into tree
    parser = SQLParser()
    tree = parser.parse_sql(sql_query)
    assert tree is not None, "Parsing failed, tree is None."

    # Extract triples
    extractor = SQLTripleExtractor()
    triples = extractor.extract_triples_from_tree(tree)

    # Validate that expected relationships exist in extracted triples
    for expected in expected_triples:
        assert any(triple[:2] == expected[:2] for triple in triples), f"Missing triple: {expected}"


def test_cli_end_to_end():
    """Tests the full CLI pipeline: parsing, extracting triples, and saving output."""
    sql_query = "SELECT name FROM users WHERE age > 21;"
    
    temp_sql_path = "./tests/input/integration.sql"
    temp_output_path = "./tests/output/temp_output.json"

    # Create temp directory if missing
    os.makedirs(os.path.dirname(temp_sql_path), exist_ok=True)

    # Save query to a temporary file
    with open(temp_sql_path, "w") as f:
        f.write(sql_query)

    # Run CLI command
    result = subprocess.run(
        ["python", "debug_extractor.py", temp_sql_path, "--output", temp_output_path],
        capture_output=True, text=True
    )

    assert "Parsing complete" in result.stdout, "CLI parsing failed."
    
    # Validate JSON output
    with open("/mnt/data/temp_output.json", "r") as f:
        output_data = json.load(f)
    
    assert "triples" in output_data, "CLI output JSON missing 'triples' key."
    assert len(output_data["triples"]) > 0, "No triples extracted in CLI output."
