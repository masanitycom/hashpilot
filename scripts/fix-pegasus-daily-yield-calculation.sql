-- ========================================
-- ペガサスユーザーの日利計算を1000ドルベースに修正
-- ========================================
--
-- 問題: ペガサスユーザーの日利計算がamount_usd（1100ドル）で計算されている
-- 解決: ペガサスユーザーは1000ドルベースで日利計算する
--
-- 実行前の確認:
-- SELECT
--   u.user_id,
--   u.is_pegasus_exchange,
--   p.amount_usd,
--   CASE
--     WHEN u.is_pegasus_exchange THEN 1000
--     ELSE (p.amount_usd * 1000.0 / 1100.0)
--   END as daily_yield_base
-- FROM users u
-- JOIN purchases p ON p.user_id = u.user_id
-- WHERE u.is_pegasus_exchange = true
-- AND p.admin_approved = true;
-- ========================================

-- 注意: この修正は process_daily_yield_with_cycles 関数内で行う必要があります
-- 以下のロジックを関数内に追加してください：

/*
日利計算の基準額を計算する部分：

変更前:
  base_amount := (purchase.amount_usd * 1000.0 / 1100.0);

変更後:
  -- ペガサスユーザーは1000ドル固定、通常ユーザーは手数料除く計算
  IF user_record.is_pegasus_exchange THEN
    base_amount := 1000.0;  -- ペガサスは1:1交換なので1000ドル固定
  ELSE
    base_amount := (purchase.amount_usd * 1000.0 / 1100.0);
  END IF;
*/

-- ========================================
-- 確認クエリ（修正後に実行）
-- ========================================

-- ペガサスユーザーの日利計算基準額を確認
SELECT
  u.user_id,
  u.email,
  u.is_pegasus_exchange,
  COUNT(p.id) as nft_count,
  SUM(p.amount_usd) as total_purchased,
  CASE
    WHEN u.is_pegasus_exchange THEN COUNT(p.id) * 1000.0
    ELSE SUM(p.amount_usd * 1000.0 / 1100.0)
  END as daily_yield_base_amount
FROM users u
LEFT JOIN purchases p ON p.user_id = u.user_id AND p.admin_approved = true
WHERE u.is_pegasus_exchange = true
GROUP BY u.user_id, u.email, u.is_pegasus_exchange
ORDER BY u.user_id;

-- ========================================
-- 重要な注意事項
-- ========================================
--
-- このSQLは参考情報です。実際の修正は：
-- 1. Supabase Dashboard → Database → Functions
-- 2. process_daily_yield_with_cycles 関数を編集
-- 3. 上記のロジックを base_amount 計算部分に追加
-- 4. 保存して適用
--
-- ========================================
