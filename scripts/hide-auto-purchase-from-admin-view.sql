-- 管理画面から自動NFT付与レコードを非表示にする
-- 作成日: 2025年10月7日
-- 目的: 手動購入のみを管理画面に表示し、自動付与は別画面で確認

-- 現在のビュー定義を確認
SELECT
    '=== Current admin_purchases_view definition ===' as info;

SELECT
    viewname,
    definition
FROM pg_views
WHERE viewname = 'admin_purchases_view';

-- ビューを再作成（自動購入を除外）
DROP VIEW IF EXISTS admin_purchases_view;

CREATE VIEW admin_purchases_view AS
SELECT
    p.id,
    p.user_id,
    u.email,
    u.full_name,
    u.coinw_uid,
    u.referrer_user_id,
    ref.email as referrer_email,
    ref.full_name as referrer_full_name,
    p.nft_quantity,
    p.amount_usd,
    p.payment_status,
    p.admin_approved,
    p.admin_approved_at,
    p.admin_approved_by,
    p.payment_proof_url,
    p.user_notes,
    p.admin_notes,
    p.created_at,
    u.has_approved_nft,
    p.is_auto_purchase
FROM purchases p
INNER JOIN users u ON p.user_id = u.user_id
LEFT JOIN users ref ON u.referrer_user_id = ref.user_id
-- ⭐ 自動購入を除外（手動購入のみ表示）
WHERE COALESCE(p.is_auto_purchase, FALSE) = FALSE
ORDER BY p.created_at DESC;

-- 自動付与履歴用のビューを新規作成
DROP VIEW IF EXISTS admin_auto_nft_grants_view;

CREATE VIEW admin_auto_nft_grants_view AS
SELECT
    p.id,
    p.user_id,
    u.email,
    u.full_name,
    p.nft_quantity,
    p.amount_usd,
    p.admin_approved_at as granted_at,
    p.created_at,
    u.has_approved_nft,
    -- NFT詳細情報を追加
    (
        SELECT COUNT(*)
        FROM nft_master nm
        WHERE nm.user_id = p.user_id
          AND nm.nft_type = 'auto'
          AND nm.buyback_date IS NULL
    ) as current_auto_nft_count,
    (
        SELECT json_agg(
            json_build_object(
                'nft_sequence', nm.nft_sequence,
                'nft_value', nm.nft_value,
                'acquired_date', nm.acquired_date
            )
            ORDER BY nm.nft_sequence DESC
        )
        FROM nft_master nm
        WHERE nm.user_id = p.user_id
          AND nm.nft_type = 'auto'
          AND nm.buyback_date IS NULL
    ) as nft_details
FROM purchases p
INNER JOIN users u ON p.user_id = u.user_id
-- ⭐ 自動購入のみを表示
WHERE p.is_auto_purchase = TRUE
ORDER BY p.created_at DESC;

-- 権限付与
GRANT SELECT ON admin_purchases_view TO anon;
GRANT SELECT ON admin_purchases_view TO authenticated;
GRANT SELECT ON admin_auto_nft_grants_view TO anon;
GRANT SELECT ON admin_auto_nft_grants_view TO authenticated;

-- 確認
SELECT
    '=== Verification ===' as info;

-- 手動購入の件数
SELECT
    COUNT(*) as manual_purchase_count,
    '手動購入' as type
FROM admin_purchases_view;

-- 自動付与の件数
SELECT
    COUNT(*) as auto_grant_count,
    '自動付与' as type
FROM admin_auto_nft_grants_view;

-- 完了メッセージ
DO $$
BEGIN
    RAISE NOTICE '===========================================';
    RAISE NOTICE 'Admin views updated successfully';
    RAISE NOTICE '===========================================';
    RAISE NOTICE 'Changes:';
    RAISE NOTICE '  - admin_purchases_view: 手動購入のみ表示';
    RAISE NOTICE '  - admin_auto_nft_grants_view: 自動付与履歴（新規作成）';
    RAISE NOTICE '';
    RAISE NOTICE 'Next steps:';
    RAISE NOTICE '  - admin/purchasesページは手動購入のみ表示';
    RAISE NOTICE '  - 自動付与履歴用の新しいページを作成可能';
    RAISE NOTICE '===========================================';
END $$;
