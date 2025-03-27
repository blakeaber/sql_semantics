
import os
import time
import logging
import argparse
from pathlib import Path
from dotenv import load_dotenv
from openai import OpenAI


logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.StreamHandler()]
)
logger = logging.getLogger(__name__)


def get_prompt(seed_prompt_file=None, input_schema_file=None):
    """Load the schema from file and return the constructed prompt"""
    assert seed_prompt_file, "Must provide path to seed prompt file!"
    assert input_schema_file, "Must provide path to input schema for prompt!"

    with open(seed_prompt_file, "r") as f:
        prompt = f.read()

    with open(input_schema_file, "r") as f:
        schema = f.read()

    logger.info(f"Loaded prompt from {seed_prompt_file} and schema from {input_schema_file}")

    prompt_template = f""" 
    Generate 10 complex and unique SQL queries for machine learning feature extraction.
    {prompt}

    Vary the structure and logic in each query. Output only SQL. Use the schema below:
    {schema}
    """
    return prompt_template


def get_openai_client():
    """Load your OpenAI API key from environment variable"""
    load_dotenv()
    return OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

def get_synthetic_chatgpt_query(base_prompt):
    """Given a prompt, returns a dict(message, error)"""

    client = get_openai_client()

    try:
        response = client.responses.create(
            model="gpt-4o",
            instructions="""
            You are a coding assistant that generates SQL queries as synthetic data.
            Do not wrap the response in code blocks (since the results will be saved to file).
            """,
            input=base_prompt
        )
        return dict(message=response.output_text, error=None)

    except Exception as e:
        return dict(message=None, error=e)


def save_results_to_file(content, batch_id=-1, output_directory=None):
    """Saves results to file; unspecified batch saves to `query_batch_000.sql"""
    assert content, "Content for file must be non-NULL!"
    assert output_directory, "Must provide path to output directory for response!"

    Path(output_directory).mkdir(parents=True, exist_ok=True)

    current_batch = batch_id + 1
    output_file = f"./{output_directory}/query_batch_{current_batch:03d}.sql"

    with open(output_file, "w") as f:
        f.write(content)
    logger.debug(f"Saved file: {output_file}")


def get_synthetic_data(total_queries, max_retries=3):
    """Generate N queries in batches of 10"""
    total_batches = int(total_queries / 10)
    base_prompt = get_prompt(seed_prompt_file=SEED_PROMPT_FILE, input_schema_file=INPUT_SCHEMA_FILE)

    for batch_id in range(total_batches):
        attempt = 0
        while attempt < max_retries:
            response = get_synthetic_chatgpt_query(base_prompt)
            if response['message']:
                save_results_to_file(response['message'], batch_id=batch_id, output_directory=OUTPUT_DIRECTORY)
                logger.info(f"Saved batch {batch_id + 1}")
                time.sleep(1)
                break
            else:
                logger.warning(f"Error in batch {batch_id + 1}, attempt {attempt + 1}: {response['error']}")
                time.sleep(5 + attempt * 5)
                attempt += 1
        else:
            logger.error(f"Failed to generate batch {batch_id + 1} after {max_retries} attempts.")


def main():
    package_root = Path(__file__).parent.parent

    parser = argparse.ArgumentParser(description="Generate synthetic SQL queries with ChatGPT.")
    parser.add_argument("--n", type=int, default=50, help="Total number of queries to generate (multiple of 10)")
    parser.add_argument("--schema", type=str, default=f"{package_root}/data/healthcare/schema.sql", help="Path to schema file")
    parser.add_argument("--prompt", type=str, default=f"{package_root}/data/seed_prompt.txt", help="Path to seed prompt file")
    parser.add_argument("--outdir", type=str, default=f"{package_root}/data/healthcare/queries/", help="Output directory for queries")
    parser.add_argument("--retries", type=int, default=3, help="Max retries per batch")

    args = parser.parse_args()

    # Set globals with args
    global SEED_PROMPT_FILE, INPUT_SCHEMA_FILE, OUTPUT_DIRECTORY

    SEED_PROMPT_FILE = args.prompt
    INPUT_SCHEMA_FILE = args.schema
    OUTPUT_DIRECTORY = args.outdir

    get_synthetic_data(total_queries=args.n, max_retries=args.retries)


if __name__ == "__main__":
    main()
