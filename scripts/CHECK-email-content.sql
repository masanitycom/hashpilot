-- 再送信対象メールの内容確認
SELECT
  id,
  subject,
  body,
  from_email,
  created_at
FROM system_emails
WHERE subject LIKE '%市場急落%'
   OR subject LIKE '%エアドロップ%'
ORDER BY created_at DESC
LIMIT 1;
