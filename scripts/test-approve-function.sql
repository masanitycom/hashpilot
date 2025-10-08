-- approve_user_nft関数を直接テスト

-- テスト実行（実際の購入IDを使用）
SELECT * FROM approve_user_nft(
    'ecee97ac-0519-4a41-b53e-03e05d033d9c',  -- E28F37の購入ID
    'test@admin.com',
    'テスト承認'
);
