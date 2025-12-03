-- 未送信のメール受信者を確認

-- 1. 最新のメールIDを確認
SELECT
  id as email_id,
  subject,
  created_at,
  (SELECT COUNT(*) FROM email_recipients WHERE email_id = system_emails.id) as total_recipients,
  (SELECT COUNT(*) FROM email_recipients WHERE email_id = system_emails.id AND status = 'sent') as sent_count,
  (SELECT COUNT(*) FROM email_recipients WHERE email_id = system_emails.id AND status = 'pending') as pending_count,
  (SELECT COUNT(*) FROM email_recipients WHERE email_id = system_emails.id AND status = 'failed') as failed_count
FROM system_emails
ORDER BY created_at DESC
LIMIT 5;

-- 2. 未送信（pending）のユーザーを確認
SELECT
  er.id,
  er.user_id,
  er.to_email,
  er.status
FROM email_recipients er
JOIN system_emails se ON er.email_id = se.id
WHERE se.subject LIKE '%Hash Pilot%'  -- 件名で絞り込み
  AND er.status = 'pending'
ORDER BY er.to_email
LIMIT 50;

-- 3. 未送信の件数
SELECT
  COUNT(*) as pending_count
FROM email_recipients er
JOIN system_emails se ON er.email_id = se.id
WHERE se.subject LIKE '%Hash Pilot%'
  AND er.status = 'pending';
