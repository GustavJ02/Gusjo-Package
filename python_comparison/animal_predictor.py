import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.neural_network import MLPClassifier

# Load the Animal dataset
df = pd.read_csv('animals.csv')