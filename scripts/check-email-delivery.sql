-- メール送信状況の詳細確認
SELECT 
  email,
  created_at,
  email_confirmed_at,
  confirmation_sent_at,
  recovery_sent_at,
  email_change_sent_at,
  CASE 
    WHEN email_confirmed_at IS NOT NULL THEN '確認済み'
    WHEN confirmation_sent_at IS NOT NULL THEN '確認メール送信済み（未確認）'
    ELSE '確認メール未送信'
  END as status,
  EXTRACT(EPOCH FROM (NOW() - created_at))/3600 as hours_since_signup
FROM auth.users 
WHERE email LIKE '%masataka.tak%' OR email LIKE '%test%'
ORDER BY created_at DESC;

-- 最近のメール送信アクティビティ
SELECT 
  COUNT(*) as total_users,
  COUNT(CASE WHEN email_confirmed_at IS NOT NULL THEN 1 END) as confirmed_users,
  COUNT(CASE WHEN confirmation_sent_at IS NOT NULL THEN 1 END) as confirmation_emails_sent,
  COUNT(CASE WHEN recovery_sent_at IS NOT NULL THEN 1 END) as recovery_emails_sent
FROM auth.users 
WHERE created_at > NOW() - INTERVAL '24 hours';
