spark-submit \
--master yarn \
--deploy-mode cluster \
--num-executors 2 \
--archives mnist/mnist.zip#mnist \
/${HOME}/nifi-academy/mnist_data_setup.py \
--output mnist/csv2 \
--format csv2
