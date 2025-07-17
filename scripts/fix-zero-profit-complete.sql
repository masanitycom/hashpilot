-- HASHPILOT利益$0問題の完全修正
-- 問題: 
-- 1. 運用開始日（NFT承認+15日）の条件チェックがない
-- 2. 重複キーエラー（UPSERT機能なし）
-- 3. 基準金額計算が間違っている（1100→1000ドル）
-- 作成日: 2025-07-17

-- 問題1: 運用開始日の条件チェック追加
-- 問題2: UPSERT機能追加
-- 問題3: 基準金額を正しい運用額（1000ドル/NFT）に修正

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
    v_eligible_user_count INTEGER := 0;
BEGIN
    -- 利率計算
    v_after_margin := p_yield_rate * (1 - p_margin_rate / 100);
    v_user_rate := v_after_margin * 0.6;
    
    -- 開始ログ（テストモードでない場合のみ）
    IF NOT p_is_test_mode THEN
        PERFORM log_system_event(
            'INFO',
            'DAILY_YIELD_PROCESSING',
            NULL,
            FORMAT('日利処理開始: %s, 利率%s%%, マージン%s%%', 
                   p_date, p_yield_rate * 100, p_margin_rate),
            jsonb_build_object(
                'date', p_date,
                'yield_rate', p_yield_rate,
                'margin_rate', p_margin_rate
            )
        );
        
        -- daily_yield_logに記録（UPSERT）
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
    
    -- 運用開始済みユーザーのカウント
    SELECT COUNT(DISTINCT p.user_id) INTO v_eligible_user_count
    FROM purchases p
    INNER JOIN affiliate_cycle ac ON p.user_id = ac.user_id
    WHERE p.admin_approved = true
      AND p.admin_approved_at IS NOT NULL
      AND (p.admin_approved_at + INTERVAL '15 days')::date <= p_date
      AND ac.total_nft_count > 0;
    
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
            -- 最初の承認日を取得
            MIN(p.admin_approved_at) as first_approved_at
        FROM affiliate_cycle ac
        INNER JOIN purchases p ON ac.user_id = p.user_id
        WHERE ac.total_nft_count > 0
          AND p.admin_approved = true
          AND p.admin_approved_at IS NOT NULL
          -- 【重要修正】運用開始日（承認日+15日）が処理日以前のユーザーのみ処理
          AND (p.admin_approved_at + INTERVAL '15 days')::date <= p_date
        GROUP BY ac.user_id, ac.phase, ac.total_nft_count, ac.cum_usdt, 
                 ac.available_usdt, ac.auto_nft_count, ac.manual_nft_count, ac.next_action
    LOOP
        -- 【重要修正】基準金額（NFT数 × 1000）- 実際の運用額は1000ドル/NFT
        v_base_amount := v_user_record.total_nft_count * 1000;
        
        -- ユーザー利益計算
        v_user_profit := v_base_amount * v_user_rate;
        
        -- 会社利益計算
        v_company_profit := v_base_amount * p_margin_rate / 100 + v_base_amount * v_after_margin * 0.1;
        
        -- サイクル処理
        v_new_cum_usdt := v_user_record.cum_usdt + v_user_profit;
        v_new_phase := v_user_record.phase;
        v_new_next_action := COALESCE(v_user_record.next_action, 'usdt');
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
                    
                    -- 自動購入ログ
                    PERFORM log_system_event(
                        'SUCCESS',
                        'AUTO_NFT_PURCHASE',
                        v_user_record.user_id,
                        FORMAT('自動NFT購入完了: %s個目', v_user_record.auto_nft_count + 1),
                        jsonb_build_object(
                            'nft_quantity', 1,
                            'amount_usd', 1100
                        )
                    );
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
        
        -- 【重要修正】user_daily_profitテーブルに記録（UPSERT処理で重複エラー回避）
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
        PERFORM log_system_event(
            'SUCCESS',
            'MONTH_END_PROCESSING',
            NULL,
            FORMAT('%s年%s月の月末処理が完了しました', 
                   EXTRACT(YEAR FROM p_date), 
                   EXTRACT(MONTH FROM p_date)),
            jsonb_build_object(
                'year', EXTRACT(YEAR FROM p_date),
                'month', EXTRACT(MONTH FROM p_date),
                'processed_users', v_user_count,
                'total_profit', v_total_user_profit
            )
        );
    END IF;
    
    -- 完了ログ（テストモードでない場合のみ）
    IF NOT p_is_test_mode THEN
        PERFORM log_system_event(
            'SUCCESS',
            'DAILY_YIELD_PROCESSING',
            NULL,
            FORMAT('日利処理完了: %s名処理, 総利益$%s', v_user_count, v_total_user_profit),
            jsonb_build_object(
                'processed_users', v_user_count,
                'eligible_users', v_eligible_user_count,
                'total_user_profit', v_total_user_profit,
                'total_company_profit', v_total_company_profit,
                'cycle_updates', v_cycle_updates,
                'auto_purchases', v_auto_purchases
            )
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
        FORMAT('%s完了: %s名処理（対象%s名中）, %s回サイクル更新, %s回自動NFT購入', 
               CASE WHEN p_is_test_mode THEN 'テスト' ELSE '本番' END,
               v_user_count, v_eligible_user_count, v_cycle_updates, v_auto_purchases)::TEXT;
    
EXCEPTION WHEN OTHERS THEN
    -- エラーログ記録
    IF NOT p_is_test_mode THEN
        PERFORM log_system_event(
            'ERROR',
            'DAILY_YIELD_PROCESSING',
            NULL,
            'Daily yield processing failed',
            jsonb_build_object(
                'error', SQLERRM,
                'date', p_date,
                'yield_rate', p_yield_rate,
                'margin_rate', p_margin_rate
            )
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

-- 実行権限付与
GRANT EXECUTE ON FUNCTION process_daily_yield_with_cycles(DATE, NUMERIC, NUMERIC, BOOLEAN, BOOLEAN) TO anon;
GRANT EXECUTE ON FUNCTION process_daily_yield_with_cycles(DATE, NUMERIC, NUMERIC, BOOLEAN, BOOLEAN) TO authenticated;

-- 過去の無効なデータをクリーンアップ
-- 運用開始日前のuser_daily_profitデータを削除
DELETE FROM user_daily_profit udp
WHERE NOT EXISTS (
    SELECT 1 
    FROM purchases p 
    WHERE p.user_id = udp.user_id 
      AND p.admin_approved = true 
      AND p.admin_approved_at IS NOT NULL
      AND (p.admin_approved_at + INTERVAL '15 days')::date <= udp.date
);

-- 修正確認のためのクエリ実行
-- 1. 運用開始済みユーザーの確認
SELECT 
    '1. 運用開始済みユーザー' as info,
    COUNT(DISTINCT p.user_id) as eligible_users,
    SUM(p.nft_quantity) as total_nfts,
    STRING_AGG(DISTINCT p.user_id, ', ') as user_list
FROM purchases p
INNER JOIN affiliate_cycle ac ON p.user_id = ac.user_id
WHERE p.admin_approved = true
  AND p.admin_approved_at IS NOT NULL
  AND (p.admin_approved_at + INTERVAL '15 days')::date <= CURRENT_DATE
  AND ac.total_nft_count > 0;

-- 2. 特定ユーザー（7A9637）の詳細確認
SELECT 
    '2. ユーザー7A9637の状況' as info,
    p.user_id,
    p.nft_quantity,
    p.admin_approved_at,
    p.admin_approved_at + INTERVAL '15 days' as operation_start_date,
    CURRENT_DATE - (p.admin_approved_at::date + 15) as days_operational,
    CASE 
        WHEN (p.admin_approved_at + INTERVAL '15 days')::date <= CURRENT_DATE 
        THEN '運用開始済み'
        ELSE '運用開始前（あと' || ((p.admin_approved_at + INTERVAL '15 days')::date - CURRENT_DATE) || '日）'
    END as status,
    ac.total_nft_count as affiliate_nft_count,
    ac.cum_usdt,
    ac.available_usdt
FROM purchases p
LEFT JOIN affiliate_cycle ac ON p.user_id = ac.user_id
WHERE p.user_id = '7A9637'
  AND p.admin_approved = true;

-- 3. 修正後のテスト実行
SELECT 
    '3. テスト実行結果' as info,
    *
FROM process_daily_yield_with_cycles(CURRENT_DATE, 0.016, 30, true, false);

-- 4. 今後の利益が発生するユーザーの予測
SELECT 
    '4. 今後の利益発生予測' as info,
    (p.admin_approved_at + INTERVAL '15 days')::date as will_start_date,
    COUNT(*) as users_count,
    SUM(p.nft_quantity) as total_nfts
FROM purchases p
WHERE p.admin_approved = true
  AND p.admin_approved_at IS NOT NULL
  AND (p.admin_approved_at + INTERVAL '15 days')::date > CURRENT_DATE
  AND (p.admin_approved_at + INTERVAL '15 days')::date <= CURRENT_DATE + INTERVAL '7 days'
GROUP BY (p.admin_approved_at + INTERVAL '15 days')::date
ORDER BY will_start_date;