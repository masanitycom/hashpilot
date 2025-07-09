-- 緊急：登録待ちユーザーへの連絡用情報

-- 問題のあるユーザーの連絡先情報
SELECT 
    'emergency_contact_info' as purpose,
    u.user_id,
    u.email,
    u.created_at,
    CASE 
        WHEN u.created_at >= '2025-07-06' THEN '🔴 緊急対応必要（今日登録）'
        WHEN u.created_at >= '2025-07-05' THEN '🟡 早急対応必要（昨日登録）'
        ELSE '🟢 通常対応'
    END as priority,
    'CoinW UIDと紹介者情報の再入力をお願いします' as action_needed
FROM users u
WHERE u.coinw_uid IS NULL
ORDER BY u.created_at DESC;

-- 連絡用テンプレート情報
SELECT 
    'contact_template' as info_type,
    '件名: HASH PILOT 登録情報の再確認のお願い' as email_subject,
    'お客様の登録情報に不備があったため、CoinW UIDと紹介者コードの再入力をお願いいたします。' as message_template;
