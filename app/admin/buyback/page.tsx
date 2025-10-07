"use client"

import { useState, useEffect } from "react"
import { useRouter } from "next/navigation"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Badge } from "@/components/ui/badge"
import { Alert, AlertDescription } from "@/components/ui/alert"
import { Textarea } from "@/components/ui/textarea"
import { supabase } from "@/lib/supabase"
import { 
  ArrowLeft, 
  DollarSign, 
  CheckCircle, 
  XCircle, 
  Loader2,
  Clock,
  AlertCircle,
  RefreshCw,
  Copy
} from "lucide-react"

interface BuybackRequest {
  id: string
  user_id: string
  email: string
  request_date: string
  manual_nft_count: number
  auto_nft_count: number
  total_nft_count: number
  manual_buyback_amount: number
  auto_buyback_amount: number
  total_buyback_amount: number
  wallet_address: string
  wallet_type: string
  status: string
  processed_by: string | null
  processed_at: string | null
  transaction_hash: string | null
  is_pegasus_exchange?: boolean
  pegasus_exchange_date?: string | null
  pegasus_withdrawal_unlock_date?: string | null
}

export default function AdminBuybackPage() {
  const [requests, setRequests] = useState<BuybackRequest[]>([])
  const [loading, setLoading] = useState(true)
  const [processingId, setProcessingId] = useState<string | null>(null)
  const [selectedRequest, setSelectedRequest] = useState<BuybackRequest | null>(null)
  const [transactionHash, setTransactionHash] = useState("")
  const [adminNotes, setAdminNotes] = useState("")
  const [filter, setFilter] = useState<"all" | "pending" | "completed" | "cancelled">("pending")
  const [message, setMessage] = useState<{ type: "success" | "error"; text: string } | null>(null)
  const [adminUser, setAdminUser] = useState<any>(null)
  const router = useRouter()

  useEffect(() => {
    checkAdminAccess()
  }, [])

  useEffect(() => {
    if (adminUser) {
      fetchRequests()
    }
  }, [filter, adminUser])

  const checkAdminAccess = async () => {
    try {
      const { data: { user } } = await supabase.auth.getUser()
      
      if (!user) {
        router.push("/login")
        return
      }

      // 緊急対応: 管理者メールのアクセス許可
      if (user.email === "basarasystems@gmail.com" || 
          user.email === "support@dshsupport.biz" || 
          user.email === "masataka.tak@gmail.com") {
        setAdminUser(user)
        return
      }

      // 管理者チェック（暫定的にコメントアウト）
      /*
      const { data: adminCheck, error: adminError } = await supabase.rpc("is_admin", {
        user_email: user.email,
      })

      if (adminError || !adminCheck) {
        router.push("/admin")
        return
      }
      */

      setAdminUser(user)
    } catch (error) {
      console.error("Error checking admin access:", error)
      router.push("/admin")
    }
  }

  const fetchRequests = async () => {
    try {
      setLoading(true)
      
      // 買い取り申請データを取得（usersテーブルからペガサス情報も取得）
      let query = supabase
        .from("buyback_requests")
        .select(`
          *,
          users!inner(
            is_pegasus_exchange,
            pegasus_exchange_date,
            pegasus_withdrawal_unlock_date
          )
        `)
        .order("request_date", { ascending: false })

      if (filter !== "all") {
        query = query.eq("status", filter)
      }

      const { data: buybackData, error: buybackError } = await query

      if (buybackError) {
        console.error("Buyback requests table access failed:", buybackError)
        setRequests([])
        setMessage({ type: "error", text: "データの取得に失敗しました" })
        return
      }

      // データを整形（JOINで取得したusers情報を展開）
      const formattedData = (buybackData || []).map((item: any) => {
        const userData = item.users || {}
        return {
          ...item,
          email: item.email || item.user_id || 'Unknown',
          is_pegasus_exchange: userData.is_pegasus_exchange || false,
          pegasus_exchange_date: userData.pegasus_exchange_date || null,
          pegasus_withdrawal_unlock_date: userData.pegasus_withdrawal_unlock_date || null,
        }
      })

      setRequests(formattedData)
    } catch (error) {
      console.error("Error fetching buyback requests:", error)
      setRequests([]) // エラー時は空配列
    } finally {
      setLoading(false)
    }
  }

  const processRequest = async (action: "complete" | "cancel") => {
    if (!selectedRequest || !adminUser) return

    if (action === "complete" && !transactionHash) {
      setMessage({ type: "error", text: "トランザクションハッシュを入力してください" })
      return
    }

    setProcessingId(selectedRequest.id)
    setMessage(null)

    try {
      const { data, error } = await supabase.rpc("process_buyback_request", {
        p_request_id: selectedRequest.id,
        p_action: action,
        p_transaction_hash: action === "complete" ? transactionHash : null,
        p_admin_notes: adminNotes || null,
        p_admin_email: adminUser.email
      })

      if (error) throw error

      if (data && data[0]?.status === "SUCCESS") {
        setMessage({
          type: "success",
          text: action === "complete" ? "買い取りが完了しました" : "申請を却下しました"
        })

        // モーダルをクリア
        setSelectedRequest(null)
        setTransactionHash("")
        setAdminNotes("")

        // リストを更新
        fetchRequests()
      } else {
        throw new Error(data?.[0]?.message || "処理に失敗しました")
      }
    } catch (error: any) {
      setMessage({ type: "error", text: error.message || "処理中にエラーが発生しました" })
    } finally {
      setProcessingId(null)
    }
  }

  const copyToClipboard = (text: string) => {
    navigator.clipboard.writeText(text)
    setMessage({ type: "success", text: `コピーしました: ${text.length > 20 ? text.substring(0, 20) + '...' : text}` })
    setTimeout(() => setMessage(null), 3000)
  }

  const getStatusBadge = (status: string) => {
    switch (status) {
      case "pending":
        return (
          <Badge className="bg-yellow-900/50 text-yellow-400 border-yellow-700">
            <Clock className="h-3 w-3 mr-1" />
            申請中
          </Badge>
        )
      case "completed":
        return (
          <Badge className="bg-green-900/50 text-green-400 border-green-700">
            <CheckCircle className="h-3 w-3 mr-1" />
            完了
          </Badge>
        )
      case "cancelled":
        return (
          <Badge className="bg-red-900/50 text-red-400 border-red-700">
            <XCircle className="h-3 w-3 mr-1" />
            却下
          </Badge>
        )
      default:
        return <Badge>{status}</Badge>
    }
  }

  const stats = {
    pending: requests.filter(r => r.status === "pending").length,
    total_pending_amount: requests
      .filter(r => r.status === "pending")
      .reduce((sum, r) => sum + r.total_buyback_amount, 0),
    completed_today: requests
      .filter(r => r.status === "completed" && 
        new Date(r.processed_at!).toDateString() === new Date().toDateString()
      ).length
  }

  return (
    <div className="min-h-screen bg-gray-950 text-white">
      <div className="container mx-auto p-4 md:p-6 space-y-6">
        {/* ヘッダー */}
        <div className="flex items-center justify-between">
          <div className="flex items-center space-x-4">
            <Button
              variant="ghost"
              size="icon"
              onClick={() => router.push("/admin")}
              className="text-gray-400 hover:text-white"
            >
              <ArrowLeft className="h-5 w-5" />
            </Button>
            <h1 className="text-2xl font-bold">NFT買い取り管理</h1>
          </div>
          <Button
            onClick={fetchRequests}
            variant="outline"
            size="sm"
            className="text-white bg-gray-700 border-gray-600 hover:bg-gray-600"
          >
            <RefreshCw className="h-4 w-4 mr-2" />
            更新
          </Button>
        </div>

        {/* 統計情報 */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <Card className="bg-gray-900/50 border-gray-700">
            <CardContent className="p-4">
              <div className="flex items-center justify-between">
                <div>
                  <div className="text-sm text-gray-400">保留中の申請</div>
                  <div className="text-2xl font-bold text-yellow-400">{stats.pending}件</div>
                </div>
                <Clock className="h-8 w-8 text-gray-600" />
              </div>
            </CardContent>
          </Card>

          <Card className="bg-gray-900/50 border-gray-700">
            <CardContent className="p-4">
              <div className="flex items-center justify-between">
                <div>
                  <div className="text-sm text-gray-400">保留中の総額</div>
                  <div className="text-2xl font-bold text-yellow-400">
                    ${stats.total_pending_amount.toLocaleString()}
                  </div>
                </div>
                <DollarSign className="h-8 w-8 text-gray-600" />
              </div>
            </CardContent>
          </Card>

          <Card className="bg-gray-900/50 border-gray-700">
            <CardContent className="p-4">
              <div className="flex items-center justify-between">
                <div>
                  <div className="text-sm text-gray-400">本日完了</div>
                  <div className="text-2xl font-bold text-green-400">{stats.completed_today}件</div>
                </div>
                <CheckCircle className="h-8 w-8 text-gray-600" />
              </div>
            </CardContent>
          </Card>
        </div>

        {/* フィルター */}
        <div className="flex space-x-2">
          {(["all", "pending", "completed", "cancelled"] as const).map((status) => (
            <Button
              key={status}
              variant={filter === status ? "default" : "outline"}
              size="sm"
              onClick={() => setFilter(status)}
              className={filter === status 
                ? "bg-yellow-600 hover:bg-yellow-700 text-white border-yellow-600" 
                : "text-white border-gray-600 hover:bg-gray-700 bg-gray-800"
              }
            >
              {status === "all" && "すべて"}
              {status === "pending" && "申請中"}
              {status === "completed" && "完了"}
              {status === "cancelled" && "却下"}
            </Button>
          ))}
        </div>

        {/* メッセージ */}
        {message && (
          <Alert className={message.type === "error" ? "bg-red-900/20 border-red-700" : "bg-green-900/20 border-green-700"}>
            <AlertDescription className={message.type === "error" ? "text-red-400" : "text-green-400"}>
              {message.type === "error" ? <AlertCircle className="h-4 w-4 inline mr-2" /> : <CheckCircle className="h-4 w-4 inline mr-2" />}
              {message.text}
            </AlertDescription>
          </Alert>
        )}

        {/* 申請一覧 */}
        <Card className="bg-gray-900/50 border-gray-700">
          <CardHeader>
            <CardTitle className="text-white">買い取り申請一覧</CardTitle>
          </CardHeader>
          <CardContent>
            {loading ? (
              <div className="flex items-center justify-center py-8">
                <Loader2 className="h-8 w-8 animate-spin text-gray-400" />
              </div>
            ) : requests.length === 0 ? (
              <div className="text-center py-8 text-gray-400">
                申請がありません
              </div>
            ) : (
              <div className="overflow-x-auto">
                <table className="w-full">
                  <thead>
                    <tr className="border-b border-gray-700">
                      <th className="text-left p-3 text-gray-400">申請日</th>
                      <th className="text-left p-3 text-gray-400">ユーザー</th>
                      <th className="text-center p-3 text-gray-400">手動NFT</th>
                      <th className="text-center p-3 text-gray-400">自動NFT</th>
                      <th className="text-left p-3 text-gray-400">送金先</th>
                      <th className="text-right p-3 text-gray-400">買い取り額</th>
                      <th className="text-center p-3 text-gray-400">ステータス</th>
                      <th className="text-center p-3 text-gray-400">アクション</th>
                    </tr>
                  </thead>
                  <tbody>
                    {requests.map((request) => (
                      <tr key={request.id} className="border-b border-gray-800 hover:bg-gray-800/30">
                        <td className="p-3 text-white">
                          {new Date(request.request_date).toLocaleDateString()}
                        </td>
                        <td className="p-3">
                          <div className="text-white">{request.email}</div>
                          <div className="text-xs text-gray-500">{request.user_id}</div>
                          {request.is_pegasus_exchange && (
                            <div className="mt-1">
                              <Badge className="bg-yellow-600 text-white text-xs">🐴 ペガサス交換</Badge>
                            </div>
                          )}
                        </td>
                        <td className="p-3 text-center text-white">
                          {request.manual_nft_count}枚
                          {request.manual_nft_count > 0 && (
                            <div className="text-xs text-gray-500">
                              ${request.manual_buyback_amount}
                            </div>
                          )}
                        </td>
                        <td className="p-3 text-center text-white">
                          {request.auto_nft_count}枚
                          {request.auto_nft_count > 0 && (
                            <div className="text-xs text-gray-500">
                              ${request.auto_buyback_amount}
                            </div>
                          )}
                        </td>
                        <td className="p-3 text-left">
                          <div className="text-white font-mono text-sm">
                            {request.wallet_type === "CoinW" ? (
                              <div>
                                <div className="text-orange-400 text-xs">CoinW UID</div>
                                <button
                                  onClick={() => copyToClipboard(request.wallet_address)}
                                  className="text-white hover:text-orange-400 transition-colors cursor-pointer text-left p-1 -ml-1 rounded hover:bg-gray-800"
                                  title="クリックでコピー"
                                >
                                  <div className="flex items-center space-x-1">
                                    <span>{request.wallet_address}</span>
                                    <Copy className="h-3 w-3" />
                                  </div>
                                </button>
                              </div>
                            ) : (
                              <div>
                                <div className="text-green-400 text-xs">USDT-BEP20</div>
                                <button
                                  onClick={() => copyToClipboard(request.wallet_address)}
                                  className="text-white hover:text-green-400 transition-colors cursor-pointer text-left p-1 -ml-1 rounded hover:bg-gray-800"
                                  title="クリックでコピー"
                                >
                                  <div className="flex items-center space-x-1">
                                    <span className="text-xs break-all">{request.wallet_address}</span>
                                    <Copy className="h-3 w-3 flex-shrink-0" />
                                  </div>
                                </button>
                              </div>
                            )}
                          </div>
                        </td>
                        <td className="p-3 text-right">
                          <div className="text-yellow-400 font-bold">
                            ${request.total_buyback_amount.toLocaleString()}
                          </div>
                        </td>
                        <td className="p-3 text-center">
                          {getStatusBadge(request.status)}
                        </td>
                        <td className="p-3 text-center">
                          {request.status === "pending" ? (
                            <Button
                              size="sm"
                              variant="outline"
                              onClick={() => setSelectedRequest(request)}
                              className="text-white bg-yellow-600 border-yellow-600 hover:bg-yellow-700"
                            >
                              処理
                            </Button>
                          ) : request.status === "completed" && request.transaction_hash ? (
                            <Button
                              size="sm"
                              variant="ghost"
                              onClick={() => copyToClipboard(request.transaction_hash!)}
                              className="text-white bg-gray-600 hover:bg-gray-700 border border-gray-500"
                            >
                              <Copy className="h-3 w-3" />
                            </Button>
                          ) : null}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </CardContent>
        </Card>

        {/* 処理モーダル */}
        {selectedRequest && (
          <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
            <Card className="bg-gray-900 border-gray-700 max-w-lg w-full">
              <CardHeader>
                <CardTitle className="text-white">買い取り申請処理</CardTitle>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="space-y-2">
                  <div className="text-sm text-gray-400">申請者</div>
                  <div className="text-white">{selectedRequest.email}</div>
                </div>

                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <div className="text-sm text-gray-400">手動NFT</div>
                    <div className="text-white">{selectedRequest.manual_nft_count}枚 (${selectedRequest.manual_buyback_amount})</div>
                  </div>
                  <div>
                    <div className="text-sm text-gray-400">自動NFT</div>
                    <div className="text-white">{selectedRequest.auto_nft_count}枚 (${selectedRequest.auto_buyback_amount})</div>
                  </div>
                </div>

                <div>
                  <div className="text-sm text-gray-400">買い取り総額</div>
                  <div className="text-2xl font-bold text-yellow-400">
                    ${selectedRequest.total_buyback_amount.toLocaleString()}
                  </div>
                </div>

                <div>
                  <div className="text-sm text-gray-400 mb-1">送金先アドレス</div>
                  <div className="flex items-center space-x-2">
                    <code className="bg-gray-800 p-2 rounded text-xs text-white flex-1 overflow-x-auto">
                      {selectedRequest.wallet_address}
                    </code>
                    <Button
                      size="sm"
                      variant="ghost"
                      onClick={() => copyToClipboard(selectedRequest.wallet_address)}
                      className="text-gray-400 hover:text-white"
                    >
                      <Copy className="h-4 w-4" />
                    </Button>
                  </div>
                </div>

                <div>
                  <Label htmlFor="txHash" className="text-white">トランザクションハッシュ</Label>
                  <Input
                    id="txHash"
                    value={transactionHash}
                    onChange={(e) => setTransactionHash(e.target.value)}
                    placeholder="0x..."
                    className="bg-gray-800 border-gray-700 text-white"
                  />
                </div>

                <div>
                  <Label htmlFor="notes" className="text-white">管理者メモ（任意）</Label>
                  <Textarea
                    id="notes"
                    value={adminNotes}
                    onChange={(e) => setAdminNotes(e.target.value)}
                    rows={3}
                    className="bg-gray-800 border-gray-700 text-white"
                  />
                </div>

                <div className="space-y-3 pt-4">
                  <Button
                    onClick={() => processRequest("complete")}
                    disabled={processingId === selectedRequest.id || !transactionHash}
                    className="w-full bg-green-600 hover:bg-green-700 text-white"
                  >
                    {processingId === selectedRequest.id ? (
                      <Loader2 className="h-4 w-4 animate-spin mr-2" />
                    ) : (
                      <CheckCircle className="h-4 w-4 mr-2" />
                    )}
                    送金完了（承認）
                  </Button>

                  <Button
                    onClick={() => processRequest("cancel")}
                    disabled={processingId === selectedRequest.id}
                    className="w-full text-white bg-red-600 border-red-600 hover:bg-red-700"
                  >
                    {processingId === selectedRequest.id ? (
                      <Loader2 className="h-4 w-4 animate-spin mr-2" />
                    ) : (
                      <XCircle className="h-4 w-4 mr-2" />
                    )}
                    却下する
                  </Button>

                  <Button
                    onClick={() => {
                      setSelectedRequest(null)
                      setTransactionHash("")
                      setAdminNotes("")
                    }}
                    variant="outline"
                    className="w-full text-white border-gray-600 hover:bg-gray-800"
                    disabled={processingId === selectedRequest.id}
                  >
                    閉じる
                  </Button>
                </div>
              </CardContent>
            </Card>
          </div>
        )}
      </div>
    </div>
  )
}