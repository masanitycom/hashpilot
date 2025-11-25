# テスト環境への移行手順（手動SQL方式）

## 📋 作業の流れ

1. 本番環境からスキーマをエクスポート
2. テスト環境にインポート
3. テストデータを少量作成
4. ペガサス機能をテスト
5. 問題なければ本番環境に適用

---

## ステップ1: テーブル定義のエクスポート

### 本番Supabaseで実行するSQL

**URL**: https://app.supabase.com/project/soghqozaxfswtxxbgeer/sql

```sql
-- すべてのテーブルのCREATE TABLE文を生成
SELECT
    'CREATE TABLE IF NOT EXISTS ' || table_name || ' (' ||
    string_agg(
        column_name || ' ' ||
        data_type ||
        CASE WHEN character_maximum_length IS NOT NULL
             THEN '(' || character_maximum_length || ')'
             ELSE '' END ||
        CASE WHEN is_nullable = 'NO' THEN ' NOT NULL' ELSE '' END ||
        CASE WHEN column_default IS NOT NULL
             THEN ' DEFAULT ' || column_default
             ELSE '' END,
        ', '
        ORDER BY ordinal_position
    ) || ');' AS create_table_sql
FROM information_schema.columns
WHERE table_schema = 'public'
GROUP BY table_name
ORDER BY table_name;
```

### または、pg_dumpスタイルで詳細取得

```sql
-- より正確なテーブル定義を取得（制約含む）
SELECT
    'Table: ' || tablename AS table_info,
    pg_get_tabledef(schemaname || '.' || tablename) AS full_definition
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;
```

---

## ステップ2: 外部キー制約のエクスポート

```sql
-- 外部キー制約を取得
SELECT
    'ALTER TABLE ' || tc.table_name ||
    ' ADD CONSTRAINT ' || tc.constraint_name ||
    ' FOREIGN KEY (' || kcu.column_name || ')' ||
    ' REFERENCES ' || ccu.table_name || '(' || ccu.column_name || ')' ||
    CASE WHEN rc.delete_rule IS NOT NULL
         THEN ' ON DELETE ' || rc.delete_rule
         ELSE '' END ||
    CASE WHEN rc.update_rule IS NOT NULL
         THEN ' ON UPDATE ' || rc.update_rule
         ELSE '' END || ';' AS fkey_sql
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage ccu
    ON ccu.constraint_name = tc.constraint_name
    AND ccu.table_schema = tc.table_schema
JOIN information_schema.referential_constraints rc
    ON tc.constraint_name = rc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
    AND tc.table_schema = 'public'
ORDER BY tc.table_name, tc.constraint_name;
```

---

## ステップ3: RPC関数のエクスポート

前回取得済みの関数定義を使用します。

```sql
-- すべてのRPC関数定義
SELECT
    p.proname AS function_name,
    pg_get_functiondef(p.oid) AS function_definition
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
AND p.prokind = 'f'
ORDER BY p.proname;
```

---

## ステップ4: インデックスのエクスポート

```sql
-- すべてのインデックス（主キー以外）
SELECT indexdef || ';' AS index_sql
FROM pg_indexes
WHERE schemaname = 'public'
AND indexname NOT LIKE '%_pkey'
ORDER BY tablename, indexname;
```

---

## ステップ5: RLSポリシーのエクスポート

```sql
-- RLS有効化
SELECT
    'ALTER TABLE ' || schemaname || '.' || tablename ||
    ' ENABLE ROW LEVEL SECURITY;' AS enable_rls_sql
FROM pg_tables
WHERE schemaname = 'public'
AND rowsecurity = true
ORDER BY tablename;
```

```sql
-- RLSポリシー定義
SELECT
    'CREATE POLICY "' || policyname || '" ON ' || tablename ||
    ' AS ' || CASE WHEN permissive THEN 'PERMISSIVE' ELSE 'RESTRICTIVE' END ||
    ' FOR ' || cmd ||
    ' TO ' || array_to_string(roles, ', ') ||
    COALESCE(' USING (' || qual || ')', '') ||
    COALESCE(' WITH CHECK (' || with_check || ')', '') || ';' AS policy_sql
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;
```

---

## ステップ6: テスト環境にインポート

**URL**: https://app.supabase.com/project/objpuphnhcjxrsiydjbf/sql

### 実行順序（重要！）

1. **テーブル定義**（外部キーなし）
2. **外部キー制約**
3. **インデックス**
4. **RPC関数**
5. **RLS有効化**
6. **RLSポリシー**

---

## ステップ7: 最小限のテストデータ作成

```sql
-- テスト用ユーザー1名作成
INSERT INTO users (
    user_id,
    email,
    full_name,
    is_approved,
    total_purchases,
    operation_start_date
) VALUES (
    'test-user-001',
    'test@example.com',
    'Test User',
    true,
    1000,
    CURRENT_DATE - INTERVAL '20 days'
);

-- テスト用ペガサス交換ユーザー1名
INSERT INTO users (
    user_id,
    email,
    full_name,
    is_approved,
    total_purchases,
    is_pegasus_exchange,
    pegasus_exchange_date,
    operation_start_date
) VALUES (
    'pegasus-user-001',
    'pegasus@example.com',
    'Pegasus Test User',
    true,
    1000,
    true,
    CURRENT_DATE - INTERVAL '10 days',
    CURRENT_DATE - INTERVAL '20 days'
);

-- affiliate_cycle初期化
INSERT INTO affiliate_cycle (user_id, current_cycle, cum_usdt, available_usdt, phase)
VALUES
    ('test-user-001', 1, 0, 0, 'USDT'),
    ('pegasus-user-001', 1, 0, 0, 'USDT');
```

---

## ステップ8: ペガサス機能のテスト

### 8-1. テスト環境でペガサス制限スクリプト実行

1. `scripts/add-pegasus-personal-profit-restriction.sql` をテスト環境で実行
2. `scripts/update-pegasus-withdrawal-restriction-simple.sql` をテスト環境で実行

### 8-2. テスト用日利データ投入

```sql
-- テスト用: 日利+1.5%を設定
SELECT process_daily_yield_with_cycles(
    CURRENT_DATE::DATE,
    1.5,  -- 日利率
    0.3,  -- マージン率
    false, -- テストモードOFF
    false  -- バリデーションスキップOFF
);
```

### 8-3. 結果確認

```sql
-- 通常ユーザーの日利確認（受け取れるはず）
SELECT * FROM user_daily_profit
WHERE user_id = 'test-user-001'
ORDER BY profit_date DESC LIMIT 5;

-- ペガサスユーザーの日利確認（受け取れないはず）
SELECT * FROM user_daily_profit
WHERE user_id = 'pegasus-user-001'
ORDER BY profit_date DESC LIMIT 5;

-- 出金テスト（ペガサスは拒否されるはず）
SELECT * FROM create_withdrawal_request(
    'pegasus-user-001',
    50,
    'USDT',
    'TRXxxxxxxxxxxxxx',
    'coinw',
    NULL
);
```

---

## ステップ9: 本番環境への適用（テスト成功後のみ）

### 本番Supabaseで実行

1. `scripts/add-pegasus-personal-profit-restriction.sql`
2. `scripts/update-pegasus-withdrawal-restriction-simple.sql`

### 実行後の確認

```sql
-- ペガサスユーザーの日利が停止しているか確認
SELECT
    u.user_id,
    u.full_name,
    u.is_pegasus_exchange,
    udp.profit_date,
    udp.profit_usd
FROM users u
LEFT JOIN user_daily_profit udp ON u.user_id = udp.user_id
WHERE u.is_pegasus_exchange = true
ORDER BY udp.profit_date DESC
LIMIT 20;
```

---

## 📝 チェックリスト

### テスト環境構築
- [ ] テーブル定義エクスポート完了
- [ ] テーブル定義インポート完了
- [ ] 外部キー制約インポート完了
- [ ] インデックスインポート完了
- [ ] RPC関数インポート完了
- [ ] RLSポリシーインポート完了
- [ ] テストデータ作成完了

### ペガサス機能テスト
- [ ] ペガサス制限スクリプト実行完了
- [ ] テスト日利データ投入
- [ ] 通常ユーザーの日利受取確認
- [ ] ペガサスユーザーの日利停止確認
- [ ] ペガサスユーザーの出金拒否確認

### 本番環境適用
- [ ] 本番環境でスクリプト実行
- [ ] ペガサスユーザーの日利停止確認
- [ ] システムログ確認

---

**所要時間**: 約2〜3時間
**推奨**: 複数人でダブルチェック
