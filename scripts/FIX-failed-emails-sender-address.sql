-- ========================================
-- 失敗したメールの送信元アドレスを修正
-- ========================================
-- noreply@send.hashpilot.biz → noreply@hashpilot.biz

-- STEP 1: 対象メールの確認
SELECT '=== 対象メールの確認 ===' as section;
SELECT
  se.id,
  se.subject,
  se.from_email,
  se.created_at,
  COUNT(*) FILTER (WHERE er.status = 'pending') as pending,
  COUNT(*) FILTER (WHERE er.status = 'failed') as failed
FROM system_emails se
LEFT JOIN email_recipients er ON se.id = er.email_id
WHERE se.from_email = 'noreply@send.hashpilot.biz'
GROUP BY se.id, se.subject, se.from_email, se.created_at
ORDER BY se.created_at DESC;

-- STEP 2: 送信元アドレスを修正
SELECT '=== 送信元アドレスを修正 ===' as section;
UPDATE system_emails
SET from_email = 'noreply@hashpilot.biz'
WHERE from_email = 'noreply@send.hashpilot.biz';

-- STEP 3: 失敗したメールをpendingに戻す（再送信可能に）
SELECT '=== 失敗メールをpendingに戻す ===' as section;
UPDATE email_recipients er
SET
  status = 'pending',
  error_message = NULL
FROM system_emails se
WHERE er.email_id = se.id
  AND se.from_email = 'noreply@hashpilot.biz'
  AND er.status = 'failed'
  AND er.error_message LIKE '%not verified%';

-- STEP 4: 修正結果の確認
SELECT '=== 修正後の状態 ===' as section;
SELECT
  se.id,
  se.subject,
  se.from_email,
  COUNT(*) FILTER (WHERE er.status = 'pending') as pending,
  COUNT(*) FILTER (WHERE er.status = 'sent' OR er.status = 'read') as success,
  COUNT(*) FILTER (WHERE er.status = 'failed') as failed
FROM system_emails se
LEFT JOIN email_recipients er ON se.id = er.email_id
WHERE se.created_at >= CURRENT_DATE
GROUP BY se.id, se.subject, se.from_email
ORDER BY se.created_at DESC;
