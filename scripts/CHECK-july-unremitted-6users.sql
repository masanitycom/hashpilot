-- ============================================================
-- 7月分で送金されなかった6件（$1,156.70）の理由を確認する
-- pending 3件 $513.22 / on_hold 3件 $643.48
-- 実行日: 2026-09-02
-- ============================================================

SELECT
  mw.user_id,
  u.email,
  mw.status,
  ROUND(mw.total_amount::numeric, 2)      AS 七月出金額,
  mw.withdrawal_method,
  mw.withdrawal_address,
  u.coinw_uid,
  u.channel_linked_confirmed              AS CH紐付け確認,
  u.is_active_investor                    AS アクティブ,
  mw.task_completed                       AS タスク完了,
  mw.notes,
  ROUND(ac.available_usdt::numeric, 2)    AS 現在残高,
  ROUND(aug.total_amount::numeric, 2)     AS 八月レコード額
FROM monthly_withdrawals mw
JOIN users u            ON u.user_id = mw.user_id
LEFT JOIN affiliate_cycle ac ON ac.user_id = mw.user_id
LEFT JOIN monthly_withdrawals aug
       ON aug.user_id = mw.user_id AND aug.withdrawal_month = '2026-08-01'
WHERE mw.withdrawal_month = '2026-07-01'
  AND mw.status IN ('pending', 'on_hold')
ORDER BY mw.status, mw.total_amount DESC;


-- ------------------------------------------------------------
-- 【対応案】送金しなかった理由が確定したら、pending の3件は
--   on_hold に落として notes に理由を残す。
--   → 実態（未送金・翌月繰越）と一致し、
--     新設の「送金完了処理が未実施です」警告の誤検知も防げる。
--   ※ 金額は available_usdt に残ったままなので8月分に繰り越される（減算しない）
-- ------------------------------------------------------------
-- UPDATE monthly_withdrawals
-- SET status = 'on_hold',
--     notes = COALESCE(NULLIF(notes, ''), '')
--             || CASE WHEN COALESCE(notes,'') <> '' THEN ' | ' ELSE '' END
--             || '2026年8月頭の送金対象外（理由: XXXX）のため8月分に繰越',
--     updated_at = NOW()
-- WHERE withdrawal_month = '2026-07-01'
--   AND status = 'pending';
