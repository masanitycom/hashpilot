"use client"

import { useState, useEffect } from "react"
import { Card, CardContent } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Alert, AlertDescription } from "@/components/ui/alert"
import { AlertTriangle, CheckCircle, Clock, DollarSign, Info } from "lucide-react"
import { supabase } from "@/lib/supabase"

interface MonthlyWithdrawalAlertProps {
  userId: string
  hasCoinwUid: boolean
}

interface PendingWithdrawal {
  id: string
  withdrawal_month: string
  total_amount: number
  status: string
  withdrawal_method: string | null
}

export function MonthlyWithdrawalAlert({ userId, hasCoinwUid }: MonthlyWithdrawalAlertProps) {
  const [pendingWithdrawals, setPendingWithdrawals] = useState<PendingWithdrawal[]>([])
  const [onHoldAmount, setOnHoldAmount] = useState<number>(0)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    if (userId) {
      fetchPendingWithdrawals()
    }
  }, [userId])

  const fetchPendingWithdrawals = async () => {
    try {
      setLoading(true)

      // 過去3ヶ月の出金記録を取得
      const threeMonthsAgo = new Date()
      threeMonthsAgo.setMonth(threeMonthsAgo.getMonth() - 3)

      const { data, error } = await supabase
        .from("monthly_withdrawals")
        .select("*")
        .eq("user_id", userId)
        .gte("withdrawal_month", threeMonthsAgo.toISOString().split('T')[0])
        .in("status", ["pending", "on_hold"])
        .order("withdrawal_month", { ascending: false })

      if (error && error.code !== "PGRST116") {
        throw error
      }

      const withdrawals = data || []
      setPendingWithdrawals(withdrawals.filter(w => w.status === "pending"))
      
      const holdAmount = withdrawals
        .filter(w => w.status === "on_hold")
        .reduce((sum, w) => sum + Number(w.total_amount), 0)
      setOnHoldAmount(holdAmount)

    } catch (err: any) {
      console.error("Error fetching pending withdrawals:", err)
    } finally {
      setLoading(false)
    }
  }

  const isMonthEnd = () => {
    const now = new Date()
    const lastDay = new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate()
    return now.getDate() >= lastDay - 2 // 月末2日前から表示
  }

  const formatMonth = (dateString: string) => {
    const date = new Date(dateString)
    return `${date.getFullYear()}年${date.getMonth() + 1}月`
  }

  if (loading) return null

  return (
    <div className="space-y-4">
      {/* 月末出金の説明 */}
      <Alert className="border-blue-700/50 bg-blue-900/20">
        <Info className="h-4 w-4" />
        <AlertDescription className="text-blue-200">
          <div className="space-y-2">
            <p className="font-medium">月末自動出金について</p>
            <ul className="text-sm space-y-1 ml-4">
              <li>• 毎月月末に自動的に報酬が出金処理されます</li>
              <li>• CoinW UIDで無料送金されます（全ユーザー設定済み）</li>
              <li>• 1ドルから出金可能です</li>
            </ul>
          </div>
        </AlertDescription>
      </Alert>

      {/* CoinW UID未設定アラート */}
      {!hasCoinwUid && isMonthEnd() && (
        <Alert className="border-red-500/50 bg-red-900/20">
          <AlertTriangle className="h-4 w-4" />
          <AlertDescription className="text-red-200">
            <div className="space-y-2">
              <p className="font-medium">⚠️ CoinW UIDが未設定です</p>
              <p className="text-sm">
                月末出金処理のため、CoinW UIDの設定が必要です。
                設定がない場合、出金が保留され、手動で設定するまで送金されません。
              </p>
            </div>
          </AlertDescription>
        </Alert>
      )}

      {/* 保留中出金額の表示 */}
      {onHoldAmount > 0 && (
        <Card className="bg-yellow-900/20 border-yellow-700/50">
          <CardContent className="p-4">
            <div className="flex items-center justify-between">
              <div className="flex items-center space-x-3">
                <Clock className="h-5 w-5 text-yellow-400" />
                <div>
                  <p className="font-medium text-yellow-200">保留中の出金額</p>
                  <p className="text-sm text-yellow-300">CoinW UID設定待ち</p>
                </div>
              </div>
              <div className="text-right">
                <p className="text-2xl font-bold text-yellow-400">
                  ${onHoldAmount.toFixed(2)}
                </p>
                <p className="text-xs text-yellow-300">設定後に送金されます</p>
              </div>
            </div>
          </CardContent>
        </Card>
      )}

      {/* 送金待ち出金の表示 */}
      {pendingWithdrawals.length > 0 && (
        <Card className="bg-green-900/20 border-green-700/50">
          <CardContent className="p-4">
            <div className="space-y-3">
              <div className="flex items-center space-x-2">
                <CheckCircle className="h-5 w-5 text-green-400" />
                <p className="font-medium text-green-200">送金予定の出金</p>
              </div>
              
              {pendingWithdrawals.map((withdrawal) => (
                <div key={withdrawal.id} className="flex items-center justify-between p-3 bg-green-900/30 rounded-lg">
                  <div>
                    <p className="text-sm font-medium text-green-200">
                      {formatMonth(withdrawal.withdrawal_month)}分
                    </p>
                    <p className="text-xs text-green-300">
                      送金方法: {withdrawal.withdrawal_method === 'coinw' ? 'CoinW' : 'BEP20アドレス'}
                    </p>
                  </div>
                  <div className="text-right">
                    <p className="font-bold text-green-400">
                      ${Number(withdrawal.total_amount).toFixed(2)}
                    </p>
                    <Badge className="bg-green-600 text-white text-xs">
                      送金待ち
                    </Badge>
                  </div>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>
      )}

      {/* CoinW UID設定完了の表示 */}
      {hasCoinwUid && onHoldAmount === 0 && (
        <Card className="bg-green-900/20 border-green-700/50">
          <CardContent className="p-4">
            <div className="flex items-center space-x-3">
              <CheckCircle className="h-5 w-5 text-green-400" />
              <div>
                <p className="font-medium text-green-200">月末出金設定完了</p>
                <p className="text-sm text-green-300">
                  CoinW UIDが設定済みです。月末に自動的に出金処理されます。
                </p>
              </div>
            </div>
          </CardContent>
        </Card>
      )}
    </div>
  )
}

