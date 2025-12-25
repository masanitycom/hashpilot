-- ========================================
-- 3ユーザーの12月補填処理
-- 225F87, 20248A, 5A708D
-- 実行日: 2025-12-24
-- 会社負担合計: $171.77
-- ========================================

-- ★★★ STEP 1: is_pegasus_exchange を false に変更 ★★★
-- これにより今後の日利処理で対象になる

UPDATE users
SET is_pegasus_exchange = false,
    updated_at = NOW()
WHERE user_id IN ('225F87', '20248A', '5A708D');

SELECT 'STEP 1: is_pegasus_exchange 更新完了' as status;
SELECT user_id, email, is_pegasus_exchange
FROM users
WHERE user_id IN ('225F87', '20248A', '5A708D');

-- ★★★ STEP 2: 12月分の個人利益を補填 ★★★
-- nft_daily_profitに各日のデータを挿入

-- 12月の日利データを取得して3ユーザー分を挿入
INSERT INTO nft_daily_profit (user_id, nft_id, date, daily_profit, base_amount, created_at)
SELECT
  u.user_id,
  nm.id as nft_id,
  v.date,
  v.profit_per_nft as daily_profit,
  1000 as base_amount,
  NOW()
FROM (
  SELECT date, profit_per_nft
  FROM daily_yield_log_v2
  WHERE date >= '2025-12-01' AND date <= '2025-12-23'
) v
CROSS JOIN users u
INNER JOIN nft_master nm ON u.user_id = nm.user_id AND nm.buyback_date IS NULL
WHERE u.user_id IN ('225F87', '20248A', '5A708D')
ON CONFLICT DO NOTHING;

SELECT 'STEP 2: 個人利益補填完了' as status;
SELECT user_id, COUNT(*) as inserted_count, SUM(daily_profit) as total_profit
FROM nft_daily_profit
WHERE user_id IN ('225F87', '20248A', '5A708D')
  AND date >= '2025-12-01'
GROUP BY user_id;

-- ★★★ STEP 3: 紹介報酬を補填（3ユーザー内の分） ★★★
-- 225F87 → 5A708D(L1)から$26.12受取
-- 20248A → 225F87(L1)から$26.12、5A708D(L2)から$13.06受取
-- 5A708D → なし（3ユーザー内からの報酬なし）

-- 日次ではなく月次で一括挿入（user_referral_profitまたはmonthly_referral_profit）
-- まずmonthly_referral_profitのカラムを確認
SELECT column_name
FROM information_schema.columns
WHERE table_name = 'monthly_referral_profit'
ORDER BY ordinal_position;
