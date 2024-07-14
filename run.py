import sqlparse
from sqlsim import structure as s


def parse_sql_query(query, idx=0):
    parsed = sqlparse.parse(query)
    if not parsed:
        return None
    else:
        parsed = parsed[idx]
    
    tree = s.SQLTree(parsed)
    tree.parse_tokens(parsed.tokens, tree.root)
    return tree


if __name__ == '__main__':

    # read in the sample query
    with open('./sqlsim/sample.sql') as f:
        query = f.read()

    # parse the statement into a tree
    sql_tree = parse_sql_query(query, idx=5)

    # Output the parsed tree structure
    sql_tree.root.traverse()

    def traverse_and_collect_nodes_edges(node, nodes, edges, parent_index=None):
        current_index = len(nodes)
        nodes.append(node)
        
        if parent_index is not None:
            edges.append((parent_index, current_index))
        
        for child in node.children:
            traverse_and_collect_nodes_edges(child, nodes, edges, current_index)

    nodes = []
    edges = []
    traverse_and_collect_nodes_edges(sql_tree.root, nodes, edges)
    print(nodes)
    print()
    print(edges)


    import torch
    from torch_geometric.data import Data

    # Assuming nodes are just indices here, but you could have features extracted from SQLNodes
    node_features = torch.eye(len(nodes))  # Identity matrix as feature placeholder

    # Convert edges to a tensor
    edge_index = torch.tensor(edges, dtype=torch.long).t().contiguous()

    # Create a PyTorch Geometric graph
    graph = Data(x=node_features, edge_index=edge_index)

    print(graph)