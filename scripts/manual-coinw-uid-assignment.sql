-- 手動でCoinW UIDを設定（管理者用）

-- Y9FVT1のCoinW UIDを手動設定（紹介者と同じ値または独自の値）
-- 紹介リンクにCoinW UIDが含まれていた場合の復旧

-- 1. 紹介者2BF53BのCoinW UIDを設定（まず紹介者から）
UPDATE users 
SET coinw_uid = '2236'  -- 実際のCoinW UIDに置き換え
WHERE user_id = '2BF53B' AND coinw_uid IS NULL;

-- 2. Y9FVT1のCoinW UIDを設定
-- 紹介リンクのパラメータに基づいて設定
UPDATE users 
SET coinw_uid = '2236'  -- 紹介リンクに含まれていたCoinW UIDに置き換え
WHERE user_id = 'Y9FVT1' AND coinw_uid IS NULL;

-- 3. 設定結果の確認
SELECT 
    user_id,
    email,
    referrer_user_id,
    coinw_uid,
    CASE 
        WHEN referrer_user_id IS NOT NULL THEN '紹介経由'
        ELSE '直接登録'
    END as registration_type
FROM users 
WHERE user_id IN ('Y9FVT1', 'MO08F3', '2BF53B')
ORDER BY created_at DESC;
