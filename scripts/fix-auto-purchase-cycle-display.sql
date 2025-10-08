-- ========================================
-- 自動NFT購入履歴のサイクル番号表示を修正
-- 購入時のサイクル番号を記録・表示する
-- ========================================

-- 1. purchasesテーブルにcycle_number_at_purchaseカラムを追加
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'purchases'
        AND column_name = 'cycle_number_at_purchase'
    ) THEN
        ALTER TABLE purchases
        ADD COLUMN cycle_number_at_purchase INTEGER;

        RAISE NOTICE 'カラム cycle_number_at_purchase を追加しました';
    ELSE
        RAISE NOTICE 'カラム cycle_number_at_purchase は既に存在します';
    END IF;
END $$;

-- 2. 既存の自動購入レコードに連番でサイクル番号を設定
DO $$
DECLARE
    v_user_id VARCHAR(6);
    v_purchase_record RECORD;
    v_cycle_num INTEGER;
BEGIN
    -- ユーザーごとに処理
    FOR v_user_id IN
        SELECT DISTINCT user_id
        FROM purchases
        WHERE is_auto_purchase = true
        ORDER BY user_id
    LOOP
        v_cycle_num := 1;

        -- そのユーザーの自動購入を古い順に処理
        FOR v_purchase_record IN
            SELECT id
            FROM purchases
            WHERE user_id = v_user_id
              AND is_auto_purchase = true
            ORDER BY created_at ASC
        LOOP
            UPDATE purchases
            SET cycle_number_at_purchase = v_cycle_num
            WHERE id = v_purchase_record.id;

            v_cycle_num := v_cycle_num + 1;
        END LOOP;

        RAISE NOTICE 'ユーザー % の自動購入履歴を更新しました（%件）', v_user_id, v_cycle_num - 1;
    END LOOP;
END $$;

-- 3. get_auto_purchase_history関数を修正
DROP FUNCTION IF EXISTS get_auto_purchase_history(TEXT, INTEGER);

CREATE OR REPLACE FUNCTION get_auto_purchase_history(
    p_user_id TEXT,
    p_limit INTEGER DEFAULT 10
)
RETURNS TABLE(
    purchase_id UUID,
    purchase_date TIMESTAMP,
    nft_quantity INTEGER,
    amount_usd TEXT,
    cycle_number INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT
        p.id,
        p.created_at,
        p.nft_quantity,
        p.amount_usd,
        COALESCE(p.cycle_number_at_purchase, 1) as cycle_number  -- 購入時のサイクル番号を使用
    FROM purchases p
    WHERE p.user_id = p_user_id
      AND p.is_auto_purchase = true
      AND p.admin_approved = true
    ORDER BY p.created_at DESC
    LIMIT p_limit;
END;
$$;

-- 4. process_daily_yield_with_cycles関数を修正して購入時にサイクル番号を記録
-- 既存の関数を確認
DO $$
BEGIN
    RAISE NOTICE '===========================================';
    RAISE NOTICE 'process_daily_yield_with_cycles関数の修正が必要です';
    RAISE NOTICE '次のステップ: add-cycle-number-to-auto-purchase.sqlを実行';
    RAISE NOTICE '===========================================';
END $$;

-- 権限付与
GRANT EXECUTE ON FUNCTION get_auto_purchase_history(TEXT, INTEGER) TO anon;
GRANT EXECUTE ON FUNCTION get_auto_purchase_history(TEXT, INTEGER) TO authenticated;

-- 完了メッセージ
DO $$
BEGIN
    RAISE NOTICE '===========================================';
    RAISE NOTICE '✅ 自動購入履歴のサイクル表示を修正しました';
    RAISE NOTICE '===========================================';
    RAISE NOTICE '変更内容:';
    RAISE NOTICE '  - purchases.cycle_number_at_purchase カラムを追加';
    RAISE NOTICE '  - 既存データに連番でサイクル番号を設定';
    RAISE NOTICE '  - get_auto_purchase_history関数を修正';
    RAISE NOTICE '';
    RAISE NOTICE '次のステップ:';
    RAISE NOTICE '  - process_daily_yield_with_cycles関数を修正';
    RAISE NOTICE '    (自動購入時にサイクル番号を記録)';
    RAISE NOTICE '===========================================';
END $$;
