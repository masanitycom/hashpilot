const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://dnfftqwgfzjnqgscywnm.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRuZmZ0cXdnZnpqbnFnc2N5d25tIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MjA2NTY3MjIsImV4cCI6MjAzNjIzMjcyMn0.p3xFhF2fNKfhNrfFGHEVrQNiF2J2jPNF3AzJOhHsaWg';

const supabase = createClient(supabaseUrl, supabaseKey);

async function fix2BF53BAdminAndProfits() {
    try {
        console.log('=== 2BF53Bの修正開始 ===\n');
        
        // 1. 現在の状況確認
        console.log('1. 現在の状況確認...');
        const { data: currentStatus } = await supabase
            .from('users')
            .select(`
                user_id,
                email,
                has_approved_nft,
                purchases!inner(nft_quantity, admin_approved_at),
                affiliate_cycle(total_nft_count, cum_usdt, available_usdt),
                admins(role)
            `)
            .eq('user_id', '2BF53B')
            .single();
        
        console.log('現在の状態:', currentStatus);
        
        // 2. adminsテーブルに追加
        console.log('\n2. adminsテーブルに追加...');
        const { error: adminError } = await supabase
            .from('admins')
            .upsert({ 
                user_id: '2BF53B', 
                role: 'admin',
                created_at: new Date().toISOString()
            }, { onConflict: 'user_id' });
        
        if (adminError && !adminError.message.includes('duplicate')) {
            console.error('Admin追加エラー:', adminError);
        } else {
            console.log('Admin登録完了');
        }
        
        // 3. 購入済みNFT数を取得
        console.log('\n3. 購入済みNFT数を確認...');
        const { data: purchases } = await supabase
            .from('purchases')
            .select('nft_quantity, admin_approved_at')
            .eq('user_id', '2BF53B')
            .eq('admin_approved', true);
        
        const totalNft = purchases ? purchases.reduce((sum, p) => sum + (p.nft_quantity || 0), 0) : 0;
        const earliestApproval = purchases ? purchases.reduce((earliest, p) => {
            return !earliest || new Date(p.admin_approved_at) < new Date(earliest) ? p.admin_approved_at : earliest;
        }, null) : null;
        
        console.log('総NFT数:', totalNft);
        console.log('最初の承認日:', earliestApproval);
        
        // 4. affiliate_cycleを更新または作成
        console.log('\n4. affiliate_cycleを更新...');
        const { data: existingCycle } = await supabase
            .from('affiliate_cycle')
            .select('*')
            .eq('user_id', '2BF53B')
            .single();
        
        if (existingCycle) {
            // 更新
            const { error: updateError } = await supabase
                .from('affiliate_cycle')
                .update({
                    total_nft_count: totalNft,
                    manual_nft_count: totalNft,
                    updated_at: new Date().toISOString()
                })
                .eq('user_id', '2BF53B');
            
            if (updateError) console.error('Cycle更新エラー:', updateError);
            else console.log('Cycle更新完了');
        } else {
            // 作成
            const { error: insertError } = await supabase
                .from('affiliate_cycle')
                .insert({
                    user_id: '2BF53B',
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
            
            if (insertError) console.error('Cycle作成エラー:', insertError);
            else console.log('Cycle作成完了');
        }
        
        // 5. 過去の利益を計算
        console.log('\n5. 過去の利益を計算...');
        if (earliestApproval && totalNft > 0) {
            const operationStart = new Date(earliestApproval);
            operationStart.setDate(operationStart.getDate() + 15);
            
            const today = new Date();
            const profits = [];
            
            // 日利ログを取得
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
            
            // 運用開始日から今日までの各日について
            for (let d = new Date(operationStart); d < today; d.setDate(d.getDate() + 1)) {
                const dateStr = d.toISOString().split('T')[0];
                
                // その日の利率を取得（なければデフォルト）
                const dayYield = yieldMap[dateStr] || {
                    yield_rate: 0.016,
                    margin_rate: 30,
                    user_rate: ((0.016 * (100 - 30) / 100) * 0.6)
                };
                
                const baseAmount = totalNft * 1000;
                const dailyProfit = baseAmount * dayYield.user_rate / 100;
                
                profits.push({
                    user_id: '2BF53B',
                    date: dateStr,
                    daily_profit: dailyProfit,
                    yield_rate: dayYield.yield_rate,
                    user_rate: dayYield.user_rate,
                    base_amount: baseAmount,
                    phase: 'USDT',
                    created_at: new Date().toISOString()
                });
            }
            
            console.log(`${profits.length}日分の利益を計算`);
            
            // 既存の利益記録を確認
            const { data: existingProfits } = await supabase
                .from('user_daily_profit')
                .select('date')
                .eq('user_id', '2BF53B');
            
            const existingDates = new Set(existingProfits ? existingProfits.map(p => p.date) : []);
            const newProfits = profits.filter(p => !existingDates.has(p.date));
            
            if (newProfits.length > 0) {
                const { error: profitError } = await supabase
                    .from('user_daily_profit')
                    .insert(newProfits);
                
                if (profitError) console.error('利益挿入エラー:', profitError);
                else console.log(`${newProfits.length}日分の利益を追加`);
            }
        }
        
        // 6. affiliate_cycleの累積を更新
        console.log('\n6. 累積利益を更新...');
        const { data: allProfits } = await supabase
            .from('user_daily_profit')
            .select('daily_profit')
            .eq('user_id', '2BF53B');
        
        const totalProfit = allProfits ? allProfits.reduce((sum, p) => sum + (p.daily_profit || 0), 0) : 0;
        
        const { error: finalUpdateError } = await supabase
            .from('affiliate_cycle')
            .update({
                cum_usdt: totalProfit,
                available_usdt: totalProfit,
                updated_at: new Date().toISOString()
            })
            .eq('user_id', '2BF53B');
        
        if (finalUpdateError) console.error('最終更新エラー:', finalUpdateError);
        else console.log('累積利益更新完了:', totalProfit.toFixed(3));
        
        // 7. 最終確認
        console.log('\n=== 修正完了後の確認 ===');
        const { data: finalStatus } = await supabase
            .from('users')
            .select(`
                user_id,
                email,
                affiliate_cycle(total_nft_count, cum_usdt, available_usdt),
                admins(role)
            `)
            .eq('user_id', '2BF53B')
            .single();
        
        console.log('最終状態:', finalStatus);
        
        // 利益記録数の確認
        const { count } = await supabase
            .from('user_daily_profit')
            .select('*', { count: 'exact', head: true })
            .eq('user_id', '2BF53B');
        
        console.log('利益記録日数:', count);
        
    } catch (error) {
        console.error('エラー:', error);
    }
}

fix2BF53BAdminAndProfits();