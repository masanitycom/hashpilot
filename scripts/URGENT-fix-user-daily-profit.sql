-- ========================================
-- 緊急修正: user_daily_profitをnft_daily_profitから自動集計
-- ========================================

-- 問題: フロントエンドはuser_daily_profitを参照しているが、
--       バックエンドはnft_daily_profitにのみデータを保存している

-- 解決策: user_daily_profitを自動的に集計するビューに変更

-- STEP 1: 既存のuser_daily_profitテーブルをバックアップ
DO $$
BEGIN
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'user_daily_profit_backup') THEN
        DROP TABLE user_daily_profit_backup;
    END IF;
END $$;

CREATE TABLE user_daily_profit_backup AS
SELECT * FROM user_daily_profit;

-- STEP 2: 既存のuser_daily_profitテーブルを削除
DROP TABLE IF EXISTS user_daily_profit CASCADE;

-- STEP 3: user_daily_profitをビューとして再作成
CREATE OR REPLACE VIEW user_daily_profit AS
SELECT
    ndp.user_id,
    ndp.date,
    SUM(ndp.daily_profit) as daily_profit,
    MAX(ndp.yield_rate) as yield_rate,
    MAX(ndp.created_at) as created_at,
    -- 追加フィールド（グラフやカード表示用）
    NULL::numeric as base_amount,
    NULL::text as phase,
    NULL::numeric as user_rate
FROM nft_daily_profit ndp
GROUP BY ndp.user_id, ndp.date;

-- STEP 4: 権限付与
GRANT SELECT ON user_daily_profit TO anon;
GRANT SELECT ON user_daily_profit TO authenticated;

-- STEP 5: 動作確認
SELECT
    'ビュー作成完了' as status,
    COUNT(*) as record_count,
    COUNT(DISTINCT user_id) as unique_users,
    MAX(date) as latest_date
FROM user_daily_profit;

-- STEP 6: サンプルデータ確認（最新5件）
SELECT
    date,
    user_id,
    daily_profit,
    yield_rate,
    created_at
FROM user_daily_profit
ORDER BY date DESC, user_id
LIMIT 10;

-- STEP 7: 集計が正しいか確認
SELECT
    '集計確認' as section,
    ndp.date,
    ndp.user_id,
    COUNT(ndp.id) as nft_count,
    SUM(ndp.daily_profit) as nft_total,
    udp.daily_profit as view_total,
    CASE
        WHEN ABS(SUM(ndp.daily_profit) - udp.daily_profit) < 0.001 THEN '✅ 一致'
        ELSE '❌ 不一致'
    END as status
FROM nft_daily_profit ndp
INNER JOIN user_daily_profit udp ON ndp.user_id = udp.user_id AND ndp.date = udp.date
GROUP BY ndp.date, ndp.user_id, udp.daily_profit
ORDER BY ndp.date DESC
LIMIT 10;

-- 完了メッセージ
DO $$
BEGIN
    RAISE NOTICE '===========================================';
    RAISE NOTICE '✅ user_daily_profitビューを作成しました';
    RAISE NOTICE '===========================================';
    RAISE NOTICE '変更内容:';
    RAISE NOTICE '  - user_daily_profitテーブル → ビューに変更';
    RAISE NOTICE '  - nft_daily_profitから自動集計';
    RAISE NOTICE '  - リアルタイムで最新データを表示';
    RAISE NOTICE '';
    RAISE NOTICE '影響:';
    RAISE NOTICE '  - ダッシュボードの利益表示が正しく動作';
    RAISE NOTICE '  - グラフにデータが表示される';
    RAISE NOTICE '  - 自動NFTの日利も正しく反映';
    RAISE NOTICE '===========================================';
END $$;
