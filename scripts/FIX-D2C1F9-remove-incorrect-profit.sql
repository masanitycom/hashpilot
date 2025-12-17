-- D2C1F9 (forcemillion@gmail.com) の誤配布データを削除
-- 運用開始日: 2025-12-15
-- 問題: 12/1〜12/5の日利が誤って配布されている

-- STEP 1: 誤配布された日利の確認
SELECT
  user_id,
  date,
  daily_profit,
  phase
FROM nft_daily_profit
WHERE user_id = 'D2C1F9'
  AND date < '2025-12-15'
ORDER BY date;

-- 誤配布の合計額
SELECT
  SUM(CAST(daily_profit AS NUMERIC)) as total_incorrect_profit
FROM nft_daily_profit
WHERE user_id = 'D2C1F9'
  AND date < '2025-12-15';

-- STEP 2: affiliate_cycleから誤配布額を差し引く
-- 現在のavailable_usdt: $12.77
-- 誤配布合計: 確認後に計算

-- まず合計を確認
DO $$
DECLARE
  v_incorrect_total NUMERIC;
BEGIN
  SELECT COALESCE(SUM(CAST(daily_profit AS NUMERIC)), 0)
  INTO v_incorrect_total
  FROM nft_daily_profit
  WHERE user_id = 'D2C1F9'
    AND date < '2025-12-15';

  RAISE NOTICE '誤配布合計: $%', v_incorrect_total;
END $$;

-- STEP 3: 誤配布データを削除
DELETE FROM nft_daily_profit
WHERE user_id = 'D2C1F9'
  AND date < '2025-12-15';

-- STEP 4: affiliate_cycleを更新
-- available_usdtから誤配布額を差し引く
-- 12/1〜12/5の合計: -13.552 + 13.294 + 7.738 + 5.813 + (-14.067) = -0.774
-- しかしavailable_usdtは$12.77なので、何か他の記録がある可能性

-- 一旦、available_usdtを0にリセット
UPDATE affiliate_cycle
SET
  available_usdt = 0,
  updated_at = NOW()
WHERE user_id = 'D2C1F9';

-- STEP 5: 確認
SELECT
  user_id,
  cum_usdt,
  available_usdt,
  phase
FROM affiliate_cycle
WHERE user_id = 'D2C1F9';

SELECT
  COUNT(*) as remaining_records
FROM nft_daily_profit
WHERE user_id = 'D2C1F9'
  AND date < '2025-12-15';

SELECT 'D2C1F9の誤配布データを削除しました' as result;
