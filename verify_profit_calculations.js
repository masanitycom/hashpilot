const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://dnfftqwgfzjnqgscywnm.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRuZmZ0cXdnZnpqbnFnc2N5d25tIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MjA2NTY3MjIsImV4cCI6MjAzNjIzMjcyMn0.p3xFhF2fNKfhNrfFGHEVrQNiF2J2jPNF3AzJOhHsaWg';

const supabase = createClient(supabaseUrl, supabaseKey);

async function verifyProfitCalculations() {
    try {
        console.log('=== 正確な利益計算確認 ===\n');
        
        // 1. 全ユーザーの基本情報と利益状況
        const { data: users } = await supabase
            .from('users')
            .select('user_id, email, has_approved_nft, is_active')
            .eq('has_approved_nft', true)
            .order('user_id');
        
        if (!users) {
            console.log('ユーザーデータが取得できませんでした');
            return;
        }
        
        console.log('承認済みユーザー数:', users.length);
        
        for (const user of users) {
            // 管理者チェック
            const { data: adminCheck } = await supabase
                .from('admins')
                .select('user_id, role')
                .eq('user_id', user.user_id);
            
            const isAdmin = adminCheck && adminCheck.length > 0;
            const adminRole = isAdmin ? adminCheck[0].role : null;
            
            // 個人利益
            const { data: personalProfits } = await supabase
                .from('user_daily_profit')
                .select('date, daily_profit, yield_rate, user_rate, base_amount')
                .eq('user_id', user.user_id)
                .order('date', { ascending: false });
            
            const personalProfitTotal = personalProfits ? personalProfits.reduce((sum, p) => sum + parseFloat(p.daily_profit || 0), 0) : 0;
            const personalProfitThisMonth = personalProfits ? personalProfits
                .filter(p => new Date(p.date) >= new Date(new Date().getFullYear(), new Date().getMonth(), 1))
                .reduce((sum, p) => sum + parseFloat(p.daily_profit || 0), 0) : 0;
            
            const personalProfitYesterday = personalProfits ? personalProfits
                .filter(p => {
                    const yesterday = new Date();
                    yesterday.setDate(yesterday.getDate() - 1);
                    return new Date(p.date).toDateString() === yesterday.toDateString();
                })
                .reduce((sum, p) => sum + parseFloat(p.daily_profit || 0), 0) : 0;
            
            // affiliate_cycle状況
            const { data: cycleData } = await supabase
                .from('affiliate_cycle')
                .select('cum_usdt, available_usdt, total_nft_count, phase')
                .eq('user_id', user.user_id);
            
            const cycle = cycleData && cycleData.length > 0 ? cycleData[0] : null;
            
            // 購入情報
            const { data: purchases } = await supabase
                .from('purchases')
                .select('admin_approved_at, nft_quantity, amount_usd')
                .eq('user_id', user.user_id)
                .eq('admin_approved', true)
                .order('admin_approved_at', { ascending: false });
            
            const latestApproval = purchases && purchases.length > 0 ? purchases[0].admin_approved_at : null;
            const totalNftPurchased = purchases ? purchases.reduce((sum, p) => sum + (p.nft_quantity || 0), 0) : 0;
            
            // 運用開始日計算
            let operationStartDate = null;
            let operationStatus = 'なし';
            if (latestApproval) {
                operationStartDate = new Date(latestApproval);
                operationStartDate.setDate(operationStartDate.getDate() + 15);
                operationStatus = new Date() >= operationStartDate ? '運用中' : '待機中';
            }
            
            console.log(`
ユーザー: ${user.user_id}
メール: ${user.email}
タイプ: ${isAdmin ? `[管理者:${adminRole}]` : '[一般]'}
承認日: ${latestApproval ? new Date(latestApproval).toLocaleDateString() : 'なし'}
運用開始日: ${operationStartDate ? operationStartDate.toLocaleDateString() : 'なし'}
運用状況: ${operationStatus}
購入NFT数: ${totalNftPurchased}
サイクルNFT数: ${cycle ? cycle.total_nft_count : 0}
累積利益(cycle): ${cycle ? parseFloat(cycle.cum_usdt || 0).toFixed(3) : '0.000'}
利用可能額: ${cycle ? parseFloat(cycle.available_usdt || 0).toFixed(3) : '0.000'}
個人利益(昨日): ${personalProfitYesterday.toFixed(3)}
個人利益(今月): ${personalProfitThisMonth.toFixed(3)}
個人利益(全期間): ${personalProfitTotal.toFixed(3)}
フェーズ: ${cycle ? cycle.phase : 'なし'}
利益記録数: ${personalProfits ? personalProfits.length : 0}
            `.trim());
        }
        
        // 2. 7A9637の詳細記録
        console.log('\n=== 7A9637の詳細利益記録 ===');
        const { data: sevenA9637Profits } = await supabase
            .from('user_daily_profit')
            .select('date, daily_profit, yield_rate, user_rate, base_amount, phase')
            .eq('user_id', '7A9637')
            .order('date', { ascending: false });
        
        if (sevenA9637Profits && sevenA9637Profits.length > 0) {
            sevenA9637Profits.forEach(p => {
                console.log(`日付: ${p.date}, 利益: ${parseFloat(p.daily_profit).toFixed(3)}, 利率: ${p.yield_rate}, ユーザー率: ${p.user_rate}, 基準額: ${p.base_amount}, フェーズ: ${p.phase}`);
            });
        } else {
            console.log('7A9637の利益記録がありません');
        }
        
    } catch (error) {
        console.error('エラー:', error);
    }
}

verifyProfitCalculations();