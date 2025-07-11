-- ユーザー2BF53BのNFTデータを確認して修正

-- 1. 現在のデータを確認
DO $$
DECLARE
    v_current_data RECORD;
BEGIN
    SELECT * INTO v_current_data
    FROM affiliate_cycle
    WHERE user_id = '2BF53B';
    
    IF FOUND THEN
        RAISE NOTICE 'Current data for 2BF53B: manual_nft=%s, auto_nft=%s, total_nft=%s', 
            v_current_data.manual_nft_count, 
            v_current_data.auto_nft_count, 
            v_current_data.total_nft_count;
    ELSE
        RAISE NOTICE 'User 2BF53B not found in affiliate_cycle';
    END IF;
END $$;

-- 2. ユーザー2BF53BのNFT数を2枚に更新（手動1枚、自動1枚）
UPDATE affiliate_cycle
SET 
    manual_nft_count = 1,
    auto_nft_count = 1,
    total_nft_count = 2,
    last_updated = NOW()
WHERE user_id = '2BF53B';

-- 3. 更新後のデータを確認
SELECT 
    user_id,
    manual_nft_count,
    auto_nft_count,
    total_nft_count,
    cum_usdt,
    available_usdt,
    phase,
    last_updated
FROM affiliate_cycle
WHERE user_id = '2BF53B';

-- 4. 念のため、ユーザーの存在を確認
SELECT 
    user_id,
    email,
    full_name
FROM users
WHERE user_id = '2BF53B';

-- 5. 買い取り申請履歴も確認
SELECT 
    id,
    user_id,
    request_date,
    manual_nft_count,
    auto_nft_count,
    total_nft_count,
    status
FROM buyback_requests
WHERE user_id = '2BF53B'
ORDER BY created_at DESC;