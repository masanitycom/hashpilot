const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  "https://soghqozaxfswtxxbgeer.supabase.co",
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNvZ2hxb3pheGZzd3R4eGJnZWVyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAxNTA3NTUsImV4cCI6MjA2NTcyNjc1NX0.dhHJiyDIsjDEMGJIEpIbUdVbtaAzTOPHUu8YpMjMWM8"
);

async function createHistoricalData() {
  console.log('🚀 Creating missing historical profit data (7/11-7/15)...');
  
  // まず日利設定を確認
  const { data: yieldSettings, error: yieldError } = await supabase
    .from('daily_yield_log')
    .select('date, yield_rate, user_rate')
    .gte('date', '2025-07-11')
    .lte('date', '2025-07-15')
    .order('date');
    
  if (yieldError) {
    console.error('❌ Error fetching yield settings:', yieldError);
    return;
  }
  
  console.log('📈 Available yield settings:', yieldSettings);
  
  if (!yieldSettings || yieldSettings.length === 0) {
    console.log('⚠️ No yield settings found for 7/11-7/15. Cannot create historical data.');
    return;
  }
  
  // 対象ユーザーを取得
  const { data: users, error: usersError } = await supabase
    .from('users')
    .select('user_id')
    .eq('has_approved_nft', true)
    .gt('total_purchases', 0);
    
  if (usersError) {
    console.error('❌ Error fetching users:', usersError);
    return;
  }
  
  console.log('👥 Target users:', users.length);
  
  // 各ユーザーのNFT数を取得
  const { data: cycles, error: cyclesError } = await supabase
    .from('affiliate_cycle')
    .select('user_id, total_nft_count, phase');
    
  if (cyclesError) {
    console.error('❌ Error fetching cycles:', cyclesError);
    return;
  }
  
  console.log('🔄 User cycles:', cycles.length);
  
  // 各日付・各ユーザーの利益データを作成
  for (const setting of yieldSettings) {
    console.log(`\n📅 Processing date: ${setting.date} (user_rate: ${setting.user_rate})`);
    
    let createdCount = 0;
    
    for (const user of users) {
      const userCycle = cycles.find(c => c.user_id === user.user_id);
      
      if (!userCycle || !userCycle.total_nft_count || userCycle.total_nft_count === 0) {
        continue;
      }
      
      const baseAmount = userCycle.total_nft_count * 1000;
      const dailyProfit = baseAmount * setting.user_rate;
      
      // データ挿入
      const { error: insertError } = await supabase
        .from('user_daily_profit')
        .upsert({
          user_id: user.user_id,
          date: setting.date,
          daily_profit: dailyProfit,
          yield_rate: setting.yield_rate,
          user_rate: setting.user_rate,
          base_amount: baseAmount,
          phase: userCycle.phase || 'USDT'
        }, {
          onConflict: 'user_id,date'
        });
        
      if (insertError) {
        console.error(`❌ Insert error for user ${user.user_id}:`, insertError);
      } else {
        createdCount++;
      }
    }
    
    console.log(`✅ Created ${createdCount} records for ${setting.date}`);
  }
  
  // 結果確認
  const { data: resultCheck, error: resultError } = await supabase
    .from('user_daily_profit')
    .select('date, daily_profit')
    .gte('date', '2025-07-11')
    .lte('date', '2025-07-16')
    .eq('user_id', '7A9637')
    .order('date');
    
  if (!resultError) {
    console.log('\n🎯 User 7A9637 historical data:');
    resultCheck.forEach(r => {
      console.log(`  ${r.date}: $${r.daily_profit}`);
    });
  }
  
  console.log('\n✅ Historical profit data creation completed!');
}

createHistoricalData();