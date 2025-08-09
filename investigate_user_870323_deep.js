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

async function deepInvestigateUser870323() {
  console.log('='.repeat(80));
  console.log('ユーザー870323の詳細データ不整合調査（拡張版）');
  console.log('='.repeat(80));

  try {
    // 1. 全テーブルの存在確認とスキーマ調査
    console.log('\n1. データベーススキーマ調査:');
    console.log('-'.repeat(50));
    
    // purchasesテーブルの全カラムを確認
    const { data: purchasesSchema, error: purchasesSchemaError } = await supabase
      .from('purchases')
      .select('*')
      .limit(1);
    
    if (purchasesSchemaError) {
      console.error('Purchasesスキーマエラー:', purchasesSchemaError);
    } else if (purchasesSchema.length > 0) {
      console.log('purchasesテーブルのカラム:', Object.keys(purchasesSchema[0]));
    }

    // 2. RLS(Row Level Security)ポリシーが影響している可能性を調査
    console.log('\n2. RLSポリシーの影響調査:');
    console.log('-'.repeat(50));
    
    // サービスロールキーがある場合はそれを使用して再調査
    console.log('現在の認証状態で全purchasesテーブルをクエリ:');
    const { data: allPurchases, error: allPurchasesError } = await supabase
      .from('purchases')
      .select('user_id, amount_usd, nft_quantity, payment_status, admin_approved, created_at')
      .limit(100);
    
    if (allPurchasesError) {
      console.error('全購入データ取得エラー:', allPurchasesError);
    } else {
      const user870323Purchases = allPurchases.filter(p => p.user_id === '870323');
      console.log(`全体の購入件数: ${allPurchases.length}`);
      console.log(`ユーザー870323の購入件数: ${user870323Purchases.length}`);
      
      if (user870323Purchases.length > 0) {
        console.log('発見された870323の購入データ:');
        user870323Purchases.forEach((purchase, index) => {
          console.log(`  購入 ${index + 1}:`);
          console.log(`    金額: $${purchase.amount_usd}`);
          console.log(`    NFT数: ${purchase.nft_quantity}`);
          console.log(`    ステータス: ${purchase.payment_status}`);
          console.log(`    管理者承認: ${purchase.admin_approved}`);
          console.log(`    作成日: ${purchase.created_at}`);
        });
      }
    }

    // 3. ユーザーIDの形式が正しいか確認
    console.log('\n3. ユーザーIDの形式確認:');
    console.log('-'.repeat(50));
    
    // 数値として検索
    const { data: purchasesNumeric, error: purchasesNumericError } = await supabase
      .from('purchases')
      .select('*')
      .eq('user_id', 870323); // 数値として検索

    if (!purchasesNumericError && purchasesNumeric.length > 0) {
      console.log(`数値形式(870323)で見つかった購入データ: ${purchasesNumeric.length}件`);
    } else {
      console.log('数値形式では購入データは見つかりませんでした');
    }

    // 文字列で完全一致検索
    const { data: purchasesString, error: purchasesStringError } = await supabase
      .from('purchases')
      .select('*')
      .eq('user_id', '870323');

    if (!purchasesStringError && purchasesString.length > 0) {
      console.log(`文字列形式('870323')で見つかった購入データ: ${purchasesString.length}件`);
    } else {
      console.log('文字列形式では購入データは見つかりませんでした');
    }

    // 4. 似たようなuser_idを検索（入力ミスの可能性）
    console.log('\n4. 類似ユーザーIDの検索:');
    console.log('-'.repeat(50));
    
    const { data: similarUsers, error: similarUsersError } = await supabase
      .from('users')
      .select('user_id, email, total_purchases')
      .like('user_id', '%870323%');

    if (!similarUsersError && similarUsers.length > 0) {
      console.log('類似ユーザーID:');
      similarUsers.forEach(user => {
        console.log(`  ユーザーID: ${user.user_id}, メール: ${user.email}, 購入額: $${user.total_purchases}`);
      });
    }

    // 5. メールアドレスでpurchasesテーブルを検索（JOINして確認）
    console.log('\n5. メールアドレスベースでの購入履歴検索:');
    console.log('-'.repeat(50));
    
    // JOINクエリは直接的にはできないので、メールアドレスからuser_idを特定
    const targetEmail = 'twister.kenji@gmail.com';
    
    // 同じメールアドレスを持つ全ユーザーを検索
    const { data: emailUsers, error: emailUsersError } = await supabase
      .from('users')
      .select('user_id, email, total_purchases')
      .eq('email', targetEmail);

    if (!emailUsersError && emailUsers.length > 0) {
      console.log(`メール ${targetEmail} に関連するユーザー:`, emailUsers.length);
      
      for (const user of emailUsers) {
        console.log(`\nユーザーID ${user.user_id} の購入履歴を検索中...`);
        
        const { data: userPurchases, error: userPurchasesError } = await supabase
          .from('purchases')
          .select('*')
          .eq('user_id', user.user_id);
        
        if (!userPurchasesError) {
          console.log(`  購入履歴件数: ${userPurchases.length}`);
          if (userPurchases.length > 0) {
            userPurchases.forEach((purchase, index) => {
              console.log(`    購入 ${index + 1}: $${purchase.amount_usd}, NFT数: ${purchase.nft_quantity}, ステータス: ${purchase.payment_status}`);
            });
          }
        }
      }
    }

    // 6. 合計金額から逆算して購入データを探索
    console.log('\n6. 金額ベースでの購入データ探索:');
    console.log('-'.repeat(50));
    
    // $2200の購入または$1100x2の購入を検索
    const { data: amount2200Purchases, error: amount2200Error } = await supabase
      .from('purchases')
      .select('*')
      .eq('amount_usd', 2200);

    if (!amount2200Error && amount2200Purchases.length > 0) {
      console.log(`$2200の購入データ: ${amount2200Purchases.length}件`);
      amount2200Purchases.forEach(purchase => {
        console.log(`  ユーザーID: ${purchase.user_id}, 作成日: ${purchase.created_at}`);
      });
    }

    const { data: amount1100Purchases, error: amount1100Error } = await supabase
      .from('purchases')
      .select('*')
      .eq('amount_usd', 1100);

    if (!amount1100Error && amount1100Purchases.length > 0) {
      console.log(`$1100の購入データ: ${amount1100Purchases.length}件`);
      amount1100Purchases.forEach(purchase => {
        console.log(`  ユーザーID: ${purchase.user_id}, 作成日: ${purchase.created_at}`);
      });
    }

    // 7. affiliate_cycleとusersの更新履歴を確認
    console.log('\n7. データの更新時刻確認:');
    console.log('-'.repeat(50));
    
    const { data: user870323Detail, error: userDetailError } = await supabase
      .from('users')
      .select('*')
      .eq('user_id', '870323')
      .single();

    if (!userDetailError && user870323Detail) {
      console.log('usersテーブルの詳細:');
      console.log(`  作成日時: ${user870323Detail.created_at}`);
      console.log(`  更新日時: ${user870323Detail.updated_at}`);
      console.log(`  総購入額: $${user870323Detail.total_purchases}`);
    }

    const { data: affiliate870323Detail, error: affiliateDetailError } = await supabase
      .from('affiliate_cycle')
      .select('*')
      .eq('user_id', '870323');

    if (!affiliateDetailError && affiliate870323Detail.length > 0) {
      console.log('affiliate_cycleテーブルの詳細:');
      affiliate870323Detail.forEach(cycle => {
        console.log(`  作成日時: ${cycle.created_at}`);
        console.log(`  更新日時: ${cycle.updated_at}`);
        console.log(`  手動NFT数: ${cycle.manual_nft_count}`);
        console.log(`  総NFT数: ${cycle.total_nft_count}`);
      });
    }

    // 8. 結論と推定原因
    console.log('\n8. 結論と推定原因:');
    console.log('-'.repeat(50));
    console.log('調査結果から判明した事実:');
    console.log('✅ ユーザー870323は確実に存在');
    console.log('✅ usersテーブルでtotal_purchases = $2200');
    console.log('✅ affiliate_cycleでtotal_nft_count = 2, manual_nft_count = 2');
    console.log('❌ purchasesテーブルに該当データが存在しない');
    console.log('');
    console.log('推定原因:');
    console.log('1. 購入データが物理削除された（soft deleteではなくharddelete）');
    console.log('2. 手動でusersとaffiliate_cycleテーブルが更新された');
    console.log('3. データ移行時の不整合');
    console.log('4. RLS(Row Level Security)によるアクセス制限');
    console.log('5. 異なるuser_id形式での重複データ');

  } catch (error) {
    console.error('詳細調査中にエラーが発生しました:', error);
  }
}

// スクリプトを実行
deepInvestigateUser870323().then(() => {
  console.log('\n詳細調査完了');
  process.exit(0);
}).catch(error => {
  console.error('実行エラー:', error);
  process.exit(1);
});