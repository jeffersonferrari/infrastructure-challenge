# infrastructure-challenge
Attached with this challenge, you will find a simple Python - Flask Web App, which reads the current RAM and CPU usage and a React frontend which shows the statistics in the browser.

# How to run?
The app is setup in a pretty standard way, just like most Python-React Apps.

## Python Backend
> Python Version used: 3.11.3 (installed with pyenv)
In the api directory, do the following.
1. `pip install -r requirements.txt`
2. `python app.py`
3. Visit [this](http://localhost:8080/stats)

## React Frontend
> Node version used: v16.20.1 (installed with nvm)
In the sys-stats directory, do the following.
1. `npm install`
2. `npm start`
> Tip: on `src/app.js` you can find the fetch to the backend.

Kindly create a different branch, do not use `main`.

# Task 1 - Dockerize the Application
The first task is to dockerise this application - as part of this task you will have to get the application to work with Docker. You can expose the frontend using NGINX or HaProxy.

The React container should also perform npm build every time it is built. 
Create 3 separate containers. 1 for the backend, 2nd for the proxy and 3rd for the react frontend.

It is expected that you create another small document/walkthrough or readme which helps us understand your thinking process behind all of the decisions you made.

You will be evaluated based on the:
* best practices
* ease of use
* quality of the documentation provided with the code

## Building Images

First, I chose to use an automated process to build and push the images to ECR. For this, I used a GitHub Actions pipeline that builds the images whenever a new PR is opened in this repository. When the merge to `main` is done, it should build and push the images to the `python-api` and `node-frontend` ECR repositories. The names of these repositories can be easily changed in the pipeline matrix.

To grant GitHub the necessary permissions for pushing images, we'll use GitHub OpenID. For this purpose, I've built a module that will grant the required permissions for this repository. After deploying this module, you'll need to add the role ARN from the pipeline into `role-to-assume`.

Anyway, if it's not possible to use GitHub OpenID, I've created a script located in the root of this project with the name `docker_build_push.sh` to facilitate the build and push of Docker images.
Before using the script, you'll need to install the [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) and [configure](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html) the necessary permissions where the push will be performed.

Example of usage for the script:

```shell
./docker_build_push.sh repository=flask-api aws_region=eu-west-1 dockerfile_path=./api/
```

| Name | Description | Required |
|------|-------------|:--------:|
| repository | Repository ECR name | yes |
| aws_region | AWS region where the script will work | yes |
| dockerfile_path | Path where the Dockerfile is located | yes |
| image_tag | Tag for the image; if no tag is specified, it will try to use tags from 0.1 to 10.9 | no |

## Terraform

After the process of building and pushing the images to your ECR repository, we will deploy them to [ECS](https://github.com/Aily-Labs/infrastructure-challenge/blob/a0d095686fa76e9bd1662ae01294bad42a344385/terraform/main.tf#L20).

For this, I've added 3 new modules that can be found in `./terraform/modules`. The ECR module is responsible for creating the repositories in your desired AWS ECR account, and the ECS module will deploy the images in your account.

On the ECS module, you can configure the infrastructure without deploying the containers by simply ignoring the variables `frontend_docker_image` and `flask_api_docker_image`. This is because you will need to create your repositories in ECR first before deploying the images to ECS. Alternatively, you can temporarily remove this module from `./terraform/main.tf` while creating the repositories on ECR and then add it back.

You will also need to provide three variables from ECS module: `vpc_id`, `subnets_id`, and `ecr_repositories_arn`. You can find more information about these variables [here](https://github.com/jeffersonferrari/infrastructure-challenge/blob/origin/jefferson_ferrari_test/terraform/modules/ecs/README.md).

With that said, you will need to [configure your AWS credentials](https://registry.terraform.io/providers/hashicorp/aws/latest/docs) with permissions to deploy this on your AWS account. You don't need to worry about the provider version since it's already defined [here](https://github.com/jeffersonferrari/infrastructure-challenge/blob/cada9d87f07cec9977edd545426526461729811f/terraform/provider.tf#L5).

# Task 2 - Deploy on AWS with terraform
It's important to remember here that the application is already containerize, maybe
you could deploy it to services which take an advantage of that fact. (example, AWS
EC2 or ECS?)
The React App should be accessible on a public URL.
Use the best practices for exposing the cloud VM to the internet, block access to
unused ports, add a static IP (elastic IP for AWS), create proper IAM users and
configure the app exactly how you would in production.

Hints:
* It is acceptable the use of other tools like Ansible for some tasks.
* Terraform code is not expected to fully work, the purpose of this exercise is to validate terraform skills and AWS Service knowledge.
* You can assume some bootstraping of the account is already in place, like VPC.

You will be evaluated based on the:
* terraform code
* best practices
* quality of the documentation provided with the code

# Task 3 - Get it to work with Kubernetes
Next step is completely separate from step 2. 
Go back to the application you built-in Stage 1 and get it to work with Kubernetes.
Separate out the two containers into separate pods, communicate between the two containers, add a load balancer (or equivalent), expose the final App over port 80 to the final user (and any other tertiary tasks you might need to do)

Describe the process to:
1. Boostrap the cluster
2. Create the Deployment, Service, RBAC, etc. to make the app work
3. (extra) How to manage the continuous deployment with FluxCD / ArgoCD

Hints:
* You can use tools like `minikube` / `kind` to have the cluster working locally

You will be evaluated based on the:
* best practices
* quality of the documentation provided

## Minikube installation

All tests were performed on an EC2 instance `t3a.small` with `ubuntu 22.04`.

To set up minikube for deploying the applications, I created a script to automate this task, which can be found in `./kubernetes/minikube.sh`.
This script accepts a parameter with two options, `install=docker` which is useful if you don't have docker installed, and then `install=minikube`.

Example of usage for the script:

```shell
./minikube.sh install=docker

./minikube.sh install=minikube
```

After running the minikube installation, we are ready to deploy the applications.
First, you need to ensure that your images are available on the machine. You can import any image using the command `minikube image load nginx:latest`. In my case, I used images from ECR, so I first configured my instance profile to have access to my ECR repositories and then [logged](https://docs.aws.amazon.com/AmazonECR/latest/userguide/getting-started-cli.html#cli-authenticate-registry) in.

After obtaining the images in your cluster, it will be necessary to update the deployment YAML with the [frontend](https://github.com/jeffersonferrari/infrastructure-challenge/blob/a14b3f4d3c85dd6759332698a8c70e604ac008c2/kubernetes/infrastructure-challenge.yaml#L24) and [API](https://github.com/jeffersonferrari/infrastructure-challenge/blob/a14b3f4d3c85dd6759332698a8c70e604ac008c2/kubernetes/infrastructure-challenge.yaml#L28) images.

Example:

```shell
minikube image load ************.dkr.ecr.eu-west-1.amazonaws.com/frontend:0.1
minikube image load ************.dkr.ecr.eu-west-1.amazonaws.com/flask-api:0.1

kubectl apply -f infrastructure-challenge.yaml

kubectl get svc -n infrastructure-challenge
NAME               TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
sysstats-service   NodePort   10.108.251.23   <none>        80:31169/TCP   133m

minikube service sysstats-service --url -n infrastructure-challenge
http://192.168.49.2:31169

curl -i http://192.168.49.2:31169
HTTP/1.1 200 OK
Server: nginx/1.25.3
Date: Tue, 06 Feb 2024 20:45:05 GMT
Content-Type: text/html
Content-Length: 3026
Last-Modified: Mon, 05 Feb 2024 17:09:16 GMT
Connection: keep-alive
ETag: "65c1163c-bd2"
Accept-Ranges: bytes

curl -i http://192.168.49.2:31169/stats
HTTP/1.1 200 OK
Server: nginx/1.25.3
Date: Tue, 06 Feb 2024 20:45:35 GMT
Content-Type: application/json
Content-Length: 24
Connection: keep-alive
Access-Control-Allow-Origin: *

{"cpu":10.8,"ram":57.9}
```

# Task 4 - AWS Tooling
Next step is completely separate from last tasks.
The exercise here is to create a CLI tool to fetch available EC2 AMI on AWS.

The expected input parameters for the CLI are:
1. **Regions** (list of strings, required) (example: us-east-1 us-west-1 eu-central-1 eu-west-1)
2. **Architecture** (string, required) (example: amd64)
3. **OS** (string, required) (example: ubuntu)
4. **Date created** (string, optional) (example: 01.06.2023)

You must use: python or goland

You will be evaluated based on the:
* Coding skills
* Input Validation
* Implementation of Help for usage of the CLI
* Error Handling

## How the fetch script works

To run this script, you need to have [python installed](https://www.python.org/downloads/), preferably version `3.8` or higher, as well as the [boto3](https://pypi.org/project/boto3/) library. An alternative is to have pyenv installed on your computer to create a virtual environment for the script. If you have [pyenv](https://github.com/pyenv/pyenv?tab=readme-ov-file#installation) installed, you can follow this example:

```shell
cd ./aws_tooling
python3 -m venv aws_tooling
. ./aws_tooling/bin/activate
pip install -r ./requirements.txt
```

The script expects four parameters by default:

| Name | Description | Required |
|------|-------------|:--------:|
| aws_regions | List of regions, e.g. `us-east-1 us-west-1` | yes |
| architecture | Architecture, e.g. `x86_64`) | yes |
| os | Operating System, e.g. `ubuntu`) | yes |
| creation_date | Date created, should follow the format of `YYYY-MM-DD` separated by `-`, e.g. `2023-12-24` | yes |

Example of usage for the script:

```shell
python3 aws_cli.py --aws_regions eu-west-1 us-east-1 --architecture x86_64 --os CentOS --creation_date 2023-12-2

Fetching for AMIs in region eu-west-1

{
    "Images": [
        {
            "Architecture": "x86_64",
            "CreationDate": "2023-12-26T16:03:41.000Z",
            "ImageId": "ami-0487c8c5a12e92d98",
            "ImageLocation": "aws-marketplace/ (SupportedImages) - Redis - CentOS 7 x86_64 - 20231204 - 20231226-35eddf45-9ec1-421b-867a-7f981203b0a6",
            "ImageType": "machine",
            "Public": true,
            "OwnerId": "679593333241",
            "PlatformDetails": "Linux/UNIX",
            "UsageOperation": "RunInstances",
            "ProductCodes": [
                {
                    "ProductCodeId": "36xselgbwce5xnwb5a3a4v0km",
                    "ProductCodeType": "marketplace"
                }
            ],
            "State": "available",
            "BlockDeviceMappings": [
                {
                    "DeviceName": "/dev/sda1",
                    "Ebs": {
                        "DeleteOnTermination": false,
                        "SnapshotId": "snap-05615c8b8b269ab17",
                        "VolumeSize": 8,
                        "VolumeType": "gp2",
                        "Encrypted": false
                    }
                }
            ],
            "Description": "Redis labs, Redislabs, redis stack,Redis cache,Redis cloud, CentOS Linux 7, CentOS 7",
            "EnaSupport": true,
            "Hypervisor": "xen",
            "ImageOwnerAlias": "aws-marketplace",
            "Name": " (SupportedImages) - Redis - CentOS 7 x86_64 - 20231204 - 20231226-35eddf45-9ec1-421b-867a-7f981203b0a6",
            "RootDeviceName": "/dev/sda1",
            "RootDeviceType": "ebs",
            "SriovNetSupport": "simple",
            "VirtualizationType": "hvm",
            "DeprecationTime": "2025-12-26T16:03:41.000Z"
        }
    ],
    "ResponseMetadata": {
        "RequestId": "baa2b0c5-1177-4cec-896f-35516a38a139",
        "HTTPStatusCode": 200,
        "HTTPHeaders": {
            "x-amzn-requestid": "baa2b0c5-1177-4cec-896f-35516a38a139",
            "cache-control": "no-cache, no-store",
            "strict-transport-security": "max-age=31536000; includeSubDomains",
            "vary": "accept-encoding",
            "content-type": "text/xml;charset=UTF-8",
            "transfer-encoding": "chunked",
            "date": "Tue, 06 Feb 2024 22:34:55 GMT",
            "server": "AmazonEC2"
        },
        "RetryAttempts": 0
    }
}
```


# Summary
This documentation is supposed to be very high-level, you will be evaluated on the basis of the low level decisions you make while implementing it and your thought process behind them. If you have any questions at all feel free to reach out and ask for help. Please package your code up in a Github repo and share the link.

Best of luck!
