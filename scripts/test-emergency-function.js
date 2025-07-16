// 緊急調査用の関数テスト
const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  'https://soghqozaxfswtxxbgeer.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNvZ2hxb3pheGZzd3R4eGJnZWVyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAxNTA3NTUsImV4cCI6MjA2NTcyNjc1NX0.dhHJiyDIsjDEMGJIEpIbUdVbtaAzTOPHUu8YpMjMWM8'
);

async function testEmergencyFunction() {
  console.log('=== 緊急調査関数テスト ===\n');

  // 1. 関数作成を試行
  console.log('1. 緊急調査関数の作成...');
  const { data: createResult, error: createError } = await supabase.rpc('quick_data_check');
  
  if (createError) {
    console.log('関数作成エラー:', createError.message);
    
    // 2. 代替手段: 基本的な統計情報の取得
    console.log('\n2. 代替手段: 基本データの取得...');
    
    // テーブルの存在確認
    const { data: tableInfo, error: tableError } = await supabase
      .from('information_schema.tables')
      .select('table_name')
      .eq('table_schema', 'public')
      .in('table_name', ['users', 'user_daily_profit', 'purchases', 'affiliate_cycle']);
    
    console.log('テーブル情報:', tableInfo);
    if (tableError) console.log('テーブル確認エラー:', tableError.message);
    
    // 日利設定ログの確認（これは見える）
    const { data: yieldLog, error: yieldError } = await supabase
      .from('daily_yield_log')
      .select('*')
      .order('date', { ascending: false })
      .limit(10);
    
    console.log('日利設定ログ:', yieldLog);
    if (yieldError) console.log('日利設定エラー:', yieldError.message);
    
    // 3. 各テーブルの基本的なカウント取得を試行
    console.log('\n3. 各テーブルのカウント取得...');
    
    const tables = ['users', 'user_daily_profit', 'purchases', 'affiliate_cycle'];
    
    for (const table of tables) {
      const { count, error } = await supabase
        .from(table)
        .select('*', { count: 'exact', head: true });
      
      if (error) {
        console.log(`${table} カウントエラー:`, error.message);
      } else {
        console.log(`${table} 件数:`, count);
      }
    }
    
    // 4. 直接のユーザー検索を試行
    console.log('\n4. 直接のユーザー検索...');
    
    const userIds = ['7A9637', '2BF53B'];
    
    for (const userId of userIds) {
      const { data: userData, error: userError } = await supabase
        .from('users')
        .select('*')
        .eq('user_id', userId);
      
      if (userError) {
        console.log(`ユーザー ${userId} 検索エラー:`, userError.message);
      } else {
        console.log(`ユーザー ${userId} データ:`, userData);
      }
    }
    
  } else {
    console.log('関数実行成功:', createResult);
  }
}

testEmergencyFunction().catch(console.error);