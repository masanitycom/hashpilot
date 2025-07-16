// 正しい関数名を使用した日利ユーザー調査
// 2025-01-16 実行

const { createClient } = require('@supabase/supabase-js');

// 環境変数を直接設定
const supabaseUrl = 'https://soghqozaxfswtxxbgeer.supabase.co';
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNvZ2hxb3pheGZzd3R4eGJnZWVyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAxNTA3NTUsImV4cCI6MjA2NTcyNjc1NX0.dhHJiyDIsjDEMGJIEpIbUdVbtaAzTOPHUu8YpMjMWM8';

const supabase = createClient(supabaseUrl, supabaseAnonKey);

async function correctDailyProfitInvestigation() {
    console.log('=== 正しい関数名を使用した日利ユーザー調査 ===\n');
    
    try {
        // 1. 既存の日利設定を確認
        console.log('1. 既存の日利設定を確認');
        const { data: yieldLogs, error: yieldError } = await supabase
            .from('daily_yield_log')
            .select('*')
            .order('date', { ascending: false })
            .limit(5);
        
        if (yieldError) {
            console.error('Error fetching yield logs:', yieldError);
        } else {
            console.log('最新の日利設定:');
            yieldLogs.forEach((log, index) => {
                console.log(`${index + 1}. ${log.date}: 日利${(log.yield_rate * 100).toFixed(1)}%, マージン${(log.margin_rate * 100).toFixed(1)}%, ユーザー${(log.user_rate * 100).toFixed(1)}%`);
                if (log.total_users) {
                    console.log(`   対象ユーザー: ${log.total_users}人, 配布総額: $${log.total_profit || 0}`);
                }
            });
        }
        
        // 2. admin_post_yield関数を使用したテスト実行
        console.log('\n2. admin_post_yield関数を使用したテスト実行');
        const testDate = new Date().toISOString().split('T')[0];
        
        try {
            const { data: yieldResult, error: yieldResultError } = await supabase
                .rpc('admin_post_yield', {
                    p_date: testDate,
                    p_yield_rate: 0.015,
                    p_margin_rate: 0.30,
                    p_is_month_end: false
                });
            
            if (yieldResultError) {
                console.error('Error calling admin_post_yield:', yieldResultError);
                if (yieldResultError.message.includes('already posted')) {
                    console.log('今日の日利は既に投稿済みです。');
                    
                    // 既存の今日の日利データを確認
                    const { data: todayYieldLog } = await supabase
                        .from('daily_yield_log')
                        .select('*')
                        .eq('date', testDate)
                        .single();
                    
                    if (todayYieldLog) {
                        console.log('今日の日利設定:');
                        console.log(`- 日利率: ${(todayYieldLog.yield_rate * 100).toFixed(1)}%`);
                        console.log(`- ユーザー受取率: ${(todayYieldLog.user_rate * 100).toFixed(1)}%`);
                        console.log(`- 対象ユーザー: ${todayYieldLog.total_users}人`);
                        console.log(`- 配布総額: $${todayYieldLog.total_profit || 0}`);
                    }
                }
            } else {
                console.log('日利処理結果:');
                console.log(`- 成功: ${yieldResult.success}`);
                console.log(`- 対象ユーザー: ${yieldResult.total_users}人`);
                console.log(`- ユーザー配布総額: $${yieldResult.total_user_profit}`);
                console.log(`- 会社利益: $${yieldResult.total_company_profit}`);
            }
        } catch (err) {
            console.error('Exception calling admin_post_yield:', err);
        }
        
        // 3. 昨日の日利処理結果を確認
        console.log('\n3. 昨日の日利処理結果を確認');
        const yesterday = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString().split('T')[0];
        
        try {
            const { data: yesterdayYieldResult, error: yesterdayError } = await supabase
                .rpc('admin_post_yield', {
                    p_date: yesterday,
                    p_yield_rate: 0.015,
                    p_margin_rate: 0.30,
                    p_is_month_end: false
                });
            
            if (yesterdayError) {
                if (yesterdayError.message.includes('already posted')) {
                    console.log('昨日の日利は既に投稿済みです。');
                    
                    // 昨日の日利データを確認
                    const { data: yesterdayYieldLog } = await supabase
                        .from('daily_yield_log')
                        .select('*')
                        .eq('date', yesterday)
                        .single();
                    
                    if (yesterdayYieldLog) {
                        console.log('昨日の日利設定:');
                        console.log(`- 日利率: ${(yesterdayYieldLog.yield_rate * 100).toFixed(1)}%`);
                        console.log(`- ユーザー受取率: ${(yesterdayYieldLog.user_rate * 100).toFixed(1)}%`);
                        console.log(`- 対象ユーザー: ${yesterdayYieldLog.total_users}人`);
                        console.log(`- 配布総額: $${yesterdayYieldLog.total_profit || 0}`);
                    }
                } else {
                    console.error('Error calling admin_post_yield for yesterday:', yesterdayError);
                }
            } else {
                console.log('昨日の日利処理結果:');
                console.log(`- 対象ユーザー: ${yesterdayYieldResult.total_users}人`);
                console.log(`- ユーザー配布総額: $${yesterdayYieldResult.total_user_profit}`);
            }
        } catch (err) {
            console.error('Exception calling admin_post_yield for yesterday:', err);
        }
        
        // 4. 直接テーブルからデータを確認
        console.log('\n4. 直接テーブルからデータを確認');
        
        // daily_yield_logテーブルから最新データを取得
        const { data: recentYieldLogs, error: recentError } = await supabase
            .from('daily_yield_log')
            .select('*')
            .gte('date', new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString().split('T')[0])
            .order('date', { ascending: false });
        
        if (recentError) {
            console.error('Error fetching recent yield logs:', recentError);
        } else {
            console.log('過去7日間の日利設定:');
            recentYieldLogs.forEach((log, index) => {
                console.log(`${index + 1}. ${log.date}: ${log.total_users || 0}人に$${log.total_profit || 0}配布`);
            });
        }
        
        // 5. アクティブなユーザーと投資額の確認
        console.log('\n5. アクティブなユーザーと投資額の確認');
        
        // システムヘルスチェックから統計情報を取得
        const { data: healthData, error: healthError } = await supabase
            .rpc('system_health_check');
        
        if (healthError) {
            console.error('Error calling system_health_check:', healthError);
        } else {
            console.log('システム統計:');
            healthData.forEach(item => {
                console.log(`- ${item.component}: ${item.message}`);
            });
        }
        
        // 6. 日利対象ユーザーの推定
        console.log('\n6. 日利対象ユーザーの推定');
        
        // 最新の日利ログから対象ユーザー数を取得
        const latestYieldLog = recentYieldLogs && recentYieldLogs.length > 0 ? recentYieldLogs[0] : null;
        
        if (latestYieldLog) {
            console.log('最新の日利配布状況:');
            console.log(`- 配布日: ${latestYieldLog.date}`);
            console.log(`- 対象ユーザー: ${latestYieldLog.total_users || 0}人`);
            console.log(`- 配布総額: $${latestYieldLog.total_profit || 0}`);
            console.log(`- 平均日利: $${latestYieldLog.total_users > 0 ? (latestYieldLog.total_profit / latestYieldLog.total_users).toFixed(2) : 0}`);
            console.log(`- 日利率: ${(latestYieldLog.yield_rate * 100).toFixed(1)}%`);
            console.log(`- ユーザー受取率: ${(latestYieldLog.user_rate * 100).toFixed(1)}%`);
        }
        
        // 7. 日利が発生していない理由の分析
        console.log('\n7. 日利が発生していない理由の分析');
        
        if (!latestYieldLog || latestYieldLog.total_users === 0) {
            console.log('日利が発生していない可能性のある理由:');
            console.log('1. NFT承認済みユーザーがいない');
            console.log('2. 購入から15日経過していない');
            console.log('3. 日利処理が実行されていない');
            console.log('4. RLSポリシーの制限');
            console.log('5. テーブル構造の問題');
        } else {
            console.log(`現在 ${latestYieldLog.total_users}人のユーザーが日利を受け取っています。`);
        }
        
    } catch (error) {
        console.error('Investigation failed:', error);
    }
}

correctDailyProfitInvestigation();