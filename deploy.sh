#!/bin/bash

echo "===== `date`" | tee -a deploy.log

if [ "$1" == "stop" ]; then
    echo "[WARNING] Stopping the deployment" | tee -a deploy.log
    sudo kubectl delete -f deployment.yaml
    sudo kubectl delete -f env.yaml
    echo "" | tee -a deploy.log
    exit 0
fi

# iterate all files under `target' to find the latest version
files=`ls target/`
max_version=0
max_file=""
for file in $files; do
    version=`echo $file | grep -oE "[0-9]+\.[0-9]+\.[0-9]+"`
    if [ "$version" \> "$max_version" ]; then
        max_version=$version
        max_file=$file
    fi
done
if [ -z $max_file ]; then
    echo "[ERROR] No file to deploy" | tee -a deploy.log
    exit 1
fi
echo "[INFO] Deploying $max_file" | tee -a deploy.log

# build docker image
if [ ! -f Dockerfile ]; then
    echo "[ERROR] Dockerfile not found" | tee -a deploy.log
    exit 1
fi
echo "[INFO] Building docker" | tee -a deploy.log
sudo docker build -t deployment:$max_version --build-arg VERSION=$max_version .
if [ $? -ne 0 ]; then
    echo "[ERROR] Docker build failed" | tee -a deploy.log
    exit 1
fi

# constructing new deployment.yaml by replacing {VERSION} with $max_version
echo "[INFO] Constructing new deployment.yaml" | tee -a deploy.log
touch deployment.yaml
mv deployment.yaml deployment.yaml.old
cat deployment.template.yaml | sed "s/{VERSION}/$max_version/g" > deployment.yaml

# reload if deployment.yaml is different from deployment.yaml.old
if cmp -s deployment.yaml deployment.yaml.old; then
    echo "[INFO] No change in deployment.yaml" | tee -a deploy.log
    echo "[WARNING] Deleting previous deployment" | tee -a deploy.log
    echo "sudo kubectl delete -f deployment.yaml" | tee -a deploy.log
    sudo kubectl delete -f deployment.yaml
fi
rm deployment.yaml.old

# apply new deployment.yaml
echo "[INFO] Applying deployment.yaml" | tee -a deploy.log
sudo kubectl apply -f env.yaml
if [ $? -ne 0 ]; then
    echo "[ERROR] Failed to apply env.yaml" | tee -a deploy.log
    exit 1
fi
sudo kubectl apply -f deployment.yaml
if [ $? -ne 0 ]; then
    echo "[ERROR] Failed to apply deployment.yaml" | tee -a deploy.log
    exit 1
fi

echo "[INFO] Completed deployment of $max_version" | tee -a deploy.log
echo "" | tee -a deploy.log
