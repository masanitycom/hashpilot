-- HASHPILOT利益$0問題の修正
-- 問題: process_daily_yield_with_cycles関数に運用開始日（NFT承認+15日）の条件チェックがない
-- 作成日: 2025-07-17

-- 1. 現在の状況確認
SELECT 
    '現在の運用開始済みユーザー' as info,
    COUNT(DISTINCT p.user_id) as eligible_users,
    SUM(p.nft_quantity) as total_nfts
FROM purchases p
WHERE p.admin_approved = true
  AND p.admin_approved_at IS NOT NULL
  AND (p.admin_approved_at + INTERVAL '15 days')::date <= CURRENT_DATE;

-- 2. 修正版のprocess_daily_yield_with_cycles関数
CREATE OR REPLACE FUNCTION process_daily_yield_with_cycles(
    p_date DATE,
    p_yield_rate NUMERIC,
    p_margin_rate NUMERIC,
    p_is_test_mode BOOLEAN DEFAULT true,
    p_is_month_end BOOLEAN DEFAULT false
)
RETURNS TABLE(
    status text,
    total_users integer,
    total_user_profit numeric,
    total_company_profit numeric,
    cycle_updates integer,
    auto_nft_purchases integer,
    message text
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_count INTEGER := 0;
    v_total_user_profit NUMERIC := 0;
    v_total_company_profit NUMERIC := 0;
    v_cycle_updates INTEGER := 0;
    v_auto_purchases INTEGER := 0;
    v_user_rate NUMERIC;
    v_after_margin NUMERIC;
    v_user_record RECORD;
    v_user_profit NUMERIC;
    v_company_profit NUMERIC;
    v_base_amount NUMERIC;
    v_new_cum_usdt NUMERIC;
    v_new_available_usdt NUMERIC;
    v_new_phase TEXT;
    v_new_next_action TEXT;
    v_referral_profit_level1 NUMERIC;
    v_referral_profit_level2 NUMERIC;
    v_referral_profit_level3 NUMERIC;
    v_referral_profit_rest NUMERIC;
BEGIN
    -- 利率計算
    v_after_margin := p_yield_rate * (1 - p_margin_rate / 100);
    v_user_rate := v_after_margin * 0.6;
    
    -- テストモードでない場合のみdaily_yield_logに記録
    IF NOT p_is_test_mode THEN
        INSERT INTO daily_yield_log (
            date, yield_rate, margin_rate, user_rate, is_month_end, created_at
        )
        VALUES (
            p_date, p_yield_rate, p_margin_rate, v_user_rate, p_is_month_end, NOW()
        )
        ON CONFLICT (date) DO UPDATE SET
            yield_rate = EXCLUDED.yield_rate,
            margin_rate = EXCLUDED.margin_rate,
            user_rate = EXCLUDED.user_rate,
            is_month_end = EXCLUDED.is_month_end,
            created_at = NOW();
    END IF;
    
    -- 各ユーザーの処理（運用開始日の条件を追加）
    FOR v_user_record IN
        SELECT 
            ac.user_id,
            ac.phase,
            ac.total_nft_count,
            ac.cum_usdt,
            ac.available_usdt,
            ac.auto_nft_count,
            ac.manual_nft_count,
            ac.next_action,
            -- 最も古い承認日を取得（運用開始日の計算用）
            MIN(p.admin_approved_at) as first_approved_at
        FROM affiliate_cycle ac
        INNER JOIN purchases p ON ac.user_id = p.user_id
        WHERE ac.total_nft_count > 0
          AND p.admin_approved = true
          AND p.admin_approved_at IS NOT NULL
          -- 運用開始日（承認日+15日）が今日以前のユーザーのみ処理
          AND (p.admin_approved_at + INTERVAL '15 days')::date <= p_date
        GROUP BY ac.user_id, ac.phase, ac.total_nft_count, ac.cum_usdt, 
                 ac.available_usdt, ac.auto_nft_count, ac.manual_nft_count, ac.next_action
    LOOP
        -- 基準金額（NFT数 × 1000）- 運用額は1000ドル/NFT
        v_base_amount := v_user_record.total_nft_count * 1000;
        
        -- ユーザー利益計算
        v_user_profit := v_base_amount * v_user_rate;
        
        -- 会社利益計算
        v_company_profit := v_base_amount * p_margin_rate / 100 + v_base_amount * v_after_margin * 0.1;
        
        -- 紹介報酬の計算（実際の配分率: 20%, 10%, 5%）
        v_referral_profit_level1 := v_base_amount * v_after_margin * 0.3 * 0.20;  -- Level1: 20%
        v_referral_profit_level2 := v_base_amount * v_after_margin * 0.3 * 0.10;  -- Level2: 10%
        v_referral_profit_level3 := v_base_amount * v_after_margin * 0.3 * 0.05;  -- Level3: 5%
        v_referral_profit_rest := v_base_amount * v_after_margin * 0.3 * 0.65;    -- 残り: 65%
        
        -- サイクル処理
        v_new_cum_usdt := v_user_record.cum_usdt + v_user_profit;
        v_new_phase := v_user_record.phase;
        v_new_next_action := v_user_record.next_action;
        v_new_available_usdt := v_user_record.available_usdt;
        
        -- サイクル処理ロジック（交互処理）
        WHILE v_new_cum_usdt >= 1100 LOOP
            IF v_new_next_action = 'usdt' THEN
                -- USDT受取
                v_new_available_usdt := v_new_available_usdt + 1100;
                v_new_cum_usdt := v_new_cum_usdt - 1100;
                v_new_next_action := 'nft';
            ELSE
                -- NFT購入
                v_new_cum_usdt := v_new_cum_usdt - 1100;
                v_new_next_action := 'usdt';
                v_auto_purchases := v_auto_purchases + 1;
                
                IF NOT p_is_test_mode THEN
                    -- 自動NFT購入をpurchasesテーブルに記録
                    INSERT INTO purchases (
                        user_id, nft_quantity, amount_usd, payment_status, 
                        admin_approved, admin_approved_at, is_auto_purchase, created_at
                    )
                    VALUES (
                        v_user_record.user_id, 1, 1100, 'completed',
                        true, NOW(), true, NOW()
                    );
                    
                    -- affiliate_cycleのNFT数を増やす
                    UPDATE affiliate_cycle 
                    SET 
                        total_nft_count = total_nft_count + 1,
                        auto_nft_count = auto_nft_count + 1
                    WHERE user_id = v_user_record.user_id;
                END IF;
            END IF;
            
            v_cycle_updates := v_cycle_updates + 1;
        END LOOP;
        
        -- フェーズ判定（レガシー互換性のため維持）
        IF v_new_cum_usdt < 1100 AND v_new_next_action = 'usdt' THEN
            v_new_phase := 'USDT';
        ELSE
            v_new_phase := 'HOLD';
        END IF;
        
        -- affiliate_cycleの更新
        IF NOT p_is_test_mode THEN
            UPDATE affiliate_cycle 
            SET 
                cum_usdt = v_new_cum_usdt,
                available_usdt = v_new_available_usdt,
                phase = v_new_phase,
                next_action = v_new_next_action,
                updated_at = NOW()
            WHERE user_id = v_user_record.user_id;
        END IF;
        
        -- user_daily_profitテーブルに記録（UPSERT処理）
        IF NOT p_is_test_mode THEN
            INSERT INTO user_daily_profit (
                user_id, date, daily_profit, yield_rate, user_rate, base_amount, phase, created_at
            )
            VALUES (
                v_user_record.user_id, p_date, v_user_profit, p_yield_rate, v_user_rate, v_base_amount, 
                v_new_phase, NOW()
            )
            ON CONFLICT (user_id, date) DO UPDATE SET
                daily_profit = EXCLUDED.daily_profit,
                yield_rate = EXCLUDED.yield_rate,
                user_rate = EXCLUDED.user_rate,
                base_amount = EXCLUDED.base_amount,
                phase = EXCLUDED.phase,
                created_at = NOW();
        END IF;
        
        v_user_count := v_user_count + 1;
        v_total_user_profit := v_total_user_profit + v_user_profit;
        v_total_company_profit := v_total_company_profit + v_company_profit;
    END LOOP;
    
    -- 月末処理
    IF p_is_month_end AND NOT p_is_test_mode THEN
        INSERT INTO monthly_statistics (
            year, month, total_users, total_nft_count, total_investment,
            total_profit, total_withdrawal, total_auto_purchases,
            active_users, new_users, created_at
        )
        SELECT 
            EXTRACT(YEAR FROM p_date)::INTEGER,
            EXTRACT(MONTH FROM p_date)::INTEGER,
            COUNT(DISTINCT u.user_id),
            COALESCE(SUM(ac.total_nft_count), 0),
            COALESCE(SUM(ac.total_nft_count * 1100), 0),
            COALESCE(SUM(ac.available_usdt), 0),
            COALESCE(SUM(w.total_withdrawn), 0),
            COALESCE(SUM(ac.auto_nft_count), 0),
            COUNT(DISTINCT CASE WHEN ac.total_nft_count > 0 THEN u.user_id END),
            COUNT(DISTINCT CASE 
                WHEN DATE_TRUNC('month', u.created_at) = DATE_TRUNC('month', p_date) 
                THEN u.user_id 
            END),
            NOW()
        FROM users u
        LEFT JOIN affiliate_cycle ac ON u.user_id = ac.user_id
        LEFT JOIN (
            SELECT user_id, SUM(amount) as total_withdrawn
            FROM withdrawal_requests
            WHERE status = 'completed'
            GROUP BY user_id
        ) w ON u.user_id = w.user_id
        ON CONFLICT (year, month) DO UPDATE SET
            total_users = EXCLUDED.total_users,
            total_nft_count = EXCLUDED.total_nft_count,
            total_investment = EXCLUDED.total_investment,
            total_profit = EXCLUDED.total_profit,
            total_withdrawal = EXCLUDED.total_withdrawal,
            total_auto_purchases = EXCLUDED.total_auto_purchases,
            active_users = EXCLUDED.active_users,
            new_users = EXCLUDED.new_users,
            created_at = NOW();
            
        -- 月末処理ログ
        INSERT INTO system_logs (
            log_type, operation, message, details, created_at
        )
        VALUES (
            'SUCCESS',
            'MONTH_END_PROCESSING',
            FORMAT('%s年%s月の月末処理が完了しました', 
                   EXTRACT(YEAR FROM p_date), 
                   EXTRACT(MONTH FROM p_date)),
            jsonb_build_object(
                'year', EXTRACT(YEAR FROM p_date),
                'month', EXTRACT(MONTH FROM p_date),
                'processed_users', v_user_count,
                'total_profit', v_total_user_profit
            ),
            NOW()
        );
    END IF;
    
    -- 結果を返す
    RETURN QUERY SELECT 
        CASE WHEN p_is_test_mode THEN 'TEST_SUCCESS' ELSE 'SUCCESS' END::TEXT,
        v_user_count::INTEGER,
        v_total_user_profit::NUMERIC,
        v_total_company_profit::NUMERIC,
        v_cycle_updates::INTEGER,
        v_auto_purchases::INTEGER,
        FORMAT('%s完了: %s名処理, %s回サイクル更新, %s回自動NFT購入', 
               CASE WHEN p_is_test_mode THEN 'テスト' ELSE '本番' END,
               v_user_count, v_cycle_updates, v_auto_purchases)::TEXT;
    
EXCEPTION WHEN OTHERS THEN
    -- エラーログ記録
    IF NOT p_is_test_mode THEN
        INSERT INTO system_logs (
            log_type, operation, message, details, created_at
        )
        VALUES (
            'ERROR',
            'DAILY_YIELD_PROCESSING',
            'Daily yield processing failed',
            jsonb_build_object(
                'error', SQLERRM,
                'date', p_date,
                'yield_rate', p_yield_rate,
                'margin_rate', p_margin_rate
            ),
            NOW()
        );
    END IF;
    
    RETURN QUERY SELECT 
        'ERROR'::TEXT,
        0::INTEGER,
        0::NUMERIC,
        0::NUMERIC,
        0::INTEGER,
        0::INTEGER,
        FORMAT('エラー: %s', SQLERRM)::TEXT;
END;
$$;

-- 3. 実行権限付与
GRANT EXECUTE ON FUNCTION process_daily_yield_with_cycles(DATE, NUMERIC, NUMERIC, BOOLEAN, BOOLEAN) TO anon;
GRANT EXECUTE ON FUNCTION process_daily_yield_with_cycles(DATE, NUMERIC, NUMERIC, BOOLEAN, BOOLEAN) TO authenticated;

-- 4. 過去のデータを修正（運用開始日前のデータを削除）
DELETE FROM user_daily_profit udp
WHERE NOT EXISTS (
    SELECT 1 
    FROM purchases p 
    WHERE p.user_id = udp.user_id 
      AND p.admin_approved = true 
      AND p.admin_approved_at IS NOT NULL
      AND (p.admin_approved_at + INTERVAL '15 days')::date <= udp.date
);

-- 5. 修正後の確認
SELECT 
    '修正後の運用開始済みユーザーの利益' as info,
    COUNT(DISTINCT udp.user_id) as users_with_profit,
    SUM(udp.daily_profit) as total_daily_profit,
    MAX(udp.date) as latest_profit_date
FROM user_daily_profit udp;

-- 6. テスト実行（今日の日付で）
SELECT * FROM process_daily_yield_with_cycles(CURRENT_DATE, 0.016, 30, true, false);

-- 7. 特定ユーザー（7A9637）の状況確認
SELECT 
    'ユーザー7A9637の詳細' as info,
    p.user_id,
    p.nft_quantity,
    p.admin_approved_at,
    p.admin_approved_at + INTERVAL '15 days' as operation_start_date,
    CASE 
        WHEN (p.admin_approved_at + INTERVAL '15 days')::date <= CURRENT_DATE 
        THEN '運用開始済み'
        ELSE '運用開始前（' || ((p.admin_approved_at + INTERVAL '15 days')::date - CURRENT_DATE) || '日後）'
    END as status,
    ac.total_nft_count,
    ac.cum_usdt,
    ac.available_usdt
FROM purchases p
LEFT JOIN affiliate_cycle ac ON p.user_id = ac.user_id
WHERE p.user_id = '7A9637'
  AND p.admin_approved = true;