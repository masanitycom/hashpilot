-- ========================================
-- 既存の日利設定確認と実際の処理実行
-- 管理画面で設定済みの値を使用
-- ========================================

-- 1. 現在の日利設定確認
SELECT 
    '=== 現在の日利設定 ===' as info,
    date,
    yield_rate,
    margin_rate,
    user_rate,
    is_month_end,
    created_at
FROM daily_yield_log
ORDER BY date DESC, created_at DESC
LIMIT 10;

-- 2. 最新の設定値を取得して処理実行
DO $$
DECLARE
    latest_yield_rate NUMERIC;
    latest_margin_rate NUMERIC;
    latest_date DATE;
    result_record RECORD;
BEGIN
    -- 最新の設定値を取得
    SELECT yield_rate, margin_rate, date
    INTO latest_yield_rate, latest_margin_rate, latest_date
    FROM daily_yield_log
    ORDER BY date DESC, created_at DESC
    LIMIT 1;
    
    -- 設定が見つからない場合のエラー
    IF latest_yield_rate IS NULL THEN
        RAISE EXCEPTION '日利設定が見つかりません。管理画面で設定してください。';
    END IF;
    
    RAISE NOTICE '最新設定を使用: 日利率=%, マージン率=%, 設定日=%', 
        latest_yield_rate, latest_margin_rate, latest_date;
    
    -- 今日の日付で既存設定を使用して処理実行
    SELECT processed_count, total_profit, total_referral_profit, message
    INTO result_record
    FROM process_daily_yield_with_cycles(
        CURRENT_DATE,           -- 今日の日付
        latest_yield_rate,      -- 管理画面の設定値
        latest_margin_rate,     -- 管理画面の設定値
        true,                   -- テストモード
        false                   -- 月末処理ではない
    );
    
    RAISE NOTICE '処理結果: %', result_record.message;
END $$;

-- 3. 処理結果確認
SELECT 
    '=== 今日の利益データ ===' as info,
    user_id,
    daily_profit,
    base_amount,
    yield_rate,
    user_rate,
    created_at
FROM user_daily_profit
WHERE date = CURRENT_DATE
ORDER BY daily_profit DESC;

-- 4. システムログ確認
SELECT 
    '=== 最新の処理ログ ===' as info,
    log_type,
    operation,
    message,
    created_at
FROM system_logs
WHERE operation = 'DAILY_YIELD_PROCESS'
ORDER BY created_at DESC
LIMIT 5;