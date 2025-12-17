-- ペガサス交換ユーザーと運用開始日を確認
-- 対象:
-- 1. 81B308 (kazushigesomeya@gmail.com) - ペガサス交換ユーザー
-- 2. D2C1F9 (2.forcemillion@gmail.com) - 運用開始日を2025/12/15に調整

-- ユーザー基本情報の確認
SELECT
  user_id,
  email,
  is_pegasus_exchange,
  has_approved_nft,
  operation_start_date,
  total_purchases,
  created_at
FROM users
WHERE user_id IN ('81B308', 'D2C1F9')
ORDER BY user_id;

-- NFT保有状況の確認
SELECT
  nm.user_id,
  u.email,
  nm.id as nft_id,
  nm.nft_type,
  nm.acquired_date,
  nm.buyback_date
FROM nft_master nm
JOIN users u ON nm.user_id = u.user_id
WHERE nm.user_id IN ('81B308', 'D2C1F9')
ORDER BY nm.user_id, nm.acquired_date;

-- 日利記録の確認（12月以降）
SELECT
  ndp.user_id,
  u.email,
  ndp.date,
  ndp.daily_profit,
  ndp.phase
FROM nft_daily_profit ndp
JOIN users u ON ndp.user_id = u.user_id
WHERE ndp.user_id IN ('81B308', 'D2C1F9')
  AND ndp.date >= '2025-12-01'
ORDER BY ndp.user_id, ndp.date;

-- affiliate_cycle状態の確認
SELECT
  ac.user_id,
  u.email,
  ac.cum_usdt,
  ac.available_usdt,
  ac.phase,
  ac.auto_nft_count,
  ac.total_nft_count
FROM affiliate_cycle ac
JOIN users u ON ac.user_id = u.user_id
WHERE ac.user_id IN ('81B308', 'D2C1F9');

-- 確認ポイント:
-- 1. 81B308: is_pegasus_exchange = TRUE であること
--    → 個人利益は配布されない（process_daily_yield_v2で除外）
--
-- 2. D2C1F9: operation_start_date = '2025-12-15' であること
--    → 12/15より前の日利処理では対象外
--    → 12/15以降の日利処理で対象になる

SELECT '確認完了' as result;
