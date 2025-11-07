-- ========================================
-- マイナス日利時に記録された紹介報酬を削除
-- ========================================
--
-- 問題:
-- マイナス日利の日に紹介報酬が記録されている
-- 仕様: マイナス日利時は紹介報酬を0にする
--
-- このスクリプトの目的:
-- 1. マイナス日利の日付を特定
-- 2. その日付のuser_referral_profitレコードを削除
-- 3. affiliate_cycleのcum_usdtから引かれた分を戻す
-- ========================================

-- STEP 1: マイナス日利の日付を確認
SELECT
  date,
  yield_rate,
  user_rate
FROM daily_yield_log
WHERE yield_rate < 0
ORDER BY date DESC;

-- STEP 2: マイナス日利の日に記録された紹介報酬を確認
SELECT
  urp.date,
  urp.user_id,
  urp.referral_level,
  urp.profit_amount,
  dyl.yield_rate
FROM user_referral_profit urp
JOIN daily_yield_log dyl ON urp.date = dyl.date
WHERE dyl.yield_rate < 0
ORDER BY urp.date DESC, urp.user_id, urp.referral_level;

-- STEP 3: 削除対象の紹介報酬の合計を確認（ユーザーごと）
SELECT
  urp.user_id,
  SUM(urp.profit_amount) as total_incorrect_referral_profit,
  COUNT(*) as record_count
FROM user_referral_profit urp
JOIN daily_yield_log dyl ON urp.date = dyl.date
WHERE dyl.yield_rate < 0
GROUP BY urp.user_id
ORDER BY total_incorrect_referral_profit DESC;

-- ========================================
-- ⚠️ 実行前確認: 上記のクエリで削除対象を確認してください
-- ========================================

-- STEP 4: マイナス日利時の紹介報酬を削除
-- ⚠️ 注意: この操作は元に戻せません。必ず上記で確認してから実行してください。

-- まず、affiliate_cycleのcum_usdtを修正（紹介報酬を引く）
DO $$
DECLARE
  v_user_record RECORD;
  v_incorrect_profit NUMERIC;
BEGIN
  FOR v_user_record IN
    SELECT
      urp.user_id,
      SUM(urp.profit_amount) as total_incorrect_profit
    FROM user_referral_profit urp
    JOIN daily_yield_log dyl ON urp.date = dyl.date
    WHERE dyl.yield_rate < 0
    GROUP BY urp.user_id
  LOOP
    v_incorrect_profit := v_user_record.total_incorrect_profit;

    -- cum_usdtから誤って加算された紹介報酬を引く
    UPDATE affiliate_cycle
    SET
      cum_usdt = cum_usdt - v_incorrect_profit,
      updated_at = NOW()
    WHERE user_id = v_user_record.user_id;

    RAISE NOTICE 'User % : 紹介報酬 $% を cum_usdt から削除',
                 v_user_record.user_id, v_incorrect_profit;
  END LOOP;
END $$;

-- user_referral_profitからマイナス日利時のレコードを削除
DELETE FROM user_referral_profit
WHERE date IN (
  SELECT date
  FROM daily_yield_log
  WHERE yield_rate < 0
);

-- ========================================
-- 確認クエリ
-- ========================================

-- 削除後の確認: マイナス日利時の紹介報酬が0件になっているはず
SELECT
  COUNT(*) as remaining_incorrect_records
FROM user_referral_profit urp
JOIN daily_yield_log dyl ON urp.date = dyl.date
WHERE dyl.yield_rate < 0;

-- 成功メッセージ
DO $$
BEGIN
  RAISE NOTICE '✅ マイナス日利時の紹介報酬を削除しました';
  RAISE NOTICE '✅ affiliate_cycleのcum_usdtを修正しました';
  RAISE NOTICE '⚠️ 次回からマイナス日利時は紹介報酬が記録されないようにするため、';
  RAISE NOTICE '⚠️ scripts/FIX-referral-no-negative.sql を実行してください';
END $$;

-- ========================================
-- 実行後の検証
-- ========================================

-- 各ユーザーのcum_usdtが妥当な値になっているか確認
SELECT
  ac.user_id,
  ac.cum_usdt,
  ac.available_usdt,
  ac.phase,
  COALESCE(SUM(urp.profit_amount), 0) as total_referral_profit
FROM affiliate_cycle ac
LEFT JOIN user_referral_profit urp ON ac.user_id = urp.user_id
GROUP BY ac.user_id, ac.cum_usdt, ac.available_usdt, ac.phase
ORDER BY ac.cum_usdt DESC
LIMIT 20;
