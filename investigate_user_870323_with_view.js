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

async function investigateWithAdminView() {
  console.log('='.repeat(80));
  console.log('ユーザー870323のデータ不整合調査（admin_purchases_viewを使用）');
  console.log('='.repeat(80));

  try {
    // 1. admin_purchases_view を使って870323の購入データを取得（管理画面と同様）
    console.log('\n1. admin_purchases_viewでの購入データ取得:');
    console.log('-'.repeat(50));
    
    const { data: adminPurchases, error: adminError } = await supabase
      .from('admin_purchases_view')
      .select('*')
      .eq('user_id', '870323')
      .order('created_at', { ascending: false });

    if (adminError) {
      console.error('admin_purchases_view エラー:', adminError);
    } else {
      console.log(`admin_purchases_viewでの購入数: ${adminPurchases.length}`);
      
      if (adminPurchases.length > 0) {
        adminPurchases.forEach((purchase, index) => {
          console.log(`\n購入 ${index + 1} (admin_purchases_view):`);
          console.log(`  購入ID: ${purchase.id}`);
          console.log(`  ユーザーID: ${purchase.user_id}`);
          console.log(`  金額: $${purchase.amount_usd}`);
          console.log(`  NFT数: ${purchase.nft_quantity}`);
          console.log(`  支払いステータス: ${purchase.payment_status}`);
          console.log(`  管理者承認: ${purchase.admin_approved}`);
          console.log(`  NFT送信済み: ${purchase.nft_sent || 'NULL'}`);
          console.log(`  作成日時: ${purchase.created_at}`);
          console.log(`  承認日時: ${purchase.admin_approved_at || 'NULL'}`);
          console.log(`  承認者: ${purchase.admin_approved_by || 'NULL'}`);
          console.log(`  メール: ${purchase.email}`);
          console.log(`  フルネーム: ${purchase.full_name || 'NULL'}`);
          console.log(`  CoinW UID: ${purchase.coinw_uid || 'NULL'}`);
          console.log(`  ユーザーメモ: ${purchase.user_notes || 'NULL'}`);
          console.log(`  管理者メモ: ${purchase.admin_notes || 'NULL'}`);
          console.log(`  支払い証明URL: ${purchase.payment_proof_url || 'NULL'}`);
        });
      } else {
        console.log('admin_purchases_viewでも購入データが見つかりませんでした');
      }
    }

    // 2. 直接purchasesテーブルからも再度確認（RLS無効化後の状況確認）
    console.log('\n\n2. 直接purchasesテーブルでの購入データ取得:');
    console.log('-'.repeat(50));
    
    const { data: directPurchases, error: directError } = await supabase
      .from('purchases')
      .select('*')
      .eq('user_id', '870323');

    if (directError) {
      console.error('直接purchases テーブルエラー:', directError);
    } else {
      console.log(`直接purchasesテーブルでの購入数: ${directPurchases.length}`);
    }

    // 3. 管理画面での全購入データ取得（参考用）
    console.log('\n\n3. admin_purchases_viewでの全購入データ（上位10件）:');
    console.log('-'.repeat(50));
    
    const { data: allAdminPurchases, error: allAdminError } = await supabase
      .from('admin_purchases_view')
      .select('user_id, email, amount_usd, payment_status, admin_approved, created_at')
      .order('created_at', { ascending: false })
      .limit(10);

    if (!allAdminError && allAdminPurchases.length > 0) {
      console.log('最新の購入データ（参考）:');
      allAdminPurchases.forEach((purchase, index) => {
        console.log(`  ${index + 1}. ユーザー: ${purchase.user_id}, 金額: $${purchase.amount_usd}, ステータス: ${purchase.payment_status}, 承認: ${purchase.admin_approved}`);
      });
    } else {
      console.log('admin_purchases_viewにデータがありません');
    }

    // 4. $1100の購入データを検索（管理画面で$1100が表示されているという情報から）
    console.log('\n\n4. $1100の購入データを検索:');
    console.log('-'.repeat(50));
    
    const { data: purchases1100, error: purchases1100Error } = await supabase
      .from('admin_purchases_view')
      .select('*')
      .eq('amount_usd', 1100)
      .order('created_at', { ascending: false });

    if (!purchases1100Error && purchases1100.length > 0) {
      console.log(`$1100の購入データ: ${purchases1100.length}件`);
      purchases1100.forEach((purchase, index) => {
        console.log(`  購入 ${index + 1}: ユーザー ${purchase.user_id}, メール: ${purchase.email}, 作成日: ${purchase.created_at}`);
      });

      // その中でuser_id 870323に関連しそうなものを探す
      const user870323Related = purchases1100.filter(p => 
        p.user_id === '870323' || 
        p.email === 'twister.kenji@gmail.com'
      );
      
      if (user870323Related.length > 0) {
        console.log('\nuser_id 870323 または対応メールアドレスで見つかった$1100の購入:');
        user870323Related.forEach((purchase, index) => {
          console.log(`  関連購入 ${index + 1}: ユーザー ${purchase.user_id}, メール: ${purchase.email}`);
        });
      }
    } else {
      console.log('$1100の購入データは見つかりませんでした');
    }

    // 5. メールアドレス 'twister.kenji@gmail.com' で検索
    console.log('\n\n5. メールアドレス twister.kenji@gmail.com での購入検索:');
    console.log('-'.repeat(50));
    
    const { data: emailPurchases, error: emailError } = await supabase
      .from('admin_purchases_view')
      .select('*')
      .eq('email', 'twister.kenji@gmail.com')
      .order('created_at', { ascending: false });

    if (!emailError && emailPurchases.length > 0) {
      console.log(`メールアドレスでの購入データ: ${emailPurchases.length}件`);
      emailPurchases.forEach((purchase, index) => {
        console.log(`\nメール購入 ${index + 1}:`);
        console.log(`  購入ID: ${purchase.id}`);
        console.log(`  ユーザーID: ${purchase.user_id}`);
        console.log(`  金額: $${purchase.amount_usd}`);
        console.log(`  ステータス: ${purchase.payment_status}`);
        console.log(`  管理者承認: ${purchase.admin_approved}`);
        console.log(`  作成日時: ${purchase.created_at}`);
      });

      // 金額の合計を計算
      const totalAmount = emailPurchases
        .filter(p => p.admin_approved === true)
        .reduce((sum, p) => sum + p.amount_usd, 0);
      
      console.log(`\n承認済み購入の合計金額: $${totalAmount}`);
    } else {
      console.log('メールアドレスでも購入データは見つかりませんでした');
    }

    // 6. 最終結論
    console.log('\n\n6. 調査結果まとめ:');
    console.log('-'.repeat(50));
    console.log('データ不整合の詳細分析:');
    
    // usersテーブルの情報を再確認
    const { data: userInfo, error: userError } = await supabase
      .from('users')
      .select('user_id, total_purchases')
      .eq('user_id', '870323')
      .single();

    // affiliate_cycleの情報を再確認
    const { data: cycleInfo, error: cycleError } = await supabase
      .from('affiliate_cycle')
      .select('user_id, total_nft_count, manual_nft_count')
      .eq('user_id', '870323')
      .single();

    console.log('\n現状の確認:');
    console.log(`  usersテーブル total_purchases: $${userInfo?.total_purchases || 'ERROR'}`);
    console.log(`  affiliate_cycle total_nft_count: ${cycleInfo?.total_nft_count || 'ERROR'}`);
    console.log(`  affiliate_cycle manual_nft_count: ${cycleInfo?.manual_nft_count || 'ERROR'}`);
    console.log(`  admin_purchases_viewでの購入データ: ${adminPurchases?.length || 0}件`);
    console.log(`  メールアドレスでの購入データ: ${emailPurchases?.length || 0}件`);

    if (emailPurchases && emailPurchases.length > 0) {
      const approvedEmailPurchases = emailPurchases.filter(p => p.admin_approved === true);
      const totalEmailAmount = approvedEmailPurchases.reduce((sum, p) => sum + p.amount_usd, 0);
      const totalEmailNft = approvedEmailPurchases.reduce((sum, p) => sum + p.nft_quantity, 0);
      
      console.log(`  メールアドレスでの承認済み購入総額: $${totalEmailAmount}`);
      console.log(`  メールアドレスでの承認済みNFT総数: ${totalEmailNft}`);
    }

    // 推定される原因
    console.log('\n推定される不整合の原因:');
    if (!adminPurchases || adminPurchases.length === 0) {
      if (!emailPurchases || emailPurchases.length === 0) {
        console.log('❌ 購入データが完全に存在しない');
        console.log('   - データが物理削除された');
        console.log('   - データが別のuser_idで登録されている');
        console.log('   - 手動でusers/affiliate_cycleテーブルが更新された');
      } else {
        console.log('⚠️ ユーザーIDの不整合');
        console.log('   - 購入時と現在のuser_idが異なる');
        console.log('   - データベース更新時の不整合');
      }
    } else {
      console.log('✅ 購入データは存在する');
      console.log('   - 管理画面の表示またはフィルター問題');
    }

  } catch (error) {
    console.error('調査中にエラーが発生しました:', error);
  }
}

// スクリプトを実行
investigateWithAdminView().then(() => {
  console.log('\n詳細調査完了');
  process.exit(0);
}).catch(error => {
  console.error('実行エラー:', error);
  process.exit(1);
});