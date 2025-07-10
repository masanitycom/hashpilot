"use client"

import { useState, useEffect } from "react"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Alert, AlertDescription } from "@/components/ui/alert"
import { Badge } from "@/components/ui/badge"
import { Wallet, DollarSign, Clock, CheckCircle, XCircle, AlertTriangle, ArrowUpRight } from "lucide-react"
import { supabase } from "@/lib/supabase"

interface WithdrawalRequestProps {
  userId: string
  availableUsdt: number
}

interface WithdrawalHistory {
  request_id: string
  amount: number
  wallet_address: string
  wallet_type: string
  status: string
  admin_notes: string | null
  transaction_hash: string | null
  created_at: string
  admin_approved_at: string | null
}

export function WithdrawalRequest({ userId, availableUsdt }: WithdrawalRequestProps) {
  const [amount, setAmount] = useState("")
  const [walletAddress, setWalletAddress] = useState("")
  const [walletType, setWalletType] = useState("USDT-TRC20")
  const [isLoading, setIsLoading] = useState(false)
  const [message, setMessage] = useState<{ type: "success" | "error" | "warning"; text: string } | null>(null)
  const [history, setHistory] = useState<WithdrawalHistory[]>([])
  const [showHistory, setShowHistory] = useState(false)

  useEffect(() => {
    if (userId) {
      fetchWithdrawalHistory()
    }
  }, [userId])

  const fetchWithdrawalHistory = async () => {
    try {
      const { data, error } = await supabase.rpc("get_user_withdrawal_history", {
        p_user_id: userId,
        p_limit: 10
      })

      if (error) throw error
      setHistory(data || [])
    } catch (error) {
      console.error("出金履歴取得エラー:", error)
    }
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setIsLoading(true)
    setMessage(null)

    try {
      const { data, error } = await supabase.rpc("create_withdrawal_request", {
        p_user_id: userId,
        p_amount: parseFloat(amount),
        p_wallet_address: walletAddress,
        p_wallet_type: walletType
      })

      if (error) throw error

      if (data && data.length > 0) {
        const result = data[0]
        if (result.status === "SUCCESS") {
          setMessage({
            type: "success",
            text: result.message
          })
          setAmount("")
          setWalletAddress("")
          await fetchWithdrawalHistory()
        } else {
          setMessage({
            type: "error",
            text: result.message
          })
        }
      }
    } catch (error: any) {
      setMessage({
        type: "error",
        text: error.message || "出金申請に失敗しました"
      })
    } finally {
      setIsLoading(false)
    }
  }

  const getStatusIcon = (status: string) => {
    switch (status) {
      case "pending":
        return <Clock className="h-4 w-4 text-yellow-400" />
      case "approved":
        return <CheckCircle className="h-4 w-4 text-green-400" />
      case "rejected":
        return <XCircle className="h-4 w-4 text-red-400" />
      case "completed":
        return <CheckCircle className="h-4 w-4 text-blue-400" />
      default:
        return <AlertTriangle className="h-4 w-4 text-gray-400" />
    }
  }

  const getStatusColor = (status: string) => {
    switch (status) {
      case "pending":
        return "bg-yellow-600"
      case "approved":
        return "bg-green-600"
      case "rejected":
        return "bg-red-600"
      case "completed":
        return "bg-blue-600"
      default:
        return "bg-gray-600"
    }
  }

  const getStatusText = (status: string) => {
    switch (status) {
      case "pending":
        return "審査中"
      case "approved":
        return "承認済み"
      case "rejected":
        return "拒否"
      case "completed":
        return "完了"
      default:
        return status
    }
  }

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleDateString("ja-JP", {
      year: "numeric",
      month: "short",
      day: "numeric",
      hour: "2-digit",
      minute: "2-digit"
    })
  }

  const hasPendingRequest = history.some(h => h.status === "pending")

  return (
    <div className="space-y-6">
      {/* 出金申請フォーム */}
      <Card className="bg-gray-800 border-gray-700">
        <CardHeader>
          <CardTitle className="text-white flex items-center gap-2">
            <Wallet className="h-5 w-5 text-green-400" />
            出金申請
          </CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="bg-green-900/20 border border-green-500/30 rounded-lg p-4">
            <div className="flex items-center justify-between">
              <span className="text-green-400 text-sm">利用可能残高</span>
              <span className="text-green-400 text-xl font-bold">
                ${availableUsdt.toFixed(2)}
              </span>
            </div>
          </div>

          {hasPendingRequest && (
            <Alert className="border-yellow-500 bg-yellow-900/20">
              <AlertTriangle className="h-4 w-4" />
              <AlertDescription className="text-yellow-300">
                保留中の出金申請があります。完了後に新しい申請が可能になります。
              </AlertDescription>
            </Alert>
          )}

          <form onSubmit={handleSubmit} className="space-y-4">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div className="space-y-2">
                <Label htmlFor="amount" className="text-white">
                  出金額 (USD)
                </Label>
                <Input
                  id="amount"
                  type="number"
                  step="0.01"
                  min="100"
                  max={availableUsdt}
                  value={amount}
                  onChange={(e) => setAmount(e.target.value)}
                  placeholder="最小 $100"
                  required
                  disabled={hasPendingRequest}
                  className="bg-gray-700 border-gray-600 text-white"
                />
                <p className="text-xs text-gray-400">最小出金額: $100</p>
              </div>

              <div className="space-y-2">
                <Label htmlFor="walletType" className="text-white">
                  ウォレットタイプ
                </Label>
                <Select
                  value={walletType}
                  onValueChange={setWalletType}
                  disabled={hasPendingRequest}
                >
                  <SelectTrigger className="bg-gray-700 border-gray-600 text-white">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="USDT-TRC20">USDT (TRC20)</SelectItem>
                    <SelectItem value="USDT-ERC20">USDT (ERC20)</SelectItem>
                    <SelectItem value="USDT-BEP20">USDT (BEP20)</SelectItem>
                  </SelectContent>
                </Select>
              </div>
            </div>

            <div className="space-y-2">
              <Label htmlFor="walletAddress" className="text-white">
                ウォレットアドレス
              </Label>
              <Input
                id="walletAddress"
                type="text"
                value={walletAddress}
                onChange={(e) => setWalletAddress(e.target.value)}
                placeholder="受取用ウォレットアドレスを入力"
                required
                disabled={hasPendingRequest}
                className="bg-gray-700 border-gray-600 text-white"
              />
              <p className="text-xs text-gray-400">
                正確なアドレスを入力してください。間違ったアドレスへの送金は復元できません。
              </p>
            </div>

            <Button
              type="submit"
              disabled={isLoading || hasPendingRequest || !amount || !walletAddress}
              className="w-full bg-green-600 hover:bg-green-700 disabled:bg-gray-600"
            >
              {isLoading ? "申請中..." : "出金申請"}
            </Button>
          </form>

          {message && (
            <Alert
              className={`${
                message.type === "error"
                  ? "border-red-500 bg-red-900/20"
                  : message.type === "warning"
                  ? "border-yellow-500 bg-yellow-900/20"
                  : "border-green-500 bg-green-900/20"
              }`}
            >
              <AlertDescription
                className={
                  message.type === "error"
                    ? "text-red-300"
                    : message.type === "warning"
                    ? "text-yellow-300"
                    : "text-green-300"
                }
              >
                {message.text}
              </AlertDescription>
            </Alert>
          )}
        </CardContent>
      </Card>

      {/* 出金履歴 */}
      <Card className="bg-gray-800 border-gray-700">
        <CardHeader>
          <div className="flex items-center justify-between">
            <CardTitle className="text-white flex items-center gap-2">
              <DollarSign className="h-5 w-5 text-blue-400" />
              出金履歴
            </CardTitle>
            <Button
              onClick={() => setShowHistory(!showHistory)}
              variant="ghost"
              size="sm"
              className="text-gray-400 hover:text-white"
            >
              {showHistory ? "非表示" : "表示"}
            </Button>
          </div>
        </CardHeader>
        {showHistory && (
          <CardContent>
            {history.length === 0 ? (
              <p className="text-gray-400 text-center py-4">出金履歴がありません</p>
            ) : (
              <div className="space-y-3">
                {history.map((item) => (
                  <div
                    key={item.request_id}
                    className="bg-gray-700/50 border border-gray-600 rounded-lg p-4 space-y-3"
                  >
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-2">
                        {getStatusIcon(item.status)}
                        <span className="text-white font-medium">
                          ${item.amount.toFixed(2)}
                        </span>
                      </div>
                      <Badge className={getStatusColor(item.status)}>
                        {getStatusText(item.status)}
                      </Badge>
                    </div>

                    <div className="grid grid-cols-1 md:grid-cols-2 gap-2 text-sm">
                      <div>
                        <span className="text-gray-400">ウォレット: </span>
                        <span className="text-white">{item.wallet_type}</span>
                      </div>
                      <div>
                        <span className="text-gray-400">申請日: </span>
                        <span className="text-white">{formatDate(item.created_at)}</span>
                      </div>
                    </div>

                    <div className="text-xs">
                      <span className="text-gray-400">アドレス: </span>
                      <span className="text-gray-300 font-mono break-all">
                        {item.wallet_address}
                      </span>
                    </div>

                    {item.transaction_hash && (
                      <div className="text-xs">
                        <span className="text-gray-400">トランザクション: </span>
                        <span className="text-blue-400 font-mono break-all">
                          {item.transaction_hash}
                        </span>
                      </div>
                    )}

                    {item.admin_notes && (
                      <div className="text-xs">
                        <span className="text-gray-400">備考: </span>
                        <span className="text-gray-300">{item.admin_notes}</span>
                      </div>
                    )}
                  </div>
                ))}
              </div>
            )}
          </CardContent>
        )}
      </Card>
    </div>
  )
}

export default WithdrawalRequest