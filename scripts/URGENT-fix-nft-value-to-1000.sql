-- ========================================
-- 緊急修正: NFT価格を1100→1000に変更
-- 理由: 日利計算は1000ドル単位で行う（1100は手数料込み価格）
-- ========================================

-- 1. 現在のnft_value分布を確認
SELECT
    '修正前のnft_value分布' as section,
    nft_value,
    COUNT(*) as count
FROM nft_master
WHERE buyback_date IS NULL
GROUP BY nft_value
ORDER BY nft_value;

-- 2. 全てのNFTのnft_valueを1100 → 1000に修正
UPDATE nft_master
SET nft_value = 1000.00
WHERE nft_value = 1100.00;

-- 3. 修正後の確認
SELECT
    '修正後のnft_value分布' as section,
    nft_value,
    COUNT(*) as count
FROM nft_master
GROUP BY nft_value
ORDER BY nft_value;

-- 4. 影響を受けたレコード数
SELECT
    '修正完了' as status,
    COUNT(*) as affected_records
FROM nft_master
WHERE nft_value = 1000.00;

-- 5. 10/2の日利を再計算する必要があるか確認
SELECT
    '10/2の日利再計算チェック' as section,
    COUNT(*) as records_count,
    SUM(daily_profit) as total_profit_before_fix
FROM nft_daily_profit
WHERE date >= '2025-10-01';

-- 完了メッセージ
DO $$
BEGIN
    RAISE NOTICE '===========================================';
    RAISE NOTICE '✅ NFT価格を1000ドルに統一しました';
    RAISE NOTICE '===========================================';
    RAISE NOTICE '変更内容:';
    RAISE NOTICE '  - nft_master.nft_value: 1100 → 1000';
    RAISE NOTICE '  - 日利計算が正しく1000ドルベースになります';
    RAISE NOTICE '';
    RAISE NOTICE '⚠️ 重要:';
    RAISE NOTICE '  - 10/1, 10/2の日利は1100ドルで計算されています';
    RAISE NOTICE '  - 10/15から新しい日利を設定すれば自動的に1000ドルで計算されます';
    RAISE NOTICE '  - 過去のデータを修正する必要はありません（テストデータのため）';
    RAISE NOTICE '===========================================';
END $$;
