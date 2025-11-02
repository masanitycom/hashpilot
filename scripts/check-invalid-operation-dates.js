// 運用開始日が1日または15日以外の異常データを確認

const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
const path = require('path');

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

async function checkInvalidOperationDates() {
  console.log('='.repeat(80));
  console.log('運用開始日の異常データチェック');
  console.log('='.repeat(80));
  console.log('\n正しい運用開始日: 毎月1日または15日のみ\n');

  const { data: allUsers, error } = await supabase
    .from('users')
    .select('user_id, email, full_name, operation_start_date, has_approved_nft')
    .not('operation_start_date', 'is', null)
    .order('operation_start_date', { ascending: false });

  if (error) {
    console.error('❌ エラー:', error);
    return;
  }

  console.log(`総ユーザー数: ${allUsers.length}名\n`);

  // 運用開始日別に集計
  const dateStats = {};
  const invalidDates = [];

  for (const user of allUsers) {
    const opDate = user.operation_start_date;
    const date = new Date(opDate);
    const day = date.getDate();

    if (!dateStats[opDate]) {
      dateStats[opDate] = { count: 0, users: [] };
    }
    dateStats[opDate].count++;
    dateStats[opDate].users.push(user);

    // 1日または15日以外は異常
    if (day !== 1 && day !== 15) {
      invalidDates.push({
        date: opDate,
        day: day,
        user: user
      });
    }
  }

  // 異常データの表示
  if (invalidDates.length > 0) {
    console.log(`❌ 異常な運用開始日が見つかりました: ${invalidDates.length}件\n`);

    const groupedInvalid = {};
    invalidDates.forEach(item => {
      if (!groupedInvalid[item.date]) {
        groupedInvalid[item.date] = [];
      }
      groupedInvalid[item.date].push(item.user);
    });

    for (const [date, users] of Object.entries(groupedInvalid)) {
      const d = new Date(date);
      console.log(`\n❌ ${date} (${d.getDate()}日) - ${users.length}名`);
      users.forEach(user => {
        console.log(`   - ${user.email} (${user.full_name})`);
      });
    }
  } else {
    console.log('✅ 全ての運用開始日が正しい（1日または15日）\n');
  }

  // 運用開始日別の統計（最新10件）
  console.log('\n' + '='.repeat(80));
  console.log('運用開始日別の統計（最新10件）');
  console.log('='.repeat(80) + '\n');

  const sortedDates = Object.keys(dateStats).sort().reverse().slice(0, 10);
  for (const date of sortedDates) {
    const d = new Date(date);
    const day = d.getDate();
    const status = (day === 1 || day === 15) ? '✅' : '❌';
    console.log(`${status} ${date} (${day}日): ${dateStats[date].count}名`);
  }

  console.log('\n');
}

checkInvalidOperationDates().catch(console.error);
