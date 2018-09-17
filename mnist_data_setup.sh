spark-submit \
--master yarn \
--deploy-mode cluster \
--num-executors 2 \
--archives $(pwd)/mnist/mnist.zip#mnist \
$(pwd)/mnist_data_setup.py \
--output mnist/csv2 \
--format csv2
