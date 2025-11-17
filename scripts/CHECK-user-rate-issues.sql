-- ========================================
-- user_rate異常値の確認と分析
-- ========================================
-- 実行環境: 本番環境Supabase SQL Editor
-- ========================================

-- 最近のデータを確認（11/13以降）
SELECT
  date,
  yield_rate,
  margin_rate,
  user_rate,
  -- 期待される正しい値（パーセント形式 - 現在のRPC関数の計算方法）
  yield_rate * (1.0 - margin_rate / 100.0) * 0.6 as expected_user_rate_percent,
  -- 期待される正しい値（デシマル形式 - 統一後の計算方法）
  (yield_rate / 100.0) * (1.0 - margin_rate / 100.0) * 0.6 as expected_user_rate_decimal,
  -- 現在の値がどちらに近いか判定
  CASE
    WHEN ABS(user_rate - (yield_rate * (1.0 - margin_rate / 100.0) * 0.6)) < 0.001
      THEN 'パーセント形式'
    WHEN ABS(user_rate - ((yield_rate / 100.0) * (1.0 - margin_rate / 100.0) * 0.6)) < 0.00001
      THEN 'デシマル形式'
    ELSE '異常値'
  END as format_type,
  -- フロントエンド表示（×100した場合）
  user_rate * 100 as displayed_if_multiplied,
  created_at
FROM daily_yield_log
WHERE date >= '2025-11-13'
ORDER BY date DESC;
