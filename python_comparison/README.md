# Comparing Python and Ada for training a simple neural network

The problem is to train a simple neural network on the Iris dataset, which consists of 150 samples of iris flowers with 4 features each (sepal length, sepal width, petal length, petal width) and 3 classes (setosa, versicolor, virginica). The goal is to classify the samples into their respective classes based on the features.

In python we use the `pandas` library to load and preprocess the data. We then use `sklearn` to split the data into training and testing sets, and `sklearn.neural_network.MLPClassifier` to train a simple feedforward neural network. Finally, we evaluate the model's accuracy on the test set.

In Ada, we use the `Gusjo` package to load and preprocess the data. We then implement a simple feedforward neural network from scratch, using basic matrix operations for the forward pass and backpropagation. We train the model on the training set and evaluate its accuracy on the test set.

To compare the two implementations, we will time the execution of both by using the `hyperfine` command in the terminal.

## Running python code
Running the python code to train the neural network on the Iris dataset:
```bash
hyperfine 'python iris_nn.py'
```

This gives the following output:
```
Benchmark 1: python iris_nn.py
  Time (mean ± σ):     984.9 ms ±  23.0 ms    [User: 3677.4 ms, System: 47.4 ms]
  Range (min … max):   960.0 ms … 1036.7 ms    10 runs
```

## Running Ada code
First, we need to compile the Ada code using `gprbuild`:
```bash
gprbuild -P gusjo.gpr usage_examples/iris_nn.adb
```
Running the Ada code to train the neural network on the Iris dataset:
```bash
hyperfine './obj/iris_nn'
```

This gives the following output:
```
Benchmark 1: ./obj/iris_nn
  Time (mean ± σ):     258.4 ms ±   4.8 ms    [User: 256.2 ms, System: 2.3 ms]
  Range (min … max):   252.0 ms … 266.4 ms    11 runs
```

Compiling an optimized version the runtime can be reduced futher:
```bash
gnatmake -P gusjo.gpr usage_examples/iris_nn.adb -cargs -O3
```
And then run the same code again:
```bash
hyperfine './obj/iris_nn'
```

This now gives the following output:
```
Benchmark 1: ./obj/iris_nn
  Time (mean ± σ):      30.0 ms ±   3.4 ms    [User: 27.8 ms, System: 2.3 ms]
  Range (min … max):    26.0 ms …  45.4 ms    94 runs
```