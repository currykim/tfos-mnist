#!/bin/bash

curl https://repo.anaconda.com/archive/Anaconda2-5.2.0-Linux-x86_64.sh -o /tmp/conda2.sh

chmod o+x /tmp/conda2.sh -b -p /opt/anaconda2

export PATH=/opt/anaconda2/bin:$PATH

rm /tmp/conda2.sh
