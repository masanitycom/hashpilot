-- ペガサス交換ユーザーの出金制限チェックを追加
-- 作成日: 2025年10月7日

-- ============================================
-- create_withdrawal_request関数を更新
-- ペガサス交換ユーザーの出金制限チェックを追加
-- ============================================

CREATE OR REPLACE FUNCTION create_withdrawal_request(
    p_user_id TEXT,
    p_amount NUMERIC,
    p_wallet_address TEXT,
    p_wallet_type TEXT DEFAULT 'USDT-TRC20'
)
RETURNS TABLE(
    request_id UUID,
    status TEXT,
    message TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_available_usdt NUMERIC;
    v_request_id UUID;
    v_user_exists BOOLEAN;
    v_is_pegasus_exchange BOOLEAN;
    v_pegasus_unlock_date DATE;
BEGIN
    -- ユーザー存在確認とペガサス情報取得
    SELECT
        EXISTS(SELECT 1 FROM users WHERE user_id = p_user_id),
        COALESCE(is_pegasus_exchange, FALSE),
        pegasus_withdrawal_unlock_date
    INTO
        v_user_exists,
        v_is_pegasus_exchange,
        v_pegasus_unlock_date
    FROM users
    WHERE user_id = p_user_id;

    IF NOT v_user_exists THEN
        RETURN QUERY SELECT
            NULL::UUID,
            'ERROR'::TEXT,
            'ユーザーが存在しません'::TEXT;
        RETURN;
    END IF;

    -- ペガサス交換ユーザーの出金制限チェック
    IF v_is_pegasus_exchange = TRUE THEN
        IF v_pegasus_unlock_date IS NULL THEN
            RETURN QUERY SELECT
                NULL::UUID,
                'ERROR'::TEXT,
                '⚠️ ペガサスNFT交換ユーザーのため、現在出金できません。管理者にお問い合わせください。'::TEXT;
            RETURN;
        END IF;

        IF CURRENT_DATE < v_pegasus_unlock_date THEN
            RETURN QUERY SELECT
                NULL::UUID,
                'ERROR'::TEXT,
                FORMAT('⚠️ ペガサスNFT交換ユーザーのため、%sまで出金制限されています。',
                    TO_CHAR(v_pegasus_unlock_date, 'YYYY年MM月DD日'))::TEXT;
            RETURN;
        END IF;
    END IF;

    -- 入力値検証
    IF p_amount <= 0 THEN
        RETURN QUERY SELECT
            NULL::UUID,
            'ERROR'::TEXT,
            '出金額は0より大きい必要があります'::TEXT;
        RETURN;
    END IF;

    IF p_amount < 100 THEN
        RETURN QUERY SELECT
            NULL::UUID,
            'ERROR'::TEXT,
            '最小出金額は$100です'::TEXT;
        RETURN;
    END IF;

    IF LENGTH(p_wallet_address) < 10 THEN
        RETURN QUERY SELECT
            NULL::UUID,
            'ERROR'::TEXT,
            '有効なウォレットアドレスを入力してください'::TEXT;
        RETURN;
    END IF;

    -- 利用可能残高確認
    SELECT COALESCE(available_usdt, 0)
    FROM affiliate_cycle
    WHERE user_id = p_user_id
    INTO v_available_usdt;

    IF v_available_usdt IS NULL THEN
        v_available_usdt := 0;
    END IF;

    IF v_available_usdt < p_amount THEN
        RETURN QUERY SELECT
            NULL::UUID,
            'ERROR'::TEXT,
            FORMAT('残高不足です。利用可能額: $%s', v_available_usdt)::TEXT;
        RETURN;
    END IF;

    -- 保留中の出金申請確認
    IF EXISTS(SELECT 1 FROM withdrawal_requests
              WHERE user_id = p_user_id AND status = 'pending') THEN
        RETURN QUERY SELECT
            NULL::UUID,
            'ERROR'::TEXT,
            '保留中の出金申請があります。完了後に再申請してください'::TEXT;
        RETURN;
    END IF;

    -- 出金申請作成
    INSERT INTO withdrawal_requests (
        user_id, amount, wallet_address, wallet_type,
        available_usdt_before, available_usdt_after,
        status, created_at, updated_at
    )
    VALUES (
        p_user_id, p_amount, p_wallet_address, p_wallet_type,
        v_available_usdt, v_available_usdt - p_amount,
        'pending', NOW(), NOW()
    )
    RETURNING id INTO v_request_id;

    -- affiliate_cycleの利用可能残高を減額（仮減額）
    UPDATE affiliate_cycle
    SET
        available_usdt = available_usdt - p_amount,
        last_updated = NOW()
    WHERE user_id = p_user_id;

    -- ログ記録
    PERFORM log_system_event(
        'INFO',
        'WITHDRAWAL_REQUEST',
        p_user_id,
        FORMAT('出金申請作成: $%s → %s', p_amount, p_wallet_address),
        jsonb_build_object(
            'request_id', v_request_id,
            'amount', p_amount,
            'wallet_address', p_wallet_address,
            'wallet_type', p_wallet_type,
            'available_before', v_available_usdt,
            'available_after', v_available_usdt - p_amount,
            'is_pegasus_exchange', v_is_pegasus_exchange
        )
    );

    RETURN QUERY SELECT
        v_request_id,
        'SUCCESS'::TEXT,
        FORMAT('出金申請を受付ました。申請ID: %s', v_request_id)::TEXT;

EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT
        NULL::UUID,
        'ERROR'::TEXT,
        FORMAT('エラーが発生しました: %s', SQLERRM)::TEXT;
END;
$$;

-- 完了メッセージ
DO $$
BEGIN
    RAISE NOTICE '✅ ペガサス交換ユーザーの出金制限チェックを追加しました';
    RAISE NOTICE '📋 更新内容:';
    RAISE NOTICE '   - create_withdrawal_request関数にペガサス制限チェックを追加';
    RAISE NOTICE '   - 出金解禁日までの出金を制限';
END $$;
