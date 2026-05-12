import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split

# Load the Iris dataset
df = pd.read_csv('iris.csv').drop(columns=['Id'])

# Prepare the data
X = df.drop('Species', axis=1).values
y = df['Species'].values


# Split the data into training and testing sets
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

# Build a simple neural network using sklearn
from sklearn.neural_network import MLPClassifier

model = MLPClassifier(hidden_layer_sizes=(10,), activation='relu', solver='adam', 
                      batch_size=5, max_iter=1000, random_state=42)

# Train the model
model.fit(X_train, y_train)

# Evaluate the model
accuracy = model.score(X_test, y_test)
print(f'Test Accuracy: {accuracy:.4f}')