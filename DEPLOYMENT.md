# Cloud Run デプロイメントガイド

このガイドでは、gemini-mcp サーバーを Google Cloud Run にデプロイし、GitHub Actions で自動デプロイを設定する手順を説明します。

## なぜ Cloud Run？

低頻度アクセス（数時間に1回）のMCPサーバーに最適：

- **コールドスタート**: 1-3秒（改善策で1秒以下も可能）
- **コスト**: 月200万リクエスト無料、低頻度なら無料枠内
- **処理時間**: 最大60分（Gemini API待ち時間に対応）
- **デプロイ**: GitHub Actionsで自動化済み

**代替案との比較**:
- AWS Lambda: 同等性能だが新規設定必要
- Cloudflare Workers: 超高速起動だがMCP SDK非対応

## 前提条件

- Google Cloud アカウント
- GitHub リポジトリ
- `gcloud` CLI（インストール＆認証済み）
- Docker（ローカルデプロイする場合）

## 事前準備（初回のみ）

スクリプトを実行する前に、以下をGCPコンソールで手動で準備してください。

### 1. GCPプロジェクトの作成

1. [Google Cloud Console](https://console.cloud.google.com/) にアクセス
2. 新しいプロジェクトを作成（または既存のプロジェクトを選択）
3. プロジェクトIDをメモ（例: `my-gemini-mcp`）

### 2. 請求先アカウントの紐付け（重要！）

1. [請求先アカウントページ](https://console.cloud.google.com/billing) にアクセス
2. プロジェクトに請求先アカウントが紐付いていることを確認
3. 未設定の場合：
   - 「請求先アカウントをリンク」をクリック
   - 既存の請求先アカウントを選択（または新規作成）

**注意**: 請求先アカウントが未設定の場合、APIの有効化でエラーが発生します。

### 3. gcloud CLIの認証

```bash
# Google Cloudにログイン
gcloud auth login

# Application Default Credentials設定
gcloud auth application-default login
```

## クイックスタート（スクリプト使用）

事前準備完了後、自動化スクリプトを使用します。

### 1. GCPの初回セットアップ

```bash
./bin/setup-gcp.sh \
  --project-id=my-gemini-mcp \
  --github-user=your-username \
  --github-repo=gemini-mcp
```

オプション：
- `--region=REGION` - デプロイリージョン（デフォルト: asia-northeast1）

スクリプトは以下を自動実行します：
- GCPプロジェクト作成・設定
- 必要なAPI有効化
- Artifact Registryリポジトリ作成
- Workload Identity Federation設定

### 2. GitHub Secrets を設定

スクリプト完了時に出力される値を、GitHubリポジトリの Settings > Secrets and variables > Actions で設定：

1. **GCP_PROJECT_ID**
2. **WIF_PROVIDER**
3. **WIF_SERVICE_ACCOUNT**
4. **GEMINI_API_KEY** - https://aistudio.google.com/app/apikey で取得

### 3. デプロイ

```bash
git push origin main
```

GitHub Actionsが自動的にCloud Runへデプロイします！

---

## 初期セットアップ（詳細手順）

スクリプトを使わず手動で行う場合の詳細手順です。

**注意**: この方法でも、プロジェクト作成と請求先アカウントの紐付けは事前にGCPコンソールで行ってください（上記「事前準備」参照）。

### 1. GCP プロジェクトの準備

```bash
# プロジェクトIDを設定（例: my-gemini-mcp）
export PROJECT_ID="your-project-id"

# プロジェクトを設定
gcloud config set project $PROJECT_ID

# 必要なAPIを有効化
gcloud services enable run.googleapis.com
gcloud services enable artifactregistry.googleapis.com
gcloud services enable iamcredentials.googleapis.com
```

### 2. Artifact Registry リポジトリの作成

```bash
# リージョンを設定（東京リージョン）
export REGION="asia-northeast1"

# Docker リポジトリを作成
gcloud artifacts repositories create gemini-mcp \
  --repository-format=docker \
  --location=$REGION \
  --description="Gemini MCP Server container images"
```

### 3. Workload Identity Federation の設定

GitHub Actions から GCP にアクセスするために、Workload Identity Federation を設定します。

```bash
# サービスアカウントを作成
gcloud iam service-accounts create github-actions \
  --display-name="GitHub Actions Service Account"

# Cloud Run と Artifact Registry の権限を付与
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:github-actions@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/run.admin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:github-actions@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/artifactregistry.writer"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:github-actions@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountUser"

# Workload Identity Pool を作成
gcloud iam workload-identity-pools create github-pool \
  --location="global" \
  --display-name="GitHub Actions Pool"

# プールのIDを取得
export WORKLOAD_IDENTITY_POOL_ID=$(gcloud iam workload-identity-pools describe github-pool \
  --location="global" \
  --format="value(name)")

# Workload Identity Provider を作成
gcloud iam workload-identity-pools providers create-oidc github-provider \
  --location="global" \
  --workload-identity-pool="github-pool" \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository" \
  --attribute-condition="assertion.repository_owner=='YOUR_GITHUB_USERNAME'"

# YOUR_GITHUB_USERNAME を実際のGitHubユーザー名に置き換えてください

# サービスアカウントに Workload Identity ユーザーロールを付与
gcloud iam service-accounts add-iam-policy-binding \
  github-actions@$PROJECT_ID.iam.gserviceaccount.com \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/$WORKLOAD_IDENTITY_POOL_ID/attribute.repository/YOUR_GITHUB_USERNAME/gemini-mcp"

# YOUR_GITHUB_USERNAME/gemini-mcp を実際のリポジトリパスに置き換えてください
```

### 4. GitHub Secrets の設定

GitHub リポジトリの Settings > Secrets and variables > Actions で以下のシークレットを追加：

1. **GCP_PROJECT_ID**
   - Value: `your-project-id`

2. **WIF_PROVIDER**
   - Value: 以下のコマンドで取得
   ```bash
   gcloud iam workload-identity-pools providers describe github-provider \
     --location="global" \
     --workload-identity-pool="github-pool" \
     --format="value(name)"
   ```

3. **WIF_SERVICE_ACCOUNT**
   - Value: `github-actions@your-project-id.iam.gserviceaccount.com`

4. **GEMINI_API_KEY**
   - Value: Google AI Studio で取得した Gemini API キー
   - 取得方法: https://aistudio.google.com/app/apikey

## デプロイ

### 自動デプロイ

`main` ブランチに push すると自動的にデプロイされます：

```bash
git add .
git commit -m "Deploy to Cloud Run"
git push origin main
```

GitHub Actions でデプロイの進行状況を確認できます。

### 手動デプロイ（ローカルから）

GitHub Actionsを使わず、ローカルから直接デプロイする場合（緊急時など）。

#### スクリプトを使用（推奨）

```bash
./bin/deploy.sh \
  --project-id=your-project-id \
  --gemini-api-key=your-api-key
```

オプション：
- `--region=REGION` - デプロイリージョン（デフォルト: asia-northeast1）
- `--memory=SIZE` - メモリ割り当て（デフォルト: 512Mi）
- `--cpu=COUNT` - CPU数（デフォルト: 1）
- `--min-instances=N` - 最小インスタンス数（デフォルト: 0）
- `--max-instances=N` - 最大インスタンス数（デフォルト: 10）

#### 手動で実行

```bash
# プロジェクトとリージョンを設定
export PROJECT_ID="your-project-id"
export REGION="asia-northeast1"

# Docker イメージをビルド
docker build -t $REGION-docker.pkg.dev/$PROJECT_ID/gemini-mcp/gemini-mcp:latest .

# Artifact Registry に push
gcloud auth configure-docker $REGION-docker.pkg.dev
docker push $REGION-docker.pkg.dev/$PROJECT_ID/gemini-mcp/gemini-mcp:latest

# Cloud Run にデプロイ
gcloud run deploy gemini-mcp \
  --image $REGION-docker.pkg.dev/$PROJECT_ID/gemini-mcp/gemini-mcp:latest \
  --region $REGION \
  --platform managed \
  --allow-unauthenticated \
  --set-env-vars GEMINI_API_KEY="your-gemini-api-key" \
  --memory 512Mi \
  --cpu 1 \
  --min-instances 0 \
  --max-instances 10
```

## デプロイ後の確認

デプロイが完了すると、Cloud Run のサービス URL が表示されます：

```
Service URL: https://gemini-mcp-xxxxx-an.a.run.app
```

MCP エンドポイント: `https://gemini-mcp-xxxxx-an.a.run.app/mcp`

### 動作確認

```bash
# サービス URL を取得
export SERVICE_URL=$(gcloud run services describe gemini-mcp \
  --region=$REGION \
  --format="value(status.url)")

# テストクライアントで確認
MCP_URL="$SERVICE_URL/mcp" npm test
```

## トラブルシューティング

### ログの確認

```bash
# Cloud Run のログを表示
gcloud run services logs read gemini-mcp --region=$REGION --limit=50
```

### デプロイの失敗

1. GitHub Actions のログを確認
2. 権限設定を確認（Workload Identity Federation）
3. API キーが正しく設定されているか確認

### コスト最適化

Cloud Run は使用した分だけ課金されます。無料枠は：
- 月 200 万リクエスト
- 月 360,000 GB-秒のメモリ
- 月 180,000 vCPU-秒

`--min-instances 0` を設定しているため、アクセスがない時は料金が発生しません。

## 環境変数の更新

Gemini API キーなどの環境変数を更新する場合：

```bash
gcloud run services update gemini-mcp \
  --region=$REGION \
  --set-env-vars GEMINI_API_KEY="new-api-key"
```

## コールドスタート最適化

### オプション1: 軽量Dockerイメージ（推奨）

現在のコンテナを最適化してコールドスタートを1秒以下に：

```dockerfile
# Dockerfile - マルチステージビルドで最適化
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

FROM node:20-alpine
WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY . .
RUN npm run build

# 不要なファイル削除
RUN rm -rf src test.ts

EXPOSE 3333
CMD ["node", "dist/server.js"]
```

**効果**: コールドスタート 1秒以下

### オプション2: 常時1インスタンス維持

コールドスタート完全回避（月額約$10）：

```bash
gcloud run services update gemini-mcp \
  --region=$REGION \
  --min-instances 1
```

### オプション3: Cloud Scheduler でウォームアップ

定期的に ping してインスタンス維持（無料枠内）：

```bash
# Cloud Scheduler ジョブ作成（30分ごとにping）
gcloud scheduler jobs create http warmup-gemini-mcp \
  --schedule="*/30 * * * *" \
  --uri="$SERVICE_URL/health" \
  --http-method=GET \
  --location=$REGION
```

健康チェックエンドポイント追加が必要：
```typescript
// server.ts に追加
app.get('/health', (req, res) => {
  res.status(200).send('OK');
});
```

## カスタマイズ

### リージョンの変更

`.github/workflows/deploy.yml` の `REGION` を変更：
- `us-central1` (アイオワ)
- `asia-northeast1` (東京)
- `europe-west1` (ベルギー)

### リソースの調整

メモリや CPU を変更する場合は、デプロイコマンドの `--memory` と `--cpu` を調整してください。

### 認証の追加

現在は `--allow-unauthenticated` で誰でもアクセス可能です。認証を追加する場合：

```bash
gcloud run services update gemini-mcp \
  --region=$REGION \
  --no-allow-unauthenticated
```

その後、Cloud Run Invoker の権限を特定のサービスアカウントに付与します。
