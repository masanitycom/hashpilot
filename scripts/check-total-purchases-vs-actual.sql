-- users.total_purchases と実際の購入額の整合性チェック

-- 1. users.total_purchasesの合計
SELECT
  '👤 users.total_purchases合計' as category,
  SUM(total_purchases) as total_amount,
  COUNT(*) as user_count
FROM users
WHERE has_approved_nft = true;

-- 2. purchasesテーブルの実際の購入額（手数料除く）
SELECT
  '💰 実際の購入額（手数料除く）' as category,
  SUM(
    CASE
      WHEN amount_usd = 1100 THEN 1000
      WHEN amount_usd = 2200 THEN 2000
      WHEN amount_usd = 3300 THEN 3000
      WHEN amount_usd = 4400 THEN 4000
      ELSE amount_usd * (1000.0 / 1100.0)
    END
  ) as total_amount,
  COUNT(*) as purchase_count
FROM purchases
WHERE admin_approved = true;

-- 3. purchasesテーブルの手数料込み合計
SELECT
  '💳 購入額（手数料込み）' as category,
  SUM(amount_usd) as total_amount,
  COUNT(*) as purchase_count
FROM purchases
WHERE admin_approved = true;

-- 4. ユーザー別の差分チェック
SELECT
  u.user_id,
  u.email,
  u.total_purchases as user_total_purchases,
  SUM(
    CASE
      WHEN p.amount_usd = 1100 THEN 1000
      WHEN p.amount_usd = 2200 THEN 2000
      WHEN p.amount_usd = 3300 THEN 3000
      WHEN p.amount_usd = 4400 THEN 4000
      ELSE p.amount_usd * (1000.0 / 1100.0)
    END
  ) as actual_total_purchases,
  (u.total_purchases - SUM(
    CASE
      WHEN p.amount_usd = 1100 THEN 1000
      WHEN p.amount_usd = 2200 THEN 2000
      WHEN p.amount_usd = 3300 THEN 3000
      WHEN p.amount_usd = 4400 THEN 4000
      ELSE p.amount_usd * (1000.0 / 1100.0)
    END
  )) as difference
FROM users u
LEFT JOIN purchases p ON u.user_id = p.user_id AND p.admin_approved = true
WHERE u.has_approved_nft = true
GROUP BY u.user_id, u.email, u.total_purchases
HAVING u.total_purchases != SUM(
  CASE
    WHEN p.amount_usd = 1100 THEN 1000
    WHEN p.amount_usd = 2200 THEN 2000
    WHEN p.amount_usd = 3300 THEN 3000
    WHEN p.amount_usd = 4400 THEN 4000
    ELSE p.amount_usd * (1000.0 / 1100.0)
  END
)
ORDER BY difference DESC
LIMIT 20;
