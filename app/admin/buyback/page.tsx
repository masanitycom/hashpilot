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
  DollarSign,
  CheckCircle,
  XCircle,
  Loader2,
  Clock,
  AlertCircle,
  RefreshCw,
  Copy,
  Coins,
  Pencil,
  Save
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
  transaction_id: string | null
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
  // 送金先アドレスの編集（ユーザーから「アドレスを変えたい」と連絡が来るケース用）
  const [editingAddress, setEditingAddress] = useState(false)
  const [newAddress, setNewAddress] = useState("")
  const [savingAddress, setSavingAddress] = useState(false)
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

      // get_all_buyback_requests関数を使用
      const { data: buybackData, error: buybackError } = await supabase.rpc(
        "get_all_buyback_requests",
        filter === "all" ? {} : { p_status: filter }
      )

      if (buybackError) {
        console.error("Buyback requests fetch failed:", buybackError)
        setRequests([])
        setMessage({ type: "error", text: "データの取得に失敗しました" })
        return
      }

      // ペガサス情報を取得するためにusersテーブルから追加情報を取得
      const requestsWithPegasus = await Promise.all(
        (buybackData || []).map(async (request: any) => {
          const { data: userData } = await supabase
            .from("users")
            .select("is_pegasus_exchange, pegasus_exchange_date, pegasus_withdrawal_unlock_date")
            .eq("user_id", request.user_id)
            .single()

          return {
            ...request,
            is_pegasus_exchange: userData?.is_pegasus_exchange || false,
            pegasus_exchange_date: userData?.pegasus_exchange_date || null,
            pegasus_withdrawal_unlock_date: userData?.pegasus_withdrawal_unlock_date || null,
          }
        })
      )

      setRequests(requestsWithPegasus)
    } catch (error) {
      console.error("Error fetching buyback requests:", error)
      setRequests([])
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
        closeModal()

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

  const openRequest = (request: BuybackRequest) => {
    setSelectedRequest(request)
    setTransactionHash("")
    setAdminNotes("")
    setEditingAddress(false)
    setNewAddress(request.wallet_address)
  }

  const closeModal = () => {
    setSelectedRequest(null)
    setTransactionHash("")
    setAdminNotes("")
    setEditingAddress(false)
    setNewAddress("")
  }

  // 送金先アドレスの変更（pendingの申請のみ。wallet_typeは変更しない）
  const saveWalletAddress = async () => {
    if (!selectedRequest || !adminUser) return

    const trimmed = newAddress.trim()

    if (!trimmed) {
      setMessage({ type: "error", text: "送金先アドレスを入力してください" })
      return
    }

    if (trimmed === selectedRequest.wallet_address) {
      setEditingAddress(false)
      return
    }

    // サーバー側でも同じ検証をしているが、往復する前に弾く
    if (selectedRequest.wallet_type === "CoinW") {
      if (!/^[0-9]{5,20}$/.test(trimmed)) {
        setMessage({ type: "error", text: "CoinW UIDは5〜20桁の数字で入力してください" })
        return
      }
    } else if (!/^0x[0-9a-fA-F]{40}$/.test(trimmed)) {
      setMessage({ type: "error", text: "USDT-BEP20アドレスの形式が正しくありません（0x + 16進40桁）" })
      return
    }

    if (!confirm(`送金先アドレスを変更します。よろしいですか？\n\n変更前: ${selectedRequest.wallet_address}\n変更後: ${trimmed}`)) {
      return
    }

    setSavingAddress(true)
    setMessage(null)

    try {
      const { data, error } = await supabase.rpc("admin_update_buyback_wallet_address", {
        p_request_id: selectedRequest.id,
        p_wallet_address: trimmed,
        p_admin_email: adminUser.email,
      })

      if (error) throw error

      const result = Array.isArray(data) ? data[0] : data

      if (result?.status !== "SUCCESS" && result?.status !== "NO_CHANGE") {
        throw new Error(result?.message || "変更に失敗しました")
      }

      // 画面上の値も更新（再取得を待たずに反映）
      setSelectedRequest({ ...selectedRequest, wallet_address: trimmed })
      setRequests((prev) =>
        prev.map((r) => (r.id === selectedRequest.id ? { ...r, wallet_address: trimmed } : r))
      )
      setEditingAddress(false)
      setMessage({ type: "success", text: result?.message || "送金先アドレスを変更しました" })

      fetchRequests()
    } catch (error: any) {
      setMessage({ type: "error", text: error.message || "変更中にエラーが発生しました" })
    } finally {
      setSavingAddress(false)
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
          <div className="flex items-center gap-4">
            <img src="/images/hash-pilot-logo.png" alt="HASH PILOT" className="h-10 rounded-lg shadow-lg" />
            <h1 className="text-2xl font-bold text-white flex items-center gap-2">
              <Coins className="h-6 w-6 text-orange-400" />
              NFT買い取り管理
            </h1>
          </div>
          <div className="flex items-center gap-2">
            <Button
              onClick={fetchRequests}
              variant="outline"
              size="sm"
              className="text-white bg-gray-700 border-gray-600 hover:bg-gray-600"
            >
              <RefreshCw className="h-4 w-4 mr-2" />
              更新
            </Button>
            <Button
              onClick={() => router.push("/admin")}
              variant="outline"
              size="sm"
              className="bg-blue-600 hover:bg-blue-700 text-white border-blue-600"
            >
              管理者ダッシュボード
            </Button>
          </div>
        </div>

        {/* 統計情報 */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <Card className="bg-black/50 border-gray-700">
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

          <Card className="bg-black/50 border-gray-700">
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

          <Card className="bg-black/50 border-gray-700">
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
        <Card className="bg-black/50 border-gray-700">
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
                      <th className="text-left p-3 text-gray-400">NFT返却TxID</th>
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
                        <td className="p-3 text-left">
                          {request.transaction_id ? (
                            <button
                              onClick={() => copyToClipboard(request.transaction_id!)}
                              className="text-white hover:text-blue-400 transition-colors cursor-pointer text-left p-1 -ml-1 rounded hover:bg-gray-800"
                              title="クリックでコピー"
                            >
                              <div className="flex items-center space-x-1">
                                <span className="text-xs font-mono break-all">
                                  {request.transaction_id.substring(0, 10)}...
                                </span>
                                <Copy className="h-3 w-3 flex-shrink-0" />
                              </div>
                            </button>
                          ) : (
                            <span className="text-gray-500 text-xs">未入力</span>
                          )}
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
                              onClick={() => openRequest(request)}
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
            <Card className="bg-black border-gray-700 max-w-lg w-full">
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
                  <div className="text-sm text-gray-400 mb-1">
                    送金先アドレス
                    <span className="ml-2 text-xs text-gray-500">
                      ({selectedRequest.wallet_type || "USDT-BEP20"})
                    </span>
                  </div>

                  {editingAddress ? (
                    <div className="space-y-2">
                      <Input
                        value={newAddress}
                        onChange={(e) => setNewAddress(e.target.value)}
                        placeholder={selectedRequest.wallet_type === "CoinW" ? "CoinW UID（数字）" : "0x..."}
                        className="bg-gray-800 border-yellow-700 text-white font-mono text-xs"
                        disabled={savingAddress}
                      />
                      <div className="text-xs text-gray-500">
                        変更前: <span className="font-mono break-all">{selectedRequest.wallet_address}</span>
                      </div>
                      <div className="flex items-center space-x-2">
                        <Button
                          size="sm"
                          onClick={saveWalletAddress}
                          disabled={savingAddress}
                          className="bg-yellow-600 hover:bg-yellow-700 text-white"
                        >
                          {savingAddress ? (
                            <Loader2 className="h-4 w-4 animate-spin mr-1" />
                          ) : (
                            <Save className="h-4 w-4 mr-1" />
                          )}
                          保存
                        </Button>
                        <Button
                          size="sm"
                          onClick={() => {
                            setEditingAddress(false)
                            setNewAddress(selectedRequest.wallet_address)
                          }}
                          disabled={savingAddress}
                          className="bg-gray-700 text-white border-gray-600 hover:bg-gray-800"
                        >
                          キャンセル
                        </Button>
                      </div>
                      <div className="text-xs text-yellow-500">
                        ※ 送金先を間違えると資金は戻りません。ユーザー本人からの依頼であることを確認してください。
                      </div>
                    </div>
                  ) : (
                    <div className="flex items-center space-x-2">
                      <code className="bg-gray-800 p-2 rounded text-xs text-white flex-1 overflow-x-auto break-all">
                        {selectedRequest.wallet_address}
                      </code>
                      <Button
                        size="sm"
                        variant="ghost"
                        onClick={() => copyToClipboard(selectedRequest.wallet_address)}
                        className="text-gray-400 hover:text-white"
                        title="コピー"
                      >
                        <Copy className="h-4 w-4" />
                      </Button>
                      <Button
                        size="sm"
                        variant="ghost"
                        onClick={() => {
                          setNewAddress(selectedRequest.wallet_address)
                          setEditingAddress(true)
                        }}
                        className="text-yellow-400 hover:text-yellow-300"
                        title="送金先アドレスを変更"
                      >
                        <Pencil className="h-4 w-4" />
                      </Button>
                    </div>
                  )}
                </div>

                {selectedRequest.transaction_id && (
                  <div>
                    <div className="text-sm text-gray-400 mb-1">NFT返却トランザクションID</div>
                    <div className="flex items-center space-x-2">
                      <code className="bg-blue-900/20 border border-blue-700 p-2 rounded text-xs text-blue-300 flex-1 overflow-x-auto">
                        {selectedRequest.transaction_id}
                      </code>
                      <Button
                        size="sm"
                        variant="ghost"
                        onClick={() => copyToClipboard(selectedRequest.transaction_id!)}
                        className="text-gray-400 hover:text-white"
                      >
                        <Copy className="h-4 w-4" />
                      </Button>
                    </div>
                    <div className="text-xs text-blue-400 mt-1">
                      ✓ ユーザーがNFTを返却したトランザクション
                    </div>
                  </div>
                )}

                <div>
                  <Label htmlFor="txHash" className="text-white">送金トランザクションハッシュ</Label>
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
                  {editingAddress && (
                    <div className="text-xs text-yellow-500 text-center">
                      送金先アドレスの編集中は処理できません。保存またはキャンセルしてください。
                    </div>
                  )}

                  <Button
                    onClick={() => processRequest("complete")}
                    disabled={processingId === selectedRequest.id || !transactionHash || editingAddress}
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
                    disabled={processingId === selectedRequest.id || editingAddress}
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
                    onClick={closeModal}
                    className="w-full bg-gray-700 text-white border-gray-600 hover:bg-gray-800 hover:text-white"
                    disabled={processingId === selectedRequest.id || savingAddress}
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