-- ========================================
-- 11/11の日利データ整合性確認
-- ========================================

-- 1. 管理画面の11/11設定値
SELECT
    '1. 管理画面の11/11設定値' as section,
    date,
    total_profit_amount as 全体運用利益,
    total_nft_count as NFT数,
    profit_per_nft as 一NFTあたり,
    cumulative_gross_profit as 累積利益_手数料前,
    cumulative_fee as 累積手数料,
    cumulative_net_profit as 顧客累積利益,
    daily_pnl as 当日利益,
    distribution_dividend as 配当60パーセント,
    distribution_affiliate as アフィリ30パーセント,
    distribution_stock as ストック10パーセント
FROM daily_yield_log_v2
WHERE date = '2025-11-11';

-- 2. 計算の確認
WITH calc AS (
    SELECT
        total_profit_amount,
        total_nft_count,
        total_profit_amount / total_nft_count as 一NFTあたり利益,
        daily_pnl,
        distribution_dividend,
        distribution_dividend / total_nft_count as 一NFTあたり配当
    FROM daily_yield_log_v2
    WHERE date = '2025-11-11'
)
SELECT
    '2. 理論計算（11/11）' as section,
    total_profit_amount as 入力値,
    total_nft_count as NFT数,
    一NFTあたり利益,
    daily_pnl as ΔN_d当日利益,
    distribution_dividend as 配当総額,
    一NFTあたり配当 as 一NFTあたり配当,
    CASE
        WHEN 一NFTあたり配当 > 0 THEN '✅ プラス配当'
        ELSE '❌ 配当なし'
    END as status
FROM calc;

-- 3. 7A9637の実際の受取額（11/11）
SELECT
    '3. 7A9637の実際の受取額（11/11）' as section,
    user_id,
    date,
    nft_id,
    daily_profit as NFT日利,
    base_amount as 基準額,
    phase
FROM nft_daily_profit
WHERE user_id = '7A9637' AND date = '2025-11-11';

-- 4. 7A9637のuser_daily_profit VIEW（11/11）
SELECT
    '4. 7A9637のVIEW集計値（11/11）' as section,
    user_id,
    date,
    daily_profit as 集計日利,
    yield_rate,
    user_rate
FROM user_daily_profit
WHERE user_id = '7A9637' AND date = '2025-11-11';

-- 5. 理論値と実際の差異チェック
WITH theory AS (
    SELECT
        distribution_dividend / total_nft_count as 理論値_一NFTあたり
    FROM daily_yield_log_v2
    WHERE date = '2025-11-11'
),
actual AS (
    SELECT
        daily_profit as 実際値
    FROM user_daily_profit
    WHERE user_id = '7A9637' AND date = '2025-11-11'
)
SELECT
    '5. 理論値と実際値の比較' as section,
    t.理論値_一NFTあたり,
    a.実際値,
    ABS(t.理論値_一NFTあたり - COALESCE(a.実際値, 0)) as 差異,
    CASE
        WHEN ABS(t.理論値_一NFTあたり - COALESCE(a.実際値, 0)) < 0.01 THEN '✅ 一致'
        WHEN a.実際値 IS NULL THEN '❌ データなし'
        ELSE '⚠️ 差異あり'
    END as status
FROM theory t
CROSS JOIN actual a;

-- 6. 11/11の全ユーザーの配当合計（検証）
SELECT
    '6. 11/11の全ユーザー配当合計' as section,
    COUNT(DISTINCT user_id) as ユーザー数,
    SUM(daily_profit) as 配当合計,
    (SELECT distribution_dividend FROM daily_yield_log_v2 WHERE date = '2025-11-11') as 理論値,
    ABS(SUM(daily_profit) - (SELECT distribution_dividend FROM daily_yield_log_v2 WHERE date = '2025-11-11')) as 差異,
    CASE
        WHEN ABS(SUM(daily_profit) - (SELECT distribution_dividend FROM daily_yield_log_v2 WHERE date = '2025-11-11')) < 0.01
        THEN '✅ 一致'
        ELSE '⚠️ 差異あり'
    END as status
FROM user_daily_profit
WHERE date = '2025-11-11';

-- 7. 7A9637の最近3日分の利益推移
SELECT
    '7. 7A9637の利益推移（直近3日）' as section,
    date,
    daily_profit,
    (SELECT total_profit_amount FROM daily_yield_log_v2 dyl WHERE dyl.date = udp.date) as システム全体利益,
    (SELECT total_nft_count FROM daily_yield_log_v2 dyl WHERE dyl.date = udp.date) as NFT総数,
    (SELECT distribution_dividend FROM daily_yield_log_v2 dyl WHERE dyl.date = udp.date) as 配当総額
FROM user_daily_profit udp
WHERE user_id = '7A9637'
ORDER BY date DESC
LIMIT 3;

-- 8. ダッシュボード表示値の確認（昨日=11/11）
WITH yesterday AS (
    SELECT CURRENT_DATE - INTERVAL '1 day' as yesterday_date
)
SELECT
    '8. ダッシュボード表示値（昨日=11/11）' as section,
    y.yesterday_date as 昨日の日付,
    udp.daily_profit as 表示されるべき値,
    CASE
        WHEN udp.daily_profit IS NOT NULL THEN '✅ 表示される'
        ELSE '❌ 表示されない'
    END as DailyProfitCard,
    CASE
        WHEN udp.daily_profit IS NOT NULL THEN '✅ 表示される'
        ELSE '❌ 表示されない'
    END as PersonalProfitCard
FROM yesterday y
LEFT JOIN user_daily_profit udp ON udp.user_id = '7A9637' AND udp.date = y.yesterday_date;

-- 9. スクリーンショットの$1.372の検証
SELECT
    '9. スクリーンショット値の検証' as section,
    '$1.372がどの日付のデータか' as 説明,
    date,
    daily_profit,
    CASE
        WHEN ABS(daily_profit - 1.372) < 0.01 THEN '✅ これがスクショの値'
        ELSE ''
    END as match
FROM user_daily_profit
WHERE user_id = '7A9637'
    AND date >= '2025-11-01'
    AND ABS(daily_profit - 1.372) < 0.1
ORDER BY date DESC;

-- 10. 今月累計の確認
SELECT
    '10. 今月累計（7A9637）' as section,
    COUNT(*) as データ日数,
    SUM(daily_profit) as 今月累計,
    MIN(date) as 開始日,
    MAX(date) as 最終日
FROM user_daily_profit
WHERE user_id = '7A9637'
    AND date >= DATE_TRUNC('month', CURRENT_DATE)
    AND date < DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month';
