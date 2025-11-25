/**
 * 本番Supabaseからスキーマを完全にエクスポートするNode.jsスクリプト
 *
 * 使い方:
 * 1. npm install pg
 * 2. node scripts/export-schema.js
 * 3. schema-export.sql ファイルが生成される
 */

const { Client } = require('pg');
const fs = require('fs');

const client = new Client({
  host: 'db.soghqozaxfswtxxbgeer.supabase.co',
  port: 5432,
  database: 'postgres',
  user: 'postgres',
  password: 'y1TuMih%%wFrMc3H',
  ssl: { rejectUnauthorized: false }
});

async function exportSchema() {
  console.log('📡 本番データベースに接続中...\n');
  await client.connect();

  let sql = '';

  // ============================================================
  // 1. テーブル定義のエクスポート
  // ============================================================
  console.log('📋 テーブル一覧を取得中...');

  const tablesResult = await client.query(`
    SELECT tablename
    FROM pg_tables
    WHERE schemaname = 'public'
    ORDER BY tablename
  `);

  const tables = tablesResult.rows.map(r => r.tablename);
  console.log(`   見つかったテーブル: ${tables.length}個\n`);

  sql += '-- ============================================================\n';
  sql += '-- テーブル定義\n';
  sql += '-- ============================================================\n\n';

  for (const table of tables) {
    console.log(`   ${table} の定義を取得中...`);

    // 列定義取得
    const columnsResult = await client.query(`
      SELECT
        column_name,
        data_type,
        character_maximum_length,
        numeric_precision,
        numeric_scale,
        is_nullable,
        column_default,
        udt_name
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = $1
      ORDER BY ordinal_position
    `, [table]);

    sql += `CREATE TABLE IF NOT EXISTS ${table} (\n`;

    const columnDefs = columnsResult.rows.map(col => {
      let def = `  ${col.column_name} `;

      // データ型の処理
      if (col.data_type === 'character varying') {
        def += `VARCHAR(${col.character_maximum_length || 255})`;
      } else if (col.data_type === 'character') {
        def += `CHAR(${col.character_maximum_length})`;
      } else if (col.data_type === 'numeric' && col.numeric_precision) {
        def += `NUMERIC(${col.numeric_precision},${col.numeric_scale || 0})`;
      } else if (col.data_type === 'timestamp without time zone') {
        def += 'TIMESTAMP';
      } else if (col.data_type === 'timestamp with time zone') {
        def += 'TIMESTAMPTZ';
      } else if (col.data_type === 'ARRAY') {
        def += col.udt_name.replace('_', '') + '[]';
      } else if (col.data_type === 'USER-DEFINED') {
        def += col.udt_name;
      } else {
        def += col.data_type.toUpperCase();
      }

      // NULL制約
      if (col.is_nullable === 'NO') {
        def += ' NOT NULL';
      }

      // デフォルト値
      if (col.column_default) {
        def += ` DEFAULT ${col.column_default}`;
      }

      return def;
    });

    sql += columnDefs.join(',\n');
    sql += '\n);\n\n';
  }

  // ============================================================
  // 2. 主キー制約
  // ============================================================
  console.log('\n🔑 主キー制約を取得中...');

  const pkResult = await client.query(`
    SELECT
      tc.table_name,
      tc.constraint_name,
      string_agg(kcu.column_name, ', ' ORDER BY kcu.ordinal_position) AS columns
    FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage kcu
      ON tc.constraint_name = kcu.constraint_name
      AND tc.table_schema = kcu.table_schema
    WHERE tc.constraint_type = 'PRIMARY KEY'
      AND tc.table_schema = 'public'
    GROUP BY tc.table_name, tc.constraint_name
    ORDER BY tc.table_name
  `);

  sql += '-- ============================================================\n';
  sql += '-- 主キー制約\n';
  sql += '-- ============================================================\n\n';

  for (const pk of pkResult.rows) {
    sql += `ALTER TABLE ${pk.table_name} ADD CONSTRAINT ${pk.constraint_name} PRIMARY KEY (${pk.columns});\n`;
  }
  sql += '\n';

  // ============================================================
  // 3. 外部キー制約
  // ============================================================
  console.log('🔗 外部キー制約を取得中...');

  const fkResult = await client.query(`
    SELECT
      tc.table_name,
      tc.constraint_name,
      kcu.column_name,
      ccu.table_name AS foreign_table_name,
      ccu.column_name AS foreign_column_name,
      rc.delete_rule,
      rc.update_rule
    FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage kcu
      ON tc.constraint_name = kcu.constraint_name
      AND tc.table_schema = kcu.table_schema
    JOIN information_schema.constraint_column_usage ccu
      ON ccu.constraint_name = tc.constraint_name
      AND ccu.table_schema = tc.table_schema
    LEFT JOIN information_schema.referential_constraints rc
      ON tc.constraint_name = rc.constraint_name
      AND tc.table_schema = rc.constraint_schema
    WHERE tc.constraint_type = 'FOREIGN KEY'
      AND tc.table_schema = 'public'
    ORDER BY tc.table_name, tc.constraint_name
  `);

  sql += '-- ============================================================\n';
  sql += '-- 外部キー制約\n';
  sql += '-- ============================================================\n\n';

  for (const fk of fkResult.rows) {
    sql += `ALTER TABLE ${fk.table_name} ADD CONSTRAINT ${fk.constraint_name} `;
    sql += `FOREIGN KEY (${fk.column_name}) `;
    sql += `REFERENCES ${fk.foreign_table_name}(${fk.foreign_column_name})`;

    if (fk.delete_rule && fk.delete_rule !== 'NO ACTION') {
      sql += ` ON DELETE ${fk.delete_rule}`;
    }
    if (fk.update_rule && fk.update_rule !== 'NO ACTION') {
      sql += ` ON UPDATE ${fk.update_rule}`;
    }
    sql += ';\n';
  }
  sql += '\n';

  // ============================================================
  // 4. インデックス
  // ============================================================
  console.log('📇 インデックスを取得中...');

  const indexResult = await client.query(`
    SELECT indexdef
    FROM pg_indexes
    WHERE schemaname = 'public'
      AND indexname NOT LIKE '%_pkey'
    ORDER BY tablename, indexname
  `);

  sql += '-- ============================================================\n';
  sql += '-- インデックス\n';
  sql += '-- ============================================================\n\n';

  for (const idx of indexResult.rows) {
    sql += idx.indexdef + ';\n';
  }
  sql += '\n';

  // ============================================================
  // 5. RPC関数
  // ============================================================
  console.log('⚙️  RPC関数を取得中...');

  const funcResult = await client.query(`
    SELECT
      p.proname AS function_name,
      pg_get_functiondef(p.oid) AS function_definition
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public'
      AND p.prokind = 'f'
    ORDER BY p.proname
  `);

  console.log(`   見つかった関数: ${funcResult.rows.length}個\n`);

  sql += '-- ============================================================\n';
  sql += '-- RPC関数\n';
  sql += '-- ============================================================\n\n';

  for (const func of funcResult.rows) {
    sql += `-- Function: ${func.function_name}\n`;
    sql += func.function_definition + '\n\n';
  }

  // ============================================================
  // 6. RLS有効化
  // ============================================================
  console.log('🔒 RLS設定を取得中...');

  const rlsTablesResult = await client.query(`
    SELECT schemaname, tablename
    FROM pg_tables
    WHERE schemaname = 'public'
      AND rowsecurity = true
    ORDER BY tablename
  `);

  sql += '-- ============================================================\n';
  sql += '-- RLS有効化\n';
  sql += '-- ============================================================\n\n';

  for (const tbl of rlsTablesResult.rows) {
    sql += `ALTER TABLE ${tbl.tablename} ENABLE ROW LEVEL SECURITY;\n`;
  }
  sql += '\n';

  // ============================================================
  // 7. RLSポリシー
  // ============================================================
  console.log('🛡️  RLSポリシーを取得中...');

  const policiesResult = await client.query(`
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
    WHERE schemaname = 'public'
    ORDER BY tablename, policyname
  `);

  console.log(`   見つかったポリシー: ${policiesResult.rows.length}個\n`);

  sql += '-- ============================================================\n';
  sql += '-- RLSポリシー\n';
  sql += '-- ============================================================\n\n';

  for (const policy of policiesResult.rows) {
    sql += `CREATE POLICY "${policy.policyname}" ON ${policy.tablename}\n`;
    sql += `  AS ${policy.permissive ? 'PERMISSIVE' : 'RESTRICTIVE'}\n`;
    sql += `  FOR ${policy.cmd}\n`;
    sql += `  TO ${policy.roles.join(', ')}\n`;

    if (policy.qual) {
      sql += `  USING (${policy.qual})\n`;
    }
    if (policy.with_check) {
      sql += `  WITH CHECK (${policy.with_check})\n`;
    }
    sql += ';\n\n';
  }

  // ============================================================
  // ファイルに書き込み
  // ============================================================
  const outputFile = 'schema-export.sql';
  fs.writeFileSync(outputFile, sql);

  console.log('✅ エクスポート完了！');
  console.log(`📁 ファイル: ${outputFile}`);
  console.log(`📊 ファイルサイズ: ${(fs.statSync(outputFile).size / 1024).toFixed(2)} KB\n`);

  await client.end();
}

// 実行
exportSchema().catch(err => {
  console.error('❌ エラーが発生しました:');
  console.error(err);
  process.exit(1);
});
