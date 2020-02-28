# MOYA

The repository is a proof of concept showing the automated deployment of a simple express app into a private subnet, creating an API proxy infront of the web app to expose the endpoint publicly.

### 00_VPC

Create a VPC and two subnets per availability zone.
The ECS cluster needs two subnets in different availability zones to function.
These can be passed in as variables in the later stages.

### 01_ECR

The elastic container registry is there to hold the images we wish to use. This can be made on its own.

### MANUAL STEP

- Build app: `yarn`
- Set repository name: `export REPO_NAME=moya_hanger`
- Set tag: `export TAG=0.1`
- Get repository arn: `export REPO_URI=$(aws ecr describe-repositories --query "repositories[?repositoryName=='$REPO_NAME'] | @[0].repositoryUri" --output text)`
- Create image: `docker build -t "$REPO_URI:$TAG" .`
- Log into AWS ECR: `$(aws ecr get-login --no-include-email)`
- Push the image: `docker push $REPO_URI:$TAG`

```
yarn

export REPO_NAME=moya_hanger
export TAG=0.1
export REPO_URI=$(aws ecr describe-repositories --query "repositories[?repositoryName=='$REPO_NAME'] | @[0].repositoryUri" --output text)
docker build -t "$REPO_URI:$TAG" .
$(aws ecr get-login --no-include-email)
docker push $REPO_URI:$TAG
```

### 02_ECS_API

This will construct the Fargate deployment of the containers along with an API Gateway to access it.

This will point toward a container in the Registry so it will need that to exist and an image to exist in there.

The load balancer should be connected to the container name in the container definition so as more of that type of container is spun up then the private IPs will be added to the target groups. (I hope)

---

## CLI

When an image has been updated and placed under the same tag the service can be updated with: `aws ecs update-service --service <service-name> --force-new-deployment`

---

Deployment plan:

1. Merge changes to master
2. Merge event picked up by AWS code pipeline.
3. AWS Code build constructs a newly tagged image to ECR
4. The new image is deployed into AWS Fargate

Infrastructure in terraform:

1. ECR + ECS
2. API Gateway to interact with the container.
