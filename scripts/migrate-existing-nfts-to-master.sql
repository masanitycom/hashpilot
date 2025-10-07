-- 既存NFTデータを nft_master テーブルに移行
-- 作成日: 2025年10月6日

-- ============================================
-- 1. 手動購入NFTの移行
-- ============================================
DO $$
DECLARE
    v_user RECORD;
    v_nft_sequence INTEGER;
    v_purchase_date DATE;
BEGIN
    RAISE NOTICE '🔄 手動購入NFTを移行中...';

    FOR v_user IN
        SELECT
            ac.user_id,
            ac.manual_nft_count,
            MIN(p.admin_approved_at)::DATE as first_purchase_date
        FROM affiliate_cycle ac
        INNER JOIN purchases p ON ac.user_id = p.user_id
        WHERE ac.manual_nft_count > 0
            AND p.admin_approved = true
        GROUP BY ac.user_id, ac.manual_nft_count
    LOOP
        -- 各ユーザーのNFT個数分ループ
        FOR v_nft_sequence IN 1..v_user.manual_nft_count LOOP
            -- NFTマスターに挿入（重複チェック付き）
            INSERT INTO nft_master (
                user_id,
                nft_sequence,
                nft_type,
                nft_value,
                acquired_date
            )
            VALUES (
                v_user.user_id,
                v_nft_sequence,
                'manual',
                1100,
                v_user.first_purchase_date
            )
            ON CONFLICT (user_id, nft_sequence) DO NOTHING;
        END LOOP;

        RAISE NOTICE '  ✅ %: % 個の手動NFTを移行', v_user.user_id, v_user.manual_nft_count;
    END LOOP;

    RAISE NOTICE '✅ 手動購入NFTの移行完了';
END $$;

-- ============================================
-- 2. 自動購入NFTの移行
-- ============================================
DO $$
DECLARE
    v_user RECORD;
    v_next_sequence INTEGER;
BEGIN
    RAISE NOTICE '🔄 自動購入NFTを移行中...';

    -- affiliate_cycleのauto_nft_countから移行
    FOR v_user IN
        SELECT
            ac.user_id,
            ac.auto_nft_count,
            COALESCE(MIN(p.admin_approved_at)::DATE, CURRENT_DATE) as first_purchase_date
        FROM affiliate_cycle ac
        LEFT JOIN purchases p ON ac.user_id = p.user_id AND p.admin_approved = true
        WHERE ac.auto_nft_count > 0
        GROUP BY ac.user_id, ac.auto_nft_count
    LOOP
        -- 既存の最大シーケンス番号を取得（手動NFTの続き番号から）
        SELECT COALESCE(MAX(nft_sequence), 0) + 1
        INTO v_next_sequence
        FROM nft_master
        WHERE user_id = v_user.user_id;

        -- 自動購入NFTの個数分ループ
        FOR i IN 1..v_user.auto_nft_count LOOP
            INSERT INTO nft_master (
                user_id,
                nft_sequence,
                nft_type,
                nft_value,
                acquired_date
            )
            VALUES (
                v_user.user_id,
                v_next_sequence + i - 1,
                'auto',
                1100,
                v_user.first_purchase_date
            )
            ON CONFLICT (user_id, nft_sequence) DO NOTHING;
        END LOOP;

        RAISE NOTICE '  ✅ %: % 個の自動NFTを移行 (日付: %)',
            v_user.user_id,
            v_user.auto_nft_count,
            v_user.first_purchase_date;
    END LOOP;

    RAISE NOTICE '✅ 自動購入NFTの移行完了';
END $$;

-- ============================================
-- 3. 移行結果の確認
-- ============================================
SELECT
    '📊 NFT移行結果サマリー' as title,
    COUNT(*) as total_nft_count,
    COUNT(*) FILTER (WHERE nft_type = 'manual') as manual_nft_count,
    COUNT(*) FILTER (WHERE nft_type = 'auto') as auto_nft_count,
    COUNT(DISTINCT user_id) as user_count
FROM nft_master;

-- ユーザーごとの確認
SELECT
    nm.user_id,
    COUNT(*) FILTER (WHERE nm.nft_type = 'manual') as manual_count,
    COUNT(*) FILTER (WHERE nm.nft_type = 'auto') as auto_count,
    COUNT(*) as total_count,
    ac.manual_nft_count as expected_manual,
    ac.auto_nft_count as expected_auto,
    ac.total_nft_count as expected_total,
    CASE
        WHEN COUNT(*) FILTER (WHERE nm.nft_type = 'manual') = ac.manual_nft_count
            AND COUNT(*) FILTER (WHERE nm.nft_type = 'auto') = ac.auto_nft_count
        THEN '✅ 一致'
        ELSE '❌ 不一致'
    END as status
FROM nft_master nm
INNER JOIN affiliate_cycle ac ON nm.user_id = ac.user_id
GROUP BY nm.user_id, ac.manual_nft_count, ac.auto_nft_count, ac.total_nft_count
ORDER BY nm.user_id;
