# 緊急修正: 2025-11-09 マイナス日利でのNFT誤付与

## 🚨 問題の概要

**発生日時**: 2025-11-09  
**問題**: マイナス$5000の日利設定なのに、NFT数が692個→834個に急増（+142個）  
**影響**: 142個のNFTが誤って自動付与された

### スクリーンショット
`public/images/FireShot Capture 773 - HASH PILOT NFT - [hashpilot-staging.vercel.app].png`

---

## 🔍 原因

### V2関数のバグ
`process_daily_yield_v2` 関数の360-422行目（NFT自動付与処理）に問題がありました：

**問題のあるコード:**
```sql
-- NFT自動付与（cum_usdt >= $2,200）
FOR v_user_record IN
  SELECT ...
  WHERE ac.cum_usdt >= 2200  -- ❌ 日利の金額を考慮していない
LOOP
  ...
END LOOP;
```

**問題点:**
- 日利がマイナスでもプラスでも、`cum_usdt >= $2,200`のユーザーがいればNFT付与
- 本来は「プラス日利の時のみ」NFT自動付与すべき

---

## 📋 実行手順

### STEP 1: 調査（データ確認）

```bash
# 調査スクリプトを実行
psql "$DATABASE_URL" < scripts/INVESTIGATE-1109-auto-nft-bug.sql
```

**確認項目:**
- 11/9に何個のNFTが自動付与されたか？
- どのユーザーに付与されたか？
- 運用開始前のユーザーへの誤付与はあるか？

**期待値:**
- 自動付与NFT数: 142個
- NFT数変化: 692個 → 834個

---

### STEP 2: V2関数の修正（プラス日利の時のみNFT付与）

```bash
# 修正版RPC関数を適用
psql "$DATABASE_URL" < scripts/FIX-process-daily-yield-v2-FINAL-CORRECT.sql
```

**修正内容:**
```sql
-- NFT自動付与（cum_usdt >= $2,200、プラス日利の時のみ）
IF v_distribution_dividend > 0 THEN  -- ✅ プラス日利の時のみ実行
  FOR v_user_record IN
    SELECT ...
    WHERE ac.cum_usdt >= 2200
  LOOP
    ...
  END LOOP;
END IF;  -- ✅ 追加
```

---

### STEP 3: 誤付与されたNFTの削除（慎重に！）

⚠️ **警告: この操作は取り消せません！必ずバックアップを取ってください。**

```bash
# 削除前に確認部分だけ実行
psql "$DATABASE_URL" < scripts/DELETE-1109-incorrect-auto-nft.sql
```

**確認項目:**
1. 11/9に自動付与されたNFT数: 142個
2. 削除対象ユーザー一覧
3. purchases テーブルの削除対象数

**削除処理:**
スクリプト内のコメントを外して実行（トランザクション使用）：

1. `nft_master` から11/9の自動NFTを削除
2. `purchases` から11/9の自動購入を削除
3. `affiliate_cycle` を元に戻す:
   - `cum_usdt += 2200`
   - `available_usdt -= 1100`
   - `auto_nft_count -= 1`
   - `total_nft_count -= 1`

---

## ✅ 最終確認

```sql
-- 1. 11/9の自動NFTが0件になっているか
SELECT COUNT(*) FROM nft_master
WHERE acquired_date = '2025-11-09' AND nft_type = 'auto';
-- 期待値: 0

-- 2. NFT総数が692個に戻っているか
SELECT COUNT(*) FROM nft_master nm
JOIN users u ON nm.user_id = u.user_id
WHERE nm.buyback_date IS NULL
  AND (u.is_pegasus_exchange = FALSE OR u.is_pegasus_exchange IS NULL);
-- 期待値: 692
```

---

## 📝 再発防止策

### 1. V2関数の修正完了
- NFT自動付与は「プラス日利の時のみ」実行
- `IF v_distribution_dividend > 0 THEN ... END IF;` で制御

### 2. テストの追加
今後、マイナス日利のテストケースを追加：
```sql
-- マイナス日利でNFT自動付与が発生しないことを確認
SELECT process_daily_yield_v2(
  '2025-11-20',
  -5000.00,  -- マイナス日利
  TRUE  -- テストモード
);
```

### 3. CLAUDE.md への記録
この問題と修正内容をCLAUDE.mdの「重要なバグ修正履歴」セクションに追加

---

## 🔧 作成されたスクリプト

| スクリプト名 | 用途 | 実行タイミング |
|------------|------|--------------|
| `INVESTIGATE-1109-auto-nft-bug.sql` | 調査 | STEP 1（先に実行） |
| `FIX-process-daily-yield-v2-FINAL-CORRECT.sql` | 修正 | STEP 2（関数修正） |
| `DELETE-1109-incorrect-auto-nft.sql` | 削除 | STEP 3（慎重に！） |

---

## ⚠️ 注意事項

1. **停電対策**: 各スクリプトはトランザクション対応（BEGIN → COMMIT/ROLLBACK）
2. **バックアップ**: 削除前に必ずデータベースバックアップを取得
3. **段階的実行**: 各STEPを確認しながら慎重に進める
4. **コミット**: 作業が完了したらgitコミット

---

## 📅 作業履歴

- **2025-11-19**: 問題発見、調査開始
- **2025-11-19**: スクリプト作成（調査・修正・削除）
- **2025-11-19**: V2関数修正完了（プラス日利の時のみNFT付与）

---

最終更新: 2025-11-19
