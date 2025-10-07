#!/usr/bin/env node
/**
 * NFT利益追跡システムのセットアップスクリプト
 * テーブル作成 → 既存データ移行を実行
 */

const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
const path = require('path');

// Supabaseクライアントの初期化
const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseKey) {
  console.error('❌ 環境変数が設定されていません');
  console.error('NEXT_PUBLIC_SUPABASE_URL:', supabaseUrl ? '✅' : '❌');
  console.error('SUPABASE_SERVICE_ROLE_KEY:', supabaseKey ? '✅' : '❌');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

async function executeSqlFile(filePath, description) {
  console.log(`\n📄 ${description}`);
  console.log(`   ファイル: ${filePath}`);

  try {
    const sql = fs.readFileSync(filePath, 'utf8');

    // PostgreSQLの場合、RPCを使って実行
    const { data, error } = await supabase.rpc('exec_sql', { sql_query: sql });

    if (error) {
      // exec_sql関数が存在しない場合は、直接SQLを実行する別の方法を試す
      console.log('   ⚠️  exec_sql関数が見つかりません。別の方法で実行します...');

      // SQLを分割して実行
      const statements = sql
        .split(';')
        .map(s => s.trim())
        .filter(s => s.length > 0 && !s.startsWith('--'));

      console.log(`   📊 ${statements.length}個のSQL文を実行します`);

      for (let i = 0; i < statements.length; i++) {
        const stmt = statements[i];
        if (stmt.includes('CREATE TABLE') || stmt.includes('CREATE INDEX') ||
            stmt.includes('CREATE VIEW') || stmt.includes('CREATE OR REPLACE')) {
          console.log(`   ⏳ [${i + 1}/${statements.length}] 実行中...`);

          // Supabase管理APIを使用
          const response = await fetch(`${supabaseUrl}/rest/v1/rpc/exec`, {
            method: 'POST',
            headers: {
              'apikey': supabaseKey,
              'Authorization': `Bearer ${supabaseKey}`,
              'Content-Type': 'application/json',
            },
            body: JSON.stringify({ query: stmt })
          });

          if (!response.ok) {
            console.error(`   ❌ エラー: ${await response.text()}`);
          }
        }
      }

      console.log('   ✅ 完了（手動実行が必要な場合があります）');
      return;
    }

    console.log('   ✅ 実行成功');
    if (data) {
      console.log('   📊 結果:', data);
    }

  } catch (err) {
    console.error(`   ❌ エラー:`, err.message);
    throw err;
  }
}

async function main() {
  console.log('🚀 NFT利益追跡システムのセットアップを開始します\n');
  console.log('=' .repeat(60));

  try {
    // ステップ1: テーブル作成
    console.log('\n📋 ステップ1: テーブル・ビュー・関数の作成');
    console.log('-'.repeat(60));
    const createTablePath = path.join(__dirname, 'create-nft-profit-tracking.sql');

    if (!fs.existsSync(createTablePath)) {
      console.error('❌ ファイルが見つかりません:', createTablePath);
      process.exit(1);
    }

    console.log('\n⚠️  このスクリプトはSupabaseの制限により、SQLを直接実行できません。');
    console.log('以下の手順で手動実行してください:\n');
    console.log('1. Supabaseダッシュボードを開く');
    console.log('2. SQL Editorに移動');
    console.log('3. 以下のファイルの内容をコピー&ペーストして実行:');
    console.log(`   📄 ${createTablePath}`);
    console.log(`   📄 ${path.join(__dirname, 'migrate-existing-nfts-to-master.sql')}`);
    console.log('\nまたは、psqlコマンドがある場合:');
    console.log(`   psql $DATABASE_URL -f ${createTablePath}`);
    console.log(`   psql $DATABASE_URL -f ${path.join(__dirname, 'migrate-existing-nfts-to-master.sql')}`);

  } catch (error) {
    console.error('\n❌ セットアップ中にエラーが発生しました:', error);
    process.exit(1);
  }
}

main();
