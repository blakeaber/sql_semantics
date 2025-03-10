
from sql_parser.utils import generate_uid


class SQLTripleExtractor:
    def extract_triples_from_tree(self, node, parent_uid=None, triples=None):
        """Converts SQLTree object into SPO triples with optimized traversal."""
        if triples is None:
            triples = []

        node_uid = generate_uid(node.node_type, node.name, node.table_prefix, node.function)
        self.node_registry[node_uid] = node

        # Define core relationships
        relationships = {
            "Query": ["contains", ["CTE", "Subquery", "Table"]],
            "Feature": ["has", ["Function", "Column"]],
            "Relationship": ["has", ["Comparison"]],
        }

        if parent_uid:
            for key, (relation, valid_types) in relationships.items():
                if parent_uid.startswith(key.lower()) and node.node_type in valid_types:
                    triples.append((parent_uid, relation, node_uid))

        # Recursively process child nodes
        for child in node.children:
            self.extract_triples_from_tree(child, node_uid, triples)

        return triples
