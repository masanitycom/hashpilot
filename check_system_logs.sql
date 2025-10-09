-- system_logsテーブルの最新ログを確認

-- 最新20件のログ
SELECT
  id,
  log_type,
  operation,
  user_id,
  message,
  created_at
FROM system_logs
ORDER BY created_at DESC
LIMIT 20;

-- 日付別のログ件数
SELECT
  DATE(created_at) as log_date,
  COUNT(*) as log_count
FROM system_logs
WHERE created_at >= '2025-10-01'
GROUP BY DATE(created_at)
ORDER BY log_date DESC;

-- 10/9以降のログがあるか確認
SELECT COUNT(*) as logs_after_oct9
FROM system_logs
WHERE created_at >= '2025-10-09 00:00:00';
