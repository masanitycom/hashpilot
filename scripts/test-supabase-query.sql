-- Supabase REST API経由でのデータ取得をシミュレート

-- RLSポリシーを確認
SELECT '=== affiliate_cycle RLSポリシー ===' as section;

SELECT
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'affiliate_cycle';

-- 実際のデータ（RLS適用前）
SELECT '=== affiliate_cycle生データ（RLS適用前） ===' as section;

SELECT
    user_id,
    manual_nft_count,
    auto_nft_count,
    total_nft_count
FROM affiliate_cycle
WHERE user_id = '7E0A1E';

-- RLSを一時的に無効化してテスト（SECURITY DEFINER関数として）
CREATE OR REPLACE FUNCTION test_get_nft_count_7E0A1E()
RETURNS TABLE(
    manual_nft_count INTEGER,
    auto_nft_count INTEGER,
    total_nft_count INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT
        ac.manual_nft_count,
        ac.auto_nft_count,
        ac.total_nft_count
    FROM affiliate_cycle ac
    WHERE ac.user_id = '7E0A1E';
END;
$$;

SELECT '=== テスト関数経由（RLS回避） ===' as section;

SELECT * FROM test_get_nft_count_7E0A1E();

-- クリーンアップ
DROP FUNCTION test_get_nft_count_7E0A1E();
