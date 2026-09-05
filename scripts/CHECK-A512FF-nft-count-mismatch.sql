-- ============================================================
-- A512FF: NFT 8枚保有なのに6枚分の報酬しかない件の調査
-- 2026-08-17 に解約（買取）申請あり
-- 実行日: 2026-09-03
--
-- 日利がNFTを数える条件（process_daily_yield_v2）:
--   nm.buyback_date IS NULL
--   AND u.has_approved_nft = true
--   AND nm.operation_start_date IS NOT NULL
--   AND nm.operation_start_date <= 対象日
--   AND (u.is_pegasus_exchange = false OR IS NULL)
--   AND buyback_requests に status='pending' が存在しない  ← ユーザー単位で全枚数停止
--
-- ※ nft_daily_profit はNFT1枚につき1行入る
--   → 日付ごとの行数 = その日に配布対象になった枚数
-- ============================================================


-- ------------------------------------------------------------
-- 【1】ユーザー基本情報
-- ------------------------------------------------------------
SELECT
  user_id, email,
  has_approved_nft        AS NFT承認済,
  operation_start_date    AS ユーザーOSD,
  is_pegasus_exchange     AS ペガサス,
  is_active_investor      AS アクティブ,
  total_purchases         AS 購入累計,
  coinw_uid, channel_linked_confirmed
FROM users
WHERE user_id = 'A512FF';


-- ------------------------------------------------------------
-- 【2】★本命★ NFT 1枚ずつの状態と、日利対象になるかの判定
--   「対象外」の行が2枚あれば、それが今回の原因
-- ------------------------------------------------------------
SELECT
  nm.nft_sequence         AS 通番,
  nm.nft_type             AS 種別,
  nm.nft_value            AS 額面,
  nm.acquired_date        AS 取得日,
  nm.operation_start_date AS NFTのOSD,
  nm.buyback_date         AS 買取日,
  nm.is_pegasus           AS ペガサスNFT,
  CASE
    WHEN nm.buyback_date IS NOT NULL              THEN '対象外: 買取済み'
    WHEN nm.operation_start_date IS NULL          THEN '対象外: 運用開始日が未設定'
    WHEN nm.operation_start_date > CURRENT_DATE   THEN '対象外: 運用開始前（' || nm.operation_start_date || 'から）'
    ELSE '対象'
  END                     AS 日利判定
FROM nft_master nm
WHERE nm.user_id = 'A512FF'
ORDER BY nm.nft_sequence;

-- 枚数サマリ
SELECT
  COUNT(*)                                                            AS 保有総数,
  COUNT(*) FILTER (WHERE buyback_date IS NULL)                        AS 買取前,
  COUNT(*) FILTER (WHERE buyback_date IS NULL
                     AND operation_start_date IS NOT NULL
                     AND operation_start_date <= CURRENT_DATE)        AS 日利対象,
  COUNT(*) FILTER (WHERE operation_start_date IS NULL)                AS OSD未設定,
  COUNT(*) FILTER (WHERE operation_start_date > CURRENT_DATE)         AS 運用開始前,
  COUNT(*) FILTER (WHERE is_pegasus = true)                           AS ペガサスNFT
FROM nft_master
WHERE user_id = 'A512FF';


-- ------------------------------------------------------------
-- 【3】affiliate_cycle の枚数と nft_master の実数のズレ
-- ------------------------------------------------------------
SELECT
  ac.user_id,
  ac.manual_nft_count     AS 手動購入,
  ac.auto_nft_count       AS 自動付与,
  ac.total_nft_count      AS cycle上の合計,
  (SELECT COUNT(*) FROM nft_master WHERE user_id = 'A512FF' AND buyback_date IS NULL) AS nft_master実数,
  ac.available_usdt, ac.cum_usdt, ac.phase, ac.withdrawn_referral_usdt
FROM affiliate_cycle ac
WHERE ac.user_id = 'A512FF';


-- ------------------------------------------------------------
-- 【4】買取（解約）申請の状況
--   status='pending' が1件でもあると、その日以降 全枚数の日利が止まる
-- ------------------------------------------------------------
SELECT *
FROM buyback_requests
WHERE user_id = 'A512FF'
ORDER BY created_at DESC;


-- ------------------------------------------------------------
-- 【5】★決定的★ 日付ごとに実際に何枚分配られたか
--   行数 = その日の配布枚数。6行なら6枚分しか配られていない
-- ------------------------------------------------------------
SELECT
  ndp.date,
  COUNT(*)                                  AS 配布枚数,
  ROUND(SUM(ndp.daily_profit)::numeric, 3)  AS 合計利益,
  ROUND(MAX(ndp.daily_profit)::numeric, 3)  AS 一枚あたり,
  ROUND(dyl.profit_per_nft::numeric, 3)     AS 全体の一枚単価,
  CASE WHEN dyl.profit_per_nft IS NOT NULL AND dyl.profit_per_nft <> 0
       THEN ROUND((SUM(ndp.daily_profit) / dyl.profit_per_nft)::numeric, 2)
  END                                       AS 逆算した枚数
FROM nft_daily_profit ndp
LEFT JOIN daily_yield_log_v2 dyl ON dyl.date = ndp.date
WHERE ndp.user_id = 'A512FF'
  AND ndp.date >= '2026-07-01'
GROUP BY ndp.date, dyl.profit_per_nft
ORDER BY ndp.date;


-- ------------------------------------------------------------
-- 【6】どのNFTに配布され、どのNFTに配布されていないか（直近日）
-- ------------------------------------------------------------
SELECT
  nm.nft_sequence         AS 通番,
  nm.acquired_date        AS 取得日,
  nm.operation_start_date AS NFTのOSD,
  nm.buyback_date         AS 買取日,
  MAX(ndp.date)                             AS 最終配布日,
  COUNT(ndp.id)                             AS 配布日数,
  ROUND(SUM(ndp.daily_profit)::numeric, 2)  AS 累計利益
FROM nft_master nm
LEFT JOIN nft_daily_profit ndp
       ON ndp.nft_id = nm.id AND ndp.date >= '2026-07-01'
WHERE nm.user_id = 'A512FF'
GROUP BY nm.id, nm.nft_sequence, nm.acquired_date, nm.operation_start_date, nm.buyback_date
ORDER BY nm.nft_sequence;


-- ------------------------------------------------------------
-- 【7】購入履歴（承認日とNFT枚数の突き合わせ）
-- ------------------------------------------------------------
SELECT
  id, nft_quantity, amount_usd,
  admin_approved, admin_approved_at, is_auto_purchase, created_at
FROM purchases
WHERE user_id = 'A512FF'
ORDER BY created_at;
