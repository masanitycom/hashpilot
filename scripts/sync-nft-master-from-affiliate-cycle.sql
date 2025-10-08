-- affiliate_cycleとnft_masterの不整合を修正
-- affiliate_cycleに記録されているNFT数に基づいて、nft_masterレコードを作成

-- ⚠️ 警告: このスクリプトは既存のnft_masterレコードを削除しません
-- 不足しているレコードのみを追加します

-- ============================================
-- STEP 1: 不整合のあるユーザーを検出して修正
-- ============================================

DO $$
DECLARE
    v_user_record RECORD;
    v_existing_manual INTEGER;
    v_existing_auto INTEGER;
    v_needed_manual INTEGER;
    v_needed_auto INTEGER;
    v_next_sequence INTEGER;
    v_purchase_date DATE;
    i INTEGER;
BEGIN
    RAISE NOTICE '=========================================';
    RAISE NOTICE 'NFT Master レコード同期開始';
    RAISE NOTICE '=========================================';

    FOR v_user_record IN
        SELECT
            ac.user_id,
            ac.manual_nft_count,
            ac.auto_nft_count,
            ac.total_nft_count,
            COALESCE(nm.manual_count, 0) as existing_manual,
            COALESCE(nm.auto_count, 0) as existing_auto
        FROM affiliate_cycle ac
        LEFT JOIN (
            SELECT
                user_id,
                COUNT(*) FILTER (WHERE nft_type = 'manual' AND buyback_date IS NULL) as manual_count,
                COUNT(*) FILTER (WHERE nft_type = 'auto' AND buyback_date IS NULL) as auto_count
            FROM nft_master
            GROUP BY user_id
        ) nm ON ac.user_id = nm.user_id
        WHERE ac.total_nft_count > 0
          AND (
            ac.manual_nft_count > COALESCE(nm.manual_count, 0)
            OR ac.auto_nft_count > COALESCE(nm.auto_count, 0)
          )
    LOOP
        RAISE NOTICE '';
        RAISE NOTICE '処理中: ユーザーID = %', v_user_record.user_id;

        -- 既存のレコード数を取得
        v_existing_manual := v_user_record.existing_manual;
        v_existing_auto := v_user_record.existing_auto;

        -- 必要なレコード数を計算
        v_needed_manual := v_user_record.manual_nft_count - v_existing_manual;
        v_needed_auto := v_user_record.auto_nft_count - v_existing_auto;

        RAISE NOTICE '  手動NFT: % 枚必要（既存: %、不足: %）',
            v_user_record.manual_nft_count, v_existing_manual, v_needed_manual;
        RAISE NOTICE '  自動NFT: % 枚必要（既存: %、不足: %）',
            v_user_record.auto_nft_count, v_existing_auto, v_needed_auto;

        -- 次のシーケンス番号を取得
        SELECT COALESCE(MAX(nft_sequence), 0) + 1
        INTO v_next_sequence
        FROM nft_master
        WHERE user_id = v_user_record.user_id;

        -- 購入日を取得（最初の承認済み購入日）
        SELECT MIN(admin_approved_at::DATE)
        INTO v_purchase_date
        FROM purchases
        WHERE user_id = v_user_record.user_id
          AND admin_approved = true;

        -- 購入日が見つからない場合は今日の日付を使用
        IF v_purchase_date IS NULL THEN
            v_purchase_date := CURRENT_DATE;
        END IF;

        -- 手動NFTレコードを作成
        IF v_needed_manual > 0 THEN
            FOR i IN 1..v_needed_manual LOOP
                INSERT INTO nft_master (
                    user_id,
                    nft_sequence,
                    nft_type,
                    nft_value,
                    acquired_date,
                    created_at,
                    updated_at
                )
                VALUES (
                    v_user_record.user_id,
                    v_next_sequence + i - 1,
                    'manual',
                    1100.00,
                    v_purchase_date,
                    NOW(),
                    NOW()
                );
            END LOOP;
            RAISE NOTICE '  ✅ 手動NFT % 枚を作成しました', v_needed_manual;
            v_next_sequence := v_next_sequence + v_needed_manual;
        END IF;

        -- 自動NFTレコードを作成
        IF v_needed_auto > 0 THEN
            FOR i IN 1..v_needed_auto LOOP
                INSERT INTO nft_master (
                    user_id,
                    nft_sequence,
                    nft_type,
                    nft_value,
                    acquired_date,
                    created_at,
                    updated_at
                )
                VALUES (
                    v_user_record.user_id,
                    v_next_sequence + i - 1,
                    'auto',
                    1100.00,
                    v_purchase_date,
                    NOW(),
                    NOW()
                );
            END LOOP;
            RAISE NOTICE '  ✅ 自動NFT % 枚を作成しました', v_needed_auto;
        END IF;
    END LOOP;

    RAISE NOTICE '';
    RAISE NOTICE '=========================================';
    RAISE NOTICE '✅ NFT Master レコード同期完了';
    RAISE NOTICE '=========================================';
END $$;

-- ============================================
-- STEP 2: 結果確認
-- ============================================

SELECT '=== 同期後の状態確認 ===' as section;

SELECT
    ac.user_id,
    ac.manual_nft_count as cycle_manual,
    ac.auto_nft_count as cycle_auto,
    ac.total_nft_count as cycle_total,
    COALESCE(nm.manual_count, 0) as master_manual,
    COALESCE(nm.auto_count, 0) as master_auto,
    COALESCE(nm.total_count, 0) as master_total,
    CASE
        WHEN ac.total_nft_count = COALESCE(nm.total_count, 0)
        THEN '✅ 一致'
        ELSE '⚠️ 不一致'
    END as status
FROM affiliate_cycle ac
LEFT JOIN (
    SELECT
        user_id,
        COUNT(*) FILTER (WHERE nft_type = 'manual' AND buyback_date IS NULL) as manual_count,
        COUNT(*) FILTER (WHERE nft_type = 'auto' AND buyback_date IS NULL) as auto_count,
        COUNT(*) FILTER (WHERE buyback_date IS NULL) as total_count
    FROM nft_master
    GROUP BY user_id
) nm ON ac.user_id = nm.user_id
WHERE ac.total_nft_count > 0
ORDER BY ac.user_id;
