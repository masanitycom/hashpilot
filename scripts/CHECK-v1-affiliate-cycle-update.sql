-- ========================================
-- V1関数のaffiliate_cycle更新処理を確認
-- ========================================

-- process_daily_yield_with_cycles関数のソースコードを確認
SELECT
    proname as function_name,
    prosrc as source_code
FROM pg_proc
WHERE proname = 'process_daily_yield_with_cycles';
