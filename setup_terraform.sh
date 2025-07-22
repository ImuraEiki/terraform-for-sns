#!/bin/bash

set -e

echo "✅ Terraform のインストールを開始します..."

# GPG キーの取得
wget -O- https://apt.releases.hashicorp.com/gpg | \
  gpg --dearmor | \
  sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null

# リポジトリ追加
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
sudo tee /etc/apt/sources.list.d/hashicorp.list > /dev/null

# パッケージ更新＆Terraformインストール
sudo apt update
sudo apt install -y terraform

# 確認
echo "✅ Terraform バージョン:"
terraform -version

echo "🎉 セットアップ完了！"
