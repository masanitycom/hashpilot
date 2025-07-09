-- RLSを一時的に無効化（トリガー用）
ALTER TABLE users DISABLE ROW LEVEL SECURITY;

-- 既存のポリシーを削除
DROP POLICY IF EXISTS "Enable insert for authenticated users during signup" ON users;
DROP POLICY IF EXISTS "Users can read their own data" ON users;
DROP POLICY IF EXISTS "Users can update their own data" ON users;
DROP POLICY IF EXISTS "Users can delete their own data" ON users;

-- ユーザー自動作成用のトリガー関数
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
DECLARE
    random_user_id text;
BEGIN
    -- ランダムな6文字のuser_idを生成
    random_user_id := upper(substring(md5(random()::text) from 1 for 6));
    
    -- usersテーブルに新しいレコードを挿入
    INSERT INTO public.users (id, user_id, email, total_purchases, total_referral_earnings, is_active)
    VALUES (new.id, random_user_id, new.email, 0, 0, true);
    
    RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 既存のトリガーがあれば削除
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- auth.usersテーブルにトリガーを設定
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- RLSを再度有効化
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- 自分のデータのみアクセス可能なポリシーを作成
CREATE POLICY "Users can access their own data" 
ON users FOR ALL 
TO authenticated 
USING (auth.uid() = id);
