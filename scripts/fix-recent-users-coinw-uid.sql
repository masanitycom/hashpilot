-- 最近登録したユーザーのCoinW UID修正（安全な方法）

-- 1. 最近の登録者でCoinW UIDが未設定のユーザーを特定
SELECT 
    'recent_users_without_coinw_uid' as check_type,
    u.user_id,
    u.email,
    u.created_at,
    'CoinW UID未設定' as status
FROM users u
WHERE u.created_at > NOW() - INTERVAL '24 hours'
AND (u.coinw_uid IS NULL OR u.coinw_uid = '');

-- 2. 紹介リンク経由の登録者を確認（CoinW UIDが含まれている可能性）
-- 注意: 実際のCoinW UIDは手動で設定する必要があります
SELECT 
    'recent_referral_registrations' as check_type,
    u.user_id,
    u.email,
    u.referrer_user_id,
    r.coinw_uid as referrer_coinw_uid,
    u.created_at
FROM users u
LEFT JOIN users r ON r.user_id = u.referrer_user_id
WHERE u.created_at > NOW() - INTERVAL '24 hours'
AND u.referrer_user_id IS NOT NULL;

-- 3. 手動でCoinW UIDを設定（管理者が実際の値を確認してから実行）
-- 以下は例です。実際のCoinW UIDに置き換えてください

-- 例: tmtm1108tmtm@gmail.com のCoinW UIDを設定
-- UPDATE users 
-- SET coinw_uid = '実際のCoinW_UID',
--     updated_at = NOW()
-- WHERE email = 'tmtm1108tmtm@gmail.com';

-- 例: oshiboriakihiro@gmail.com のCoinW UIDを設定
-- UPDATE users 
-- SET coinw_uid = '実際のCoinW_UID',
--     updated_at = NOW()
-- WHERE email = 'oshiboriakihiro@gmail.com';

-- 例: soccergurataku@gmail.com のCoinW UIDを設定
-- UPDATE users 
-- SET coinw_uid = '実際のCoinW_UID',
--     updated_at = NOW()
-- WHERE email = 'soccergurataku@gmail.com';

-- 例: tamakimining@gmail.com のCoinW UIDを設定
-- UPDATE users 
-- SET coinw_uid = '実際のCoinW_UID',
--     updated_at = NOW()
-- WHERE email = 'tamakimining@gmail.com';

-- 4. 更新後の確認
SELECT 
    'updated_users_check' as check_type,
    u.user_id,
    u.email,
    u.coinw_uid,
    u.referrer_user_id,
    u.created_at,
    CASE 
        WHEN u.coinw_uid IS NOT NULL THEN '✅ 設定済み'
        ELSE '❌ 未設定'
    END as coinw_uid_status
FROM users u
WHERE u.created_at > NOW() - INTERVAL '24 hours'
ORDER BY u.created_at DESC;
