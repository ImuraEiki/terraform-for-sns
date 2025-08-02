# Terraform for building my SNS application on AWS 
### 概要
[react_sns](https://github.com/ImuraEiki/react_sns)のAWS環境(VPC / ECR / ECS / ALB等)を一括で構築します。
### 手順

#### terraformインストール
`sh setup_terraform.sh` 

variables.tfのecr_image_versionはgitの最新コミットのハッシュを設定すること

#### リソース構築
`terraform init`
`terraform plan`
`terraform apply -auto-approve`
#### ECRにイメージをpush
下記コマンドは開発用ディレクトリで実行。
```
USER_ID=
REPO_NAME=my-react-app
REGION=us-east-1
VERSION=fbdb3a64a4acf42d3ff6e503b2e2ce4a3431a7d3

aws ecr get-login-password --region ${REGION} | docker login --username AWS --password-stdin ${USER_ID}.dkr.ecr.${REGION}.amazonaws.com
docker build -f dockerfile.prod -t ${REPO_NAME} .
docker tag ${REPO_NAME}:${VERSION} ${USER_ID}.dkr.ecr.${REGION}.amazonaws.com/${REPO_NAME}:${VERSION}
docker push ${USER_ID}.dkr.ecr.${REGION}.amazonaws.com/${REPO_NAME}:${VERSION}
```

#### すべてを終了
`terraform destroy -auto-approve`