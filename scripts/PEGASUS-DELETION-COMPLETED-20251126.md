# ペガサス個人利益削除完了報告（2025-11-26）

## 実行結果

### 削除対象
- **ユーザー数**: 66名
- **削除レコード数**: 201件（nft_daily_profit）
- **個人利益合計**: 約$104.48

### 削除前の状態
- `total_available_usdt`: -$1,363.18（マイナス残高）
- `total_cum_usdt`: $855.83（紹介報酬）

### 削除後の状態
- ✅ 全66名の`available_usdt = 0`
- ✅ 全66名の個人利益レコード削除完了
- ✅ 紹介報酬（cum_usdt）は保持

### マイナス残高の原因（推測）
ペガサス交換時に以下の処理が行われた可能性：
- ペガサス1枚 = $20相当
- 交換時に`available_usdt`から$20を減算
- その後、日利が配布されたため、マイナス残高が発生

例: user_id "039483"
```
交換前: available_usdt = $0
交換時: available_usdt = $0 - $20 = -$20
日利配布後: available_usdt = -$20 + $1.575 + $2.95 = -$15.475（≈ -$15.66）
```

### バックアップ
- `nft_daily_profit_backup_20251126`（201レコード）
- `affiliate_cycle_backup_20251126`（66レコード）

### 復元方法（必要時のみ）
`scripts/BACKUP-pegasus-deletion-20251126.sql` の STEP 4 を参照

---

## 実行したSQL

### STEP 1: バックアップ作成
```sql
-- scripts/BACKUP-pegasus-deletion-20251126.sql
-- STEP 1-3 を実行
```

### STEP 2: 個人利益削除
```sql
DELETE FROM nft_daily_profit
WHERE user_id IN (
    SELECT user_id
    FROM users
    WHERE is_pegasus_exchange = TRUE
);
-- 201 rows deleted
```

### STEP 3: available_usdtリセット
```sql
UPDATE affiliate_cycle
SET
    available_usdt = 0,
    updated_at = NOW()
WHERE user_id IN (
    SELECT user_id
    FROM users
    WHERE is_pegasus_exchange = TRUE
);
-- 66 rows updated
```

### STEP 4-5: 検証
```sql
-- 全66名の検証完了
-- available_usdt = 0
-- remaining_profit_count = 0
-- cum_usdt は保持
```

---

## 今後の対応

### 即時対応不要
- ペガサスユーザーは個人利益を受け取らない仕様が正しく適用されました
- 紹介報酬は引き続き受け取ります

### 監視事項
- 今後の日利配布時にペガサスユーザーが除外されているか確認
- RPC関数 `process_daily_yield_v2` の以下の部分で除外処理を確認:
  ```sql
  IF v_user_record.is_pegasus_exchange = TRUE THEN
    CONTINUE;
  END IF;
  ```

---

実行日時: 2025-11-26
実行者: 管理者
環境: 本番環境Supabase
