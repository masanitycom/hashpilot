# ペガサス特例3名対応完了報告（2025-11-30）

## 対象ユーザー

| user_id | email | NFT数 | operation_start_date |
|---------|-------|-------|---------------------|
| 5A708D | feel.me.yurie@gmail.com | 1 | 2025-07-15 |
| 225F87 | akihiro.y.grant@gmail.com | 1 | 2025-09-01 |
| 20248A | balance.p.p.p.p.1060@gmail.com | 1 | 2025-09-15 |

## 実行内容

### 1. フラグ設定（STEP 1）
- `users.exclude_from_daily_profit`カラム追加
- 特例3名: `exclude_from_daily_profit = FALSE`（日利対象）
- 他の63名: `exclude_from_daily_profit = TRUE`（日利対象外）
- `is_pegasus_exchange = TRUE`は全員維持（ラベル表示用）

### 2. 過去の日利配布（STEP 2-4）
**期間:** 2025-11-01 ～ 2025-11-29（23日分）

**個人利益配布:**
- 各ユーザー: 23レコード、合計$23.060
- `nft_daily_profit`テーブルにINSERT完了

**affiliate_cycle更新:**
| user_id | available_usdt | cum_usdt |
|---------|----------------|----------|
| 5A708D | $34.20 | $90.72 |
| 225F87 | $33.10 | $20.23 |
| 20248A | $27.33 | $8.69 |

**紹介報酬配布（Level 1のみ）:**
- `5A708D` → 紹介者`B51CA4`に報酬配布
- `225F87` → 紹介者`5A708D`に報酬配布
- `20248A` → 紹介者`225F87`に報酬配布

### 3. RPC関数更新（STEP 5）
**修正箇所:**
```sql
-- 修正前:
IF v_user_record.is_pegasus_exchange = TRUE THEN
  CONTINUE;
END IF;

-- 修正後:
IF v_user_record.exclude_from_daily_profit = TRUE THEN
  CONTINUE;
END IF;
```

**影響:**
- 今後の日利設定で特例3名にも自動配布される
- 他の63名は引き続き対象外

## 紹介関係の連鎖

特例3名は以下のように連鎖しています：

```
B51CA4 (ペガサス・対象外)
  └─ 5A708D (feel.me.yurie) ← 特例
       └─ 225F87 (akihiro.y.grant) ← 特例
            └─ 20248A (balance.p.p.p.p) ← 特例
```

- `B51CA4`は特例ではないため、個人利益は受け取らない
- しかし`5A708D`の紹介報酬は受け取る

## 制限事項

### Level 2, Level 3の紹介報酬
今回のスクリプトでは**Level 1の紹介報酬のみ**配布しました。

Level 2, Level 3の計算は複雑なため、簡易版では省略しています。

完全な紹介報酬が必要な場合は、RPC関数での再計算が必要です。

## 今後の運用

### 通常の日利設定
1. 管理画面（/admin/yield）から日利を設定
2. 特例3名にも自動的に配布される
3. `is_pegasus_exchange = TRUE`のラベルは表示されたまま

### 特例の追加・削除
```sql
-- 特例に追加する場合
UPDATE users
SET exclude_from_daily_profit = FALSE
WHERE email = 'example@example.com';

-- 特例から削除する場合
UPDATE users
SET exclude_from_daily_profit = TRUE
WHERE email = 'example@example.com';
```

## 検証結果

### 個人利益
- ✅ 各ユーザー23日分のレコード作成
- ✅ 各ユーザー$23.060の個人利益配布
- ✅ `nft_daily_profit`テーブルに正しくINSERT

### affiliate_cycle
- ✅ `available_usdt`に個人利益を加算
- ✅ 紹介報酬を`cum_usdt`と`available_usdt`に加算

### RPC関数
- ✅ `process_daily_yield_with_cycles`更新完了
- ✅ `exclude_from_daily_profit`フラグで制御

---

実行日時: 2025-11-30
実行者: 管理者
環境: 本番環境Supabase
