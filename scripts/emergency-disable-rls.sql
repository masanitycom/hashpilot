-- 緊急対応：RLSを一時的に完全無効化してテスト

-- 全てのRLSを無効化
ALTER TABLE users DISABLE ROW LEVEL SECURITY;
ALTER TABLE purchases DISABLE ROW LEVEL SECURITY;
ALTER TABLE admins DISABLE ROW LEVEL SECURITY;

-- 既存のポリシーを全て削除
DO $$ 
DECLARE
    r RECORD;
BEGIN
    -- usersテーブルのポリシーを削除
    FOR r IN (SELECT policyname FROM pg_policies WHERE tablename = 'users') LOOP
        EXECUTE 'DROP POLICY IF EXISTS ' || quote_ident(r.policyname) || ' ON users';
    END LOOP;
    
    -- purchasesテーブルのポリシーを削除
    FOR r IN (SELECT policyname FROM pg_policies WHERE tablename = 'purchases') LOOP
        EXECUTE 'DROP POLICY IF EXISTS ' || quote_ident(r.policyname) || ' ON purchases';
    END LOOP;
    
    -- adminsテーブルのポリシーを削除
    FOR r IN (SELECT policyname FROM pg_policies WHERE tablename = 'admins') LOOP
        EXECUTE 'DROP POLICY IF EXISTS ' || quote_ident(r.policyname) || ' ON admins';
    END LOOP;
END $$;

-- 現在のポリシー状況を確認（空になっているはず）
SELECT 'Remaining policies:' as info;
SELECT tablename, policyname 
FROM pg_policies 
WHERE tablename IN ('users', 'purchases', 'admins');

-- テスト用クエリ（RLS無効化後）
SELECT 'RLS disabled - testing access:' as test;
SELECT COUNT(*) as user_count FROM users;
SELECT COUNT(*) as purchase_count FROM purchases;
SELECT COUNT(*) as admin_count FROM admins;

-- 特定ユーザーの確認
SELECT 'Specific user check:' as test;
SELECT id, user_id, email, has_approved_nft 
FROM users 
WHERE id = '4e9afb05-aa71-4624-8f03-711ead9cb4bd';
