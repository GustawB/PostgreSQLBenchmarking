import xml.dom.minidom
from subprocess import run
import json
from pathlib import Path
from time import sleep

def create_config(db: str, terminals: int, time: int, path: str):
    url = f'jdbc:postgresql:///?service=benchmark_tpcc&dbname={db}&rewriteBatchedInserts=true'
    docs = xml.dom.minidom.parse('/home/staff/mim/gb448194/Desktop/benchbase/config/postgres/sample_tpcc_config.xml')
    docs.getElementsByTagName("url")[0].childNodes[0].nodeValue = url
    docs.getElementsByTagName("terminals")[0].childNodes[0].nodeValue = str(terminals)
    docs.getElementsByTagName("time")[0].childNodes[0].nodeValue = str(time)
    docs.getElementsByTagName("scalefactor")[0].childNodes[0].nodeValue = str(1000)


    xml_string = docs.toprettyxml(indent='  ', encoding='utf-8')

    with open(path, "wb") as f:
        f.write(xml_string)


def get_results_json(base_path: str) -> dict:
    results_dir = Path(base_path)
    summary_files = list(results_dir.glob("*summary.json"))
    target_file = summary_files[0]
    with open(target_file, 'r') as f:
        result = json.load(f)
    return result


def run_benchmark(db: str):
    terminals = [2, 1, 10, 20, 30, 40, 50, 60, 70]
    #terminals = [60]
    time = 1200

    for t in terminals:
        create_config(db, t, time, '/home/staff/mim/gb448194/Desktop/benchbase/target/benchbase-postgres/benchmark_config.xml')
        run(['java', '-jar', '/home/staff/mim/gb448194/Desktop/benchbase/target/benchbase-postgres/benchbase.jar', '-b', 'tpcc', '-c', '/home/staff/mim/gb448194/Desktop/benchbase/target/benchbase-postgres/benchmark_config.xml', '--create=false', '--load=false', '--execute=true', '-d', f'results_{db}_term{t}/'], cwd = '/home/staff/mim/gb448194/Desktop/benchbase/target/benchbase-postgres')
        sleep(120)


def run_all():
    dbs = ['raidhdd', 'ssd']
    for db in dbs:
        run_benchmark(db)
        sleep(120)


run_all()
