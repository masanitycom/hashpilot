-- ============================================================
-- 代理での解約（買取）申請作成 — 5名分
--
-- 経緯: 本人が高齢で画面操作ができないため、事務が代行して申請を作成する
-- 実行日: 2026-09-05
--
-- ⚠️⚠️ 実行前に必ず確認すること ⚠️⚠️
--   1. 送金先アドレスを本人に確認したか
--      → 下記に入れてあるのは users.nft_receive_address（NFT受取用アドレス）。
--        買取代金(USDT)の受取先として本人が指定したものではない。
--        送金は取り消せない。確認が取れるまで実行しないこと。
--   2. CoinW宛に送金する運用なら、アドレスではなくCoinW UIDを使う可能性がある。
--      事務がどちらで送金しているか確認すること。
--   3. 申請日の翌日から日利が停止する（2026-09-05申請なら9/6から停止）
--
-- 2026-09-05時点の試算:
--   6151EB daiya2020aiko@gmail.com    買取 $976.23 + 残高 $11.81 = $988.04
--   17E340 mayumi19591207@icloud.com  買取 $971.08 + 残高 $14.09 = $985.17
--   21721A ken.atae727@gmail.com      買取 $918.22 + 残高 $11.81 = $930.03
--   40B221 mie123mie54321@gmail.com   買取 $918.22 + 残高 $11.81 = $930.03
--   FB9CDC yarenshanxia901@gmail.com  買取 $877.87 + 残高 $19.79 = $897.66
--   合計 $4,730.93（買取 $4,661.62 + 未出金残高 $69.31）
--   ※ 買取金額は累計利益で変わるため、実行日が変われば金額も変わる
-- ============================================================


-- ------------------------------------------------------------
-- 【事前】重複申請がないことの再確認（5件とも0であること）
-- ------------------------------------------------------------
SELECT u.user_id, u.email,
       COUNT(br.id) FILTER (WHERE br.status = 'pending') AS 既存のpending申請
FROM users u
LEFT JOIN buyback_requests br ON br.user_id = u.user_id
WHERE u.user_id IN ('6151EB','17E340','21721A','40B221','FB9CDC')
GROUP BY u.user_id, u.email
ORDER BY u.email;


-- ============================================================
-- 本処理
--   ★ p_wallet_address は本人確認後に必要なら書き換えること ★
--   ★ p_transaction_id は備考欄。代理申請の記録として必須 ★
-- ============================================================

-- daiya2020aiko@gmail.com
SELECT * FROM create_buyback_request(
  '6151EB', 1, 0,
  '0x453BdF3061Df225fBeC178cb1879D4d7438f271c',
  'USDT-BEP20',
  '代理申請：本人が高齢で画面操作不可のため事務が代行（2026-09-05）'
);

-- mayumi19591207@icloud.com
SELECT * FROM create_buyback_request(
  '17E340', 1, 0,
  '0x3f9888ac52EAd0831f22aD51587A7a69DD32EC79',
  'USDT-BEP20',
  '代理申請：本人が高齢で画面操作不可のため事務が代行（2026-09-05）'
);

-- ken.atae727@gmail.com
SELECT * FROM create_buyback_request(
  '21721A', 1, 0,
  '0xe0d3BE1CB500F431Cd35c744ABbdefa9417aE195',
  'USDT-BEP20',
  '代理申請：本人が高齢で画面操作不可のため事務が代行（2026-09-05）'
);

-- mie123mie54321@gmail.com
SELECT * FROM create_buyback_request(
  '40B221', 1, 0,
  '0xdA9f24ff3A4Ecc6285dE6DaAbf50fc34D784809A',
  'USDT-BEP20',
  '代理申請：本人が高齢で画面操作不可のため事務が代行（2026-09-05）'
);

-- yarenshanxia901@gmail.com
SELECT * FROM create_buyback_request(
  'FB9CDC', 1, 0,
  '0x36D268f170c294c846fB735d1d02a57AE8B85353',
  'USDT-BEP20',
  '代理申請：本人が高齢で画面操作不可のため事務が代行（2026-09-05）'
);


-- ------------------------------------------------------------
-- 【事後確認】作成された申請の内容と金額
--   total_buyback_amount が上記の試算と一致すること
-- ------------------------------------------------------------
SELECT
  u.email, br.user_id,
  (br.request_date AT TIME ZONE 'Asia/Tokyo')::date AS 申請日,
  br.status,
  br.manual_nft_count AS 手動枚数,
  br.auto_nft_count   AS 自動枚数,
  ROUND(br.total_buyback_amount::numeric, 2) AS 買取金額,
  br.wallet_type, br.wallet_address,
  br.transaction_id   AS 備考
FROM buyback_requests br
JOIN users u ON u.user_id = br.user_id
WHERE br.user_id IN ('6151EB','17E340','21721A','40B221','FB9CDC')
ORDER BY u.email;

-- 合計（$4,661.62 になるはず）
SELECT ROUND(SUM(total_buyback_amount)::numeric, 2) AS 買取金額合計
FROM buyback_requests
WHERE user_id IN ('6151EB','17E340','21721A','40B221','FB9CDC')
  AND status = 'pending';
