-- ============================================================
-- 7月分で送金しなかった6名に繰越理由を記録する
--
-- 理由: 全員 CoinW UID が未設定、またはUIDではない値が入っており送金不可
--   361CF6 / YBVQ9D / 2C44D5 : coinw_uid = NULL（送金先なし）
--   E28F37                    : coinw_uid = 'Yu523840326.com'
--   28DC01                    : coinw_uid = 'E9557E'
--   8D01EC                    : coinw_uid = 'investmentffg@gmail.com'
--   ※ 6名とも channel_linked_confirmed = false
--
-- 効果:
--   1. 実態（未送金・8月分に繰越）とデータが一致する
--   2. pending の3件を on_hold に揃える
--   3. 新設の「送金完了処理が未実施です」警告から除外される
--      （警告は notes 未記載の未清算レコードのみを検知する）
--
-- 注意: available_usdt は減算しない。金額は8月分に繰り越し済み。
-- 実行日: 2026-09-02
-- ============================================================

-- 実行前の確認
SELECT user_id, status, ROUND(total_amount::numeric, 2) AS 出金額, notes
FROM monthly_withdrawals
WHERE withdrawal_month = '2026-07-01'
  AND status IN ('pending', 'on_hold')
ORDER BY status, total_amount DESC;


BEGIN;

UPDATE monthly_withdrawals
SET
    status = 'on_hold',
    notes = COALESCE(NULLIF(notes, ''), '')
            || CASE WHEN COALESCE(notes, '') <> '' THEN ' | ' ELSE '' END
            || 'CoinW UID未設定または不正のため2026年8月頭の送金対象外。8月分に繰越',
    updated_at = NOW()
WHERE withdrawal_month = '2026-07-01'
  AND status IN ('pending', 'on_hold');

COMMIT;


-- 実行後の確認（6件すべて on_hold ＋ notes 付きになる）
SELECT user_id, status, ROUND(total_amount::numeric, 2) AS 出金額, notes
FROM monthly_withdrawals
WHERE withdrawal_month = '2026-07-01'
  AND status <> 'completed'
ORDER BY total_amount DESC;

-- 7月分の最終状態
SELECT status, COUNT(*) AS 件数, ROUND(SUM(total_amount)::numeric, 2) AS 合計額
FROM monthly_withdrawals
WHERE withdrawal_month = '2026-07-01'
GROUP BY status ORDER BY status;
