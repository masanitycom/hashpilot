const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');

// .env.localファイルを手動で読み込む
let supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
let supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseAnonKey) {
  try {
    const envContent = fs.readFileSync('.env.local', 'utf8');
    const envLines = envContent.split('\n');
    
    envLines.forEach(line => {
      if (line.startsWith('NEXT_PUBLIC_SUPABASE_URL=')) {
        supabaseUrl = line.split('=')[1];
      }
      if (line.startsWith('NEXT_PUBLIC_SUPABASE_ANON_KEY=')) {
        supabaseAnonKey = line.split('=')[1];
      }
    });
  } catch (error) {
    console.error('.env.localファイルの読み込みに失敗しました:', error.message);
  }
}

if (!supabaseUrl || !supabaseAnonKey) {
  console.error('Supabase credentials not found in environment variables');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseAnonKey);

async function investigateUser870323() {
  console.log('='.repeat(80));
  console.log('ユーザー870323のデータ不整合調査');
  console.log('='.repeat(80));

  try {
    // 1. purchasesテーブルで870323の全購入履歴を調査
    console.log('\n1. purchasesテーブルの全購入履歴:');
    console.log('-'.repeat(50));
    const { data: purchases, error: purchasesError } = await supabase
      .from('purchases')
      .select('*')
      .eq('user_id', '870323')
      .order('created_at', { ascending: false });

    if (purchasesError) {
      console.error('Purchases query error:', purchasesError);
    } else {
      console.log(`購入履歴数: ${purchases.length}`);
      purchases.forEach((purchase, index) => {
        console.log(`\n購入 ${index + 1}:`);
        console.log(`  ID: ${purchase.id}`);
        console.log(`  金額: $${purchase.amount_usd}`);
        console.log(`  NFT数: ${purchase.nft_quantity}`);
        console.log(`  支払いステータス: ${purchase.payment_status}`);
        console.log(`  管理者承認: ${purchase.admin_approved || 'NULL'}`);
        console.log(`  NFT送信済み: ${purchase.nft_sent}`);
        console.log(`  作成日時: ${purchase.created_at}`);
        console.log(`  承認日時: ${purchase.confirmed_at || 'NULL'}`);
        console.log(`  完了日時: ${purchase.completed_at || 'NULL'}`);
      });
    }

    // 2. usersテーブルの870323の詳細情報
    console.log('\n\n2. usersテーブルの詳細情報:');
    console.log('-'.repeat(50));
    const { data: users, error: usersError } = await supabase
      .from('users')
      .select('*')
      .eq('user_id', '870323')
      .single();

    if (usersError) {
      console.error('Users query error:', usersError);
    } else {
      console.log('ユーザー情報:');
      console.log(`  ユーザーID: ${users.user_id}`);
      console.log(`  メール: ${users.email}`);
      console.log(`  総購入額: $${users.total_purchases}`);
      console.log(`  総紹介収益: $${users.total_referral_earnings}`);
      console.log(`  アクティブ: ${users.is_active}`);
      console.log(`  作成日時: ${users.created_at}`);
    }

    // 3. affiliate_cycleテーブルの870323の詳細情報
    console.log('\n\n3. affiliate_cycleテーブルの詳細情報:');
    console.log('-'.repeat(50));
    const { data: affiliateCycles, error: affiliateError } = await supabase
      .from('affiliate_cycle')
      .select('*')
      .eq('user_id', '870323')
      .order('cycle_start_date', { ascending: false });

    if (affiliateError) {
      console.error('Affiliate cycle query error:', affiliateError);
    } else {
      console.log(`サイクル数: ${affiliateCycles.length}`);
      affiliateCycles.forEach((cycle, index) => {
        console.log(`\nサイクル ${index + 1}:`);
        console.log(`  ID: ${cycle.id}`);
        console.log(`  総NFT数: ${cycle.total_nft_count}`);
        console.log(`  手動NFT数: ${cycle.manual_nft_count}`);
        console.log(`  自動購入NFT数: ${cycle.auto_purchased_nft_count || 0}`);
        console.log(`  前サイクルNFT数: ${cycle.previous_cycle_nft_count || 0}`);
        console.log(`  総利益: $${cycle.total_profit || 0}`);
        console.log(`  サイクル開始: ${cycle.cycle_start_date}`);
        console.log(`  サイクル終了: ${cycle.cycle_end_date || 'NULL'}`);
        console.log(`  運用開始: ${cycle.operation_start_date || 'NULL'}`);
        console.log(`  アクティブ: ${cycle.is_active}`);
      });
    }

    // 4. 購入金額の集計確認
    console.log('\n\n4. 購入金額の集計確認:');
    console.log('-'.repeat(50));
    if (purchases && purchases.length > 0) {
      const totalPurchases = purchases.length;
      const totalAmount = purchases.reduce((sum, p) => sum + p.amount_usd, 0);
      const totalNftQuantity = purchases.reduce((sum, p) => sum + p.nft_quantity, 0);
      
      const approvedPurchases = purchases.filter(p => p.payment_status === 'approved' && p.admin_approved === true);
      const approvedAmount = approvedPurchases.reduce((sum, p) => sum + p.amount_usd, 0);
      const approvedNftQuantity = approvedPurchases.reduce((sum, p) => sum + p.nft_quantity, 0);

      console.log(`総購入数: ${totalPurchases}`);
      console.log(`総購入金額: $${totalAmount}`);
      console.log(`総NFT数: ${totalNftQuantity}`);
      console.log(`承認済み購入数: ${approvedPurchases.length}`);
      console.log(`承認済み購入金額: $${approvedAmount}`);
      console.log(`承認済みNFT数: ${approvedNftQuantity}`);
    }

    // 5. 購入ステータス別の詳細分析
    console.log('\n\n5. 購入ステータス別の詳細分析:');
    console.log('-'.repeat(50));
    if (purchases && purchases.length > 0) {
      const statusGroups = {};
      purchases.forEach(p => {
        const key = `${p.payment_status}_${p.admin_approved}_${p.nft_sent}`;
        if (!statusGroups[key]) {
          statusGroups[key] = {
            payment_status: p.payment_status,
            admin_approved: p.admin_approved,
            nft_sent: p.nft_sent,
            count: 0,
            total_amount: 0,
            total_nft: 0
          };
        }
        statusGroups[key].count++;
        statusGroups[key].total_amount += p.amount_usd;
        statusGroups[key].total_nft += p.nft_quantity;
      });

      Object.values(statusGroups).forEach(group => {
        console.log(`\nステータス組み合わせ:`);
        console.log(`  支払いステータス: ${group.payment_status}`);
        console.log(`  管理者承認: ${group.admin_approved}`);
        console.log(`  NFT送信: ${group.nft_sent}`);
        console.log(`  件数: ${group.count}`);
        console.log(`  合計金額: $${group.total_amount}`);
        console.log(`  合計NFT: ${group.total_nft}`);
      });
    }

    // 6. 最終確認: データの整合性チェック
    console.log('\n\n6. データの整合性チェック:');
    console.log('-'.repeat(50));
    console.log('調査結果サマリー:');
    console.log(`  usersテーブルの総購入額: $${users?.total_purchases || 'NULL'}`);
    
    if (purchases && purchases.length > 0) {
      const actualApprovedAmount = purchases
        .filter(p => p.payment_status === 'approved' && p.admin_approved === true)
        .reduce((sum, p) => sum + p.amount_usd, 0);
      console.log(`  実際の承認済み購入額: $${actualApprovedAmount}`);
    }

    if (affiliateCycles && affiliateCycles.length > 0) {
      console.log(`  affiliate_cycleのNFT数: ${affiliateCycles[0]?.total_nft_count || 'NULL'}`);
      console.log(`  affiliate_cycleの手動NFT数: ${affiliateCycles[0]?.manual_nft_count || 'NULL'}`);
    }

    if (purchases && purchases.length > 0) {
      const actualApprovedNft = purchases
        .filter(p => p.payment_status === 'approved' && p.admin_approved === true)
        .reduce((sum, p) => sum + p.nft_quantity, 0);
      console.log(`  実際の承認済みNFT数: ${actualApprovedNft}`);
    }

    // 不整合の分析
    console.log('\n\n7. 不整合の分析:');
    console.log('-'.repeat(50));
    
    const usersTotalPurchases = users?.total_purchases || 0;
    const actualApprovedAmount = purchases
      ?.filter(p => p.payment_status === 'approved' && p.admin_approved === true)
      ?.reduce((sum, p) => sum + p.amount_usd, 0) || 0;
    
    const affiliateCycleNftCount = affiliateCycles?.[0]?.total_nft_count || 0;
    const affiliateCycleManualNft = affiliateCycles?.[0]?.manual_nft_count || 0;
    const actualApprovedNft = purchases
      ?.filter(p => p.payment_status === 'approved' && p.admin_approved === true)
      ?.reduce((sum, p) => sum + p.nft_quantity, 0) || 0;

    console.log('不整合ポイント:');
    
    if (usersTotalPurchases !== actualApprovedAmount) {
      console.log(`  ❌ 購入金額の不整合: users.total_purchases($${usersTotalPurchases}) ≠ 実際の承認済み購入額($${actualApprovedAmount})`);
      console.log(`     差額: $${usersTotalPurchases - actualApprovedAmount}`);
    } else {
      console.log(`  ✅ 購入金額は整合: $${usersTotalPurchases}`);
    }

    if (affiliateCycleNftCount !== actualApprovedNft) {
      console.log(`  ❌ NFT数の不整合: affiliate_cycle.total_nft_count(${affiliateCycleNftCount}) ≠ 実際の承認済みNFT数(${actualApprovedNft})`);
      console.log(`     差: ${affiliateCycleNftCount - actualApprovedNft} NFT`);
    } else {
      console.log(`  ✅ NFT数は整合: ${affiliateCycleNftCount} NFT`);
    }

    if (affiliateCycleManualNft !== actualApprovedNft) {
      console.log(`  ❌ 手動NFT数の不整合: affiliate_cycle.manual_nft_count(${affiliateCycleManualNft}) ≠ 実際の承認済みNFT数(${actualApprovedNft})`);
      console.log(`     差: ${affiliateCycleManualNft - actualApprovedNft} NFT`);
    } else {
      console.log(`  ✅ 手動NFT数は整合: ${affiliateCycleManualNft} NFT`);
    }

  } catch (error) {
    console.error('調査中にエラーが発生しました:', error);
  }
}

// スクリプトを実行
investigateUser870323().then(() => {
  console.log('\n調査完了');
  process.exit(0);
}).catch(error => {
  console.error('実行エラー:', error);
  process.exit(1);
});