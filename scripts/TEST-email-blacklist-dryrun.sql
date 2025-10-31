-- ========================================
-- メール送信除外リスト機能のテスト（実際にメールは送らない）
-- ========================================

-- 1. 現在のemail_blacklistedユーザー確認
SELECT '=== 1. 現在の除外ユーザー ===' as section;

SELECT
    user_id,
    email,
    full_name,
    email_blacklisted,
    total_purchases
FROM users
WHERE email_blacklisted = TRUE
ORDER BY created_at DESC;

-- 2. 全ユーザー送信の場合の対象者数確認
SELECT '=== 2. 全ユーザー送信の場合 ===' as section;

SELECT
    COUNT(*) FILTER (WHERE email_blacklisted = FALSE OR email_blacklisted IS NULL) as would_receive,
    COUNT(*) FILTER (WHERE email_blacklisted = TRUE) as would_skip,
    COUNT(*) as total_users
FROM users;

-- 3. 承認済みユーザー送信の場合
SELECT '=== 3. 承認済みユーザー送信の場合 ===' as section;

SELECT
    COUNT(DISTINCT u.user_id) FILTER (WHERE u.email_blacklisted = FALSE OR u.email_blacklisted IS NULL) as would_receive,
    COUNT(DISTINCT u.user_id) FILTER (WHERE u.email_blacklisted = TRUE) as would_skip,
    COUNT(DISTINCT u.user_id) as total_approved_users
FROM users u
INNER JOIN purchases p ON u.user_id = p.user_id
WHERE p.admin_approved = TRUE;

-- 4. 未承認ユーザー送信の場合
SELECT '=== 4. 未承認ユーザー送信の場合 ===' as section;

SELECT
    COUNT(*) FILTER (WHERE email_blacklisted = FALSE OR email_blacklisted IS NULL) as would_receive,
    COUNT(*) FILTER (WHERE email_blacklisted = TRUE) as would_skip,
    COUNT(*) as total_unapproved_users
FROM users u
WHERE NOT EXISTS (
    SELECT 1 FROM purchases p
    WHERE p.user_id = u.user_id AND p.admin_approved = TRUE
);

-- 5. テスト実行（実際にemail_recipientsテーブルにレコードを作成するが、メールは送信しない）
SELECT '=== 5. テスト実行（後で削除） ===' as section;

SELECT * FROM create_system_email(
    'テストメール - 後で削除します',
    'これはテストメールです。後で削除されます。',
    'all',
    NULL
);

-- 6. 作成されたemail_recipientsの確認
SELECT '=== 6. テスト結果確認 ===' as section;

SELECT
    er.recipient_email,
    u.email_blacklisted,
    er.status
FROM email_recipients er
INNER JOIN system_emails se ON er.email_id = se.id
LEFT JOIN users u ON er.user_id = u.user_id
WHERE se.subject = 'テストメール - 後で削除します'
ORDER BY u.email_blacklisted DESC NULLS LAST, er.recipient_email
LIMIT 20;

-- 7. 除外されたユーザーが含まれていないか確認
SELECT '=== 7. 除外ユーザーが含まれていないか確認 ===' as section;

SELECT
    u.user_id,
    u.email,
    u.email_blacklisted,
    CASE
        WHEN er.recipient_email IS NOT NULL THEN '❌ 含まれている（エラー）'
        ELSE '✅ 正しく除外されている'
    END as result
FROM users u
LEFT JOIN email_recipients er ON u.user_id = er.user_id
    AND er.email_id = (
        SELECT id FROM system_emails
        WHERE subject = 'テストメール - 後で削除します'
        LIMIT 1
    )
WHERE u.email_blacklisted = TRUE;

-- 8. テストデータ削除
SELECT '=== 8. テストデータ削除 ===' as section;

DELETE FROM email_recipients
WHERE email_id IN (
    SELECT id FROM system_emails
    WHERE subject = 'テストメール - 後で削除します'
);

DELETE FROM system_emails
WHERE subject = 'テストメール - 後で削除します';

SELECT '✅ テスト完了・テストデータ削除済み' as status;
