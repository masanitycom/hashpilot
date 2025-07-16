'use client';

import { useEffect, useState } from 'react';
import { createClient } from '@/lib/supabase';
import { User } from '@supabase/supabase-js';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';

export default function DebugPage() {
  const [data, setData] = useState<any>({});
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [user, setUser] = useState<User | null>(null);

  useEffect(() => {
    checkAuthAndInvestigate();
  }, []);

  async function checkAuthAndInvestigate() {
    const supabase = createClient();
    const { data: { user } } = await supabase.auth.getUser();
    setUser(user);
    
    if (!user) {
      setError('認証が必要です。まずログインしてください。');
      setLoading(false);
      return;
    }

    investigateUsers();
  }

  async function investigateUsers() {
    try {
      const supabase = createClient();
      const results: any = {};

      console.log('=== HASHPILOT 日利状況緊急調査開始 ===');

      // 1. ユーザー「7A9637」の基本情報
      console.log('1. ユーザー「7A9637」の基本情報');
      const { data: user7A9637, error: userError1 } = await supabase
        .from('users')
        .select('*')
        .eq('user_id', '7A9637')
        .single();
      
      results.user7A9637 = { data: user7A9637, error: userError1?.message };
      console.log('ユーザー7A9637:', user7A9637, 'エラー:', userError1?.message);

      // 2. ユーザー「7A9637」の日利記録
      console.log('2. ユーザー「7A9637」の日利記録');
      const { data: profit7A9637, error: profitError1 } = await supabase
        .from('user_daily_profit')
        .select('*')
        .eq('user_id', '7A9637')
        .order('date', { ascending: false });
      
      results.profit7A9637 = { data: profit7A9637, error: profitError1?.message };
      console.log('日利記録7A9637:', profit7A9637, 'エラー:', profitError1?.message);

      // 3. ユーザー「7A9637」のNFT購入状況
      console.log('3. ユーザー「7A9637」のNFT購入状況');
      const { data: purchases7A9637, error: purchaseError1 } = await supabase
        .from('purchases')
        .select('*')
        .eq('user_id', '7A9637')
        .order('created_at', { ascending: false });
      
      results.purchases7A9637 = { data: purchases7A9637, error: purchaseError1?.message };
      console.log('購入記録7A9637:', purchases7A9637, 'エラー:', purchaseError1?.message);

      // 4. ユーザー「7A9637」のサイクル状況
      console.log('4. ユーザー「7A9637」のサイクル状況');
      const { data: cycle7A9637, error: cycleError1 } = await supabase
        .from('affiliate_cycle')
        .select('*')
        .eq('user_id', '7A9637')
        .single();
      
      results.cycle7A9637 = { data: cycle7A9637, error: cycleError1?.message };
      console.log('サイクル7A9637:', cycle7A9637, 'エラー:', cycleError1?.message);

      // 5. ユーザー「2BF53B」の基本情報
      console.log('5. ユーザー「2BF53B」の基本情報');
      const { data: user2BF53B, error: userError2 } = await supabase
        .from('users')
        .select('*')
        .eq('user_id', '2BF53B')
        .single();
      
      results.user2BF53B = { data: user2BF53B, error: userError2?.message };
      console.log('ユーザー2BF53B:', user2BF53B, 'エラー:', userError2?.message);

      // 6. ユーザー「2BF53B」の日利記録
      console.log('6. ユーザー「2BF53B」の日利記録');
      const { data: profit2BF53B, error: profitError2 } = await supabase
        .from('user_daily_profit')
        .select('*')
        .eq('user_id', '2BF53B')
        .order('date', { ascending: false });
      
      results.profit2BF53B = { data: profit2BF53B, error: profitError2?.message };
      console.log('日利記録2BF53B:', profit2BF53B, 'エラー:', profitError2?.message);

      // 7. ユーザー「2BF53B」のNFT購入状況
      console.log('7. ユーザー「2BF53B」のNFT購入状況');
      const { data: purchases2BF53B, error: purchaseError2 } = await supabase
        .from('purchases')
        .select('*')
        .eq('user_id', '2BF53B')
        .order('created_at', { ascending: false });
      
      results.purchases2BF53B = { data: purchases2BF53B, error: purchaseError2?.message };
      console.log('購入記録2BF53B:', purchases2BF53B, 'エラー:', purchaseError2?.message);

      // 8. ユーザー「2BF53B」のサイクル状況
      console.log('8. ユーザー「2BF53B」のサイクル状況');
      const { data: cycle2BF53B, error: cycleError2 } = await supabase
        .from('affiliate_cycle')
        .select('*')
        .eq('user_id', '2BF53B')
        .single();
      
      results.cycle2BF53B = { data: cycle2BF53B, error: cycleError2?.message };
      console.log('サイクル2BF53B:', cycle2BF53B, 'エラー:', cycleError2?.message);

      // 9. 承認済みユーザー全体
      console.log('9. 承認済みユーザー全体');
      const { data: approvedUsers, error: approvedError } = await supabase
        .from('users')
        .select('user_id, email, full_name, total_purchases, has_approved_nft, created_at')
        .eq('has_approved_nft', true)
        .order('created_at', { ascending: false });
      
      results.approvedUsers = { data: approvedUsers, error: approvedError?.message };
      console.log('承認済みユーザー:', approvedUsers, 'エラー:', approvedError?.message);

      // 10. 最新の日利記録
      console.log('10. 最新の日利記録');
      const { data: latestProfits, error: latestError } = await supabase
        .from('user_daily_profit')
        .select('*')
        .order('date', { ascending: false })
        .order('created_at', { ascending: false })
        .limit(20);
      
      results.latestProfits = { data: latestProfits, error: latestError?.message };
      console.log('最新日利記録:', latestProfits, 'エラー:', latestError?.message);

      // 11. 最新の日利設定
      console.log('11. 最新の日利設定');
      const { data: yieldSettings, error: yieldError } = await supabase
        .from('daily_yield_log')
        .select('*')
        .order('date', { ascending: false })
        .limit(10);
      
      results.yieldSettings = { data: yieldSettings, error: yieldError?.message };
      console.log('日利設定:', yieldSettings, 'エラー:', yieldError?.message);

      // 12. 承認済み購入記録
      console.log('12. 承認済み購入記録');
      const { data: approvedPurchases, error: purchaseError } = await supabase
        .from('purchases')
        .select('user_id, created_at, admin_approved, nft_quantity, amount_usd')
        .eq('admin_approved', true)
        .order('created_at', { ascending: false });
      
      results.approvedPurchases = { data: approvedPurchases, error: purchaseError?.message };
      console.log('承認済み購入:', approvedPurchases, 'エラー:', purchaseError?.message);

      // 13. システムログ
      console.log('13. システムログ');
      const { data: systemLogs, error: logError } = await supabase
        .from('system_logs')
        .select('*')
        .or('operation.ilike.%yield%,operation.ilike.%profit%,operation.ilike.%batch%')
        .order('created_at', { ascending: false })
        .limit(10);
      
      results.systemLogs = { data: systemLogs, error: logError?.message };
      console.log('システムログ:', systemLogs, 'エラー:', logError?.message);

      // 運用開始判定の計算
      if (results.approvedPurchases.data) {
        results.operationAnalysis = results.approvedPurchases.data.map((purchase: any) => {
          const purchaseDate = new Date(purchase.created_at);
          const operationStartDate = new Date(purchaseDate);
          operationStartDate.setDate(operationStartDate.getDate() + 15);
          const today = new Date();
          const isStarted = today >= operationStartDate;
          const daysSinceStart = Math.floor((today.getTime() - operationStartDate.getTime()) / (1000 * 60 * 60 * 24));
          
          return {
            ...purchase,
            purchaseDate: purchaseDate.toISOString().split('T')[0],
            operationStartDate: operationStartDate.toISOString().split('T')[0],
            isStarted,
            daysSinceStart,
            status: isStarted ? 'STARTED' : 'WAITING'
          };
        });
      }

      console.log('=== 調査完了 ===');
      setData(results);
      setLoading(false);
    } catch (err: any) {
      console.error('調査エラー:', err);
      setError(err.message);
      setLoading(false);
    }
  }

  if (loading) {
    return <div className="p-4">調査中...</div>;
  }

  if (error) {
    return (
      <div className="p-4">
        <div className="text-red-500 mb-4">エラー: {error}</div>
        {!user && (
          <div>
            <p className="mb-2">管理者として調査を行うためにログインしてください：</p>
            <a href="/login" className="text-blue-500 underline">ログインページへ</a>
          </div>
        )}
      </div>
    );
  }

  return (
    <div className="p-4 space-y-4">
      <h1 className="text-2xl font-bold">HASHPILOT 日利状況緊急調査</h1>
      
      <div className="grid gap-4">
        <Card>
          <CardHeader>
            <CardTitle>ユーザー「7A9637」の状況</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-2">
              <div><strong>基本情報:</strong></div>
              <pre className="bg-gray-100 p-2 rounded text-sm overflow-x-auto">
                {JSON.stringify(data.user7A9637, null, 2)}
              </pre>
              
              <div><strong>日利記録:</strong></div>
              <pre className="bg-gray-100 p-2 rounded text-sm overflow-x-auto">
                {JSON.stringify(data.profit7A9637, null, 2)}
              </pre>
              
              <div><strong>NFT購入状況:</strong></div>
              <pre className="bg-gray-100 p-2 rounded text-sm overflow-x-auto">
                {JSON.stringify(data.purchases7A9637, null, 2)}
              </pre>
              
              <div><strong>サイクル状況:</strong></div>
              <pre className="bg-gray-100 p-2 rounded text-sm overflow-x-auto">
                {JSON.stringify(data.cycle7A9637, null, 2)}
              </pre>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>ユーザー「2BF53B」の状況</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-2">
              <div><strong>基本情報:</strong></div>
              <pre className="bg-gray-100 p-2 rounded text-sm overflow-x-auto">
                {JSON.stringify(data.user2BF53B, null, 2)}
              </pre>
              
              <div><strong>日利記録:</strong></div>
              <pre className="bg-gray-100 p-2 rounded text-sm overflow-x-auto">
                {JSON.stringify(data.profit2BF53B, null, 2)}
              </pre>
              
              <div><strong>NFT購入状況:</strong></div>
              <pre className="bg-gray-100 p-2 rounded text-sm overflow-x-auto">
                {JSON.stringify(data.purchases2BF53B, null, 2)}
              </pre>
              
              <div><strong>サイクル状況:</strong></div>
              <pre className="bg-gray-100 p-2 rounded text-sm overflow-x-auto">
                {JSON.stringify(data.cycle2BF53B, null, 2)}
              </pre>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>承認済みユーザー一覧</CardTitle>
          </CardHeader>
          <CardContent>
            <pre className="bg-gray-100 p-2 rounded text-sm overflow-x-auto">
              {JSON.stringify(data.approvedUsers, null, 2)}
            </pre>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>最新の日利記録</CardTitle>
          </CardHeader>
          <CardContent>
            <pre className="bg-gray-100 p-2 rounded text-sm overflow-x-auto">
              {JSON.stringify(data.latestProfits, null, 2)}
            </pre>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>日利設定ログ</CardTitle>
          </CardHeader>
          <CardContent>
            <pre className="bg-gray-100 p-2 rounded text-sm overflow-x-auto">
              {JSON.stringify(data.yieldSettings, null, 2)}
            </pre>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>運用開始判定</CardTitle>
          </CardHeader>
          <CardContent>
            <pre className="bg-gray-100 p-2 rounded text-sm overflow-x-auto">
              {JSON.stringify(data.operationAnalysis, null, 2)}
            </pre>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>システムログ</CardTitle>
          </CardHeader>
          <CardContent>
            <pre className="bg-gray-100 p-2 rounded text-sm overflow-x-auto">
              {JSON.stringify(data.systemLogs, null, 2)}
            </pre>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}