# Cloudflare SSL エラー修正手順

## 問題
`SSL handshake failed (Error 525)` - XサーバーにSSL証明書がない

## 解決手順

### ステップ1: Cloudflare SSL設定を変更

1. Cloudflareダッシュボードで **hashpilot.biz** を選択

2. 左メニューから **SSL/TLS** をクリック

3. **暗号化モード** を **「Flexible」** に変更
   - ❌ Full (strict) → これはXサーバーに有効なSSL証明書が必要
   - ❌ Full → これもXサーバーにSSL証明書が必要
   - ✅ **Flexible** → XサーバーにSSL証明書不要（Cloudflare ↔ 訪問者のみSSL）

4. 保存して数分待つ

### ステップ2: Xサーバーにドメインを追加（まだなら）

1. Xサーバーのサーバーパネルにログイン

2. **ドメイン設定** → **ドメイン設定追加**

3. `hashpilot.biz` を入力して追加

4. **無料独自SSL設定** → **独自SSL設定を追加する(確定)** をクリック

5. 数分～1時間待つ（SSL証明書が自動発行される）

### ステップ3: SSL証明書発行後

SSL証明書が発行されたら、Cloudflareの暗号化モードを **「Full」** または **「Full (strict)」** に戻す。

---

## 今すぐアクセスする方法（暫定）

### HTTP でアクセス
- `http://hashpilot.biz/yield/` （HTTPSではなくHTTP）
- ⚠️ 非推奨（セキュリティ上の問題）

### Cloudflare Flexible に変更後
- `https://hashpilot.biz/yield/` （HTTPS可能）
- ✅ 推奨（訪問者 ↔ Cloudflare 間はSSL、Cloudflare ↔ サーバー間は非SSL）

---

## 完璧な設定（将来）

1. XサーバーでSSL証明書発行完了
2. Cloudflare暗号化モードを **Full (strict)** に変更
3. 完全なHTTPS接続（訪問者 ↔ Cloudflare ↔ サーバー全てSSL）
