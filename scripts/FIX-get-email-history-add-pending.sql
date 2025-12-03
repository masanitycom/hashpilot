-- get_email_history関数にpending_countを追加

CREATE OR REPLACE FUNCTION get_email_history(
  p_admin_email VARCHAR,
  p_limit INTEGER DEFAULT 50
)
RETURNS TABLE(
  email_id UUID,
  subject VARCHAR,
  email_type VARCHAR,
  target_group VARCHAR,
  created_at TIMESTAMPTZ,
  total_recipients BIGINT,
  sent_count BIGINT,
  failed_count BIGINT,
  read_count BIGINT,
  pending_count BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    se.id as email_id,
    se.subject,
    se.email_type,
    se.target_group,
    se.created_at,
    COUNT(er.id) as total_recipients,
    COUNT(CASE WHEN er.status = 'sent' THEN 1 END) as sent_count,
    COUNT(CASE WHEN er.status = 'failed' THEN 1 END) as failed_count,
    COUNT(CASE WHEN er.read_at IS NOT NULL THEN 1 END) as read_count,
    COUNT(CASE WHEN er.status = 'pending' THEN 1 END) as pending_count
  FROM system_emails se
  LEFT JOIN email_recipients er ON se.id = er.email_id
  WHERE se.created_by = (SELECT id FROM auth.users WHERE email = p_admin_email)
     OR p_admin_email IN ('basarasystems@gmail.com', 'support@dshsupport.biz')
  GROUP BY se.id, se.subject, se.email_type, se.target_group, se.created_at
  ORDER BY se.created_at DESC
  LIMIT p_limit;
END;
$$;

-- 確認
SELECT 'get_email_history function updated with pending_count' as result;
