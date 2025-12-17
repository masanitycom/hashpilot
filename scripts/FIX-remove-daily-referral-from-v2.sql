-- V2日利処理で誤って追加された日次紹介報酬を削除し、cum_usdtをリセット
-- 紹介報酬は月次のみ（monthly_referral_profit）

-- STEP 1: 12月の日次紹介報酬を削除
DELETE FROM user_referral_profit
WHERE date >= '2025-12-01';

-- STEP 2: cum_usdtを月次紹介報酬のみにリセット（全ユーザー）
-- monthly_referral_profitの合計を使用
UPDATE affiliate_cycle ac
SET cum_usdt = COALESCE((
  SELECT SUM(
    CAST(COALESCE(level1_amount, '0') AS NUMERIC) +
    CAST(COALESCE(level2_amount, '0') AS NUMERIC) +
    CAST(COALESCE(level3_amount, '0') AS NUMERIC)
  )
  FROM monthly_referral_profit mrp
  WHERE mrp.user_id = ac.user_id
), 0),
updated_at = NOW();

-- STEP 3: 確認
SELECT
  ac.user_id,
  ac.cum_usdt as new_cum_usdt,
  (
    SELECT SUM(
      CAST(COALESCE(level1_amount, '0') AS NUMERIC) +
      CAST(COALESCE(level2_amount, '0') AS NUMERIC) +
      CAST(COALESCE(level3_amount, '0') AS NUMERIC)
    )
    FROM monthly_referral_profit mrp
    WHERE mrp.user_id = ac.user_id
  ) as monthly_total
FROM affiliate_cycle ac
WHERE ac.user_id = '7A9637';

-- 確認メッセージ
SELECT '12月の日次紹介報酬を削除し、cum_usdtを月次紹介報酬のみにリセットしました' as result;
