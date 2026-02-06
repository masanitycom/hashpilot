-- ========================================
-- 累計紹介報酬を取得するRPC関数
-- Supabaseの1000件制限を回避するため、サーバーサイドで集計
-- ========================================

-- 既存の関数を削除
DROP FUNCTION IF EXISTS get_cumulative_referral(TEXT[], TEXT);

CREATE OR REPLACE FUNCTION get_cumulative_referral(
  p_user_ids TEXT[],
  p_year_month TEXT
)
RETURNS TABLE(
  user_id TEXT,
  cumulative_amount NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    mrp.user_id::TEXT,
    ROUND(SUM(mrp.profit_amount)::numeric, 2) as cumulative_amount
  FROM monthly_referral_profit mrp
  WHERE mrp.user_id = ANY(p_user_ids)
    AND mrp.year_month <= p_year_month
  GROUP BY mrp.user_id;
END;
$$;

-- 使用例：
-- SELECT * FROM get_cumulative_referral(ARRAY['5FAE2C', '7A9637'], '2026-01');
