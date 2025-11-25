-- ========================================
-- ユーザー6764B9の詳細確認（本番環境用・スキーマ対応版）
-- ========================================

-- 1. ユーザー基本情報
SELECT
    '1. ユーザー基本情報（6764B9）' as section,
    u.user_id,
    u.email,
    u.total_purchases,
    u.operation_start_date,
    u.has_approved_nft,
    u.is_pegasus_exchange,
    u.created_at,
    CASE
        WHEN u.operation_start_date IS NULL THEN '❌ 運用開始日未設定'
        WHEN u.operation_start_date > CURRENT_DATE THEN '⏳ 運用開始前'
        ELSE '✅ 運用中'
    END as 運用ステータス
FROM users u
WHERE u.user_id = '6764B9';

-- 2. NFT保有状況
SELECT
    '2. NFT保有状況（6764B9）' as section,
    nm.id,
    nm.nft_sequence,
    nm.nft_type,
    nm.acquired_date,
    nm.nft_value,
    nm.buyback_date,
    nm.created_at,
    CASE
        WHEN nm.buyback_date IS NULL THEN '✅ 運用中'
        ELSE '❌ 買い取り済み'
    END as status
FROM nft_master nm
WHERE nm.user_id = '6764B9'
ORDER BY nm.nft_sequence;

-- 3. affiliate_cycle（サイクル情報）
SELECT
    '3. サイクル情報（6764B9）' as section,
    ac.user_id,
    ac.total_nft_count,
    ac.manual_nft_count,
    ac.auto_nft_count,
    ac.cum_usdt as 累積USDT,
    ac.available_usdt as 確定USDT,
    ac.phase as フェーズ,
    ac.created_at,
    ac.updated_at,
    CASE
        WHEN ac.cum_usdt > 0 THEN '⚠️ 運用開始前なのにカウントあり'
        ELSE '✅ 正常（0）'
    END as 判定
FROM affiliate_cycle ac
WHERE ac.user_id = '6764B9';

-- 4. 紹介報酬履歴（本番環境用：level列なし）
SELECT
    '4. 紹介報酬履歴（6764B9）' as section,
    urp.date,
    urp.profit_amount,
    urp.created_at
FROM user_referral_profit urp
WHERE urp.user_id = '6764B9'
ORDER BY urp.date DESC;

-- 5. 紹介報酬の合計
SELECT
    '5. 紹介報酬合計（6764B9）' as section,
    COUNT(*) as レコード数,
    SUM(urp.profit_amount) as 合計額,
    MIN(urp.date) as 最初の日付,
    MAX(urp.date) as 最後の日付,
    (SELECT cum_usdt FROM affiliate_cycle WHERE user_id = '6764B9') as affiliate_cycle累積,
    CASE
        WHEN SUM(urp.profit_amount) > 0 THEN '⚠️ 運用開始前なのに報酬あり'
        ELSE '✅ 正常'
    END as 判定
FROM user_referral_profit urp
WHERE urp.user_id = '6764B9';

-- 6. 個人利益履歴（念のため）
SELECT
    '6. 個人利益履歴（6764B9）' as section,
    udp.date,
    udp.daily_profit,
    udp.yield_rate
FROM user_daily_profit udp
WHERE udp.user_id = '6764B9'
ORDER BY udp.date DESC
LIMIT 10;

-- 7. purchasesテーブルの状況
SELECT
    '7. NFT購入履歴（6764B9）' as section,
    p.id,
    p.amount_usd,
    p.coinw_uid,
    p.admin_approved,
    p.admin_approved_at,
    p.is_auto_purchase,
    p.created_at
FROM purchases p
WHERE p.user_id = '6764B9'
ORDER BY p.created_at DESC;

-- 8. 紹介者（このユーザーが紹介した人）
SELECT
    '8. 紹介者リスト（6764B9が紹介した人）' as section,
    u.user_id,
    u.email,
    u.total_purchases,
    u.operation_start_date,
    CASE
        WHEN u.operation_start_date IS NOT NULL AND u.operation_start_date <= CURRENT_DATE
        THEN '✅ 運用中'
        WHEN u.operation_start_date IS NULL
        THEN '❌ 未設定'
        ELSE '⏳ 運用開始前'
    END as 紹介者の運用ステータス,
    CASE
        WHEN u.operation_start_date IS NOT NULL AND u.operation_start_date <= CURRENT_DATE
        THEN FLOOR(u.total_purchases / 1100) * 1000
        ELSE 0
    END as 運用中投資額
FROM users u
WHERE u.referrer_user_id = '6764B9'
ORDER BY u.created_at DESC;

-- 9. 環境確認
SELECT
    '9. 環境確認' as section,
    CURRENT_DATABASE() as データベース名,
    CURRENT_DATE as 今日の日付,
    (SELECT COUNT(*) FROM users WHERE operation_start_date IS NULL OR operation_start_date > CURRENT_DATE) as 運用開始前ユーザー数,
    (SELECT COUNT(*) FROM affiliate_cycle WHERE cum_usdt > 0) as cum_usdtがプラスのユーザー数,
    (SELECT COUNT(*)
     FROM users u
     JOIN affiliate_cycle ac ON ac.user_id = u.user_id
     WHERE (u.operation_start_date IS NULL OR u.operation_start_date > CURRENT_DATE)
       AND ac.cum_usdt > 0) as 運用開始前でcum_usdtプラスのユーザー数;

-- 10. システム設定確認
SELECT
    '10. システム設定' as section,
    'process_daily_yield_v2 RPC関数が使われているか確認' as 確認項目,
    'user_referral_profitテーブルに最近のデータがあるか' as 確認方法,
    (SELECT MAX(date) FROM user_referral_profit) as 最終紹介報酬日付,
    (SELECT MAX(date) FROM daily_yield_log_v2) as 最終日利設定日付;

-- 11. user_referral_profitテーブルのスキーマ確認
SELECT
    '11. user_referral_profitテーブル構造' as section,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'user_referral_profit'
ORDER BY ordinal_position;
