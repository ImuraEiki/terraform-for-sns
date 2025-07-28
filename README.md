# Terraform for building my SNS application on AWS 
### 概要
[react_sns](https://github.com/ImuraEiki/react_sns)のAWS環境(VPC / ECR / ECS / ALB等)を一括で構築します。
### 手順

#### リソース構築
`terraform init`
`terraform plan`
`terraform apply`
#### ECRにイメージをpush
下記コマンドは開発用ディレクトリで実行。
```
USER_ID=
REPO_NAME=my-react-app
REGION=us-east-1

aws ecr get-login-password --region ${REGION} | docker login --username AWS --password-stdin ${USER_ID}.dkr.ecr.${REGION}.amazonaws.com
docker build -f dockerfile.prod -t ${REPO_NAME} .
docker tag ${REPO_NAME}:latest ${USER_ID}.dkr.ecr.${REGION}.amazonaws.com/${REPO_NAME}:latest
docker push ${USER_ID}.dkr.ecr.${REGION}.amazonaws.com/${REPO_NAME}:latest
```

#### すべてを終了
`terraform destroy`