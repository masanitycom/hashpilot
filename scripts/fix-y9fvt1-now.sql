-- Y9FVT1の問題を今すぐ修正

-- Y9FVT1の未承認購入を削除
DELETE FROM purchases 
WHERE user_id = 'Y9FVT1' 
AND admin_approved = false;

-- データ強制更新
UPDATE users SET updated_at = NOW() WHERE user_id = 'Y9FVT1';
UPDATE affiliate_cycle SET updated_at = NOW() WHERE user_id = 'Y9FVT1';

-- 確認
SELECT 'Y9FVT1修正完了' as status;