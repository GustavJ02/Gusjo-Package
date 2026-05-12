# Comparing Python and Ada for training a simple neural network

The problem is to train a simple neural network on the Iris dataset, which consists of 150 samples of iris flowers with 4 features each (sepal length, sepal width, petal length, petal width) and 3 classes (setosa, versicolor, virginica). The goal is to classify the samples into their respective classes based on the features.

In python we use the `pandas` library to load and preprocess the data. We then use `sklearn` to split the data into training and testing sets, and `sklearn.neural_network.MLPClassifier` to train a simple feedforward neural network. Finally, we evaluate the model's accuracy on the test set.

In Ada, we use the `Gusjo` package to load and preprocess the data. We then implement a simple feedforward neural network from scratch, using basic matrix operations for the forward pass and backpropagation. We train the model on the training set and evaluate its accuracy on the test set.

To compare the two implementations, we will time the execution of both and compare their accuracies. To time the runtime of both implementations, we can use the `time` command in the terminal and to get the accuracy, we can use the `accuracy_score` function from `sklearn.metrics` in Python and calculate it manually in Ada.

## Running python code
Running the python code to train the neural network on the Iris dataset:
```bash
time python iris_nn.py
```

This gives the following output:
```
Test Accuracy: 0.9333

real	0m1.242s
user	0m4.945s
sys	    0m0.064s
```

## Running Ada code
First, we need to compile the Ada code using `gprbuild`:
```bash
time gprbuild -P gusjo.gpr usage_examples/iris_nn.adb
```
Running the Ada code to train the neural network on the Iris dataset:
```bash
time ./obj/iris_nn
```

This gives the following output:
```
Loading iris dataset...
Splitting dataset into train/test...
Training NN classifier...
Final test accuracy: 0.9667

real	0m0.268s
user	0m0.264s
sys	    0m0.004s
```

Compiling an optimized version the runtime can be reduced futher:
```bash
gnatmake -P gusjo.gpr usage_examples/iris_nn.adb -cargs -O3 -march=native -gnatn -largs
```
And then run the same code again:
```bash
time ./obj/iris_nn
```

This now gives the following output:
```
Loading iris dataset...
Splitting dataset into train/test...
Training NN classifier...
Final test accuracy: 0.9667

real	0m0.057s
user	0m0.050s
sys	    0m0.008s
```