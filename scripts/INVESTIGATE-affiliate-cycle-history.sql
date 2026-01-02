-- ========================================
-- affiliate_cycleの更新履歴を推測
-- ========================================
-- available_usdtがどのように加算されたか調べる

-- 1. ACACDBの詳細
SELECT '=== 1. ACACDB: 現在のaffiliate_cycle ===' as section;
SELECT * FROM affiliate_cycle WHERE user_id = 'ACACDB';

-- 2. 12月日利の合計（nft_daily_profit）
SELECT '=== 2. ACACDB: 12月日利合計 ===' as section;
SELECT
  SUM(daily_profit) as dec_profit,
  COUNT(*) as record_count
FROM nft_daily_profit
WHERE user_id = 'ACACDB'
  AND date >= '2025-12-01' AND date < '2026-01-01';

-- 3. 月次紹介報酬の合計
SELECT '=== 3. ACACDB: 月次紹介報酬合計 ===' as section;
SELECT
  SUM(profit_amount) as referral_total
FROM user_referral_profit_monthly
WHERE user_id = 'ACACDB';

-- 4. 過剰額の計算（修正前ベース）
SELECT '=== 4. 過剰額の分析 ===' as section;
SELECT
  972.35 as before_fix,
  493.91 as after_fix,
  972.35 - 493.91 as over_amount,
  280.896 as daily_profit,
  213.01 as referral_profit,
  (972.35 - 493.91) / 280.896 as over_ratio_to_daily,
  (972.35 - 493.91) / 213.01 as over_ratio_to_referral;

-- 5. process_daily_yield_v2がavailable_usdtを更新した回数
-- nft_daily_profitの日付数 = available_usdtへの加算回数
SELECT '=== 5. ACACDB: 日利配布日数 ===' as section;
SELECT
  COUNT(DISTINCT date) as days_with_profit
FROM nft_daily_profit
WHERE user_id = 'ACACDB';

-- 6. user_referral_profit_monthlyの作成日時
SELECT '=== 6. 月次紹介報酬の作成タイミング ===' as section;
SELECT
  user_id,
  profit_amount,
  created_at
FROM user_referral_profit_monthly
WHERE user_id = 'ACACDB'
ORDER BY created_at;

-- 7. 12月1日〜15日の日利合計（12/1開始ユーザー）
SELECT '=== 7. 12/1〜12/15の日利合計（1NFT） ===' as section;
SELECT
  SUM(profit_per_nft * 0.42) as half_month_profit
FROM daily_yield_log_v2
WHERE date >= '2025-12-01' AND date <= '2025-12-15';

-- 8. $478.44に近い値を探す
SELECT '=== 8. $478.44の正体を探す ===' as section;
SELECT
  -- 可能性1: 日利の約1.7倍
  280.896 * 1.7 as daily_x_1_7,
  -- 可能性2: 日利 + 紹介報酬 + 日利（二重加算）
  280.896 + 213.01 + 280.896 - 493.91 as double_daily,
  -- 可能性3: 日利が別の場所でも加算された
  972.35 - 213.01 as available_minus_referral,
  (972.35 - 213.01) / 280.896 as ratio_to_daily,
  -- 可能性4: 過剰額 ÷ NFT数
  478.44 / 12 as over_per_nft;

-- 9. 12NFTユーザーの12月前半の日利
SELECT '=== 9. 12NFT × 12月前半 ===' as section;
SELECT
  SUM(profit_per_nft * 0.42) * 12 as expected_half_month_12nft
FROM daily_yield_log_v2
WHERE date >= '2025-12-01' AND date <= '2025-12-15';

-- 10. 1NFTの12月前半日利
SELECT '=== 10. 1NFT × 12月前半（$23.912との比較） ===' as section;
SELECT
  SUM(profit_per_nft * 0.42) as half_month_1nft
FROM daily_yield_log_v2
WHERE date >= '2025-12-01' AND date <= '2025-12-15';
