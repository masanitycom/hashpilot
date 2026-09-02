-- ============================================================
-- 8月分 出金レコードから 7月分の混入を除去する
--
-- 背景:
--   7月分を8月頭に実送金したが「完了済みにする」を実行し忘れ、
--   available_usdt から7月分が引かれないまま 9/1 に 8/31 の日利を投入。
--   月末処理が自動実行され、8月分レコードに7月分が上乗せされた。
--
-- 方式: レコードの作り直しではなく「金額の上書き」
--   再作成すると新レコードが必ず on_hold / task_completed=false になり、
--   monthly_reward_tasks は ON CONFLICT DO NOTHING のため、
--   すでにタスク完了済みのユーザーがポップアップも出ず on_hold で詰む。
--
-- 前提: 9月の日利が未投入であること
--   → その場合、今の available_usdt は「8/31時点 − 7月送金分」と一致し、
--     そのまま8月分の正しい total_amount になる。
--
-- ★実行順序★
--   1. 事務が7月分の実送金分を「完了済みにする」
--   2. STEP 0 の前提チェック（自動で止まる）
--   3. STEP 1〜4 を実行
--   4. STEP 5 の検証
--
-- 実行日: 2026-09-02
--
-- 【実測値 2026-09-02 / 7月分の完了処理 実施後】
--   7月分: completed 428件 $14,786.89（事務の実送金額と一致）
--          未送金の繰越 pending 3件 $513.22 / on_hold 3件 $643.48（計 $1,156.70）
--   8月分: 434件 $30,222.63（2026-09-01 07:37:07 に自動作成）
--   9月の日利: 0件
--
--   恒等式の成立を確認済み:
--     $30,222.63 − $14,786.89 = $15,435.74 = 対象者の available_usdt 合計
--   → ★修正後の8月分合計は $15,435.74 になる★
--
--   既知の例外: A30CB1 は available_usdt = -$25.12（今回の処理とは無関係の既存ズレ）
--               → 8月分は $0 になる。別途調査。
-- ============================================================


-- ============================================================
-- STEP 0: 前提チェック（条件を満たさなければ例外で停止）
-- ============================================================
DO $$
DECLARE
    v_sep_profit   INTEGER;
    v_aug_total    NUMERIC;
    v_jul_done     NUMERIC;
    v_balance      NUMERIC;
    v_gap          NUMERIC;
    v_jul_pending  INTEGER;
    v_jul_on_hold  INTEGER;
BEGIN
    -- 9月の日利が入っていたら止める（available_usdt が8/31時点とズレる）
    SELECT COUNT(*) INTO v_sep_profit
    FROM nft_daily_profit WHERE date >= '2026-09-01';

    IF v_sep_profit > 0 THEN
        RAISE EXCEPTION '❌ 9月の日利が既に%件投入されています。このスクリプトは使えません（要相談）。', v_sep_profit;
    END IF;

    -- 恒等式チェック:
    --   8月レコード合計 − 7月完了額 = 対象者の available_usdt 合計
    -- これが成立していれば「total_amount を available_usdt で上書き」が正しい。
    SELECT COALESCE(SUM(total_amount), 0) INTO v_aug_total
    FROM monthly_withdrawals WHERE withdrawal_month = '2026-08-01';

    SELECT COALESCE(SUM(total_amount), 0) INTO v_jul_done
    FROM monthly_withdrawals
    WHERE withdrawal_month = '2026-07-01' AND status = 'completed';

    SELECT COALESCE(SUM(GREATEST(0, ac.available_usdt)), 0) INTO v_balance
    FROM affiliate_cycle ac
    WHERE EXISTS (SELECT 1 FROM monthly_withdrawals mw
                   WHERE mw.user_id = ac.user_id
                     AND mw.withdrawal_month = '2026-08-01');

    v_gap := ABS((v_aug_total - v_jul_done) - v_balance);

    IF v_gap > 1.00 THEN
        RAISE EXCEPTION
          '❌ 恒等式が成立しません。8月合計 $% − 7月完了額 $% = $% ですが、対象者残高合計は $% です（差 $%）。修正方針の見直しが必要です。',
          ROUND(v_aug_total,2), ROUND(v_jul_done,2),
          ROUND(v_aug_total - v_jul_done,2), ROUND(v_balance,2), ROUND(v_gap,2);
    END IF;

    -- 7月分の未完了は「実際に送金しなかった分」なので残っていて正常。
    -- 繰越として8月分に含まれる。件数を表示するだけで止めない。
    SELECT COUNT(*) INTO v_jul_pending
    FROM monthly_withdrawals WHERE withdrawal_month = '2026-07-01' AND status = 'pending';
    SELECT COUNT(*) INTO v_jul_on_hold
    FROM monthly_withdrawals WHERE withdrawal_month = '2026-07-01' AND status = 'on_hold';

    RAISE NOTICE '✅ 前提チェックOK';
    RAISE NOTICE '   7月完了額: $%  / 未送金の繰越: pending %件, on_hold %件',
                 ROUND(v_jul_done,2), v_jul_pending, v_jul_on_hold;
    RAISE NOTICE '   8月分は $% → $% に修正されます',
                 ROUND(v_aug_total,2), ROUND(v_balance,2);
END $$;


-- ============================================================
-- STEP 1: 8月分レコードをバックアップ
-- ============================================================
DROP TABLE IF EXISTS backup_monthly_withdrawals_202608;

CREATE TABLE backup_monthly_withdrawals_202608 AS
SELECT * FROM monthly_withdrawals
WHERE withdrawal_month = '2026-08-01';

SELECT COUNT(*) AS バックアップ件数,
       ROUND(SUM(total_amount)::numeric, 2) AS バックアップ合計
FROM backup_monthly_withdrawals_202608;


-- ============================================================
-- STEP 2: 修正前後の比較（★UPDATE前に必ず目視★）
--   差額 = 除去される7月分の混入額
-- ============================================================
SELECT
  mw.user_id,
  mw.status,
  ROUND(mw.total_amount::numeric, 2)      AS 現在の八月total,
  ROUND(GREATEST(0, ac.available_usdt)::numeric, 2) AS 修正後total,
  ROUND((mw.total_amount - GREATEST(0, ac.available_usdt))::numeric, 2) AS 除去額,
  ROUND(jul.total_amount::numeric, 2)     AS 参考_七月total,
  jul.status                              AS 参考_七月status
FROM monthly_withdrawals mw
JOIN affiliate_cycle ac ON ac.user_id = mw.user_id
LEFT JOIN monthly_withdrawals jul
       ON jul.user_id = mw.user_id AND jul.withdrawal_month = '2026-07-01'
WHERE mw.withdrawal_month = '2026-08-01'
ORDER BY (mw.total_amount - GREATEST(0, ac.available_usdt)) DESC
LIMIT 50;

-- 全体サマリ
SELECT
  COUNT(*)                                                            AS 対象件数,
  ROUND(SUM(mw.total_amount)::numeric, 2)                             AS 修正前合計,
  ROUND(SUM(GREATEST(0, ac.available_usdt))::numeric, 2)              AS 修正後合計,
  ROUND(SUM(mw.total_amount - GREATEST(0, ac.available_usdt))::numeric, 2) AS 除去額合計
FROM monthly_withdrawals mw
JOIN affiliate_cycle ac ON ac.user_id = mw.user_id
WHERE mw.withdrawal_month = '2026-08-01';

-- 修正後 $0 になるユーザー（8月の利益が0で、7月分だけが乗っていた人）
--   → 送金対象なし。レコードは残して翌月に繰り越す（ステータスは変えない）
SELECT COUNT(*) AS 修正後ゼロ件数
FROM monthly_withdrawals mw
JOIN affiliate_cycle ac ON ac.user_id = mw.user_id
WHERE mw.withdrawal_month = '2026-08-01'
  AND GREATEST(0, ac.available_usdt) < 0.01;

-- referral_amount が修正後 total を超えるユーザー（LEAST で丸められる）
SELECT mw.user_id,
       ROUND(mw.referral_amount::numeric, 2) AS 現在の紹介報酬,
       ROUND(GREATEST(0, ac.available_usdt)::numeric, 2) AS 修正後total
FROM monthly_withdrawals mw
JOIN affiliate_cycle ac ON ac.user_id = mw.user_id
WHERE mw.withdrawal_month = '2026-08-01'
  AND mw.referral_amount > GREATEST(0, ac.available_usdt)
ORDER BY mw.referral_amount DESC;

-- 要注意: available_usdt がマイナス（write-offユーザー等）→ 修正後 $0 になる
SELECT mw.user_id, mw.status,
       ROUND(mw.total_amount::numeric, 2) AS 現在の八月total,
       ROUND(ac.available_usdt::numeric, 2) AS available_usdt
FROM monthly_withdrawals mw
JOIN affiliate_cycle ac ON ac.user_id = mw.user_id
WHERE mw.withdrawal_month = '2026-08-01'
  AND ac.available_usdt <= 0
ORDER BY ac.available_usdt;


-- ============================================================
-- STEP 3: 本処理（total_amount と referral_amount を上書き）
--   ※ STEP 2 の内容を確認してから実行すること
-- ============================================================
BEGIN;

UPDATE monthly_withdrawals mw
SET
    -- 出金額 = 今の available_usdt 全額（7月分減算後）
    total_amount = ROUND(GREATEST(0, ac.available_usdt)::numeric, 2),

    -- 紹介報酬の内訳を CLAUDE.md の4パターン式で再計算
    -- （7月分の withdrawn_referral_usdt 反映後の値で計算される）
    referral_amount = LEAST(
        ROUND(GREATEST(0, ac.available_usdt)::numeric, 2),
        CASE
            WHEN ac.auto_nft_count > 0 THEN
                CASE
                    WHEN ac.phase = 'USDT' THEN ROUND(GREATEST(0, ac.cum_usdt)::numeric, 2)
                    WHEN ac.phase = 'HOLD' THEN ROUND(GREATEST(0, ac.cum_usdt - 1100)::numeric, 2)
                    ELSE 0
                END
            ELSE
                CASE
                    WHEN ac.phase = 'USDT' THEN ROUND(GREATEST(0, ac.cum_usdt - COALESCE(ac.withdrawn_referral_usdt, 0))::numeric, 2)
                    WHEN ac.phase = 'HOLD' THEN ROUND(GREATEST(0, 1100 - COALESCE(ac.withdrawn_referral_usdt, 0))::numeric, 2)
                    ELSE 0
                END
        END
    ),

    notes = COALESCE(NULLIF(mw.notes, ''), '')
            || CASE WHEN COALESCE(mw.notes, '') <> '' THEN ' | ' ELSE '' END
            || '2026-09-02 7月分完了処理漏れによる混入を除去（修正前 $'
            || ROUND(mw.total_amount::numeric, 2) || '）',

    updated_at = NOW()
FROM affiliate_cycle ac
WHERE mw.user_id = ac.user_id
  AND mw.withdrawal_month = '2026-08-01'
  AND mw.status IN ('pending', 'on_hold');

COMMIT;


-- ============================================================
-- STEP 4: personal_amount の整合（表示用の内訳。total を超えないよう調整）
-- ============================================================
UPDATE monthly_withdrawals mw
SET personal_amount = LEAST(mw.personal_amount, mw.total_amount),
    updated_at = NOW()
WHERE mw.withdrawal_month = '2026-08-01'
  AND mw.personal_amount > mw.total_amount;


-- ============================================================
-- STEP 5: 検証
-- ============================================================
-- 5-1) 8月分の合計が available_usdt 合計と一致するか
SELECT
  (SELECT ROUND(SUM(total_amount)::numeric, 2)
     FROM monthly_withdrawals WHERE withdrawal_month = '2026-08-01')          AS 八月レコード合計,
  (SELECT ROUND(SUM(GREATEST(0, available_usdt))::numeric, 2)
     FROM affiliate_cycle ac
     WHERE EXISTS (SELECT 1 FROM monthly_withdrawals mw
                    WHERE mw.user_id = ac.user_id
                      AND mw.withdrawal_month = '2026-08-01'))                AS 対象者残高合計;

-- 5-2) ステータス別サマリ（件数・金額が想定内か）
SELECT status, COUNT(*) AS 件数, ROUND(SUM(total_amount)::numeric, 2) AS 合計額
FROM monthly_withdrawals
WHERE withdrawal_month = '2026-08-01'
GROUP BY status ORDER BY status;

-- 5-3) 7月分が全件クローズされたか
SELECT status, COUNT(*) AS 件数, ROUND(SUM(total_amount)::numeric, 2) AS 合計額
FROM monthly_withdrawals
WHERE withdrawal_month = '2026-07-01'
GROUP BY status ORDER BY status;

-- 5-4) 整合性チェック
SELECT * FROM check_monthly_integrity(2026, 8);
-- ※ Check 3 (available_usdt整合性) の既知NGユーザーは無視してよい:
--    0E9C6C, 39CD6D, D3E589, CB4F3A, C92A91, 177B83, 2F6364, 59C23C, CA7902


-- ============================================================
-- 【ロールバック】STEP 3/4 を取り消す場合
-- ============================================================
-- UPDATE monthly_withdrawals mw
-- SET total_amount    = b.total_amount,
--     personal_amount = b.personal_amount,
--     referral_amount = b.referral_amount,
--     notes           = b.notes,
--     updated_at      = NOW()
-- FROM backup_monthly_withdrawals_202608 b
-- WHERE mw.id = b.id;
