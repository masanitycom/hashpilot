-- 既存のusersテーブルのreward_address_bep20を使用するように月末出金システムを更新

-- 1. user_withdrawal_settingsテーブルは既存のusersテーブルを使用するので不要
-- 代わりに、usersテーブルに月末出金関連フィールドを追加

-- CoinW UIDフィールドを追加（既にある場合は無視）
ALTER TABLE users ADD COLUMN IF NOT EXISTS coinw_uid_for_withdrawal TEXT;

-- 2. monthly_withdrawals テーブルを既存フィールドに対応させる
DROP TABLE IF EXISTS monthly_withdrawals;

CREATE TABLE monthly_withdrawals (
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
    
    -- 送金先情報（usersテーブルから取得）
    withdrawal_address TEXT, -- reward_address_bep20 または coinw_uid
    withdrawal_method TEXT, -- 'bep20' or 'coinw'
    
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

-- 4. RLS設定
ALTER TABLE monthly_withdrawals ENABLE ROW LEVEL SECURITY;

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

-- 5. 更新された月末出金処理関数
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
    v_withdrawal_address TEXT;
    v_withdrawal_method TEXT;
    v_status TEXT;
BEGIN
    -- 対象月の全ユーザーの報酬を計算
    FOR user_record IN 
        SELECT DISTINCT u.user_id, u.email, u.reward_address_bep20, u.coinw_uid
        FROM users u
        WHERE EXISTS (
            SELECT 1 FROM user_daily_profit udp 
            WHERE udp.user_id = u.user_id 
            AND date_trunc('month', udp.date) = date_trunc('month', p_target_month)
        )
    LOOP
        -- ユーザーの月間合計報酬を計算
        SELECT 
            COALESCE(SUM(daily_profit::DECIMAL), 0)
        INTO v_total_user_amount
        FROM user_daily_profit
        WHERE user_id = user_record.user_id
        AND date_trunc('month', date) = date_trunc('month', p_target_month);
        
        -- 最小出金額チェック（$10以上）
        IF v_total_user_amount >= 10 THEN
            -- 出金先設定を確認
            IF user_record.coinw_uid IS NOT NULL AND user_record.coinw_uid != '' THEN
                v_withdrawal_address := user_record.coinw_uid;
                v_withdrawal_method := 'coinw';
                v_status := 'pending';
            ELSIF user_record.reward_address_bep20 IS NOT NULL AND user_record.reward_address_bep20 != '' THEN
                v_withdrawal_address := user_record.reward_address_bep20;
                v_withdrawal_method := 'bep20';
                v_status := 'pending';
            ELSE
                v_withdrawal_address := NULL;
                v_withdrawal_method := NULL;
                v_status := 'on_hold';
            END IF;
            
            -- 出金記録を作成/更新
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
                withdrawal_method,
                status
            )
            VALUES (
                user_record.user_id,
                user_record.email,
                date_trunc('month', p_target_month),
                v_total_user_amount,
                0, 0, 0, 0, -- アフィリエイト報酬（将来実装）
                v_total_user_amount,
                v_withdrawal_address,
                v_withdrawal_method,
                v_status
            )
            ON CONFLICT (user_id, withdrawal_month) DO UPDATE SET
                total_amount = EXCLUDED.total_amount,
                daily_profit = EXCLUDED.daily_profit,
                withdrawal_address = EXCLUDED.withdrawal_address,
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
GRANT SELECT ON monthly_withdrawals TO authenticated;
GRANT EXECUTE ON FUNCTION process_monthly_withdrawals(DATE) TO authenticated;

-- 7. 動作確認
SELECT 'Monthly withdrawal system updated for existing users table' as status;