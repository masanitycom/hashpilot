# yield.hashpilot.info 緊急修正手順

## ⚠️ 問題
現在、yield.hashpilot.infoに**社内極秘情報（日利率）**が表示されています。

## ✅ 修正内容
- ❌ 削除: 日利率（%）列
- ❌ 削除: 平均日利率
- ✅ 残す: ユーザー受取率（%）のみ

## 📤 アップロード方法

### 方法1: FTPクライアント（FileZilla/Cyberduck等）

1. **接続情報**
   - ホスト: `basaraserver.xsrv.jp`
   - ユーザー名: `basaraserver`
   - パスワード: （あなたのパスワード）
   - プロトコル: FTP

2. **アップロード先**
   ```
   /hashpilot.info/public_html/yield.hashpilot.info/index.html
   ```

3. **アップロードファイル**
   ```
   /mnt/d/HASHPILOT/public/yield-public-safe.html
   ```
   ↑このファイルを `index.html` にリネームしてアップロード

### 方法2: コマンドライン（curlを使用）

```bash
cd /mnt/d/HASHPILOT

curl -T public/yield-public-safe.html \
  ftp://basaraserver.xsrv.jp/hashpilot.info/public_html/yield.hashpilot.info/index.html \
  --user basaraserver:YOUR_PASSWORD
```

### 方法3: 既存ファイルを直接編集

現在のindex.htmlから以下を削除：

**削除箇所1: テーブルヘッダー**
```html
<!-- 削除前 -->
<tr>
    <th>日付</th>
    <th>日利率 (%)</th>
    <th>ユーザー受取率 (%)</th>
    <th>増加率 (%)</th>
</tr>

<!-- 削除後 -->
<tr>
    <th>日付</th>
    <th>ユーザー受取率 (%)</th>
</tr>
```

**削除箇所2: テーブルデータ行（JavaScriptの displayData 関数内）**
```javascript
// 削除前
return `
    <tr>
        <td class="date-cell">${formatDate(item.date)}</td>
        <td class="${yieldClass}">${yieldSign}${item.yield_rate.toFixed(3)}%</td>
        <td>${item.profit_percentage}%</td>
        <td class="${yieldClass}">${yieldSign}${item.profit_percentage}%</td>
    </tr>
`;

// 削除後
return `
    <tr>
        <td class="date-cell">${formatDate(item.date)}</td>
        <td class="${userRateClass}">${userRateSign}${userRateValue}%</td>
    </tr>
`;
```

**削除箇所3: 統計カード（平均日利率）**
```javascript
// displayStats 関数内で以下を削除
<div class="stat-card">
    <h3>平均日利率</h3>
    <div class="value ${avgYieldRate > 0 ? 'positive' : 'negative'}">${avgYieldRate > 0 ? '+' : ''}${avgYieldRate}%</div>
</div>
```

## ✅ 確認

アップロード後、以下で確認：
```
https://yield.hashpilot.info/
```

表示されるべき項目：
- ✅ 日付
- ✅ ユーザー受取率（%）
- ✅ 総レコード数
- ✅ プラス日数
- ✅ マイナス日数
- ✅ 平均ユーザー受取率

表示されてはいけない項目：
- ❌ 日利率（%）
- ❌ 平均日利率
