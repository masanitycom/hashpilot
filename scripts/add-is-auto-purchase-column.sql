-- purchasesテーブルにis_auto_purchaseカラムを追加
-- 作成日: 2025年10月7日

-- is_auto_purchaseカラムを追加（存在しない場合のみ）
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'purchases' AND column_name = 'is_auto_purchase'
    ) THEN
        ALTER TABLE purchases
        ADD COLUMN is_auto_purchase BOOLEAN DEFAULT FALSE;

        RAISE NOTICE '✅ is_auto_purchaseカラムを追加しました';
    ELSE
        RAISE NOTICE 'ℹ️  is_auto_purchaseカラムは既に存在します';
    END IF;
END $$;

-- 確認
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_name = 'purchases' AND column_name = 'is_auto_purchase';

-- コメント追加
COMMENT ON COLUMN purchases.is_auto_purchase IS '自動購入フラグ（サイクル到達による自動NFT付与）';
