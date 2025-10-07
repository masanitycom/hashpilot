-- ペガサス交換NFTフラグの追加
-- 作成日: 2025年10月6日

-- ============================================
-- 1. usersテーブルにペガサス交換フラグを追加
-- ============================================

-- ペガサス交換フラグ
ALTER TABLE users
ADD COLUMN IF NOT EXISTS is_pegasus_exchange BOOLEAN DEFAULT FALSE;

-- ペガサス交換日
ALTER TABLE users
ADD COLUMN IF NOT EXISTS pegasus_exchange_date DATE;

-- 出金解禁日
ALTER TABLE users
ADD COLUMN IF NOT EXISTS pegasus_withdrawal_unlock_date DATE;

-- インデックス追加（検索の高速化）
CREATE INDEX IF NOT EXISTS idx_users_pegasus_exchange
ON users(is_pegasus_exchange)
WHERE is_pegasus_exchange = TRUE;

-- コメント追加
COMMENT ON COLUMN users.is_pegasus_exchange IS 'ペガサスNFT交換フラグ（管理者のみ表示）';
COMMENT ON COLUMN users.pegasus_exchange_date IS 'ペガサスNFT交換日';
COMMENT ON COLUMN users.pegasus_withdrawal_unlock_date IS '出金解禁日（この日以降出金可能）';

-- 完了メッセージ
DO $$
BEGIN
    RAISE NOTICE '✅ ペガサス交換フラグを追加しました';
    RAISE NOTICE '📋 追加されたカラム:';
    RAISE NOTICE '   - is_pegasus_exchange (BOOLEAN)';
    RAISE NOTICE '   - pegasus_exchange_date (DATE)';
    RAISE NOTICE '   - pegasus_withdrawal_unlock_date (DATE)';
END $$;
