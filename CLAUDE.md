# HASHPILOT システム管理ガイド

## 🚨🚨🚨 日次処理と月末処理の分離（最重要）🚨🚨🚨

**絶対に守ること：日次処理と月末処理は完全に分離する**

### 日次処理（`process_daily_yield_v2`）
| 項目 | 実行 | 備考 |
|------|------|------|
| 個人利益配布（60%） | ✅ 実行 | available_usdtに加算 |
| 紹介報酬計算 | ❌ 実行しない | 月末処理で実行 |
| cum_usdt更新 | ❌ 実行しない | 月末処理で実行 |
| NFT自動付与 | ❌ 実行しない | 月末処理で実行 |

### 月末処理（`process_monthly_referral_reward`）
| 項目 | 実行 | 備考 |
|------|------|------|
| 紹介報酬計算（30%） | ✅ 実行 | monthly_referral_profitに保存 |
| cum_usdt更新 | ✅ 実行 | 紹介報酬のみ |
| phase再計算 | ✅ 実行 | USDT/HOLD判定 |
| NFT自動付与 | ✅ 実行 | cum_usdt >= 2200 |

### ⚠️ 禁止事項
- `process_daily_yield_v2`に紹介報酬計算を追加してはいけない
- `process_daily_yield_v2`にNFT自動付与を追加してはいけない
- `user_referral_profit`テーブル（日次紹介報酬）は廃止済み、使用禁止

### 関連テーブル
| テーブル | 用途 | 更新タイミング |
|----------|------|----------------|
| `nft_daily_profit` | 日次個人利益 | 日次処理 |
| `monthly_referral_profit` | 月次紹介報酬 | 月末処理 |
| `affiliate_cycle.available_usdt` | 出金可能額 | 日次+月末 |
| `affiliate_cycle.cum_usdt` | 紹介報酬累計 | 月末処理のみ |

### 🔧 RPC関数の状態（2026年1月13日確認）

| 関数名 | 用途 | 使用状況 | NFT自動付与 |
|--------|------|----------|-------------|
| `process_daily_yield_v2` | 日次利益配布 | ✅ フロントエンド使用 | なし（正常） |
| `process_monthly_referral_reward` | 月末紹介報酬 | ✅ フロントエンド使用 | nft_sequence設定済み |
| `process_monthly_referral_profit` | 月末紹介報酬（旧） | ❌ 未使用 | nft_sequence設定済み |
| `process_daily_yield_with_cycles` | V1日次処理 | ❌ 未使用（useV2=true） | - |

**フロントエンド呼び出し（`app/admin/yield/page.tsx`）:**
- 日次処理: `supabase.rpc('process_daily_yield_v2', ...)`
- 月末処理: `supabase.rpc('process_monthly_referral_reward', ...)`

---

## 🚨 紹介報酬計算の絶対ルール（最重要）

**紹介報酬は月末の合計利益で計算する。日々のプラス・マイナスは関係ない。**

### 正しい計算方法：
```sql
-- ✅ 正しい：プラス・マイナス両方を含める
CREATE TEMP TABLE temp_monthly_profit AS
SELECT
  user_id,
  SUM(daily_profit) as monthly_profit  -- 月末合計（プラス・マイナス含む）
FROM user_daily_profit
WHERE date >= v_start_date AND date <= v_end_date
GROUP BY user_id;

-- ❌ 間違い：プラス日利のみで計算
WHERE daily_profit > 0  -- これは絶対に使わない
```

### 例：9A3A16（156 NFT）の11月
- 全日利合計: **$4,994.184**（これを使う）
- プラス日利のみ: $8,525.712（使わない）
- マイナス日利: -$3,531.528（月末合計に含まれる）

### 紹介報酬の計算：
- Level 1: $4,994.184 × 20% = $998.84
- Level 2: $4,994.184 × 10% = **$499.42**
- Level 3: $4,994.184 × 5% = $249.71

### 重要な注意：
- 個人利益：プラス・マイナス両方を反映
- 紹介報酬：**月末合計がプラスの場合のみ**配布（`monthly_profit > 0`）
- マイナス月末合計の場合：紹介報酬は$0

---

## 📁 ファイル保存ルール

**重要:** SQLスクリプトやドキュメントを作成する際は、必ず以下のディレクトリに保存すること：

- **SQLスクリプト**: `scripts/` ディレクトリ（例: `scripts/CHECK-xxx.sql`）
- **ドキュメント**: プロジェクトルート（例: `CLAUDE.md`, `FIX-XXX.md`）
- **一時ファイル禁止**: `/tmp/` に保存しない

**命名規則:**
- 確認系: `CHECK-xxx.sql`
- 修正系: `FIX-xxx.sql`
- 削除系: `DELETE-xxx.sql`
- 調査系: `INVESTIGATE-xxx.sql`
- 緊急系: `URGENT-xxx.sql`

---

## 🚨🚨🚨 ペガサスユーザーの運用ルール（最重要）🚨🚨🚨

### 基本ルール
**ペガサスユーザー（is_pegasus_exchange = true）は日利・紹介報酬の対象外**

- `is_pegasus_exchange = true` → 日利を受け取らない
- 特例ユーザーは `is_pegasus_exchange = false` に設定されている
- 特例ユーザーは通常ユーザーと同じ扱いで日利を受け取る

### ✅ 必須の除外条件（絶対に含める）
```sql
-- ✅ ペガサス除外条件は必ず含める
AND (u.is_pegasus_exchange = FALSE OR u.is_pegasus_exchange IS NULL)
```

### ⛔ 禁止事項
```sql
-- ❌ ペガサス除外条件を削除してはいけない
-- operation_start_dateだけで判定すると、ペガサスユーザーにも日利が配布されてしまう
```

### 特例ユーザー（2026年2月時点）
以下のユーザーは元ペガサスだが `is_pegasus_exchange = false` に設定されている：
- balance.p.p.p.p.1060@gmail.com
- akihiro.y.grant@gmail.com
- feel.me.yurie@gmail.com
- msic200906@yahoo.co.jp
- oaiaiaio1226@gmail.com
- kyoko7oha@gmail.com
- miekohannsei@gmail.com
- sakanatsuri303@gmail.com
- yosshi.manmaru.oka1027@gmail.com
- tkpuraimu@gmail.com（2/1運用開始）
- shinmisoo311@gmail.com（2/1運用開始）
- zakaishi2326@gmail.com（ペガサス7枚中2枚補填、NFT1枚のみ運用中、もう1枚はoperation_start_date=NULL）

---

## 🔒 外部プロジェクト使用テーブル（編集禁止）

以下のテーブルは外部プロジェクト（hashokx）で使用しています。HASHPILOTでは一切触らないでください。

| テーブル名 | 使用プロジェクト | 用途 |
|------------|------------------|------|
| user_api_keys | hashokx | ユーザーのOKX APIキー管理 |

**注意:** これらのテーブルはHASHPILOTの機能とは無関係です。誤って編集・削除しないでください。

---

## 💰 月末出金の紹介報酬計算（2026年2月7日確定）

### 🚨 最重要：referral_amount計算式

`monthly_withdrawals.referral_amount`（今月出金できる紹介報酬）の計算は、**NFT自動購入の有無**と**フェーズ**の組み合わせで決まる。

#### 計算式（4パターン）

| NFT自動購入 | フェーズ | referral_amount計算式 |
|-------------|----------|----------------------|
| あり（auto_nft_count > 0） | USDT | `cum_usdt` |
| あり（auto_nft_count > 0） | HOLD | `cum_usdt - 1100` |
| なし（auto_nft_count = 0） | USDT | `cum_usdt - withdrawn_referral_usdt` |
| なし（auto_nft_count = 0） | HOLD | `MAX(0, 1100 - withdrawn_referral_usdt)` |

#### 計算ロジックの解説

**NFT自動購入あり（auto_nft_count > 0）:**
- NFT自動購入時に`cum_usdt`から$2,200が引かれ、$1,100が`available_usdt`に戻る
- つまり`cum_usdt`は既に自動購入分がリセットされている
- `withdrawn_referral_usdt`を引く必要はない（NFT購入でリセット済み）

**NFT自動購入なし（auto_nft_count = 0）:**
- `withdrawn_referral_usdt`（既に出金済みの紹介報酬累計）を引く必要がある
- HOLDフェーズでも$1,100までは出金可能（$1,100 - 既払い = 残り出金可能額）

#### SQL実装例

```sql
UPDATE monthly_withdrawals mw
SET
  referral_amount = CASE
    -- NFT購入あり
    WHEN ac.auto_nft_count > 0 THEN
      CASE
        WHEN ac.phase = 'USDT' THEN ROUND(GREATEST(0, ac.cum_usdt)::numeric, 2)
        WHEN ac.phase = 'HOLD' THEN ROUND(GREATEST(0, ac.cum_usdt - 1100)::numeric, 2)
        ELSE 0
      END
    -- NFT購入なし
    ELSE
      CASE
        WHEN ac.phase = 'USDT' THEN ROUND(GREATEST(0, ac.cum_usdt - COALESCE(ac.withdrawn_referral_usdt, 0))::numeric, 2)
        -- HOLDは$1100まで出金可能
        WHEN ac.phase = 'HOLD' THEN ROUND(GREATEST(0, 1100 - COALESCE(ac.withdrawn_referral_usdt, 0))::numeric, 2)
        ELSE 0
      END
  END,
  total_amount = mw.personal_amount + [上記と同じCASE式]
FROM affiliate_cycle ac
WHERE mw.user_id = ac.user_id
  AND mw.withdrawal_month = '対象月'
  AND mw.status IN ('pending', 'on_hold');
```

#### 関連テーブル・カラム

| テーブル.カラム | 説明 |
|-----------------|------|
| `affiliate_cycle.cum_usdt` | 紹介報酬累計（NFT自動購入で-$2,200） |
| `affiliate_cycle.withdrawn_referral_usdt` | 出金済み紹介報酬の累計 |
| `affiliate_cycle.auto_nft_count` | 自動NFT購入回数 |
| `affiliate_cycle.phase` | USDT / HOLD |
| `monthly_withdrawals.referral_amount` | 今月出金する紹介報酬 |
| `monthly_withdrawals.personal_amount` | 今月の個人利益（日利合計） |
| `monthly_withdrawals.total_amount` | 出金合計 = personal + referral |

#### 修正用SQLスクリプト

- `scripts/FIX-january-referral-hold-correct.sql` - 正しい計算式

---

## 📚 詳細ドキュメント（参照）

@docs/BUSINESS_LOGIC.md
@docs/BUG_HISTORY.md
@docs/TODO.md
@docs/INFRASTRUCTURE.md

---

最終更新: 2026年3月1日
