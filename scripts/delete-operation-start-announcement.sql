-- 「正式運用開始のお知らせ」を削除

DELETE FROM announcements
WHERE title LIKE '%正式運用開始%' OR title LIKE '%運用開始%';
