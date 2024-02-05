#!/bin/bash

docker_build_push() {
  local REPOSITORY=$1
  local IMAGE_TAG=$2
  local DOCKERFILE_PATH=$3
  local AWS_REGION=$4
  local AWS_ACCOUNT_ID=$5
  local ECR_REPOSITORY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPOSITORY}:${IMAGE_TAG}"
  echo -e "\nThe Docker build will start on the repository ${REPOSITORY} with the tag ${IMAGE_TAG}."
  cd ${DOCKERFILE_PATH}
  aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
  docker build -t ${REPOSITORY}:${IMAGE_TAG} .
  docker tag ${REPOSITORY}:${IMAGE_TAG} ${ECR_REPOSITORY}
  docker push ${ECR_REPOSITORY}
  echo -e "* ${CURRENT_DATE} - INFO: Image successfully pushed to repository ${ECR_REPOSITORY}."
}

REPOSITORY=""
AWS_REGION=""
DOCKERFILE_PATH=""
IMAGE_TAG=""
CURRENT_DATE=$(date)

for arg in "$@"; do
    case $arg in  
        repository=*)
        REPOSITORY="${arg#*=}"
        shift
        ;;
        aws_region=*)
        AWS_REGION="${arg#*=}"
        shift
        ;;
        dockerfile_path=*)
        DOCKERFILE_PATH="${arg#*=}"
        shift
        ;;
        image_tag=*)
        IMAGE_TAG="${arg#*=}"
        shift
        ;;
        *)
        ;;
    esac
done

REPOSITORY=$(echo "$REPOSITORY" | tr '[:upper:]' '[:lower:]')

if [[ " ${REPOSITORY} " == "" ]]; then
    echo -e "\n----> Please specify a value for repository"
    echo -e "* ${CURRENT_DATE} - ERROR: repository is empty\n"
    exit 1
fi

AWS_REGION=$(echo "$AWS_REGION" | tr '[:upper:]' '[:lower:]')

if [[ " ${AWS_REGION} " == "" ]]; then
    echo -e "\n----> Please specify a region. eg aws_region=us-east-1"
    echo -e "* ${CURRENT_DATE} - ERROR: aws_region is empty\n"
    exit 1
fi

if [[ " ${DOCKERFILE_PATH} " == "" ]]; then
    echo -e "\n----> Please specify a Dockerfile path. eg ./path"
    echo -e "* ${CURRENT_DATE} - ERROR: aws_region is empty\n"
    exit 1
fi

if [[ ! " ${IMAGE_TAG} " == "" ]]; then
    IMAGE_TAG="0.1"
fi

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)

for first_number in {0..10}; do
  if [ ${first_number} -eq 10 ]; then
    for second_number in {0..9}; do
      IMAGE_TAG="${first_number}.${second_number}"
      if ! aws ecr describe-images --repository-name ${REPOSITORY} --image-ids imageTag=${IMAGE_TAG} --region ${AWS_REGION} >/dev/null 2>&1; then
        docker_build_push ${REPOSITORY} ${IMAGE_TAG} ${DOCKERFILE_PATH} ${AWS_REGION} ${AWS_ACCOUNT_ID}
        exit 0
      fi
    done
  else
    for second_number in {1..9}; do
      IMAGE_TAG="${first_number}.${second_number}"
      if ! aws ecr describe-images --repository-name ${REPOSITORY} --image-ids imageTag=${IMAGE_TAG} --region ${AWS_REGION} >/dev/null 2>&1; then
        docker_build_push ${REPOSITORY} ${IMAGE_TAG} ${DOCKERFILE_PATH} ${AWS_REGION} ${AWS_ACCOUNT_ID}
        exit 0
      fi
    done
  fi
done

echo -e "\n* ${CURRENT_DATE} - ERROR: No available tags found for range 0.1 to 10.9"
exit 1
