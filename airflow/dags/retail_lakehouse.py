from datetime import datetime, timezone
from pathlib import Path
import subprocess

import pendulum
from airflow.sdk import dag, task


PROJECT = Path("/mnt/f/Big Data/Retail_Lakehouse_Learning")
SPARK_PYTHON = Path.home() / ".venvs/retail-lakehouse/bin/python"

SILVER_NOTEBOOKS = sorted(
    (PROJECT / "lakehouse/silver").glob("[0-9][0-9]_silver_*.ipynb")
)
GOLD_NOTEBOOKS = sorted(
    (PROJECT / "lakehouse/gold").glob("[0-9][0-9]_gold_*.ipynb")
)
EXPORT_NOTEBOOK = PROJECT / "powerbi/01_export_gold_parquet.ipynb"


def execute_notebook(notebook: Path):
    if not notebook.is_file():
        raise FileNotFoundError(notebook)

    output_dir = Path.home() / "airflow-retail/runs"
    output_dir.mkdir(parents=True, exist_ok=True)
    run_name = datetime.now(timezone.utc).strftime(
        f"{notebook.stem}_%Y%m%dT%H%M%S%f"
    )

    command = [
        str(SPARK_PYTHON),
        "-m", "jupyter", "nbconvert",
        "--to", "notebook",
        "--execute",
        "--ExecutePreprocessor.kernel_name=retail-lakehouse-wsl",
        "--ExecutePreprocessor.timeout=3600",
        "--output", run_name,
        "--output-dir", str(output_dir),
        str(notebook),
    ]

    print(f"Running {notebook}", flush=True)
    subprocess.run(command, check=True, cwd=PROJECT)
    print(f"Saved executed notebook in {output_dir}", flush=True)


@dag(
    dag_id="retail_lakehouse",
    schedule=None,
    start_date=pendulum.datetime(2026, 10, 1, tz="UTC"),
    catchup=False,
    max_active_runs=1,
    tags=["retail", "learning"],
)
def retail_lakehouse():

    @task
    def check_project():
        if not PROJECT.is_dir():
            raise FileNotFoundError(PROJECT)
        if not SPARK_PYTHON.is_file():
            raise FileNotFoundError(SPARK_PYTHON)
        if len(SILVER_NOTEBOOKS) != 9:
            raise RuntimeError(
                f"Expected 9 Silver notebooks; found {len(SILVER_NOTEBOOKS)}"
            )
        if len(GOLD_NOTEBOOKS) != 4:
            raise RuntimeError(
                f"Expected 4 Gold notebooks; found {len(GOLD_NOTEBOOKS)}"
            )
        if not EXPORT_NOTEBOOK.is_file():
            raise FileNotFoundError(EXPORT_NOTEBOOK)
        print("Project, runtime, and all stage notebooks found.")

    @task
    def run_bronze_csv():
        execute_notebook(PROJECT / "lakehouse/bronze/01_bronze_csv.ipynb")

    @task
    def run_bronze_postgres():
        execute_notebook(PROJECT / "lakehouse/bronze/02_bronze_postgres.ipynb")

    @task
    def run_stage_notebook(relative_path: str):
        execute_notebook(PROJECT / relative_path)

    @task
    def export_powerbi():
        execute_notebook(EXPORT_NOTEBOOK)

    previous = check_project()

    bronze_csv = run_bronze_csv()
    previous >> bronze_csv
    previous = bronze_csv

    bronze_postgres = run_bronze_postgres()
    previous >> bronze_postgres
    previous = bronze_postgres

    for notebook in SILVER_NOTEBOOKS + GOLD_NOTEBOOKS:
        relative_path = str(notebook.relative_to(PROJECT))
        task_id = f"run_{notebook.stem[3:]}"
        current = run_stage_notebook.override(task_id=task_id)(relative_path)
        previous >> current
        previous = current

    powerbi_export = export_powerbi()
    previous >> powerbi_export


retail_pipeline = retail_lakehouse()
