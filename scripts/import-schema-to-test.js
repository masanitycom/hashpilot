/**
 * テスト環境にスキーマをインポートするNode.jsスクリプト
 */

const { Client } = require('pg');
const fs = require('fs');

const client = new Client({
  host: 'db.objpuphnhcjxrsiydjbf.supabase.co',
  port: 5432,
  database: 'postgres',
  user: 'postgres',
  password: '8tZ8dZUYScKR',
  ssl: { rejectUnauthorized: false }
});

async function importSchema() {
  console.log('📡 テストデータベースに接続中...\n');

  try {
    await client.connect();
    console.log('✅ 接続成功！\n');

    console.log('📄 SQLファイルを読み込み中...');
    const sql = fs.readFileSync('production-schema-clean.sql', 'utf8');
    console.log(`   ファイルサイズ: ${(sql.length / 1024).toFixed(2)} KB\n`);

    console.log('🔄 スキーマをインポート中...');
    console.log('   （この処理には数分かかる場合があります）\n');

    // 大きなSQLを一度に実行
    await client.query(sql);

    console.log('✅ インポート完了！\n');

    // 確認: テーブル数を取得
    const tablesResult = await client.query(`
      SELECT COUNT(*) as table_count
      FROM pg_tables
      WHERE schemaname = 'public'
    `);
    console.log(`📊 作成されたテーブル数: ${tablesResult.rows[0].table_count}`);

    // 確認: 関数数を取得
    const functionsResult = await client.query(`
      SELECT COUNT(*) as function_count
      FROM pg_proc p
      JOIN pg_namespace n ON p.pronamespace = n.oid
      WHERE n.nspname = 'public' AND p.prokind = 'f'
    `);
    console.log(`⚙️  作成されたRPC関数数: ${functionsResult.rows[0].function_count}\n`);

    await client.end();
    console.log('✅ すべて完了！');

  } catch (err) {
    console.error('❌ エラーが発生しました:');
    console.error(err.message);

    if (err.message.includes('already exists')) {
      console.log('\n💡 ヒント: テーブルまたは関数がすでに存在します。');
      console.log('   既存のスキーマを削除してから再実行してください：\n');
      console.log('   DROP SCHEMA public CASCADE;');
      console.log('   CREATE SCHEMA public;');
      console.log('   GRANT ALL ON SCHEMA public TO postgres;');
      console.log('   GRANT ALL ON SCHEMA public TO public;');
    }

    process.exit(1);
  }
}

importSchema();
