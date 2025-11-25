-- 2025/11/7のデータを完全削除（最終版）

-- 元のテーブル: nft_daily_profit から削除
DELETE FROM nft_daily_profit
WHERE date = '2025-11-07';

-- 削除確認
SELECT
  'nft_daily_profit' as table_name,
  COUNT(*) as remaining_records
FROM nft_daily_profit
WHERE date = '2025-11-07'
UNION ALL
SELECT
  'user_daily_profit (ビュー)' as table_name,
  COUNT(*) as remaining_records
FROM user_daily_profit
WHERE date = '2025-11-07';

-- 成功メッセージ
DO $$
BEGIN
    RAISE NOTICE '✅ 2025/11/7のデータを削除しました';
    RAISE NOTICE 'nft_daily_profitテーブルから削除';
    RAISE NOTICE 'user_daily_profitビューも自動更新されます';
END $$;
