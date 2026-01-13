-- ========================================
-- phaseカラムをNULLにリセット
-- フロントエンドで現在のフェーズを表示するように戻す
-- 実行日: 2026-01-13
-- ========================================

UPDATE monthly_withdrawals SET phase = NULL;

SELECT 'phaseカラムをNULLにリセットしました' as status;
SELECT COUNT(*) as total_records FROM monthly_withdrawals;
