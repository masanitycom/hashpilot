const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://dnfftqwgfzjnqgscywnm.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRuZmZ0cXdnZnpqbnFnc2N5d25tIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MjA2NTY3MjIsImV4cCI6MjAzNjIzMjcyMn0.p3xFhF2fNKfhNrfFGHEVrQNiF2J2jPNF3AzJOhHsaWg';

const supabase = createClient(supabaseUrl, supabaseKey);

async function emergencyFixAllUsers() {
    try {
        console.log('🚨🚨🚨 緊急修正開始: 全ユーザーの利益計算 🚨🚨🚨\n');
        
        // 1. 現在の状況確認
        console.log('1. 現在の異常状況を確認中...');
        const { data: currentStats } = await supabase.rpc('emergency_get_user_stats');
        
        // 直接クエリで確認
        const { data: users } = await supabase
            .from('users')
            .select(`
                user_id,
                email,
                has_approved_nft,
                affiliate_cycle(total_nft_count, cum_usdt),
                purchases!inner(nft_quantity, admin_approved_at)
            `)
            .eq('has_approved_nft', true);
        
        console.log(`承認済みユーザー数: ${users ? users.length : 0}`);
        
        let fixedUsers = 0;
        let totalProfitsAdded = 0;
        
        // 2. 各ユーザーを個別に修正
        for (const user of users || []) {
            try {
                console.log(`\n修正中: ${user.user_id} (${user.email})`);
                
                // NFT数計算
                const totalNft = user.purchases.reduce((sum, p) => sum + (p.nft_quantity || 0), 0);
                const earliestApproval = user.purchases.reduce((earliest, p) => {
                    return !earliest || new Date(p.admin_approved_at) < new Date(earliest) 
                        ? p.admin_approved_at : earliest;
                }, null);
                
                if (totalNft === 0) {
                    console.log(`  スキップ: NFT購入なし`);
                    continue;
                }
                
                console.log(`  NFT数: ${totalNft}, 承認日: ${new Date(earliestApproval).toLocaleDateString()}`);
                
                // affiliate_cycleを更新または作成
                const { data: existingCycle } = await supabase
                    .from('affiliate_cycle')
                    .select('*')
                    .eq('user_id', user.user_id)
                    .single();
                
                if (existingCycle) {
                    // 更新
                    await supabase
                        .from('affiliate_cycle')
                        .update({
                            total_nft_count: totalNft,
                            manual_nft_count: totalNft,
                            updated_at: new Date().toISOString()
                        })
                        .eq('user_id', user.user_id);
                    console.log(`  Cycle更新完了`);
                } else {
                    // 作成
                    await supabase
                        .from('affiliate_cycle')
                        .insert({
                            user_id: user.user_id,
                            phase: 'USDT',
                            total_nft_count: totalNft,
                            cum_usdt: 0,
                            available_usdt: 0,
                            auto_nft_count: 0,
                            manual_nft_count: totalNft,
                            cycle_number: 1,
                            next_action: 'usdt',
                            cycle_start_date: earliestApproval,
                            created_at: new Date().toISOString(),
                            updated_at: new Date().toISOString()
                        });
                    console.log(`  Cycle作成完了`);
                }
                
                // 運用開始日計算
                const operationStart = new Date(earliestApproval);
                operationStart.setDate(operationStart.getDate() + 15);
                
                if (new Date() <= operationStart) {
                    console.log(`  運用開始前: ${operationStart.toLocaleDateString()}`);
                    continue;
                }
                
                // 既存の利益記録確認
                const { data: existingProfits } = await supabase
                    .from('user_daily_profit')
                    .select('date')
                    .eq('user_id', user.user_id);
                
                const existingDates = new Set(existingProfits ? existingProfits.map(p => p.date) : []);
                
                // 日利設定を取得
                const { data: yieldLogs } = await supabase
                    .from('daily_yield_log')
                    .select('date, yield_rate, margin_rate, user_rate')
                    .gte('date', operationStart.toISOString().split('T')[0])
                    .order('date', { ascending: true });
                
                const yieldMap = {};
                if (yieldLogs) {
                    yieldLogs.forEach(log => {
                        yieldMap[log.date] = log;
                    });
                }
                
                // 過去の利益を計算
                const profits = [];
                const today = new Date();
                let totalUserProfit = 0;
                
                for (let d = new Date(operationStart); d < today; d.setDate(d.getDate() + 1)) {
                    const dateStr = d.toISOString().split('T')[0];
                    
                    if (existingDates.has(dateStr)) continue;
                    
                    const dayYield = yieldMap[dateStr] || {
                        yield_rate: 0.016,
                        margin_rate: 30,
                        user_rate: ((0.016 * (100 - 30) / 100) * 0.6)
                    };
                    
                    const baseAmount = totalNft * 1000;
                    const dailyProfit = baseAmount * dayYield.user_rate / 100;
                    totalUserProfit += dailyProfit;
                    
                    profits.push({
                        user_id: user.user_id,
                        date: dateStr,
                        daily_profit: dailyProfit,
                        yield_rate: dayYield.yield_rate,
                        user_rate: dayYield.user_rate,
                        base_amount: baseAmount,
                        phase: 'USDT',
                        created_at: new Date().toISOString()
                    });
                }
                
                // 利益データを挿入
                if (profits.length > 0) {
                    const { error: profitError } = await supabase
                        .from('user_daily_profit')
                        .insert(profits);
                    
                    if (profitError) {
                        console.error(`  利益挿入エラー:`, profitError.message);
                    } else {
                        console.log(`  ${profits.length}日分の利益を追加: $${totalUserProfit.toFixed(2)}`);
                        totalProfitsAdded += totalUserProfit;
                    }
                }
                
                // 既存利益も含めて累積を計算
                const { data: allUserProfits } = await supabase
                    .from('user_daily_profit')
                    .select('daily_profit')
                    .eq('user_id', user.user_id);
                
                const totalCumulative = allUserProfits ? 
                    allUserProfits.reduce((sum, p) => sum + (p.daily_profit || 0), 0) : 0;
                
                // affiliate_cycleの累積を更新
                await supabase
                    .from('affiliate_cycle')
                    .update({
                        cum_usdt: totalCumulative,
                        available_usdt: totalCumulative,
                        updated_at: new Date().toISOString()
                    })
                    .eq('user_id', user.user_id);
                
                console.log(`  累積利益更新: $${totalCumulative.toFixed(2)}`);
                fixedUsers++;
                
            } catch (error) {
                console.error(`${user.user_id}の修正エラー:`, error.message);
            }
        }
        
        console.log('\n🎉 緊急修正完了 🎉');
        console.log(`修正ユーザー数: ${fixedUsers}`);
        console.log(`追加利益総額: $${totalProfitsAdded.toFixed(2)}`);
        
        // 最終確認
        console.log('\n=== 最終確認 ===');
        const { data: finalCheck } = await supabase
            .from('users')
            .select(`
                user_id,
                email,
                affiliate_cycle(total_nft_count, cum_usdt)
            `)
            .eq('has_approved_nft', true);
        
        if (finalCheck) {
            const withProfits = finalCheck.filter(u => 
                u.affiliate_cycle && 
                u.affiliate_cycle.total_nft_count > 0 && 
                u.affiliate_cycle.cum_usdt > 0
            );
            
            console.log(`利益があるユーザー: ${withProfits.length}/${finalCheck.length}`);
            
            // 利益が0のユーザーを表示
            const zeroProfits = finalCheck.filter(u => 
                u.affiliate_cycle && 
                u.affiliate_cycle.total_nft_count > 0 && 
                u.affiliate_cycle.cum_usdt === 0
            );
            
            if (zeroProfits.length > 0) {
                console.log('\n🚨 まだ利益が0のユーザー:');
                zeroProfits.forEach(u => {
                    console.log(`${u.user_id}: NFT${u.affiliate_cycle.total_nft_count}個`);
                });
            }
        }
        
    } catch (error) {
        console.error('緊急修正エラー:', error);
    }
}

emergencyFixAllUsers();