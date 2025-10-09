# バリュードメイン DNS設定（Resend用）- 実践編

hashpilot.biz のDNS設定画面での正確な入力方法

---

## 📋 入力する場所

バリュードメインのDNS設定画面（テキストボックス）に、以下を**既存の設定の下に追加**してください。

---

## ⚠️ 重要：Resendの完全な値を確認

まず、Resendの画面で各レコードの**完全な値**をコピーしてください：

### 確認手順

1. Resendのドメイン設定画面に戻る
2. 各レコードの「Value」欄を**クリック**
3. 完全な値が表示される → **全てコピー**
4. 特に `resend._domainkey` の値は非常に長いので注意

---

## 📝 バリュードメインに追加する内容

### STEP 1: Resendから値をコピー

**必要な値（Resendの画面からコピー）:**

1. **MXレコードの値**: `feedback-smtp.●●●●.amazonses.com`
   - ●の部分はResendに表示されている実際の値

2. **SPFレコードの値**: `v=spf1 include:●●●●`
   - ●の部分はResendに表示されている実際の値

3. **DKIMレコードの値**: `p=MIGfMA0GCS...`（非常に長い文字列）
   - Resendの画面で**全てコピー**

4. **DMARCレコードの値**: `v=DMARC1; p=none;`

### STEP 2: バリュードメインに追加

既存のDNS設定の**一番下に**、以下を追加してください：

```dns
# ========== Resend メール送信設定（追加） ==========

# MXレコード（sendサブドメイン用）
mx send 10 [ここにResendのMX値をペースト].

# SPFレコード（sendサブドメイン用）
txt send [ここにResendのSPF値をペースト]

# DKIMレコード（メール署名用）- 長い文字列
txt resend._domainkey [ここにResendのDKIM値をペースト]

# DMARCレコード（推奨）
txt _dmarc v=DMARC1; p=none;

# ========== ここまで追加 ==========
```

---

## 💡 具体例（実際の値を入れた場合）

```dns
# 既存の設定（そのまま）
a @ 203.0.113.1
cname www @
mx @ 10 mail.hashpilot.biz.

# ========== Resend メール送信設定（追加） ==========

# MXレコード
mx send 10 feedback-smtp.ap-northeast-1.amazonses.com.

# SPFレコード
txt send v=spf1 include:amazonses.com ~all

# DKIMレコード
txt resend._domainkey p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDEI8R9F7VnHqMpF... (長い文字列全て)

# DMARCレコード
txt _dmarc v=DMARC1; p=none;

# ========== ここまで追加 ==========
```

---

## ✅ チェックポイント

### 入力前の確認

- [ ] Resendの画面で**全ての値を正確にコピー**した
- [ ] 特にDKIMの長い文字列を**全てコピー**した
- [ ] 既存のDNS設定を**消さない**ようにする

### 入力時の注意

- [ ] 既存の設定の**下に追加**（上書きしない）
- [ ] 各行の末尾に**余分な改行やスペースを入れない**
- [ ] MXレコードの値の末尾に**ドット（.）**を付ける
- [ ] コピー時に**改行が入らない**ようにする（DKIMレコード）

### 保存後

- [ ] 「保存」ボタンをクリック
- [ ] エラーが出ないことを確認
- [ ] 15分〜1時間待つ

---

## 🔍 Resendで完全な値を確認する方法

### 方法1: 値をクリック

Resendの画面で、各レコードの「Value」欄を**クリック**すると、
完全な値がポップアップまたは展開されます。

### 方法2: コピーボタン

値の右側に**コピーボタン**（📋アイコン）がある場合、それをクリック。

### 方法3: ブラウザの開発者ツール

1. Resendの画面で**右クリック** → **検証**
2. 値の部分を選択
3. 完全な文字列が表示される

---

## 📸 入力例のスクリーンショット

### 入力前（既存の設定）
```
a @ 203.0.113.1
cname www @
mx @ 10 mail.hashpilot.biz.
txt @ v=spf1 +ip4:203.0.113.1 ~all
```

### 入力後（Resend追加後）
```
a @ 203.0.113.1
cname www @
mx @ 10 mail.hashpilot.biz.
txt @ v=spf1 +ip4:203.0.113.1 ~all

# Resend追加
mx send 10 feedback-smtp.ap-northeast-1.amazonses.com.
txt send v=spf1 include:amazonses.com ~all
txt resend._domainkey p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQD...（長い）
txt _dmarc v=DMARC1; p=none;
```

---

## ⏰ DNS反映時間

- **最短**: 15分
- **通常**: 1〜2時間
- **最長**: 48時間

反映後、Resendの画面で「Verify」をクリックして確認してください。

---

## 🚨 トラブルシューティング

### エラー: 「フォーマットが正しくありません」

**原因**: 余分なスペースや改行
**解決**:
- 各行を1行にまとめる
- 行末の余分なスペースを削除

### エラー: 「MXレコードが重複しています」

**原因**: 既存のMXレコードと競合
**解決**:
- `send` サブドメインを使用しているので競合しないはず
- 既存のMXレコードは `@` （ルートドメイン）用なので問題なし

### Resendで「Not Verified」のまま

**原因**: DNS反映待ち、または値が間違っている
**解決**:
1. 1時間待ってから再度 Verify
2. バリュードメインの設定を再確認
3. Resendの値を再度コピーして入力

---

## 📞 サポート

### 自分で解決できない場合

バリュードメインサポートに連絡：
- サポートページ: https://www.value-domain.com/support/
- 以下のように伝える:

> hashpilot.biz のDNSに、Resendというメールサービスのレコードを追加したいです。
> 以下のレコードを追加する方法を教えてください：
>
> 1. mx send 10 feedback-smtp.ap-northeast-1.amazonses.com.
> 2. txt send v=spf1 include:amazonses.com ~all
> 3. txt resend._domainkey p=MIGf...（長い文字列）
> 4. txt _dmarc v=DMARC1; p=none;

---

## 次のステップ

DNS設定完了 → Resendで認証 → Supabase Edge Functionに設定

詳細は `/docs/RESEND_SETUP_GUIDE.md` を参照してください。
