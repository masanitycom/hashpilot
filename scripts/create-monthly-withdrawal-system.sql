-- 月末自動出金システムのデータベース構造

-- 1. ユーザーの出金先設定テーブル
CREATE TABLE IF NOT EXISTS user_withdrawal_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL REFERENCES users(user_id),
    withdrawal_address TEXT, -- 送金先アドレス
    coinw_uid TEXT, -- CoinW UID（優先）
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    UNIQUE(user_id)
);

-- 2. 月末出金記録テーブル
CREATE TABLE IF NOT EXISTS monthly_withdrawals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL,
    email TEXT NOT NULL,
    withdrawal_month DATE NOT NULL, -- 対象月（YYYY-MM-01形式）
    
    -- 報酬詳細
    level1_reward DECIMAL(10,3) DEFAULT 0,
    level2_reward DECIMAL(10,3) DEFAULT 0,
    level3_reward DECIMAL(10,3) DEFAULT 0,
    level4_plus_reward DECIMAL(10,3) DEFAULT 0,
    daily_profit DECIMAL(10,3) DEFAULT 0,
    total_amount DECIMAL(10,3) NOT NULL,
    
    -- 送金先情報
    withdrawal_address TEXT,
    coinw_uid TEXT,
    withdrawal_method TEXT, -- 'coinw' or 'address'
    
    -- ステータス
    status TEXT DEFAULT 'pending', -- 'pending', 'completed', 'failed', 'on_hold'
    processed_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    
    -- メタデータ
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    notes TEXT,
    
    -- インデックス用
    UNIQUE(user_id, withdrawal_month)
);

-- 3. インデックス作成
CREATE INDEX IF NOT EXISTS idx_monthly_withdrawals_status ON monthly_withdrawals(status);
CREATE INDEX IF NOT EXISTS idx_monthly_withdrawals_month ON monthly_withdrawals(withdrawal_month);
CREATE INDEX IF NOT EXISTS idx_monthly_withdrawals_user ON monthly_withdrawals(user_id);

-- 4. RLS（Row Level Security）設定
ALTER TABLE user_withdrawal_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE monthly_withdrawals ENABLE ROW LEVEL SECURITY;

-- ユーザーは自分の設定のみ表示・編集可能
CREATE POLICY "users_own_withdrawal_settings"
ON user_withdrawal_settings
FOR ALL
TO public
USING (
    user_id IN (
        SELECT user_id FROM users WHERE id = auth.uid()
    )
);

-- ユーザーは自分の出金記録のみ閲覧可能
CREATE POLICY "users_own_withdrawals"
ON monthly_withdrawals
FOR SELECT
TO public
USING (
    user_id IN (
        SELECT user_id FROM users WHERE id = auth.uid()
    )
);

-- 管理者は全ての出金記録を閲覧・編集可能
CREATE POLICY "admin_all_withdrawals"
ON monthly_withdrawals
FOR ALL
TO public
USING (
    EXISTS (
        SELECT 1 FROM admins WHERE user_id = auth.uid()::text
    )
);

-- 5. 月末出金処理関数
CREATE OR REPLACE FUNCTION process_monthly_withdrawals(
    p_target_month DATE
)
RETURNS TABLE (
    processed_count INTEGER,
    total_amount DECIMAL,
    pending_count INTEGER,
    on_hold_count INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_processed_count INTEGER := 0;
    v_total_amount DECIMAL := 0;
    v_pending_count INTEGER := 0;
    v_on_hold_count INTEGER := 0;
    user_record RECORD;
    v_total_user_amount DECIMAL;
BEGIN
    -- 対象月の全ユーザーの報酬を計算
    FOR user_record IN 
        SELECT DISTINCT u.user_id, u.email
        FROM users u
        WHERE EXISTS (
            SELECT 1 FROM user_daily_profit udp 
            WHERE udp.user_id = u.user_id 
            AND date_trunc('month', udp.date) = date_trunc('month', p_target_month)
        )
    LOOP
        -- ユーザーの月間合計報酬を計算
        WITH user_monthly_rewards AS (
            -- 日利報酬
            SELECT 
                COALESCE(SUM(daily_profit::DECIMAL), 0) as daily_profit_total
            FROM user_daily_profit
            WHERE user_id = user_record.user_id
            AND date_trunc('month', date) = date_trunc('month', p_target_month)
        ),
        user_referral_rewards AS (
            -- アフィリエイト報酬（仮の計算、実際のロジックに合わせて調整）
            SELECT 
                0 as level1_reward,
                0 as level2_reward, 
                0 as level3_reward,
                0 as level4_plus_reward
        )
        SELECT 
            umr.daily_profit_total,
            urr.level1_reward,
            urr.level2_reward,
            urr.level3_reward,
            urr.level4_plus_reward,
            (umr.daily_profit_total + urr.level1_reward + urr.level2_reward + urr.level3_reward + urr.level4_plus_reward) as total_amount
        FROM user_monthly_rewards umr, user_referral_rewards urr
        INTO v_total_user_amount;
        
        -- 最小出金額チェック（$10以上）
        IF v_total_user_amount >= 10 THEN
            -- 出金先設定を確認
            INSERT INTO monthly_withdrawals (
                user_id,
                email,
                withdrawal_month,
                daily_profit,
                level1_reward,
                level2_reward,
                level3_reward,
                level4_plus_reward,
                total_amount,
                withdrawal_address,
                coinw_uid,
                withdrawal_method,
                status
            )
            SELECT 
                user_record.user_id,
                user_record.email,
                date_trunc('month', p_target_month),
                v_total_user_amount,
                0, 0, 0, 0, -- アフィリエイト報酬（実装時に計算）
                v_total_user_amount,
                uws.withdrawal_address,
                uws.coinw_uid,
                CASE 
                    WHEN uws.coinw_uid IS NOT NULL AND uws.coinw_uid != '' THEN 'coinw'
                    WHEN uws.withdrawal_address IS NOT NULL AND uws.withdrawal_address != '' THEN 'address'
                    ELSE NULL
                END,
                CASE 
                    WHEN uws.coinw_uid IS NOT NULL AND uws.coinw_uid != '' THEN 'pending'
                    WHEN uws.withdrawal_address IS NOT NULL AND uws.withdrawal_address != '' THEN 'pending'
                    ELSE 'on_hold'
                END
            FROM user_withdrawal_settings uws
            WHERE uws.user_id = user_record.user_id
            AND uws.is_active = true
            ON CONFLICT (user_id, withdrawal_month) DO UPDATE SET
                total_amount = EXCLUDED.total_amount,
                withdrawal_address = EXCLUDED.withdrawal_address,
                coinw_uid = EXCLUDED.coinw_uid,
                withdrawal_method = EXCLUDED.withdrawal_method,
                status = EXCLUDED.status,
                updated_at = NOW();
            
            v_processed_count := v_processed_count + 1;
            v_total_amount := v_total_amount + v_total_user_amount;
        END IF;
    END LOOP;
    
    -- 集計結果を取得
    SELECT 
        COUNT(CASE WHEN status = 'pending' THEN 1 END),
        COUNT(CASE WHEN status = 'on_hold' THEN 1 END)
    INTO v_pending_count, v_on_hold_count
    FROM monthly_withdrawals
    WHERE withdrawal_month = date_trunc('month', p_target_month);
    
    RETURN QUERY SELECT v_processed_count, v_total_amount, v_pending_count, v_on_hold_count;
END;
$$;

-- 6. 権限付与
GRANT SELECT, INSERT, UPDATE ON user_withdrawal_settings TO authenticated;
GRANT SELECT ON monthly_withdrawals TO authenticated;
GRANT EXECUTE ON FUNCTION process_monthly_withdrawals(DATE) TO authenticated;

-- 7. 初期データ確認
SELECT 'Monthly withdrawal system created successfully' as status;