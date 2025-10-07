-- 7A9637に3個のNFTを自動付与
-- cum_usdt = 8759.30ドル → 3個のNFT付与（6600ドル消費）

SELECT '=== 付与前の状態確認 ===' as section;

SELECT
    user_id,
    total_nft_count,
    manual_nft_count,
    auto_nft_count,
    cum_usdt,
    available_usdt,
    phase
FROM affiliate_cycle
WHERE user_id = '7A9637';

-- 現在のNFT一覧
SELECT
    COUNT(*) as current_nft_count,
    COUNT(*) FILTER (WHERE nft_type = 'auto') as current_auto_nft
FROM nft_master
WHERE user_id = '7A9637' AND buyback_date IS NULL;

SELECT '=== NFT自動付与処理 ===' as section;

-- 次のNFTシーケンス番号を取得
DO $$
DECLARE
    v_next_sequence INTEGER;
    v_nft_count INTEGER := 3; -- 付与するNFT数
    v_cum_usdt NUMERIC;
    v_remaining_usdt NUMERIC;
BEGIN
    -- 次のシーケンス番号
    SELECT COALESCE(MAX(nft_sequence), 0) + 1
    INTO v_next_sequence
    FROM nft_master
    WHERE user_id = '7A9637';

    -- 現在のcum_usdt
    SELECT cum_usdt INTO v_cum_usdt
    FROM affiliate_cycle
    WHERE user_id = '7A9637';

    -- 残りのcum_usdt
    v_remaining_usdt := v_cum_usdt - (v_nft_count * 2200);

    RAISE NOTICE '付与するNFT数: %個', v_nft_count;
    RAISE NOTICE '次のシーケンス番号: %', v_next_sequence;
    RAISE NOTICE '現在のcum_usdt: $%', v_cum_usdt;
    RAISE NOTICE '残りのcum_usdt: $%', v_remaining_usdt;

    -- NFTレコードを作成
    FOR i IN 1..v_nft_count LOOP
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
            '7A9637',
            v_next_sequence + i - 1,
            'auto',
            1100.00,
            CURRENT_DATE,
            NOW(),
            NOW()
        );
    END LOOP;

    -- purchasesテーブルに記録
    INSERT INTO purchases (
        user_id,
        nft_quantity,
        amount_usd,
        payment_status,
        admin_approved,
        is_auto_purchase,
        admin_approved_at,
        admin_approved_by
    )
    VALUES (
        '7A9637',
        v_nft_count,
        v_nft_count * 1100,
        'completed',
        true,
        true,
        NOW(),
        'SYSTEM_AUTO'
    );

    -- affiliate_cycleを更新
    UPDATE affiliate_cycle
    SET
        total_nft_count = total_nft_count + v_nft_count,
        auto_nft_count = auto_nft_count + v_nft_count,
        cum_usdt = v_remaining_usdt,
        available_usdt = available_usdt + (v_nft_count * 1100),
        phase = CASE
            WHEN v_remaining_usdt >= 1100 THEN 'HOLD'
            ELSE 'USDT'
        END,
        last_updated = NOW()
    WHERE user_id = '7A9637';

    RAISE NOTICE 'NFT付与完了！';
END $$;

SELECT '=== 付与後の状態確認 ===' as section;

SELECT
    user_id,
    total_nft_count,
    manual_nft_count,
    auto_nft_count,
    cum_usdt,
    available_usdt,
    phase
FROM affiliate_cycle
WHERE user_id = '7A9637';

-- 新しく作成されたNFT
SELECT
    nft_sequence,
    nft_type,
    nft_value,
    acquired_date
FROM nft_master
WHERE user_id = '7A9637'
  AND nft_type = 'auto'
  AND buyback_date IS NULL
ORDER BY nft_sequence DESC
LIMIT 3;

-- 自動購入履歴
SELECT
    id,
    nft_quantity,
    amount_usd,
    admin_approved_at,
    is_auto_purchase
FROM purchases
WHERE user_id = '7A9637'
  AND is_auto_purchase = true
ORDER BY created_at DESC
LIMIT 1;

-- 完了メッセージ
DO $$
DECLARE
    v_total_nft INTEGER;
    v_auto_nft INTEGER;
    v_available NUMERIC;
BEGIN
    SELECT total_nft_count, auto_nft_count, available_usdt
    INTO v_total_nft, v_auto_nft, v_available
    FROM affiliate_cycle
    WHERE user_id = '7A9637';

    RAISE NOTICE '===========================================';
    RAISE NOTICE '✅ NFT自動付与が完了しました';
    RAISE NOTICE '===========================================';
    RAISE NOTICE '付与したNFT: 3個';
    RAISE NOTICE '総NFT数: %個', v_total_nft;
    RAISE NOTICE '自動NFT数: %個', v_auto_nft;
    RAISE NOTICE '受取可能額: $%', v_available;
    RAISE NOTICE '===========================================';
END $$;
