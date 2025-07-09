-- V1SPIYユーザーの実際のCoinW UID値を復元

-- 現在の状態確認
SELECT 
    'before_restore' as status,
    user_id,
    email,
    coinw_uid as current_coinw_uid,
    'Should be: 656546545' as actual_value
FROM users 
WHERE user_id = 'V1SPIY';

-- 実際のCoinW UID値に復元
UPDATE users 
SET coinw_uid = '656546545',
    updated_at = NOW()
WHERE user_id = 'V1SPIY';

-- 復元後の確認
SELECT 
    'after_restore' as status,
    user_id,
    email,
    coinw_uid as restored_coinw_uid
FROM users 
WHERE user_id = 'V1SPIY';

-- 管理画面での表示確認
SELECT 
    'admin_view_restored' as check_type,
    user_id,
    email,
    coinw_uid,
    amount_usd
FROM admin_purchases_view 
WHERE user_id = 'V1SPIY'
ORDER BY amount_usd DESC;

-- 成功メッセージ
SELECT 
    '✅ CoinW UID復元完了！' as message,
    'V1SPIY' as user_id,
    '656546545' as restored_coinw_uid,
    'ユーザーへの問い合わせ不要' as status;
