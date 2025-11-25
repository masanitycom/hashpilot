# V1（旧システム）vs V2（新システム）の比較

## 基本情報
- **V1**: `process_daily_yield_with_cycles` - 利率％で入力
- **V2**: `process_daily_yield_v2` - 金額＄で入力

---

## 重要な仕様の比較

### 1. ペガサス交換ユーザーの扱い

| 項目 | V1（旧システム） | V2（現在の実装） | 正誤 |
|------|------------------|------------------|------|
| **個人利益（日利）** | ❌ 除外 `COALESCE(u.is_pegasus_exchange, FALSE) = FALSE` | ❌ 除外 `(u.is_pegasus_exchange = FALSE OR NULL)` | ✅ 正しい |
| **紹介報酬の元** | ✅ **含める**（NFT価値から仮の利益を計算） | ❌ **含めない**（nft_daily_profitから計算） | ❌ **間違い** |
| **紹介報酬の受取** | ✅ 受け取る | ✅ 受け取る | ✅ 正しい |

**V2の問題:**
```sql
-- V2の紹介報酬計算（間違い）
SELECT COALESCE(SUM(ndp.daily_profit), 0) as child_profit
FROM users child
LEFT JOIN nft_daily_profit ndp ON ndp.user_id = child.user_id
-- ペガサス交換ユーザーはndpに記録がないので、紹介報酬が発生しない！
```

**V1の正しい方法:**
```sql
-- V1の紹介報酬計算（正しい）
SELECT COALESCE(SUM(nm.nft_value), 0) as total_nft_value
FROM users u
LEFT JOIN nft_master nm ON u.user_id = nm.user_id
-- NFT価値から直接計算するので、ペガサス交換ユーザーも含まれる
v_user_profit := v_user_record.total_nft_value * v_user_rate;
```

---

### 2. 運用開始日のチェック

| 項目 | V1（旧システム） | V2（現在の実装） | CLAUDE.md修正 | 正誤 |
|------|------------------|------------------|---------------|------|
| **個人利益** | `IS NULL OR <= p_date` | `IS NOT NULL AND <= p_date` | `IS NOT NULL AND <= p_date` | ✅ 正しい |
| **紹介報酬（親）** | `IS NULL OR <= p_date` | `IS NOT NULL AND <= p_date` | `IS NOT NULL AND <= p_date` | ✅ 正しい |
| **紹介報酬（子）** | `IS NULL OR <= p_date` | `IS NOT NULL AND <= p_date` | `IS NOT NULL AND <= p_date` | ✅ 正しい |

**CLAUDE.mdの修正履歴（2025年11月13日）:**
> **問題:** `operation_start_date IS NULL` のユーザーも日利と紹介報酬の対象になっていた
>
> **修正:** `IS NOT NULL AND <= p_date` に変更

V2は既に修正済みの仕様を実装している ✅

---

### 3. NFT自動付与のロジック

| 項目 | V1（旧システム） | V2（現在の実装） | 正誤 |
|------|------------------|------------------|------|
| **判定条件** | `cum_usdt >= 2200` | `cum_usdt >= 2200` | ✅ 正しい |
| **cum_usdt減算** | `-= 2200` | `-= 1100` | ❌ **間違い** |
| **available_usdt加算** | `+= 1100` | `+= 1100` | ✅ 正しい |
| **NFT価格** | `$1100` | `$1100` | ✅ 正しい |
| **フェーズ更新** | `>= 1100 → HOLD` | `>= 1100 → HOLD` | ✅ 正しい |

**V2の問題:**
```sql
-- V2（間違い）
UPDATE affiliate_cycle
SET
  cum_usdt = cum_usdt - 1100,  -- ❌ 間違い！
  available_usdt = available_usdt + 1100
```

**V1の正しい方法:**
```sql
-- V1（正しい）
UPDATE affiliate_cycle
SET
  cum_usdt = cum_usdt - 2200,  -- ✅ 正しい！
  available_usdt = available_usdt + 1100
```

**理由:**
- NFT自動付与は$2,200到達時に発生
- ユーザーは$1,100のNFTを受け取る
- 残りの$1,100は`available_usdt`に加算（出金可能）
- `cum_usdt`からは**$2,200**を減算する（サイクルリセット）

---

### 4. affiliate_cycleの更新方法

| 項目 | V1（旧システム） | V2（現在の実装） | 正誤 |
|------|------------------|------------------|------|
| **個人利益** | `available_usdt += profit` | `available_usdt += profit` | ✅ 正しい |
| **紹介報酬（cum）** | `cum_usdt += referral` | `cum_usdt += referral` | ✅ 正しい |
| **紹介報酬（available）** | `available_usdt`は更新しない | `available_usdt += referral` | ❌ **間違い** |

**V2の問題:**
```sql
-- V2（間違い）
UPDATE affiliate_cycle
SET
  cum_usdt = cum_usdt + v_referral_profit,  -- ✅ 正しい
  available_usdt = available_usdt + v_referral_profit  -- ❌ 間違い！
```

**V1の正しい方法:**
```sql
-- V1（正しい）
-- 紹介報酬はcum_usdtのみに加算（サイクル計算用）
INSERT INTO affiliate_cycle (user_id, cum_usdt, available_usdt, ...)
VALUES (parent_id, v_referral_profit, 0, ...)  -- ✅ available_usdtは0
ON CONFLICT (user_id) DO UPDATE SET
  cum_usdt = affiliate_cycle.cum_usdt + EXCLUDED.cum_usdt
```

**重要:**
- 紹介報酬は`cum_usdt`のみに加算（サイクル計算用）
- `available_usdt`には加算しない
- NFT自動付与時に`available_usdt`に移動する

---

## まとめ：V2システムの修正が必要な箇所

### ❌ 重大な問題（修正必須）

1. **紹介報酬の計算方法**
   - 現在: `nft_daily_profit`から計算
   - 正しい: `nft_master`のNFT価値から計算
   - 影響: ペガサス交換ユーザーが紹介報酬の元にならない

2. **NFT自動付与の減算額**
   - 現在: `cum_usdt -= 1100`
   - 正しい: `cum_usdt -= 2200`
   - 影響: サイクルが正しくリセットされない

3. **紹介報酬のaffiliate_cycle更新**
   - 現在: `cum_usdt`と`available_usdt`の両方に加算
   - 正しい: `cum_usdt`のみに加算
   - 影響: 二重払いの問題

### ✅ 正しく実装されている箇所

1. ペガサス交換ユーザーの個人利益除外
2. 運用開始日のチェック（IS NOT NULL AND <= p_date）
3. マイナス日利の配布
4. 紹介報酬の受取（親側のチェック）

---

## 次のステップ

1. V2システムを修正
2. テスト環境で検証
3. 本番環境への適用
