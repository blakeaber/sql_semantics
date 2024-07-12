from sqlsim import etl


if __name__ == '__main__':

    # read in the sample query
    with open('./sqlsim/dml.sql') as f:
        query = f.read()

    # parse the statement into a tree
    sql_tree = etl.parse_sql_query(query, statement_idx=0)

    # Output the parsed tree structure
    sql_tree.root.traverse()
