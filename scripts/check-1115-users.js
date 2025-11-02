// 11/15運用開始ユーザーに11/1の日利が誤って配布されていないか確認

const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
const path = require('path');

// .env.localファイルを手動で読み込む
const envPath = path.join(__dirname, '..', '.env.local');
const envFile = fs.readFileSync(envPath, 'utf8');
const envVars = {};
envFile.split('\n').forEach(line => {
  const match = line.match(/^([^=]+)=(.*)$/);
  if (match) {
    envVars[match[1]] = match[2];
  }
});

const supabase = createClient(
  envVars.NEXT_PUBLIC_SUPABASE_URL,
  envVars.SUPABASE_SERVICE_ROLE_KEY || envVars.NEXT_PUBLIC_SUPABASE_ANON_KEY
);

async function checkOperationStartDates() {
  console.log('='.repeat(80));
  console.log('11/15運用開始ユーザーの11/1日利配布チェック');
  console.log('='.repeat(80));

  // 1. 11/15運用開始のユーザーのみを取得
  const { data: users1115, error: usersError } = await supabase
    .from('users')
    .select('user_id, email, full_name, operation_start_date, has_approved_nft')
    .eq('operation_start_date', '2025-11-15');

  if (usersError) {
    console.error('❌ ユーザー取得エラー:', usersError);
    return;
  }

  console.log(`\n📊 11/15運用開始ユーザー数: ${users1115.length}名\n`);

  if (users1115.length === 0) {
    console.log('✅ 11/15運用開始のユーザーはいません');
    return;
  }

  // 2. 各ユーザーの11/1の日利配布状況を確認
  let errorCount = 0;
  for (const user of users1115) {
    const { data: profits, error: profitsError } = await supabase
      .from('nft_daily_profit')
      .select('nft_id, date, daily_profit, yield_rate')
      .eq('user_id', user.user_id)
      .eq('date', '2024-11-01');

    if (profitsError) {
      console.error(`❌ ${user.email} の日利取得エラー:`, profitsError);
      continue;
    }

    if (profits && profits.length > 0) {
      errorCount++;
      console.log(`❌ ERROR: ${user.email} (${user.full_name})`);
      console.log(`   運用開始日: ${user.operation_start_date}`);
      console.log(`   11/1に配布された日利: ${profits.length}件`);
      console.log(`   配布額合計: $${profits.reduce((sum, p) => sum + parseFloat(p.daily_profit), 0).toFixed(2)}`);
      console.log('');
    } else {
      console.log(`✅ OK: ${user.email} - 11/1の日利配布なし（正常）`);
    }
  }

  console.log('\n' + '='.repeat(80));
  console.log(`チェック結果: ${users1115.length}名中 ${errorCount}名にエラー`);
  console.log('='.repeat(80));

  // 3. 全体の運用開始日別統計
  console.log('\n📊 運用開始日別の11/1日利配布統計:\n');

  const { data: allUsers, error: allUsersError } = await supabase
    .from('users')
    .select('user_id, operation_start_date')
    .not('operation_start_date', 'is', null)
    .eq('has_approved_nft', true);

  if (!allUsersError && allUsers) {
    const stats = {};

    for (const user of allUsers) {
      const opDate = user.operation_start_date;
      if (!stats[opDate]) {
        stats[opDate] = { total: 0, received: 0 };
      }
      stats[opDate].total++;

      // 11/1の日利配布を確認
      const { data: profits } = await supabase
        .from('nft_daily_profit')
        .select('user_id')
        .eq('user_id', user.user_id)
        .eq('date', '2024-11-01')
        .limit(1);

      if (profits && profits.length > 0) {
        stats[opDate].received++;
      }
    }

    // 結果を表示
    const sortedDates = Object.keys(stats).sort().reverse().slice(0, 10);
    for (const date of sortedDates) {
      const stat = stats[date];
      const shouldReceive = date <= '2024-11-01';
      const status = shouldReceive
        ? (stat.received === stat.total ? '✅' : '⚠️')
        : (stat.received === 0 ? '✅' : '❌');

      console.log(`${status} ${date}: ${stat.total}名中${stat.received}名が11/1の日利を受取 ${shouldReceive ? '(配布されるべき)' : '(配布されるべきではない)'}`);
    }
  }

  console.log('\n');
}

checkOperationStartDates().catch(console.error);
