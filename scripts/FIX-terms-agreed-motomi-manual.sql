-- ========================================
-- motomi0101usp@gmail.com / motomi0101usp+2@gmail.com の
-- 利用規約同意状態を手動でセット（NULLのため再表示が止まらない問題への対応）
-- ========================================

UPDATE users
SET terms_agreed_at = NOW()
WHERE email IN ('motomi0101usp@gmail.com', 'motomi0101usp+2@gmail.com')
  AND terms_agreed_at IS NULL;

-- 確認
SELECT user_id, email, terms_agreed_at
FROM users
WHERE email IN ('motomi0101usp@gmail.com', 'motomi0101usp+2@gmail.com');
