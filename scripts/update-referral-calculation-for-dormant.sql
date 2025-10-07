-- 紹介報酬計算ロジックを更新（休眠ユーザー対応）
-- 作成日: 2025年10月7日
--
-- 休眠ユーザー（is_active_investor=FALSE）の紹介報酬を
-- 会社アカウント（7A9637）が受け取るように修正

-- ============================================
-- 紹介報酬計算関数（休眠ユーザー対応版）
-- ============================================

CREATE OR REPLACE FUNCTION calculate_referral_rewards_with_dormant(
    p_date DATE,
    p_is_test_mode BOOLEAN DEFAULT FALSE
)
RETURNS TABLE(
    status TEXT,
    total_users INTEGER,
    total_rewards DECIMAL(10,3),
    company_bonus_from_dormant DECIMAL(10,3),
    message TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_record RECORD;
    v_referrer_record RECORD;
    v_user_count INTEGER := 0;
    v_total_rewards DECIMAL(10,3) := 0;
    v_company_bonus DECIMAL(10,3) := 0;
    v_user_daily_profit DECIMAL(10,3);
    v_level INTEGER;
    v_referrer_id TEXT;
    v_reward_amount DECIMAL(10,3);
    v_reward_rate DECIMAL(5,4);
    v_is_dormant BOOLEAN;
    v_referrer_email TEXT;
    v_current_user_id TEXT;
BEGIN
    -- 各ユーザーの日次利益を取得
    FOR v_user_record IN
        SELECT
            udp.user_id,
            udp.daily_profit,
            u.referrer_user_id
        FROM user_daily_profit udp
        INNER JOIN users u ON udp.user_id = u.user_id
        WHERE udp.date = p_date
          AND udp.daily_profit > 0  -- プラス利益のみ
    LOOP
        v_user_daily_profit := v_user_record.daily_profit;
        v_current_user_id := v_user_record.user_id;
        v_level := 0;

        -- 最大3レベルまで遡る
        WHILE v_level < 3 AND v_current_user_id IS NOT NULL LOOP
            -- 上位の紹介者を取得
            SELECT
                u.user_id,
                u.email,
                u.is_active_investor,
                u.referrer_user_id
            INTO v_referrer_record
            FROM users u
            WHERE u.user_id = (
                SELECT referrer_user_id
                FROM users
                WHERE user_id = v_current_user_id
            );

            -- 紹介者が存在しない場合は終了
            EXIT WHEN v_referrer_record.user_id IS NULL;

            v_level := v_level + 1;

            -- レベルに応じた報酬率
            v_reward_rate := CASE v_level
                WHEN 1 THEN 0.10  -- Level 1: 10%
                WHEN 2 THEN 0.05  -- Level 2: 5%
                WHEN 3 THEN 0.03  -- Level 3: 3%
                ELSE 0
            END;

            v_reward_amount := v_user_daily_profit * v_reward_rate;

            -- ★★★ 重要：休眠ユーザーかチェック ★★★
            v_is_dormant := NOT COALESCE(v_referrer_record.is_active_investor, FALSE);

            IF NOT p_is_test_mode THEN
                IF v_is_dormant THEN
                    -- 休眠ユーザー → 会社アカウント（7A9637）へ報酬
                    INSERT INTO user_referral_profit (
                        user_id,
                        date,
                        referral_level,
                        child_user_id,
                        profit_amount,
                        created_at
                    )
                    VALUES (
                        '7A9637',  -- 会社アカウント
                        p_date,
                        v_level,
                        v_user_record.user_id,
                        v_reward_amount,
                        NOW()
                    );

                    -- 会社ボーナステーブルに記録
                    INSERT INTO company_bonus_from_dormant (
                        date,
                        dormant_user_id,
                        dormant_user_email,
                        child_user_id,
                        referral_level,
                        original_amount,
                        company_user_id
                    )
                    VALUES (
                        p_date,
                        v_referrer_record.user_id,
                        v_referrer_record.email,
                        v_user_record.user_id,
                        v_level,
                        v_reward_amount,
                        '7A9637'
                    );

                    v_company_bonus := v_company_bonus + v_reward_amount;

                ELSE
                    -- アクティブユーザー → 通常通り紹介者へ報酬
                    INSERT INTO user_referral_profit (
                        user_id,
                        date,
                        referral_level,
                        child_user_id,
                        profit_amount,
                        created_at
                    )
                    VALUES (
                        v_referrer_record.user_id,
                        p_date,
                        v_level,
                        v_user_record.user_id,
                        v_reward_amount,
                        NOW()
                    );
                END IF;

                v_total_rewards := v_total_rewards + v_reward_amount;
            END IF;

            -- 次のレベルへ
            v_current_user_id := v_referrer_record.referrer_user_id;
        END LOOP;

        v_user_count := v_user_count + 1;
    END LOOP;

    -- 結果を返す
    RETURN QUERY SELECT
        CASE WHEN p_is_test_mode THEN 'TEST_SUCCESS' ELSE 'SUCCESS' END::TEXT,
        v_user_count::INTEGER,
        v_total_rewards::DECIMAL(10,3),
        v_company_bonus::DECIMAL(10,3),
        FORMAT('%s完了: %s名処理, 総報酬: $%s, 会社ボーナス: $%s',
               CASE WHEN p_is_test_mode THEN 'テスト' ELSE '本番' END,
               v_user_count, v_total_rewards, v_company_bonus)::TEXT;

EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT
        'ERROR'::TEXT,
        0::INTEGER,
        0::DECIMAL(10,3),
        0::DECIMAL(10,3),
        FORMAT('エラー: %s', SQLERRM)::TEXT;
END;
$$;

-- 実行権限付与
GRANT EXECUTE ON FUNCTION calculate_referral_rewards_with_dormant(DATE, BOOLEAN) TO anon;
GRANT EXECUTE ON FUNCTION calculate_referral_rewards_with_dormant(DATE, BOOLEAN) TO authenticated;

-- ============================================
-- 会社ボーナスレポート取得関数
-- ============================================

CREATE OR REPLACE FUNCTION get_company_bonus_report(
    p_start_date DATE DEFAULT CURRENT_DATE - INTERVAL '30 days',
    p_end_date DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE(
    report_date DATE,
    total_bonus DECIMAL(10,3),
    bonus_count INTEGER,
    dormant_users_count INTEGER,
    level1_bonus DECIMAL(10,3),
    level2_bonus DECIMAL(10,3),
    level3_bonus DECIMAL(10,3)
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        cb.date as report_date,
        SUM(cb.original_amount) as total_bonus,
        COUNT(*)::INTEGER as bonus_count,
        COUNT(DISTINCT cb.dormant_user_id)::INTEGER as dormant_users_count,
        SUM(CASE WHEN cb.referral_level = 1 THEN cb.original_amount ELSE 0 END) as level1_bonus,
        SUM(CASE WHEN cb.referral_level = 2 THEN cb.original_amount ELSE 0 END) as level2_bonus,
        SUM(CASE WHEN cb.referral_level = 3 THEN cb.original_amount ELSE 0 END) as level3_bonus
    FROM company_bonus_from_dormant cb
    WHERE cb.date BETWEEN p_start_date AND p_end_date
    GROUP BY cb.date
    ORDER BY cb.date DESC;
END;
$$;

-- 実行権限付与
GRANT EXECUTE ON FUNCTION get_company_bonus_report(DATE, DATE) TO anon;
GRANT EXECUTE ON FUNCTION get_company_bonus_report(DATE, DATE) TO authenticated;

-- ============================================
-- 7A9637アカウントの紹介報酬サマリービュー
-- ============================================

CREATE OR REPLACE VIEW company_account_referral_summary AS
SELECT
    urp.date,
    SUM(urp.profit_amount) as total_referral_profit,
    SUM(CASE WHEN urp.referral_level = 1 THEN urp.profit_amount ELSE 0 END) as level1_profit,
    SUM(CASE WHEN urp.referral_level = 2 THEN urp.profit_amount ELSE 0 END) as level2_profit,
    SUM(CASE WHEN urp.referral_level = 3 THEN urp.profit_amount ELSE 0 END) as level3_profit,
    COUNT(DISTINCT urp.child_user_id) as unique_children,
    -- 休眠ユーザーからのボーナス分を識別
    COALESCE(cb.dormant_bonus, 0) as bonus_from_dormant,
    SUM(urp.profit_amount) - COALESCE(cb.dormant_bonus, 0) as normal_referral_profit
FROM user_referral_profit urp
LEFT JOIN (
    SELECT
        date,
        SUM(original_amount) as dormant_bonus
    FROM company_bonus_from_dormant
    GROUP BY date
) cb ON urp.date = cb.date
WHERE urp.user_id = '7A9637'
GROUP BY urp.date, cb.dormant_bonus
ORDER BY urp.date DESC;

COMMENT ON VIEW company_account_referral_summary IS '7A9637の紹介報酬サマリー（通常報酬と休眠ボーナスを分離）';

-- 完了メッセージ
DO $$
BEGIN
    RAISE NOTICE '============================================';
    RAISE NOTICE '✅ 紹介報酬計算ロジックを更新しました';
    RAISE NOTICE '============================================';
    RAISE NOTICE '📋 更新内容:';
    RAISE NOTICE '   - calculate_referral_rewards_with_dormant() 関数';
    RAISE NOTICE '   - 休眠ユーザー（is_active_investor=FALSE）の報酬を7A9637へ';
    RAISE NOTICE '   - company_bonus_from_dormant テーブルに記録';
    RAISE NOTICE '   - get_company_bonus_report() レポート関数';
    RAISE NOTICE '   - company_account_referral_summary ビュー';
    RAISE NOTICE '';
    RAISE NOTICE '📊 使用例:';
    RAISE NOTICE '   -- テスト実行';
    RAISE NOTICE '   SELECT * FROM calculate_referral_rewards_with_dormant(''2025-10-07'', TRUE);';
    RAISE NOTICE '';
    RAISE NOTICE '   -- 本番実行';
    RAISE NOTICE '   SELECT * FROM calculate_referral_rewards_with_dormant(''2025-10-07'', FALSE);';
    RAISE NOTICE '';
    RAISE NOTICE '   -- 会社ボーナスレポート（過去30日）';
    RAISE NOTICE '   SELECT * FROM get_company_bonus_report();';
    RAISE NOTICE '';
    RAISE NOTICE '   -- 7A9637の紹介報酬サマリー';
    RAISE NOTICE '   SELECT * FROM company_account_referral_summary LIMIT 10;';
    RAISE NOTICE '============================================';
END $$;
