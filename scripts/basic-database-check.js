// 基本的なデータベース接続とテーブル確認
// 2025-01-16 実行

const { createClient } = require('@supabase/supabase-js');

// 環境変数を直接設定
const supabaseUrl = 'https://soghqozaxfswtxxbgeer.supabase.co';
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNvZ2hxb3pheGZzd3R4eGJnZWVyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAxNTA3NTUsImV4cCI6MjA2NTcyNjc1NX0.dhHJiyDIsjDEMGJIEpIbUdVbtaAzTOPHUu8YpMjMWM8';

const supabase = createClient(supabaseUrl, supabaseAnonKey);

async function basicDatabaseCheck() {
    console.log('=== 基本的なデータベース接続とテーブル確認 ===\n');
    
    // テーブルの存在確認
    const tables = [
        'users', 
        'purchases', 
        'user_daily_profit', 
        'affiliate_cycle', 
        'daily_yield_log', 
        'withdrawal_requests',
        'system_logs'
    ];
    
    for (const table of tables) {
        try {
            console.log(`\n=== ${table}テーブルの確認 ===`);
            
            // テーブルの存在確認（1行だけ取得）
            const { data, error, count } = await supabase
                .from(table)
                .select('*', { count: 'exact' })
                .limit(1);
            
            if (error) {
                console.error(`Error accessing ${table}:`, error.message);
                console.error('Error details:', error);
            } else {
                console.log(`${table} テーブル: ${count}件のレコード`);
                if (data && data.length > 0) {
                    console.log(`サンプルデータ構造:`, Object.keys(data[0]).join(', '));
                }
            }
            
        } catch (err) {
            console.error(`Exception accessing ${table}:`, err.message);
        }
    }
    
    // 日利記録の詳細確認
    console.log('\n=== 日利記録の詳細確認 ===');
    try {
        const { data: profitData, error: profitError } = await supabase
            .from('user_daily_profit')
            .select('*')
            .order('date', { ascending: false })
            .limit(5);
        
        if (profitError) {
            console.error('Error fetching profit data:', profitError);
        } else {
            console.log(`最新の日利記録 ${profitData.length}件:`);
            profitData.forEach((row, index) => {
                console.log(`${index + 1}. ${row.date}: User ${row.user_id}, $${row.daily_profit}`);
            });
        }
    } catch (err) {
        console.error('Exception fetching profit data:', err);
    }
    
    // NFT購入記録の確認
    console.log('\n=== NFT購入記録の確認 ===');
    try {
        const { data: purchaseData, error: purchaseError } = await supabase
            .from('purchases')
            .select('*')
            .order('created_at', { ascending: false })
            .limit(5);
        
        if (purchaseError) {
            console.error('Error fetching purchase data:', purchaseError);
        } else {
            console.log(`最新の購入記録 ${purchaseData.length}件:`);
            purchaseData.forEach((row, index) => {
                console.log(`${index + 1}. ${new Date(row.created_at).toLocaleDateString()}: User ${row.user_id}, ${row.nft_quantity}NFT, $${row.amount_usd}, 承認: ${row.admin_approved}`);
            });
        }
    } catch (err) {
        console.error('Exception fetching purchase data:', err);
    }
    
    // ユーザー情報の確認
    console.log('\n=== ユーザー情報の確認 ===');
    try {
        const { data: userData, error: userError } = await supabase
            .from('users')
            .select('*')
            .order('created_at', { ascending: false })
            .limit(5);
        
        if (userError) {
            console.error('Error fetching user data:', userError);
        } else {
            console.log(`最新のユーザー ${userData.length}件:`);
            userData.forEach((row, index) => {
                console.log(`${index + 1}. ${row.email}: NFT承認=${row.has_approved_nft}, 総投資=${row.total_purchases}, アクティブ=${row.is_active}`);
            });
        }
    } catch (err) {
        console.error('Exception fetching user data:', err);
    }
    
    // 日利設定の確認
    console.log('\n=== 日利設定の確認 ===');
    try {
        const { data: yieldData, error: yieldError } = await supabase
            .from('daily_yield_log')
            .select('*')
            .order('date', { ascending: false })
            .limit(5);
        
        if (yieldError) {
            console.error('Error fetching yield data:', yieldError);
        } else {
            console.log(`最新の日利設定 ${yieldData.length}件:`);
            yieldData.forEach((row, index) => {
                console.log(`${index + 1}. ${row.date}: 日利${(row.yield_rate * 100).toFixed(1)}%, マージン${row.margin_rate}%, ユーザー${(row.user_rate * 100).toFixed(1)}%`);
            });
        }
    } catch (err) {
        console.error('Exception fetching yield data:', err);
    }
    
    // RPC関数の確認
    console.log('\n=== RPC関数の確認 ===');
    try {
        const { data: healthData, error: healthError } = await supabase
            .rpc('system_health_check');
        
        if (healthError) {
            console.error('Error calling system_health_check:', healthError);
        } else {
            console.log('システムヘルスチェック結果:', healthData);
        }
    } catch (err) {
        console.error('Exception calling system_health_check:', err);
    }
}

basicDatabaseCheck().catch(console.error);