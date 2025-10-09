# バリュードメインでResend DNSレコード設定方法

ドメイン: hashpilot.biz
目的: Resendメール送信のためのDNS認証

---

## 📋 設定するDNSレコード一覧

Resendの画面に表示されている4つのレコードを設定します。

### 必須レコード（DKIM and SPF）

#### 1. MX レコード
```
タイプ: MX
ホスト名: send.hashpilot.biz
値: feedback-smtp.ap-northeast-1.amazonses.com
優先度: 10
TTL: 3600（または自動）
```

#### 2. TXT レコード（SPF）
```
タイプ: TXT
ホスト名: send.hashpilot.biz
値: v=spf1 include:amazonses.com ~all
TTL: 3600（または自動）
```

#### 3. TXT レコード（DKIM）
```
タイプ: TXT
ホスト名: resend._domainkey.hashpilot.biz
値: p=MIGfMA0GCSqGSIb3DQEB... （Resendの画面に表示されている長い文字列）
TTL: 3600（または自動）
```

### 推奨レコード（DMARC）

#### 4. TXT レコード（DMARC）
```
タイプ: TXT
ホスト名: _dmarc.hashpilot.biz
値: v=DMARC1; p=none;
TTL: 3600（または自動）
```

---

## 🔧 バリュードメインでの設定手順

### STEP 1: バリュードメインにログイン

1. https://www.value-domain.com/ にアクセス
2. ログイン

### STEP 2: DNS設定画面を開く

1. **コントロールパネル** → **ドメイン**
2. **hashpilot.biz** を探す
3. **DNS/URL** ボタンをクリック
4. または **DNS設定** をクリック

### STEP 3: DNSレコードを追加

バリュードメインは「テキスト形式」でDNS設定を入力します。

#### ⚠️ 重要：既存のレコードは残す

既存の設定を**削除せず**、以下のレコードを**追加**してください。

#### 入力形式

バリュードメインのDNS設定画面で、以下を**追加**します：

```dns
# Resend メール送信設定（追加）
mx send 10 feedback-smtp.ap-northeast-1.amazonses.com.
txt send v=spf1 include:amazonses.com ~all
txt resend._domainkey p=MIGfMA0GCSqGSIb3DQEB...（ここにResendの長い文字列をコピー）
txt _dmarc v=DMARC1; p=none;
```

### STEP 4: 保存

1. **保存**ボタンをクリック
2. 確認画面で**OK**をクリック

---

## 📝 詳細な入力例

### バリュードメインの入力フォーマット

バリュードメインは1行に1レコードを記述します：

```
レコードタイプ ホスト名 [優先度] 値
```

### 具体例

```dns
# 既存のレコード（そのまま残す）
a @ 123.456.789.0
cname www @

# ↓↓↓ ここから追加 ↓↓↓

# Resend MX レコード
mx send 10 feedback-smtp.ap-northeast-1.amazonses.com.

# Resend SPF レコード
txt send v=spf1 include:amazonses.com ~all

# Resend DKIM レコード（長い文字列をコピー）
txt resend._domainkey p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDEI...

# Resend DMARC レコード
txt _dmarc v=DMARC1; p=none;
```

---

## ⚠️ 注意事項

### 1. ホスト名について

バリュードメインでは、ホスト名に **ドメイン名を含めない** 場合があります：

- ❌ `send.hashpilot.biz` ← 含める場合もある
- ✅ `send` ← 通常はこれ

**確認方法**：
既存のレコードを見て、フォーマットを合わせてください。

### 2. 値の末尾のドット

MXレコードの値の末尾には**ドット（.）**が必要な場合があります：
```
feedback-smtp.ap-northeast-1.amazonses.com.
                                          ↑ このドット
```

### 3. TXTレコードの引用符

TXTレコードの値を引用符で囲む必要がある場合があります：
```
txt send "v=spf1 include:amazonses.com ~all"
```

バリュードメインの仕様に合わせて調整してください。

### 4. DKIMの長い文字列

DKIM レコード（`resend._domainkey`）の値は**非常に長い**です：
- Resendの画面から**全てコピー**してください
- 改行せずに1行で貼り付けてください

---

## ✅ 設定確認方法

### 方法1: Resend で確認

1. DNS設定後、15分〜1時間待つ
2. Resendのドメイン設定画面に戻る
3. **Verify Records** または **Check DNS** をクリック
4. 全て緑色の✓になれば完了

### 方法2: DNSチェッカーで確認

オンラインツールで確認：
- https://mxtoolbox.com/
- ドメインを入力してDNS確認

---

## 🔄 トラブルシューティング

### 設定したのに認証されない

**原因1: DNS反映待ち**
- DNS設定は最大48時間かかる（通常は数時間）
- 待ってから再度確認

**原因2: 入力ミス**
- ホスト名、値をもう一度確認
- コピー&ペーストでスペースが入っていないか確認

**原因3: フォーマットエラー**
- バリュードメインのヘルプを確認
- サポートに問い合わせ

### バリュードメインのDNS設定画面が見つからない

1. コントロールパネル
2. **ドメイン** または **ドメイン一覧**
3. hashpilot.biz の **操作** → **DNS設定**

---

## 📞 サポート

### バリュードメインサポート
- https://www.value-domain.com/support/
- 営業時間: 平日10:00-18:00

### 設定代行（必要な場合）
バリュードメインのサポートに以下を伝えて代行依頼：

> Resendというメールサービスを使うため、以下のDNSレコードを追加したいです：
> 1. MX レコード: send → feedback-smtp.ap-northeast-1.amazonses.com 優先度10
> 2. TXT レコード: send → v=spf1 include:amazonses.com ~all
> 3. TXT レコード: resend._domainkey → p=MIGf...（長い文字列）
> 4. TXT レコード: _dmarc → v=DMARC1; p=none;

---

## 📝 記録用

**設定実施日**: _______________
**設定者**: _______________
**認証状態**: □ Verified □ Pending □ Failed
**備考**: _______________
