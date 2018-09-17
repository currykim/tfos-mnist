spark-submit \
--master yarn \
--queue default \
--deploy-mode cluster \
--queue default \
--num-executors 2 \
--executor-memory 2G \
--py-files $(pwd)/nifi/mnist_dist.py \
--conf spark.dynamicAllocation.enabled=false \
--conf spark.yarn.maxAppAttempts=1 \
--conf spark.streaming.stopGracefullyOnShutdown=true \
--conf spark.executorEnv.HADOOP_HDFS_HOME=/usr/hdp/current/hadoop-hdfs-client \
--conf spark.executorEnv.LD_LIBRARY_PATH="$LIB_HDFS:$LIB_JVM" \
--conf spark.executorEnv.CLASSPATH="$($HADOOP_HOME/bin/hadoop classpath --glob):${CLASSPATH}" \
$(pwd)/nifi/mnist_spark.py \
--images stream_data \
--format csv2 \
--mode inference \
--model /user/yarn/mnist_model \
--output predictions/batch
