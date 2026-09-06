-- ============================================================
-- E28F37（yuzuki.aoi523840326@gmail.com）の代理解約申請
-- 申請日を 2026-09-05 付けにする
--
-- 経緯: 2026-09-05 に実施した高齢者5名の代理申請から漏れていた
-- 実行日: 2026-09-06
--
-- ※ 申請日を9/5にすると 9/5分の日利までは配布され、9/6分から停止する
--   （process_daily_yield_v2 は「申請日 < 日利の日付」で除外する）
-- ============================================================


-- ------------------------------------------------------------
-- 【1】事前確認
--   ・NFT枚数（手動/自動）
--   ・既存の買取申請がないこと
--   ・送金先に使えるアドレス
-- ------------------------------------------------------------
SELECT
  u.user_id, u.email,
  u.has_approved_nft      AS NFT承認済,
  u.operation_start_date  AS 運用開始日,
  u.is_active_investor    AS アクティブ,
  u.is_pegasus_exchange   AS ペガサス,
  u.coinw_uid,
  u.nft_receive_address   AS NFT受取アドレス,
  u.channel_linked_confirmed AS CH紐付け確認,
  COUNT(*) FILTER (WHERE nm.nft_type = 'manual' AND nm.buyback_date IS NULL) AS 手動NFT,
  COUNT(*) FILTER (WHERE nm.nft_type = 'auto'   AND nm.buyback_date IS NULL) AS 自動NFT,
  (SELECT COUNT(*) FROM buyback_requests br
    WHERE br.user_id = u.user_id AND br.status = 'pending')                  AS 既存の申請
FROM users u
LEFT JOIN nft_master nm ON nm.user_id = u.user_id
WHERE u.email = 'yuzuki.aoi523840326@gmail.com'
GROUP BY u.user_id, u.email, u.has_approved_nft, u.operation_start_date,
         u.is_active_investor, u.is_pegasus_exchange, u.coinw_uid,
         u.nft_receive_address, u.channel_linked_confirmed;

-- 解約した場合の金額（買取額 + 未出金残高）
WITH c AS (
  SELECT
    u.user_id,
    COUNT(*) FILTER (WHERE nm.nft_type = 'manual' AND nm.buyback_date IS NULL)::int AS m,
    COUNT(*) FILTER (WHERE nm.nft_type = 'auto'   AND nm.buyback_date IS NULL)::int AS a
  FROM users u
  LEFT JOIN nft_master nm ON nm.user_id = u.user_id
  WHERE u.email = 'yuzuki.aoi523840326@gmail.com'
  GROUP BY u.user_id
)
SELECT
  c.user_id, c.m AS 手動, c.a AS 自動,
  b.daily_profit    AS 累計日利,
  b.referral_profit AS 累計紹介報酬,
  b.total_buyback   AS 買取金額,
  ROUND(COALESCE(ac.available_usdt, 0)::numeric, 2) AS 未出金残高,
  ROUND((b.total_buyback + COALESCE(ac.available_usdt, 0))::numeric, 2) AS 受取総額
FROM c
LEFT JOIN affiliate_cycle ac ON ac.user_id = c.user_id
CROSS JOIN LATERAL calculate_user_buyback_amount(c.user_id, c.m, c.a) b;

-- 未出金の月末出金レコード（買取とは別に受け取る分）
SELECT withdrawal_month AS 対象月, status,
       ROUND(total_amount::numeric, 2) AS 出金額, notes
FROM monthly_withdrawals
WHERE user_id = 'E28F37' AND status <> 'completed'
ORDER BY withdrawal_month;


-- ============================================================
-- 【2】申請作成
--   ★ 手動/自動の枚数を【1】の結果に合わせること ★
--   ★ 送金先アドレスは本人確認後に差し替えること ★
--     このユーザーは coinw_uid に 'Yu523840326.com' という
--     UIDではない値が入っており、7月分も送金できていない。
--     アドレスは /admin/buyback から後で変更可能。
-- ============================================================
BEGIN;

SELECT * FROM create_buyback_request(
  'E28F37',
  1,          -- ← 手動NFT枚数（【1】の結果に合わせる）
  0,          -- ← 自動NFT枚数（【1】の結果に合わせる）
  '（NFT受取アドレスを【1】から転記）',
  'USDT-BEP20',
  '代理申請：本人が高齢で画面操作不可のため事務が代行。2026-09-05付け（9/5の5名分から漏れていたため後日登録）'
);

-- 申請日を 2026-09-05（日本時間）に補正する
--   日利の停止判定は request_date を日本時間の日付に変換して行うため、
--   JSTで9/5になる時刻を指定する
UPDATE buyback_requests
SET request_date = '2026-09-05 12:00:00+09'::timestamptz,
    created_at   = '2026-09-05 12:00:00+09'::timestamptz,
    updated_at   = NOW()
WHERE user_id = 'E28F37'
  AND status = 'pending'
  AND id = (SELECT id FROM buyback_requests
            WHERE user_id = 'E28F37' AND status = 'pending'
            ORDER BY created_at DESC LIMIT 1);

COMMIT;


-- ============================================================
-- 【3】事後確認
-- ============================================================
SELECT
  br.id, br.user_id, u.email,
  (br.request_date AT TIME ZONE 'Asia/Tokyo')::date AS 申請日_JST,
  br.status,
  br.manual_nft_count AS 手動, br.auto_nft_count AS 自動,
  ROUND(br.total_buyback_amount::numeric, 2) AS 買取金額,
  br.wallet_type, br.wallet_address,
  br.transaction_id AS 備考
FROM buyback_requests br
JOIN users u ON u.user_id = br.user_id
WHERE br.user_id = 'E28F37';

-- 日利の停止確認: 9/5分は配布され、9/6分から止まる
SELECT ndp.date, COUNT(*) AS 枚数,
       ROUND(SUM(ndp.daily_profit)::numeric, 3) AS 受取額
FROM nft_daily_profit ndp
WHERE ndp.user_id = 'E28F37' AND ndp.date >= '2026-09-01'
GROUP BY ndp.date ORDER BY ndp.date;
