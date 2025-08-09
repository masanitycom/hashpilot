-- ========================================
-- NFT重複カウントを防ぐための対策
-- ========================================

-- 1. 定期監査用のビュー作成
CREATE OR REPLACE VIEW nft_count_audit AS
SELECT 
    u.user_id,
    u.email,
    u.total_purchases as recorded_amount,
    ac.total_nft_count as recorded_nft,
    COALESCE(p.actual_amount, 0) as actual_amount,
    COALESCE(p.actual_nft, 0) as actual_nft,
    CASE 
        WHEN u.total_purchases = COALESCE(p.actual_amount, 0) 
         AND ac.total_nft_count = COALESCE(p.actual_nft, 0) THEN 'OK'
        ELSE 'DISCREPANCY'
    END as status,
    u.total_purchases - COALESCE(p.actual_amount, 0) as amount_diff,
    ac.total_nft_count - COALESCE(p.actual_nft, 0) as nft_diff
FROM users u
LEFT JOIN affiliate_cycle ac ON u.user_id = ac.user_id
LEFT JOIN (
    SELECT user_id, 
           SUM(amount_usd) as actual_amount,
           SUM(nft_quantity) as actual_nft
    FROM purchases
    WHERE admin_approved = true
    GROUP BY user_id
) p ON u.user_id = p.user_id
WHERE u.has_approved_nft = true;

-- 2. 承認処理を改善する関数（重複防止）
CREATE OR REPLACE FUNCTION approve_nft_purchase_safe(
    p_purchase_id UUID,
    p_admin_user_id UUID
) RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id VARCHAR(6);
    v_nft_quantity INTEGER;
    v_amount_usd DECIMAL;
    v_already_approved BOOLEAN;
BEGIN
    -- 既に承認済みかチェック
    SELECT admin_approved, user_id, nft_quantity, amount_usd
    INTO v_already_approved, v_user_id, v_nft_quantity, v_amount_usd
    FROM purchases
    WHERE id = p_purchase_id;
    
    -- 既に承認済みなら何もしない
    IF v_already_approved THEN
        RAISE NOTICE 'Purchase % is already approved', p_purchase_id;
        RETURN FALSE;
    END IF;
    
    -- トランザクション開始
    BEGIN
        -- 購入を承認
        UPDATE purchases 
        SET admin_approved = true,
            approved_at = NOW(),
            approved_by = p_admin_user_id
        WHERE id = p_purchase_id
        AND admin_approved = false;  -- 二重防止
        
        -- 影響を受けた行がない場合は既に処理済み
        IF NOT FOUND THEN
            RETURN FALSE;
        END IF;
        
        -- ユーザーのNFT状態を更新（実際の購入数に基づいて）
        UPDATE users u
        SET has_approved_nft = true,
            total_purchases = (
                SELECT COALESCE(SUM(amount_usd), 0)
                FROM purchases
                WHERE user_id = v_user_id
                AND admin_approved = true
            )
        WHERE user_id = v_user_id;
        
        -- affiliate_cycleを更新（実際の購入数に基づいて）
        UPDATE affiliate_cycle ac
        SET total_nft_count = (
                SELECT COALESCE(SUM(nft_quantity), 0)
                FROM purchases
                WHERE user_id = v_user_id
                AND admin_approved = true
            ),
            manual_nft_count = (
                SELECT COALESCE(SUM(nft_quantity), 0)
                FROM purchases
                WHERE user_id = v_user_id
                AND admin_approved = true
            )
        WHERE user_id = v_user_id;
        
        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Error approving purchase: %', SQLERRM;
            RETURN FALSE;
    END;
END;
$$;

-- 3. 毎日の自動チェック用関数
CREATE OR REPLACE FUNCTION check_nft_discrepancies()
RETURNS TABLE(
    user_id VARCHAR(6),
    email TEXT,
    discrepancy_type TEXT,
    expected_value DECIMAL,
    actual_value DECIMAL
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        na.user_id,
        na.email,
        CASE 
            WHEN na.amount_diff != 0 THEN 'AMOUNT_MISMATCH'
            WHEN na.nft_diff != 0 THEN 'NFT_COUNT_MISMATCH'
        END::TEXT as discrepancy_type,
        na.actual_amount as expected_value,
        na.recorded_amount as actual_value
    FROM nft_count_audit na
    WHERE na.status = 'DISCREPANCY';
END;
$$;

-- 4. 自動修正関数（管理者権限が必要）
CREATE OR REPLACE FUNCTION auto_fix_nft_discrepancies()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_fixed_count INTEGER := 0;
    v_user RECORD;
BEGIN
    -- 不整合のあるユーザーを修正
    FOR v_user IN 
        SELECT * FROM nft_count_audit 
        WHERE status = 'DISCREPANCY'
    LOOP
        -- usersテーブルを修正
        UPDATE users 
        SET total_purchases = v_user.actual_amount
        WHERE user_id = v_user.user_id;
        
        -- affiliate_cycleテーブルを修正
        UPDATE affiliate_cycle 
        SET total_nft_count = v_user.actual_nft,
            manual_nft_count = v_user.actual_nft
        WHERE user_id = v_user.user_id;
        
        v_fixed_count := v_fixed_count + 1;
        
        RAISE NOTICE 'Fixed user %: % -> %', 
            v_user.user_id, 
            v_user.recorded_amount, 
            v_user.actual_amount;
    END LOOP;
    
    RETURN v_fixed_count;
END;
$$;

-- 5. アラート用のトリガー（今後の重複を検知）
CREATE OR REPLACE FUNCTION check_nft_update()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_actual_nft INTEGER;
BEGIN
    -- 実際の購入NFT数を取得
    SELECT COALESCE(SUM(nft_quantity), 0)
    INTO v_actual_nft
    FROM purchases
    WHERE user_id = NEW.user_id
    AND admin_approved = true;
    
    -- 不整合を検知
    IF NEW.total_nft_count > v_actual_nft THEN
        RAISE WARNING 'NFT count mismatch detected for user %: recorded=%, actual=%',
            NEW.user_id, NEW.total_nft_count, v_actual_nft;
    END IF;
    
    RETURN NEW;
END;
$$;

-- トリガーを作成
DROP TRIGGER IF EXISTS check_nft_update_trigger ON affiliate_cycle;
CREATE TRIGGER check_nft_update_trigger
    AFTER UPDATE OF total_nft_count ON affiliate_cycle
    FOR EACH ROW
    EXECUTE FUNCTION check_nft_update();

-- 6. 権限設定
GRANT SELECT ON nft_count_audit TO authenticated;
GRANT EXECUTE ON FUNCTION check_nft_discrepancies() TO authenticated;

SELECT 'Prevention measures installed successfully!' as status;