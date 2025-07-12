-- 緊急削除：AA8D9Bを手動で安全に削除

-- 1. 削除前確認
SELECT 'AA8D9B削除前の状況:' as info, user_id, email, total_purchases FROM users WHERE user_id = 'AA8D9B';

-- 2. RPC関数で安全に削除
SELECT * FROM delete_user_safely('AA8D9B', 'masataka.tak@gmail.com');

-- 3. 削除完了確認
SELECT 
  CASE 
    WHEN COUNT(*) = 0 THEN '✅ AA8D9B完全削除成功'
    ELSE '❌ 削除失敗 - まだ存在'
  END as result
FROM users WHERE user_id = 'AA8D9B';