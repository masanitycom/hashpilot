// 現在日利が発生しているユーザーの調査
// 2025-01-16 実行

const { createClient } = require('@supabase/supabase-js');

// 環境変数を直接設定
const supabaseUrl = 'https://soghqozaxfswtxxbgeer.supabase.co';
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNvZ2hxb3pheGZzd3R4eGJnZWVyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAxNTA3NTUsImV4cCI6MjA2NTcyNjc1NX0.dhHJiyDIsjDEMGJIEpIbUdVbtaAzTOPHUu8YpMjMWM8';

const supabase = createClient(supabaseUrl, supabaseAnonKey);

async function investigateDailyProfitUsers() {
    console.log('=== 現在日利が発生しているユーザーの調査 ===\n');
    
    try {
        // 1. 最新の日利記録確認
        console.log('1. 最新の日利記録確認');
        const { data: recentProfits, error: recentError } = await supabase
            .from('user_daily_profit')
            .select('date, daily_profit')
            .gte('date', new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString().split('T')[0])
            .order('date', { ascending: false });
        
        if (recentError) {
            console.error('Error fetching recent profits:', recentError);
        } else {
            const profitByDate = {};
            recentProfits.forEach(row => {
                if (!profitByDate[row.date]) {
                    profitByDate[row.date] = { count: 0, total: 0 };
                }
                profitByDate[row.date].count++;
                profitByDate[row.date].total += parseFloat(row.daily_profit);
            });
            
            console.log('過去7日間の日利記録:');
            Object.entries(profitByDate)
                .sort(([a], [b]) => b.localeCompare(a))
                .forEach(([date, data]) => {
                    console.log(`${date}: ${data.count}人, 合計$${data.total.toFixed(2)}, 平均$${(data.total/data.count).toFixed(2)}`);
                });
        }
        
        // 2. 本日の日利受取ユーザー一覧
        console.log('\n2. 本日の日利受取ユーザー一覧');
        const today = new Date().toISOString().split('T')[0];
        const { data: todayProfits, error: todayError } = await supabase
            .from('user_daily_profit')
            .select(`
                user_id,
                daily_profit,
                yield_rate,
                user_rate,
                base_amount,
                phase,
                users!inner(email, full_name, total_purchases, has_approved_nft)
            `)
            .eq('date', today)
            .order('daily_profit', { ascending: false })
            .limit(20);
        
        if (todayError) {
            console.error('Error fetching today profits:', todayError);
        } else {
            console.log(`本日の日利受取者: ${todayProfits.length}人`);
            todayProfits.forEach((row, index) => {
                console.log(`${index + 1}. ${row.users.email} (${row.users.full_name})`);
                console.log(`   日利: $${row.daily_profit}, 運用額: $${row.base_amount}, フェーズ: ${row.phase}`);
            });
        }
        
        // 3. 昨日の日利受取ユーザー一覧
        console.log('\n3. 昨日の日利受取ユーザー一覧');
        const yesterday = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString().split('T')[0];
        const { data: yesterdayProfits, error: yesterdayError } = await supabase
            .from('user_daily_profit')
            .select(`
                user_id,
                daily_profit,
                yield_rate,
                user_rate,
                base_amount,
                phase,
                users!inner(email, full_name, total_purchases, has_approved_nft)
            `)
            .eq('date', yesterday)
            .order('daily_profit', { ascending: false })
            .limit(20);
        
        if (yesterdayError) {
            console.error('Error fetching yesterday profits:', yesterdayError);
        } else {
            console.log(`昨日の日利受取者: ${yesterdayProfits.length}人`);
            yesterdayProfits.forEach((row, index) => {
                console.log(`${index + 1}. ${row.users.email} (${row.users.full_name})`);
                console.log(`   日利: $${row.daily_profit}, 運用額: $${row.base_amount}, フェーズ: ${row.phase}`);
            });
        }
        
        // 4. NFT購入状況と運用開始日
        console.log('\n4. NFT購入状況と運用開始日');
        const { data: purchases, error: purchaseError } = await supabase
            .from('purchases')
            .select(`
                user_id,
                nft_quantity,
                amount_usd,
                created_at,
                admin_approved,
                users!inner(email, full_name, has_approved_nft)
            `)
            .eq('admin_approved', true)
            .order('created_at', { ascending: true });
        
        if (purchaseError) {
            console.error('Error fetching purchases:', purchaseError);
        } else {
            const userPurchases = {};
            purchases.forEach(purchase => {
                if (!userPurchases[purchase.user_id]) {
                    userPurchases[purchase.user_id] = {
                        email: purchase.users.email,
                        full_name: purchase.users.full_name,
                        has_approved_nft: purchase.users.has_approved_nft,
                        nft_count: 0,
                        total_investment: 0,
                        first_purchase: null,
                        last_purchase: null
                    };
                }
                
                userPurchases[purchase.user_id].nft_count += purchase.nft_quantity;
                userPurchases[purchase.user_id].total_investment += parseFloat(purchase.amount_usd);
                
                if (!userPurchases[purchase.user_id].first_purchase) {
                    userPurchases[purchase.user_id].first_purchase = purchase.created_at;
                }
                userPurchases[purchase.user_id].last_purchase = purchase.created_at;
            });
            
            console.log('NFT購入ユーザー（投資額順）:');
            Object.entries(userPurchases)
                .sort(([,a], [,b]) => b.total_investment - a.total_investment)
                .slice(0, 20)
                .forEach(([userId, data], index) => {
                    const firstPurchase = new Date(data.first_purchase);
                    const operationStart = new Date(firstPurchase.getTime() + 15 * 24 * 60 * 60 * 1000);
                    const isOperationActive = operationStart <= new Date();
                    
                    console.log(`${index + 1}. ${data.email} (${data.full_name})`);
                    console.log(`   NFT: ${data.nft_count}個, 投資額: $${data.total_investment.toFixed(2)}`);
                    console.log(`   初回購入: ${firstPurchase.toDateString()}`);
                    console.log(`   運用開始: ${operationStart.toDateString()} (${isOperationActive ? 'ACTIVE' : 'WAITING'})`);
                    console.log(`   承認済み: ${data.has_approved_nft ? 'YES' : 'NO'}`);
                });
        }
        
        // 5. アフィリエイトサイクル状況
        console.log('\n5. アフィリエイトサイクル状況');
        const { data: cycles, error: cycleError } = await supabase
            .from('affiliate_cycle')
            .select(`
                user_id,
                phase,
                total_nft_count,
                cum_usdt,
                available_usdt,
                auto_nft_count,
                manual_nft_count,
                cycle_number,
                next_action,
                cycle_start_date,
                users!inner(email, full_name, has_approved_nft)
            `)
            .gt('total_nft_count', 0)
            .order('cum_usdt', { ascending: false })
            .limit(20);
        
        if (cycleError) {
            console.error('Error fetching cycles:', cycleError);
        } else {
            console.log(`アフィリエイトサイクル参加者: ${cycles.length}人`);
            cycles.forEach((row, index) => {
                console.log(`${index + 1}. ${row.users.email} (${row.users.full_name})`);
                console.log(`   フェーズ: ${row.phase}, NFT: ${row.total_nft_count}個`);
                console.log(`   累積USDT: $${row.cum_usdt}, 利用可能: $${row.available_usdt}`);
                console.log(`   次のアクション: ${row.next_action}, サイクル: ${row.cycle_number}`);
            });
        }
        
        // 6. 日利設定ログ最新情報
        console.log('\n6. 日利設定ログ最新情報');
        const { data: yieldLogs, error: yieldError } = await supabase
            .from('daily_yield_log')
            .select('date, yield_rate, margin_rate, user_rate, is_month_end, created_at')
            .order('date', { ascending: false })
            .limit(10);
        
        if (yieldError) {
            console.error('Error fetching yield logs:', yieldError);
        } else {
            console.log('最新の日利設定:');
            yieldLogs.forEach((row, index) => {
                console.log(`${index + 1}. ${row.date}: 日利${(row.yield_rate * 100).toFixed(1)}%, マージン${row.margin_rate}%, ユーザー受取${(row.user_rate * 100).toFixed(1)}%`);
                console.log(`   月末処理: ${row.is_month_end ? 'YES' : 'NO'}, 設定日時: ${new Date(row.created_at).toLocaleString()}`);
            });
        }
        
        // 7. システム統計サマリー
        console.log('\n7. システム統計サマリー');
        
        const { data: totalUsers } = await supabase
            .from('users')
            .select('id')
            .eq('is_active', true);
        
        const { data: approvedUsers } = await supabase
            .from('users')
            .select('id')
            .eq('has_approved_nft', true);
        
        const { data: totalPurchases } = await supabase
            .from('purchases')
            .select('id')
            .eq('admin_approved', true);
        
        const { data: recentProfitUsers } = await supabase
            .from('user_daily_profit')
            .select('user_id')
            .gte('date', new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString().split('T')[0]);
        
        const { data: cycleUsers } = await supabase
            .from('affiliate_cycle')
            .select('user_id')
            .gt('total_nft_count', 0);
        
        console.log(`アクティブユーザー総数: ${totalUsers ? totalUsers.length : 0}人`);
        console.log(`NFT承認済みユーザー: ${approvedUsers ? approvedUsers.length : 0}人`);
        console.log(`承認済みNFT購入数: ${totalPurchases ? totalPurchases.length : 0}件`);
        console.log(`過去7日間の日利受取ユーザー: ${recentProfitUsers ? new Set(recentProfitUsers.map(p => p.user_id)).size : 0}人`);
        console.log(`アフィリエイトサイクル参加者: ${cycleUsers ? cycleUsers.length : 0}人`);
        
        if (recentProfitUsers) {
            const totalRecentProfit = recentProfitUsers.reduce((sum, p) => sum + parseFloat(p.daily_profit || 0), 0);
            console.log(`過去7日間の日利総額: $${totalRecentProfit.toFixed(2)}`);
        }
        
    } catch (error) {
        console.error('Investigation failed:', error);
    }
}

investigateDailyProfitUsers();