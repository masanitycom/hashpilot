-- ============================================================
-- 指定5名の「今日付けで解約した場合」の金額試算
-- 実行日: 2026-09-05
--
-- 対象（高齢で操作ができないため代理対応）:
--   daiya2020aiko@gmail.com
--   mayumi19591207@icloud.com
--   mie123mie54321@gmail.com
--   ken.atae727@gmail.com
--   yarenshanxia901@gmail.com
--
-- 買取金額の計算式（calculate_user_buyback_amount）:
--   1枚あたり利益 = (累計日利 + 累計紹介報酬) / 保有NFT枚数
--   利益 >= 0 : 手動 = 枚数 × (1000 - 利益/2) 、自動 = 枚数 × (500 - 利益/2)
--   利益 <  0 : 手動 = 枚数 × (1000 + 利益)   、自動 = 枚数 × (500 + 利益)
--
-- ⚠️ 累計利益は日々変わるため、金額は実行日時点のもの
-- ============================================================


-- ------------------------------------------------------------
-- 【1】対象5名の基本情報（user_idの特定と状態確認）
-- ------------------------------------------------------------
SELECT
  u.user_id, u.email,
  u.has_approved_nft         AS NFT承認済,
  u.operation_start_date     AS 運用開始日,
  u.is_active_investor       AS アクティブ,
  u.is_pegasus_exchange      AS ペガサス,
  u.coinw_uid,
  u.nft_receive_address      AS NFT受取アドレス,
  u.channel_linked_confirmed AS CH紐付け確認,
  (SELECT COUNT(*) FROM nft_master nm
    WHERE nm.user_id = u.user_id AND nm.buyback_date IS NULL) AS 保有NFT数,
  (SELECT COUNT(*) FROM buyback_requests br
    WHERE br.user_id = u.user_id AND br.status = 'pending')   AS 既存の申請
FROM users u
WHERE u.email IN (
  'daiya2020aiko@gmail.com',
  'mayumi19591207@icloud.com',
  'mie123mie54321@gmail.com',
  'ken.atae727@gmail.com',
  'yarenshanxia901@gmail.com'
)
ORDER BY u.email;


-- ------------------------------------------------------------
-- 【2】★本命★ 解約した場合の金額
--   買取金額 ＋ 未出金残高 ＝ 受取総額
-- ------------------------------------------------------------
WITH target AS (
  SELECT u.user_id, u.email
  FROM users u
  WHERE u.email IN (
    'daiya2020aiko@gmail.com',
    'mayumi19591207@icloud.com',
    'mie123mie54321@gmail.com',
    'ken.atae727@gmail.com',
    'yarenshanxia901@gmail.com'
  )
),
counts AS (
  SELECT
    t.user_id, t.email,
    COUNT(*) FILTER (WHERE nm.nft_type = 'manual') AS manual_count,
    COUNT(*) FILTER (WHERE nm.nft_type = 'auto')   AS auto_count
  FROM target t
  LEFT JOIN nft_master nm
    ON nm.user_id = t.user_id AND nm.buyback_date IS NULL
  GROUP BY t.user_id, t.email
)
SELECT
  c.email,
  c.user_id,
  c.manual_count                                  AS 手動購入NFT,
  c.auto_count                                    AS 自動付与NFT,
  b.daily_profit                                  AS 累計日利,
  b.referral_profit                               AS 累計紹介報酬,
  b.total_profit                                  AS 累計利益,
  b.profit_per_nft                                AS 一枚あたり利益,
  b.manual_buyback                                AS 手動分買取額,
  b.auto_buyback                                  AS 自動分買取額,
  b.total_buyback                                 AS 買取金額,
  ROUND(COALESCE(ac.available_usdt, 0)::numeric, 2) AS 未出金残高,
  ROUND((b.total_buyback + COALESCE(ac.available_usdt, 0))::numeric, 2) AS 受取総額
FROM counts c
LEFT JOIN affiliate_cycle ac ON ac.user_id = c.user_id
CROSS JOIN LATERAL calculate_user_buyback_amount(c.user_id, c.manual_count::int, c.auto_count::int) b
WHERE c.manual_count + c.auto_count > 0
ORDER BY c.email;


-- ------------------------------------------------------------
-- 【3】NFTの内訳（1枚ずつ）
-- ------------------------------------------------------------
SELECT
  u.email, nm.user_id,
  nm.nft_sequence         AS 通番,
  nm.nft_type             AS 種別,
  nm.acquired_date        AS 取得日,
  nm.operation_start_date AS 運用開始日,
  nm.is_pegasus           AS ペガサスNFT,
  ROUND(COALESCE((SELECT SUM(ndp.daily_profit) FROM nft_daily_profit ndp
                   WHERE ndp.nft_id = nm.id), 0)::numeric, 2) AS このNFTの累計日利
FROM nft_master nm
JOIN users u ON u.user_id = nm.user_id
WHERE u.email IN (
  'daiya2020aiko@gmail.com','mayumi19591207@icloud.com','mie123mie54321@gmail.com',
  'ken.atae727@gmail.com','yarenshanxia901@gmail.com'
)
  AND nm.buyback_date IS NULL
ORDER BY u.email, nm.nft_sequence;


-- ------------------------------------------------------------
-- 【4】未出金の月末出金レコード（解約とは別に受け取る分）
-- ------------------------------------------------------------
SELECT
  u.email, mw.user_id,
  mw.withdrawal_month  AS 対象月,
  mw.status,
  ROUND(mw.total_amount::numeric, 2)    AS 出金額,
  ROUND(mw.personal_amount::numeric, 2) AS 個人利益,
  ROUND(mw.referral_amount::numeric, 2) AS 紹介報酬,
  mw.notes
FROM monthly_withdrawals mw
JOIN users u ON u.user_id = mw.user_id
WHERE u.email IN (
  'daiya2020aiko@gmail.com','mayumi19591207@icloud.com','mie123mie54321@gmail.com',
  'ken.atae727@gmail.com','yarenshanxia901@gmail.com'
)
  AND mw.status <> 'completed'
ORDER BY u.email, mw.withdrawal_month;
