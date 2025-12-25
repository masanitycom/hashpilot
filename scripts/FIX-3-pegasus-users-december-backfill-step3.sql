-- ========================================
-- 3ユーザーの12月補填処理 STEP 3-4
-- 個人利益のみ（紹介報酬は月末締めなので待機）
-- ========================================

-- ★★★ STEP 3: affiliate_cycle を更新（個人利益のみ）★★★
-- 3ユーザーの個人利益: 各 $11.54

UPDATE affiliate_cycle
SET 
  available_usdt = available_usdt + 11.54,
  last_updated = NOW()
WHERE user_id IN ('225F87', '20248A', '5A708D');

SELECT 'STEP 3: affiliate_cycle更新完了（個人利益のみ）' as status;

-- ★★★ STEP 4: 結果確認 ★★★
SELECT 'STEP 4: 最終確認' as status;

SELECT
  ac.user_id,
  u.email,
  ac.available_usdt,
  ac.cum_usdt,
  ac.phase
FROM affiliate_cycle ac
JOIN users u ON ac.user_id = u.user_id
WHERE ac.user_id IN ('225F87', '20248A', '5A708D')
ORDER BY ac.user_id;

-- 補填サマリー
SELECT '=== 補填サマリー ===' as info;
SELECT 
  user_id,
  COUNT(*) as days,
  SUM(daily_profit) as total_personal_profit
FROM nft_daily_profit
WHERE user_id IN ('225F87', '20248A', '5A708D')
  AND date >= '2025-12-01' AND date <= '2025-12-23'
GROUP BY user_id;

-- 注意事項
SELECT '=== 注意 ===' as info;
SELECT '紹介報酬は月末締め（12/31）のため、月次処理で自動計算されます' as note;
SELECT '今後の日利処理では、is_pegasus_exchange=false なので自動的に対象になります' as note;
