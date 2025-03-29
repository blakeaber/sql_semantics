import logging
import argparse
from pathlib import Path

import networkx as nx
from node2vec import Node2Vec

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.StreamHandler()]
)
logger = logging.getLogger(__name__)


def build_graph(G: nx.DiGraph, triples_path: str) -> nx.DiGraph:
    """Builds a directed graph from triple file."""
    with open(triples_path, 'r') as f:
        for line in f.readlines():
            s, p, o = line.strip().split('\t')
            G.add_edge(s, p)
            G.add_edge(p, o)
    return G


def n2v_instantiate_model(G: nx.DiGraph, dimensions=128, walk_length=40, num_walks=20, workers=3):
    """Initializes paths and returns Node2Vec model."""
    return Node2Vec(
        G,
        dimensions=dimensions,
        walk_length=walk_length,
        num_walks=num_walks,
        workers=workers,
        quiet=True,
        seed=42
    )


def n2v_train_model(model, window=8, min_count=1, batch_words=4) -> Node2Vec:
    """Trains Node2Vec model."""
    return model.fit(window=window, min_count=min_count, batch_words=batch_words)



def main():
    package_root = Path(__file__).parent.parent

    parser = argparse.ArgumentParser(description="Train Node2Vec on SQL triples.")
    parser.add_argument("--triples", type=str, default="../sqlflow/data/healthcare/triples.txt", help="Path to triples file")
    parser.add_argument("--modelpath", type=str, default=f"{package_root}/data/healthcare/embeddings.kv", help="Embeddings model path")
    parser.add_argument("--dims", type=int, default=128, help="Dimensions")
    parser.add_argument("--walksize", type=int, default=40, help="Walk length")
    parser.add_argument("--numwalks", type=int, default=20, help="Number of walks")
    parser.add_argument("--workers", type=int, default=3, help="Number of CPUs")
    parser.add_argument("--window", type=int, default=8, help="Window size")
    parser.add_argument("--mincount", type=int, default=1, help="Minimum count observed")
    parser.add_argument("--batchwords", type=int, default=4, help="Words per batch")

    args = parser.parse_args()

    logger.info("Building graph...")
    G = nx.DiGraph()
    G = build_graph(G, args.triples)

    logger.info("Instantiating Node2Vec model...")
    model = n2v_instantiate_model(G, dimensions=args.dims, walk_length=args.walksize, num_walks=args.numwalks, workers=args.workers)

    logger.info("Training Node2Vec model...")
    model = n2v_train_model(model, window=args.window, min_count=args.mincount, batch_words=args.batchwords)

    logger.info("Saving Node2Vec model to file...")
    model.wv.save(args.modelpath)

    logger.info(f"Total unique nodes embedded: {len(model.wv.key_to_index.keys())}")


if __name__ == "__main__":
    main()
