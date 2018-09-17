# NiFi-Spark-Tensorflow MNIST 필기체 인식

## Requirements
1. Python 2.7.x
2. Spark 2.x 
3. Yarn으로 구성된 Spark Cluster
4. 각 노드에서 HDFS에 접근가능



## 1. Tensorflow 설치


각 Spark 클러스터에 아래 쉘 명령어를 통해 `Anaconda python 2.7` 배포판 을 설치합니다.

클러스터 노드가 다수일 경우 `pssh` 유틸을 사용하거나 아래처럼 실행한다면 쉽게 설치할 수 있습니다.
```bash
### 노드 호스트를 입력해줍니다 (node1, node2, node3)
hosts=( node1 node2 node3 ); \
for n in "${hosts[@]}"; \
do ssh $n \
    "curl https://repo.anaconda.com/archive/Anaconda2-5.2.0-Linux-x86_64.sh -o /tmp/conda2.sh && \
	chmod o+x /tmp/conda2.sh -b -p /opt/anaconda2 && \
	echo export PATH=/opt/anaconda2/bin:$PATH >> ~/.bashrc && \
	rm /tmp/conda2.sh";
done
```
`Python Version` : 2.7
`설치경로` : /opt/anaconda3

설치가 완료되면 각 노드의 `python`버전을 확인합니다.

```bash
python -version
```
이제 `Tensorflow`를 설치합니다. 동일하게 `python`이 설치된 노드에 `pip`명령을 통해 설치할 수 있습니다.

```bash
hosts=( node1 node2 node3 ); \
for n in "${hosts[@]}"; \
do ssh $n "$(which pip) install tensorflow"; \
done
```


## 2. TensorflowOnSpark 설치

`TensorflowOnSpark`를 설치합니다. 각 노드에서 `pip` 명령으로 설치할 수 있습니다.
```bash
hosts=( node1 node2 node3 ); \
for n in "${hosts[@]}"; \
do ssh $n "$(which pip) install tensorflowonspark"; \
done
```



## 3. MNIST 데이터셋 준비

```bash
git clone https://github.com/sundobu/tfos-mnist.git
cd tfos-mnist
curl -O "http://yann.lecun.com/exdb/mnist/train-images-idx3-ubyte.gz"
curl -O "http://yann.lecun.com/exdb/mnist/train-labels-idx1-ubyte.gz"
curl -O "http://yann.lecun.com/exdb/mnist/t10k-images-idx3-ubyte.gz"
curl -O "http://yann.lecun.com/exdb/mnist/t10k-labels-idx1-ubyte.gz"
zip -r mnist.zip *.gz
```
학습할 이미지 데이터를 생성하였으므로 모든 노드가 동일하게 데이터를 share하기 위해 `HDFS`상에 이미지 데이터를 올립니다.
아래 명령어를 통해 `HDFS`홈 디렉토리에 `/mnist/csv2` 경로로 `train`, `test` 데이터를 분류하여 저장합니다.
```bash
vi mnist_data_setup.sh
---------------------------------
spark-submit \
--master yarn \
--deploy-mode cluster \
--num-executors 2 \
--archives $(pwd)/mnist.zip#mnist \
$(pwd)/mnist_data_setup.py \
--output mnist/csv2 \
--format csv2
---------------------------------
sh mnist_data_setup.sh
```



## 4. 학습 및 Checkpoint 생성

준비된 `mnist/csv2/train` 데이터를 가지고 `Tensorflow`를 통해 학습을 진행합니다.
아래처럼 명령어를 실행하거나 `train.sh` 스크립트를 실행하여 `Spark Streaming`을 시작합니다.

`--num-executors` : 학습 수행 노드 갯수를 지정
`--executor-memory` : 메모리 지정 (1G, 4G ...)
`--images` : 학습 이미지를 담을 경로
`--model` : 학습된 모델, 체크포인트 저장 경로

```bash
vi train.sh
---------------------------------
spark-submit \
--master yarn \
--deploy-mode cluster \
--queue default \
--num-executors 2 \
--executor-memory 1G \
--py-files $(pwd)/TensorFlowOnSpark/examples/mnist/streaming/mnist_dist.py \
--conf spark.dynamicAllocation.enabled=false \
--conf spark.yarn.maxAppAttempts=1 \
--conf spark.streaming.stopGracefullyOnShutdown=true \
--conf spark.executorEnv.HADOOP_HDFS_HOME=/usr/hdp/current/hadoop-hdfs-client \
--conf spark.executorEnv.LD_LIBRARY_PATH="$LIB_HDFS:$LIB_JVM" \
--conf spark.executorEnv.CLASSPATH="$($HADOOP_HOME/bin/hadoop classpath --glob):${CLASSPATH}" \
$(pwd)/TensorFlowOnSpark/examples/mnist/streaming/mnist_spark.py \
--images stream_data \
--format csv2 \
--mode train \
--model mnist_model
---------------------------------
sh train.sh
```
`Spark streaming`이 시작되면 아래처럼 이미지 파일들을 `--images stream_data` 경로에 옮깁니다.
```bash
hdfs dfs -cp mnist/csv2/train/part-* stream_data
```
`--model mnist_model` 디렉토리로 학습된 `model` 및 `chkpt`파일이 생성됩니다.

※ `permission error` 발생 시, `--model mnist_model` 경로를 `--model /user/$(whoami)/mnist_model`로 변경

###4.1 종료
학습 및 `Spark streaming`을 종료시키려면 아래처럼 `stop_streaming.sh` 을 실행시킵니다.
Reservation Port, Host 는 `SparkUI`상의 `dirver log`를 통해 확인할 수 있습니다.

`<IP>` : Reservation Host
`<Port>` : Reservation Port

```bash
sh stop_streaming.sh <IP> <Port>
```



## 5. Inference

`NiFi`를 통해 변환된 `필기체 이미지 CSV` 파일을 업로드시켜 결과를 확인합니다.
`nifi/stream.sh` 을 실행시키고 `stream_data`에 `CSV`파일을 업로드시킵니다.

`--num-executors` : 노드 갯수를 지정
`--executor-memory` : 메모리 지정 (1G, 4G ...)
`--images` : CSV 파일 업로드 경로
`--model` : 학습된 model, chkpt 경로
`--output` : 예측결과

```bash
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
--model mnist_model \
--output predictions/batch
```
아래 처럼 `predictions/batch` 경로를 확인하여 결과를 조회합니다.
```bash
hdfs dfs -cat predictions/batch-*/part-*
```

마찬가지로 `inference` 및 `spark streaming`을 종료시키기 위해서 `stop_streaming.sh` 을 실행시킵니다.

```bash
sh stop_streaming.sh <IP> <Port>
```