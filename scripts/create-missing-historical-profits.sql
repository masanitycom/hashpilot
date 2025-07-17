-- ========================================
-- 📊 7/11-7/15の履歴利益データ作成
-- 実際の管理者設定日利を使用
-- ========================================

-- STEP 1: 実際の日利設定を確認
SELECT 
    '=== 📈 実際の日利設定確認 ===' as check_settings,
    date,
    yield_rate,
    margin_rate,
    user_rate,
    (yield_rate * 100) as yield_percent,
    (user_rate * 100) as user_percent
FROM daily_yield_log
WHERE date >= '2025-07-11' AND date <= '2025-07-15'
ORDER BY date;

-- STEP 2: 対象ユーザーの確認（NFT承認済み）
SELECT 
    '=== 👥 対象ユーザー確認 ===' as user_check,
    COUNT(*) as total_users,
    array_agg(user_id ORDER BY user_id) as user_ids
FROM users 
WHERE has_approved_nft = true
  AND total_purchases > 0;

-- STEP 3: 既存データ確認（重複防止）
SELECT 
    '=== 📋 既存データ確認 ===' as existing_data,
    date,
    COUNT(*) as record_count,
    SUM(daily_profit) as total_profit
FROM user_daily_profit
WHERE date >= '2025-07-11' AND date <= '2025-07-15'
GROUP BY date
ORDER BY date;

-- STEP 4: 7/11の利益データ作成（日利設定が存在する場合のみ）
DO $$ 
DECLARE
    target_date DATE := '2025-07-11';
    yield_settings RECORD;
    user_record RECORD;
    nft_amount NUMERIC;
    daily_profit_amount NUMERIC;
    base_amount NUMERIC;
    user_phase TEXT;
BEGIN
    -- 7/11の日利設定を取得
    SELECT yield_rate, margin_rate, user_rate 
    INTO yield_settings
    FROM daily_yield_log 
    WHERE date = target_date;
    
    IF yield_settings IS NULL THEN
        RAISE NOTICE '⚠️ 7/11の日利設定が見つかりません。スキップします。';
        RETURN;
    END IF;
    
    RAISE NOTICE '✅ 7/11の日利設定: yield_rate=%, user_rate=%', 
                 yield_settings.yield_rate, yield_settings.user_rate;
    
    -- 対象ユーザーごとに利益計算
    FOR user_record IN 
        SELECT u.user_id, ac.total_nft_count, ac.phase
        FROM users u
        LEFT JOIN affiliate_cycle ac ON u.user_id = ac.user_id
        WHERE u.has_approved_nft = true 
          AND u.total_purchases > 0
    LOOP
        -- NFT数が0の場合はスキップ
        IF user_record.total_nft_count IS NULL OR user_record.total_nft_count = 0 THEN
            CONTINUE;
        END IF;
        
        -- 運用額計算（1NFT = $1000）
        nft_amount := user_record.total_nft_count;
        base_amount := nft_amount * 1000;
        
        -- 日利計算
        daily_profit_amount := base_amount * yield_settings.user_rate;
        
        -- フェーズ設定
        user_phase := COALESCE(user_record.phase, 'USDT');
        
        -- データ挿入（重複時は更新）
        INSERT INTO user_daily_profit (
            user_id, date, daily_profit, yield_rate, user_rate, 
            base_amount, phase, created_at
        ) VALUES (
            user_record.user_id, target_date, daily_profit_amount,
            yield_settings.yield_rate, yield_settings.user_rate,
            base_amount, user_phase, NOW()
        )
        ON CONFLICT (user_id, date) DO UPDATE SET
            daily_profit = EXCLUDED.daily_profit,
            yield_rate = EXCLUDED.yield_rate,
            user_rate = EXCLUDED.user_rate,
            base_amount = EXCLUDED.base_amount,
            phase = EXCLUDED.phase,
            created_at = NOW();
            
        RAISE NOTICE '📊 User % - NFT: %, Amount: $%, Profit: $%', 
                     user_record.user_id, nft_amount, base_amount, daily_profit_amount;
    END LOOP;
    
    RAISE NOTICE '✅ 7/11の利益データ作成完了';
END $$;

-- STEP 5: 7/12の利益データ作成
DO $$ 
DECLARE
    target_date DATE := '2025-07-12';
    yield_settings RECORD;
    user_record RECORD;
    nft_amount NUMERIC;
    daily_profit_amount NUMERIC;
    base_amount NUMERIC;
    user_phase TEXT;
BEGIN
    -- 7/12の日利設定を取得
    SELECT yield_rate, margin_rate, user_rate 
    INTO yield_settings
    FROM daily_yield_log 
    WHERE date = target_date;
    
    IF yield_settings IS NULL THEN
        RAISE NOTICE '⚠️ 7/12の日利設定が見つかりません。スキップします。';
        RETURN;
    END IF;
    
    RAISE NOTICE '✅ 7/12の日利設定: yield_rate=%, user_rate=%', 
                 yield_settings.yield_rate, yield_settings.user_rate;
    
    -- 対象ユーザーごとに利益計算
    FOR user_record IN 
        SELECT u.user_id, ac.total_nft_count, ac.phase
        FROM users u
        LEFT JOIN affiliate_cycle ac ON u.user_id = ac.user_id
        WHERE u.has_approved_nft = true 
          AND u.total_purchases > 0
    LOOP
        -- NFT数が0の場合はスキップ
        IF user_record.total_nft_count IS NULL OR user_record.total_nft_count = 0 THEN
            CONTINUE;
        END IF;
        
        -- 運用額計算（1NFT = $1000）
        nft_amount := user_record.total_nft_count;
        base_amount := nft_amount * 1000;
        
        -- 日利計算
        daily_profit_amount := base_amount * yield_settings.user_rate;
        
        -- フェーズ設定
        user_phase := COALESCE(user_record.phase, 'USDT');
        
        -- データ挿入（重複時は更新）
        INSERT INTO user_daily_profit (
            user_id, date, daily_profit, yield_rate, user_rate, 
            base_amount, phase, created_at
        ) VALUES (
            user_record.user_id, target_date, daily_profit_amount,
            yield_settings.yield_rate, yield_settings.user_rate,
            base_amount, user_phase, NOW()
        )
        ON CONFLICT (user_id, date) DO UPDATE SET
            daily_profit = EXCLUDED.daily_profit,
            yield_rate = EXCLUDED.yield_rate,
            user_rate = EXCLUDED.user_rate,
            base_amount = EXCLUDED.base_amount,
            phase = EXCLUDED.phase,
            created_at = NOW();
    END LOOP;
    
    RAISE NOTICE '✅ 7/12の利益データ作成完了';
END $$;

-- STEP 6: 7/13の利益データ作成
DO $$ 
DECLARE
    target_date DATE := '2025-07-13';
    yield_settings RECORD;
    user_record RECORD;
    nft_amount NUMERIC;
    daily_profit_amount NUMERIC;
    base_amount NUMERIC;
    user_phase TEXT;
BEGIN
    -- 7/13の日利設定を取得
    SELECT yield_rate, margin_rate, user_rate 
    INTO yield_settings
    FROM daily_yield_log 
    WHERE date = target_date;
    
    IF yield_settings IS NULL THEN
        RAISE NOTICE '⚠️ 7/13の日利設定が見つかりません。スキップします。';
        RETURN;
    END IF;
    
    RAISE NOTICE '✅ 7/13の日利設定: yield_rate=%, user_rate=%', 
                 yield_settings.yield_rate, yield_settings.user_rate;
    
    -- 対象ユーザーごとに利益計算
    FOR user_record IN 
        SELECT u.user_id, ac.total_nft_count, ac.phase
        FROM users u
        LEFT JOIN affiliate_cycle ac ON u.user_id = ac.user_id
        WHERE u.has_approved_nft = true 
          AND u.total_purchases > 0
    LOOP
        -- NFT数が0の場合はスキップ
        IF user_record.total_nft_count IS NULL OR user_record.total_nft_count = 0 THEN
            CONTINUE;
        END IF;
        
        -- 運用額計算（1NFT = $1000）
        nft_amount := user_record.total_nft_count;
        base_amount := nft_amount * 1000;
        
        -- 日利計算
        daily_profit_amount := base_amount * yield_settings.user_rate;
        
        -- フェーズ設定
        user_phase := COALESCE(user_record.phase, 'USDT');
        
        -- データ挿入（重複時は更新）
        INSERT INTO user_daily_profit (
            user_id, date, daily_profit, yield_rate, user_rate, 
            base_amount, phase, created_at
        ) VALUES (
            user_record.user_id, target_date, daily_profit_amount,
            yield_settings.yield_rate, yield_settings.user_rate,
            base_amount, user_phase, NOW()
        )
        ON CONFLICT (user_id, date) DO UPDATE SET
            daily_profit = EXCLUDED.daily_profit,
            yield_rate = EXCLUDED.yield_rate,
            user_rate = EXCLUDED.user_rate,
            base_amount = EXCLUDED.base_amount,
            phase = EXCLUDED.phase,
            created_at = NOW();
    END LOOP;
    
    RAISE NOTICE '✅ 7/13の利益データ作成完了';
END $$;

-- STEP 7: 7/14の利益データ作成
DO $$ 
DECLARE
    target_date DATE := '2025-07-14';
    yield_settings RECORD;
    user_record RECORD;
    nft_amount NUMERIC;
    daily_profit_amount NUMERIC;
    base_amount NUMERIC;
    user_phase TEXT;
BEGIN
    -- 7/14の日利設定を取得
    SELECT yield_rate, margin_rate, user_rate 
    INTO yield_settings
    FROM daily_yield_log 
    WHERE date = target_date;
    
    IF yield_settings IS NULL THEN
        RAISE NOTICE '⚠️ 7/14の日利設定が見つかりません。スキップします。';
        RETURN;
    END IF;
    
    RAISE NOTICE '✅ 7/14の日利設定: yield_rate=%, user_rate=%', 
                 yield_settings.yield_rate, yield_settings.user_rate;
    
    -- 対象ユーザーごとに利益計算
    FOR user_record IN 
        SELECT u.user_id, ac.total_nft_count, ac.phase
        FROM users u
        LEFT JOIN affiliate_cycle ac ON u.user_id = ac.user_id
        WHERE u.has_approved_nft = true 
          AND u.total_purchases > 0
    LOOP
        -- NFT数が0の場合はスキップ
        IF user_record.total_nft_count IS NULL OR user_record.total_nft_count = 0 THEN
            CONTINUE;
        END IF;
        
        -- 運用額計算（1NFT = $1000）
        nft_amount := user_record.total_nft_count;
        base_amount := nft_amount * 1000;
        
        -- 日利計算
        daily_profit_amount := base_amount * yield_settings.user_rate;
        
        -- フェーズ設定
        user_phase := COALESCE(user_record.phase, 'USDT');
        
        -- データ挿入（重複時は更新）
        INSERT INTO user_daily_profit (
            user_id, date, daily_profit, yield_rate, user_rate, 
            base_amount, phase, created_at
        ) VALUES (
            user_record.user_id, target_date, daily_profit_amount,
            yield_settings.yield_rate, yield_settings.user_rate,
            base_amount, user_phase, NOW()
        )
        ON CONFLICT (user_id, date) DO UPDATE SET
            daily_profit = EXCLUDED.daily_profit,
            yield_rate = EXCLUDED.yield_rate,
            user_rate = EXCLUDED.user_rate,
            base_amount = EXCLUDED.base_amount,
            phase = EXCLUDED.phase,
            created_at = NOW();
    END LOOP;
    
    RAISE NOTICE '✅ 7/14の利益データ作成完了';
END $$;

-- STEP 8: 7/15の利益データ作成
DO $$ 
DECLARE
    target_date DATE := '2025-07-15';
    yield_settings RECORD;
    user_record RECORD;
    nft_amount NUMERIC;
    daily_profit_amount NUMERIC;
    base_amount NUMERIC;
    user_phase TEXT;
BEGIN
    -- 7/15の日利設定を取得
    SELECT yield_rate, margin_rate, user_rate 
    INTO yield_settings
    FROM daily_yield_log 
    WHERE date = target_date;
    
    IF yield_settings IS NULL THEN
        RAISE NOTICE '⚠️ 7/15の日利設定が見つかりません。スキップします。';
        RETURN;
    END IF;
    
    RAISE NOTICE '✅ 7/15の日利設定: yield_rate=%, user_rate=%', 
                 yield_settings.yield_rate, yield_settings.user_rate;
    
    -- 対象ユーザーごとに利益計算
    FOR user_record IN 
        SELECT u.user_id, ac.total_nft_count, ac.phase
        FROM users u
        LEFT JOIN affiliate_cycle ac ON u.user_id = ac.user_id
        WHERE u.has_approved_nft = true 
          AND u.total_purchases > 0
    LOOP
        -- NFT数が0の場合はスキップ
        IF user_record.total_nft_count IS NULL OR user_record.total_nft_count = 0 THEN
            CONTINUE;
        END IF;
        
        -- 運用額計算（1NFT = $1000）
        nft_amount := user_record.total_nft_count;
        base_amount := nft_amount * 1000;
        
        -- 日利計算
        daily_profit_amount := base_amount * yield_settings.user_rate;
        
        -- フェーズ設定
        user_phase := COALESCE(user_record.phase, 'USDT');
        
        -- データ挿入（重複時は更新）
        INSERT INTO user_daily_profit (
            user_id, date, daily_profit, yield_rate, user_rate, 
            base_amount, phase, created_at
        ) VALUES (
            user_record.user_id, target_date, daily_profit_amount,
            yield_settings.yield_rate, yield_settings.user_rate,
            base_amount, user_phase, NOW()
        )
        ON CONFLICT (user_id, date) DO UPDATE SET
            daily_profit = EXCLUDED.daily_profit,
            yield_rate = EXCLUDED.yield_rate,
            user_rate = EXCLUDED.user_rate,
            base_amount = EXCLUDED.base_amount,
            phase = EXCLUDED.phase,
            created_at = NOW();
    END LOOP;
    
    RAISE NOTICE '✅ 7/15の利益データ作成完了';
END $$;

-- STEP 9: 作成結果確認
SELECT 
    '=== 📊 作成結果確認 ===' as result_check,
    date,
    COUNT(*) as record_count,
    SUM(daily_profit) as total_profit,
    AVG(daily_profit) as avg_profit,
    MIN(daily_profit) as min_profit,
    MAX(daily_profit) as max_profit
FROM user_daily_profit
WHERE date >= '2025-07-11' AND date <= '2025-07-15'
GROUP BY date
ORDER BY date;

-- STEP 10: User 7A9637の結果確認
SELECT 
    '=== 🎯 7A9637の履歴確認 ===' as user_check,
    date,
    daily_profit,
    yield_rate,
    user_rate,
    base_amount,
    phase
FROM user_daily_profit
WHERE user_id = '7A9637'
  AND date >= '2025-07-11' AND date <= '2025-07-16'
ORDER BY date;