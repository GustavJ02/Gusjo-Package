from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.neural_network import MLPClassifier

CSV_PATH = Path('animals.csv')


def load_animals_csv(path: Path) -> pd.DataFrame:
    columns = pd.read_csv(path, nrows=0).columns

    dtype_map = {}
    if len(columns) > 0:
        dtype_map[columns[0]] = np.int32
    if len(columns) > 1:
        dtype_map[columns[1]] = 'category'
    for column in columns[2:]:
        dtype_map[column] = np.float32

    return pd.read_csv(
        path,
        dtype=dtype_map,
        low_memory=True,
        memory_map=True,
    )


# Load the Animal dataset with compact dtypes
df = load_animals_csv(CSV_PATH)