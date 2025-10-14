-- ========================================
-- 日利計算関数のソースコード確認
-- ========================================

-- process_daily_yield_with_cycles関数の定義を取得
SELECT pg_get_functiondef(oid)
FROM pg_proc
WHERE proname = 'process_daily_yield_with_cycles'
LIMIT 1;
