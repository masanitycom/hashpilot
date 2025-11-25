-- ステップ8: 最終確認
SELECT
    (SELECT COUNT(*) FROM admins) as admins,
    (SELECT COUNT(*) FROM users) as users,
    (SELECT COUNT(*) FROM affiliate_cycle) as cycles,
    (SELECT COUNT(*) FROM purchases) as purchases,
    (SELECT COUNT(*) FROM nft_master) as nfts,
    (SELECT COUNT(*) FROM users WHERE is_pegasus_exchange = true) as pegasus_users;
