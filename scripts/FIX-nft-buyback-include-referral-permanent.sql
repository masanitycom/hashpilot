-- ============================================================
-- 買取金額に紹介報酬を反映する（恒久修正）
--
-- 事象:
--   calculate_nft_buyback_amount が個人収益（日利）のみで買取額を計算しており、
--   紹介報酬が控除されていなかった。
--   ユーザー画面（calculate_buyback_preview）も申請作成（create_buyback_request）も
--   この関数を呼ぶため、画面・記録ともに紹介報酬が引かれていない状態だった。
--
-- 修正:
--   1枚あたりの紹介報酬 = そのユーザーの累計紹介報酬 / 保有NFT枚数
--   を個人収益に加えてから買取額を計算する。
--
-- 計算式（変更なし。控除対象の利益に紹介報酬が加わるだけ）:
--   利益 >= 0 : 買取額 = 基本額 − 利益 / 2
--   利益 <  0 : 買取額 = 基本額 + 利益
--   基本額: 手動 $1,000 / 自動 $500 、下限 $0
--
-- この1関数を直せば画面表示と申請作成の両方に反映される。
-- 実行日: 2026-09-05
-- ============================================================

CREATE OR REPLACE FUNCTION calculate_nft_buyback_amount(p_nft_id UUID)
RETURNS DECIMAL(10,2) AS $$
DECLARE
    v_user_id TEXT;
    v_nft_type TEXT;
    v_base_value DECIMAL(10,2);
    v_personal_profit DECIMAL(10,3);
    v_referral_total DECIMAL(10,3);
    v_active_nft_count INTEGER;
    v_referral_share DECIMAL(10,3);
    v_total_profit DECIMAL(10,3);
    v_buyback_amount DECIMAL(10,2);
BEGIN
    -- NFT情報と個人収益（日利）を取得
    SELECT user_id, nft_type, COALESCE(total_profit_for_buyback, 0)
    INTO v_user_id, v_nft_type, v_personal_profit
    FROM nft_total_profit
    WHERE nft_id = p_nft_id;

    IF v_user_id IS NULL THEN
        RETURN 0;
    END IF;

    -- 基本額
    IF v_nft_type = 'manual' THEN
        v_base_value := 1000;
    ELSE
        v_base_value := 500;
    END IF;

    -- ▼▼▼ 追加: 紹介報酬を1枚あたりに按分して控除対象に加える ▼▼▼
    SELECT COALESCE(SUM(mrp.profit_amount), 0)
    INTO v_referral_total
    FROM monthly_referral_profit mrp
    WHERE mrp.user_id = v_user_id;

    SELECT GREATEST(COUNT(*), 1)
    INTO v_active_nft_count
    FROM nft_master nm
    WHERE nm.user_id = v_user_id AND nm.buyback_date IS NULL;

    v_referral_share := v_referral_total / v_active_nft_count;
    v_total_profit := v_personal_profit + v_referral_share;
    -- ▲▲▲ 追加ここまで ▲▲▲

    -- 買取額の計算（式は従来どおり）
    IF v_total_profit >= 0 THEN
        v_buyback_amount := v_base_value - (v_total_profit / 2);
    ELSE
        v_buyback_amount := v_base_value + v_total_profit;
    END IF;

    IF v_buyback_amount < 0 THEN
        v_buyback_amount := 0;
    END IF;

    RETURN v_buyback_amount;
END;
$$ LANGUAGE plpgsql;


-- ============================================================
-- 既存の pending 申請の金額を新しい計算で作り直す
--   ※ completed（送金済み）は変更しない
-- ============================================================

-- バックアップ
DROP TABLE IF EXISTS backup_buyback_requests_20260905;
CREATE TABLE backup_buyback_requests_20260905 AS
SELECT * FROM buyback_requests WHERE status = 'pending';

SELECT COUNT(*) AS バックアップ件数,
       ROUND(SUM(total_buyback_amount)::numeric, 2) AS 修正前合計
FROM backup_buyback_requests_20260905;


-- 修正前後の比較（★UPDATE前に確認★）
--   create_buyback_request と同じ方法（nft_sequence昇順で申請枚数分）で再計算
WITH recalc AS (
  SELECT
    br.id,
    COALESCE((
      SELECT SUM(calculate_nft_buyback_amount(x.id))
      FROM (SELECT nm.id FROM nft_master nm
            WHERE nm.user_id = br.user_id AND nm.nft_type = 'manual' AND nm.buyback_date IS NULL
            ORDER BY nm.nft_sequence ASC LIMIT br.manual_nft_count) x
    ), 0) AS new_manual,
    COALESCE((
      SELECT SUM(calculate_nft_buyback_amount(x.id))
      FROM (SELECT nm.id FROM nft_master nm
            WHERE nm.user_id = br.user_id AND nm.nft_type = 'auto' AND nm.buyback_date IS NULL
            ORDER BY nm.nft_sequence ASC LIMIT br.auto_nft_count) x
    ), 0) AS new_auto
  FROM buyback_requests br
  WHERE br.status = 'pending'
)
SELECT
  br.user_id, u.email,
  (br.request_date AT TIME ZONE 'Asia/Tokyo')::date AS 申請日,
  br.manual_nft_count AS 手動, br.auto_nft_count AS 自動,
  ROUND(br.total_buyback_amount::numeric, 2)          AS 修正前,
  ROUND((r.new_manual + r.new_auto)::numeric, 2)      AS 修正後,
  ROUND((br.total_buyback_amount - (r.new_manual + r.new_auto))::numeric, 2) AS 差額,
  ROUND(COALESCE((SELECT SUM(mrp.profit_amount) FROM monthly_referral_profit mrp
                   WHERE mrp.user_id = br.user_id), 0)::numeric, 2) AS 累計紹介報酬
FROM buyback_requests br
JOIN recalc r ON r.id = br.id
JOIN users u ON u.user_id = br.user_id
WHERE br.status = 'pending'
ORDER BY (br.total_buyback_amount - (r.new_manual + r.new_auto)) DESC;


-- 本処理
BEGIN;

WITH recalc AS (
  SELECT
    br.id,
    COALESCE((
      SELECT SUM(calculate_nft_buyback_amount(x.id))
      FROM (SELECT nm.id FROM nft_master nm
            WHERE nm.user_id = br.user_id AND nm.nft_type = 'manual' AND nm.buyback_date IS NULL
            ORDER BY nm.nft_sequence ASC LIMIT br.manual_nft_count) x
    ), 0) AS new_manual,
    COALESCE((
      SELECT SUM(calculate_nft_buyback_amount(x.id))
      FROM (SELECT nm.id FROM nft_master nm
            WHERE nm.user_id = br.user_id AND nm.nft_type = 'auto' AND nm.buyback_date IS NULL
            ORDER BY nm.nft_sequence ASC LIMIT br.auto_nft_count) x
    ), 0) AS new_auto
  FROM buyback_requests br
  WHERE br.status = 'pending'
)
UPDATE buyback_requests br
SET manual_buyback_amount = r.new_manual,
    auto_buyback_amount   = r.new_auto,
    total_buyback_amount  = r.new_manual + r.new_auto,
    updated_at            = NOW()
FROM recalc r
WHERE br.id = r.id;

COMMIT;


-- ============================================================
-- 検証
-- ============================================================
-- 1) 今日の5件
SELECT u.email, br.user_id,
       ROUND(br.total_buyback_amount::numeric, 2) AS 買取金額
FROM buyback_requests br
JOIN users u ON u.user_id = br.user_id
WHERE br.user_id IN ('6151EB','17E340','21721A','40B221','FB9CDC')
ORDER BY u.email;

-- 2) pending 全体の合計
SELECT COUNT(*) AS 件数, ROUND(SUM(total_buyback_amount)::numeric, 2) AS 修正後合計
FROM buyback_requests WHERE status = 'pending';

-- 3) 画面表示と記録が一致するか（0件なら一致）
SELECT COUNT(*) AS 不一致件数
FROM buyback_requests br
CROSS JOIN LATERAL calculate_buyback_preview(br.user_id, br.manual_nft_count, br.auto_nft_count) p
WHERE br.status = 'pending'
  AND ABS(br.total_buyback_amount - p.total_buyback_amount) > 0.01;


-- ============================================================
-- ロールバック
-- ============================================================
-- UPDATE buyback_requests br
-- SET manual_buyback_amount = b.manual_buyback_amount,
--     auto_buyback_amount   = b.auto_buyback_amount,
--     total_buyback_amount  = b.total_buyback_amount,
--     updated_at = NOW()
-- FROM backup_buyback_requests_20260905 b WHERE br.id = b.id;
--
-- ※ 関数を戻す場合は scripts/FIX-nft-buyback-minus-profit.sql を再実行
