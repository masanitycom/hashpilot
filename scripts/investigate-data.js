const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');

const supabase = createClient(
  'https://soghqozaxfswtxxbgeer.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNvZ2hxb3pheGZzd3R4eGJnZWVyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAxNTA3NTUsImV4cCI6MjA2NTcyNjc1NX0.dhHJiyDIsjDEMGJIEpIbUdVbtaAzTOPHUu8YpMjMWM8'
);

async function investigateUsers() {
  console.log('=== HASHPILOT 日利状況緊急調査 ===\n');
  
  // 1. ユーザー「7A9637」の基本情報
  console.log('1. ユーザー「7A9637」の基本情報');
  const { data: user7A9637, error: userError1 } = await supabase
    .from('users')
    .select('*')
    .eq('user_id', '7A9637')
    .single();
  
  if (userError1) {
    console.log('エラー:', userError1.message);
  } else {
    console.log('結果:', user7A9637);
  }
  console.log('');

  // 2. ユーザー「7A9637」の日利記録
  console.log('2. ユーザー「7A9637」の日利記録');
  const { data: profit7A9637, error: profitError1 } = await supabase
    .from('user_daily_profit')
    .select('*')
    .eq('user_id', '7A9637')
    .order('date', { ascending: false });
  
  if (profitError1) {
    console.log('エラー:', profitError1.message);
  } else {
    console.log('件数:', profit7A9637?.length || 0);
    console.log('記録:', profit7A9637);
  }
  console.log('');

  // 3. ユーザー「7A9637」のNFT購入状況
  console.log('3. ユーザー「7A9637」のNFT購入状況');
  const { data: purchases7A9637, error: purchaseError1 } = await supabase
    .from('purchases')
    .select('*')
    .eq('user_id', '7A9637')
    .order('created_at', { ascending: false });
  
  if (purchaseError1) {
    console.log('エラー:', purchaseError1.message);
  } else {
    console.log('件数:', purchases7A9637?.length || 0);
    console.log('購入記録:', purchases7A9637);
  }
  console.log('');

  // 4. ユーザー「7A9637」のサイクル状況
  console.log('4. ユーザー「7A9637」のサイクル状況');
  const { data: cycle7A9637, error: cycleError1 } = await supabase
    .from('affiliate_cycle')
    .select('*')
    .eq('user_id', '7A9637')
    .single();
  
  if (cycleError1) {
    console.log('エラー:', cycleError1.message);
  } else {
    console.log('結果:', cycle7A9637);
  }
  console.log('');

  // 5. ユーザー「2BF53B」の基本情報
  console.log('5. ユーザー「2BF53B」の基本情報');
  const { data: user2BF53B, error: userError2 } = await supabase
    .from('users')
    .select('*')
    .eq('user_id', '2BF53B')
    .single();
  
  if (userError2) {
    console.log('エラー:', userError2.message);
  } else {
    console.log('結果:', user2BF53B);
  }
  console.log('');

  // 6. ユーザー「2BF53B」の日利記録
  console.log('6. ユーザー「2BF53B」の日利記録');
  const { data: profit2BF53B, error: profitError2 } = await supabase
    .from('user_daily_profit')
    .select('*')
    .eq('user_id', '2BF53B')
    .order('date', { ascending: false });
  
  if (profitError2) {
    console.log('エラー:', profitError2.message);
  } else {
    console.log('件数:', profit2BF53B?.length || 0);
    console.log('記録:', profit2BF53B);
  }
  console.log('');

  // 7. ユーザー「2BF53B」のNFT購入状況
  console.log('7. ユーザー「2BF53B」のNFT購入状況');
  const { data: purchases2BF53B, error: purchaseError2 } = await supabase
    .from('purchases')
    .select('*')
    .eq('user_id', '2BF53B')
    .order('created_at', { ascending: false });
  
  if (purchaseError2) {
    console.log('エラー:', purchaseError2.message);
  } else {
    console.log('件数:', purchases2BF53B?.length || 0);
    console.log('購入記録:', purchases2BF53B);
  }
  console.log('');

  // 8. ユーザー「2BF53B」のサイクル状況
  console.log('8. ユーザー「2BF53B」のサイクル状況');
  const { data: cycle2BF53B, error: cycleError2 } = await supabase
    .from('affiliate_cycle')
    .select('*')
    .eq('user_id', '2BF53B')
    .single();
  
  if (cycleError2) {
    console.log('エラー:', cycleError2.message);
  } else {
    console.log('結果:', cycle2BF53B);
  }
  console.log('');

  // 9. 全体の運用開始ユーザー一覧
  console.log('9. 全体の運用開始ユーザー一覧（has_approved_nft = true）');
  const { data: approvedUsers, error: approvedError } = await supabase
    .from('users')
    .select('user_id, email, full_name, total_purchases, has_approved_nft, created_at')
    .eq('has_approved_nft', true)
    .order('created_at', { ascending: false });
  
  if (approvedError) {
    console.log('エラー:', approvedError.message);
  } else {
    console.log('承認済みユーザー数:', approvedUsers?.length || 0);
    console.log('ユーザー一覧:', approvedUsers);
  }
  console.log('');

  // 10. 最新の日利記録全体
  console.log('10. 最新の日利記録全体（最新10件）');
  const { data: latestProfits, error: latestError } = await supabase
    .from('user_daily_profit')
    .select('*')
    .order('date', { ascending: false })
    .order('created_at', { ascending: false })
    .limit(10);
  
  if (latestError) {
    console.log('エラー:', latestError.message);
  } else {
    console.log('最新日利記録件数:', latestProfits?.length || 0);
    console.log('記録:', latestProfits);
  }
  console.log('');

  // 11. 最新の日利設定ログ
  console.log('11. 最新の日利設定ログ');
  const { data: yieldSettings, error: yieldError } = await supabase
    .from('daily_yield_log')
    .select('*')
    .order('date', { ascending: false })
    .limit(5);
  
  if (yieldError) {
    console.log('エラー:', yieldError.message);
  } else {
    console.log('設定記録件数:', yieldSettings?.length || 0);
    console.log('設定:', yieldSettings);
  }
  console.log('');

  // 12. 運用開始条件チェック
  console.log('12. 運用開始条件チェック（15日経過確認）');
  const { data: operationCheck, error: operationError } = await supabase
    .from('purchases')
    .select('user_id, created_at, admin_approved, nft_quantity, amount_usd')
    .eq('admin_approved', true)
    .order('created_at', { ascending: false });
  
  if (operationError) {
    console.log('エラー:', operationError.message);
  } else {
    console.log('承認済み購入件数:', operationCheck?.length || 0);
    
    // 運用開始判定
    if (operationCheck && operationCheck.length > 0) {
      console.log('運用開始判定:');
      operationCheck.forEach(purchase => {
        const purchaseDate = new Date(purchase.created_at);
        const operationStartDate = new Date(purchaseDate);
        operationStartDate.setDate(operationStartDate.getDate() + 15);
        const today = new Date();
        const isStarted = today >= operationStartDate;
        const daysSinceStart = Math.floor((today - operationStartDate) / (1000 * 60 * 60 * 24));
        
        console.log(`  ${purchase.user_id}: 購入日=${purchaseDate.toISOString().split('T')[0]}, 運用開始日=${operationStartDate.toISOString().split('T')[0]}, 状態=${isStarted ? 'STARTED' : 'WAITING'}, 経過日数=${daysSinceStart}`);
      });
    }
  }
  console.log('');

  // 13. 特定日の日利実行ログ確認
  console.log('13. 最新のシステムログ（日利関連）');
  const { data: systemLogs, error: logError } = await supabase
    .from('system_logs')
    .select('*')
    .or('operation.ilike.%yield%,operation.ilike.%profit%,operation.ilike.%batch%')
    .order('created_at', { ascending: false })
    .limit(10);
  
  if (logError) {
    console.log('エラー:', logError.message);
  } else {
    console.log('システムログ件数:', systemLogs?.length || 0);
    console.log('ログ:', systemLogs);
  }
  console.log('');

  console.log('=== 調査完了 ===');
}

investigateUsers().catch(console.error);