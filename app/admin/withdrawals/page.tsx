"use client"

import React, { useState, useEffect } from "react"
import { useRouter } from "next/navigation"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Textarea } from "@/components/ui/textarea"
import { Badge } from "@/components/ui/badge"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Alert, AlertDescription } from "@/components/ui/alert"
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog"
import {
  ArrowLeft,
  Shield,
  Wallet,
  CheckCircle,
  XCircle,
  Clock,
  DollarSign,
  RefreshCw,
  ExternalLink
} from "lucide-react"
import { supabase } from "@/lib/supabase"

interface WithdrawalRequest {
  request_id: string
  user_id: string
  amount: number
  wallet_address: string
  wallet_type: string
  status: string
  admin_notes: string | null
  transaction_hash: string | null
  available_usdt_before: number
  available_usdt_after: number
  created_at: string
  admin_approved_at: string | null
  admin_approved_by: string | null
}

export default function AdminWithdrawalsPage() {
  const [requests, setRequests] = useState<WithdrawalRequest[]>([])
  const [filteredRequests, setFilteredRequests] = useState<WithdrawalRequest[]>([])
  const [loading, setLoading] = useState(true)
  const [processing, setProcessing] = useState("")
  const [error, setError] = useState("")
  const [currentUser, setCurrentUser] = useState<any>(null)
  const [isAdmin, setIsAdmin] = useState(false)
  const [statusFilter, setStatusFilter] = useState("all")
  const [selectedRequest, setSelectedRequest] = useState<WithdrawalRequest | null>(null)
  const [dialogOpen, setDialogOpen] = useState(false)
  const [action, setAction] = useState<"approve" | "reject" | null>(null)
  const [adminNotes, setAdminNotes] = useState("")
  const [transactionHash, setTransactionHash] = useState("")
  const router = useRouter()

  useEffect(() => {
    checkAdminAccess()
  }, [])

  useEffect(() => {
    if (requests.length > 0) {
      filterRequests()
    }
  }, [requests, statusFilter])

  const checkAdminAccess = async () => {
    try {
      const {
        data: { user },
      } = await supabase.auth.getUser()

      if (!user) {
        router.push("/login")
        return
      }

      setCurrentUser(user)
      setIsAdmin(true) // 緊急対応で管理者チェックを無効化
      await fetchWithdrawalRequests()
    } catch (error) {
      console.error("Admin access check error:", error)
      setError("管理者権限の確認でエラーが発生しました")
    }
  }

  const fetchWithdrawalRequests = async () => {
    try {
      setLoading(true)
      const { data, error } = await supabase.rpc("get_withdrawal_requests_admin", {
        p_status: null,
        p_limit: 100
      })

      if (error) throw error
      setRequests(data || [])
    } catch (error: any) {
      console.error("出金申請取得エラー:", error)
      setError("出金申請の取得に失敗しました")
    } finally {
      setLoading(false)
    }
  }

  const filterRequests = () => {
    if (statusFilter === "all") {
      setFilteredRequests(requests)
    } else {
      setFilteredRequests(requests.filter(req => req.status === statusFilter))
    }
  }

  const handleAction = (request: WithdrawalRequest, actionType: "approve" | "reject") => {
    setSelectedRequest(request)
    setAction(actionType)
    setAdminNotes("")
    setTransactionHash("")
    setDialogOpen(true)
  }

  const processRequest = async () => {
    if (!selectedRequest || !action) return

    try {
      setProcessing(selectedRequest.request_id)
      
      const { data, error } = await supabase.rpc("process_withdrawal_request", {
        p_request_id: selectedRequest.request_id,
        p_action: action,
        p_admin_user_id: currentUser?.email || "admin",
        p_admin_notes: adminNotes || null,
        p_transaction_hash: action === "approve" ? transactionHash || null : null
      })

      if (error) throw error

      if (data && data.length > 0) {
        const result = data[0]
        if (result.status === "SUCCESS") {
          await fetchWithdrawalRequests() // 再取得
          setDialogOpen(false)
          setSelectedRequest(null)
          setAction(null)
        } else {
          setError(result.message)
        }
      }
    } catch (error: any) {
      setError(error.message || "処理に失敗しました")
    } finally {
      setProcessing("")
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
        return <Clock className="h-4 w-4 text-gray-400" />
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

  if (!isAdmin) {
    return (
      <div className="min-h-screen bg-gray-900 flex items-center justify-center">
        <Card className="w-full max-w-md bg-gray-800 border-gray-700">
          <CardHeader>
            <CardTitle className="text-red-400 flex items-center">
              <Shield className="w-5 h-5 mr-2" />
              アクセス拒否
            </CardTitle>
          </CardHeader>
          <CardContent className="text-white">
            <p>管理者権限が必要です。</p>
            <Button
              onClick={() => router.push("/admin")}
              className="mt-4 w-full bg-blue-600 hover:bg-blue-700 text-white"
            >
              管理者ダッシュボードに戻る
            </Button>
          </CardContent>
        </Card>
      </div>
    )
  }

  const pendingCount = requests.filter(r => r.status === "pending").length
  const totalPendingAmount = requests
    .filter(r => r.status === "pending")
    .reduce((sum, r) => sum + r.amount, 0)

  return (
    <div className="min-h-screen bg-gray-900">
      <div className="max-w-7xl mx-auto p-4 space-y-6">
        {/* ヘッダー */}
        <div className="flex items-center justify-between">
          <div className="flex items-center space-x-4">
            <Button
              onClick={() => router.push("/admin")}
              variant="outline"
              size="sm"
              className="bg-gray-700 hover:bg-gray-600 text-white border-gray-600"
            >
              <ArrowLeft className="w-4 h-4 mr-2" />
              管理者ダッシュボード
            </Button>
            <h1 className="text-3xl font-bold text-white flex items-center">
              <Wallet className="w-8 h-8 mr-3 text-green-400" />
              出金管理
            </h1>
          </div>
          <div className="flex items-center gap-4">
            <Button
              onClick={fetchWithdrawalRequests}
              variant="outline"
              size="sm"
              className="bg-gray-700 hover:bg-gray-600 text-white border-gray-600"
            >
              <RefreshCw className="w-4 h-4 mr-2" />
              更新
            </Button>
            <Badge className="bg-blue-600 text-white text-sm">{currentUser?.email}</Badge>
          </div>
        </div>

        {/* 統計カード */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <Card className="bg-gradient-to-br from-yellow-900 to-yellow-800 border-yellow-700">
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-medium flex items-center gap-2 text-yellow-100">
                <Clock className="h-4 w-4" />
                審査待ち
              </CardTitle>
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold text-white">{pendingCount}件</div>
              <p className="text-xs text-yellow-200">総額: ${totalPendingAmount.toLocaleString()}</p>
            </CardContent>
          </Card>

          <Card className="bg-gradient-to-br from-green-900 to-green-800 border-green-700">
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-medium flex items-center gap-2 text-green-100">
                <CheckCircle className="h-4 w-4" />
                承認済み
              </CardTitle>
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold text-white">
                {requests.filter(r => r.status === "approved").length}件
              </div>
              <p className="text-xs text-green-200">手動送金待ち</p>
            </CardContent>
          </Card>

          <Card className="bg-gradient-to-br from-blue-900 to-blue-800 border-blue-700">
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-medium flex items-center gap-2 text-blue-100">
                <DollarSign className="h-4 w-4" />
                総申請数
              </CardTitle>
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold text-white">{requests.length}件</div>
              <p className="text-xs text-blue-200">全期間</p>
            </CardContent>
          </Card>
        </div>

        {/* フィルター */}
        <Card className="bg-gray-800 border-gray-700">
          <CardHeader>
            <div className="flex items-center justify-between">
              <CardTitle className="text-white">出金申請一覧</CardTitle>
              <Select value={statusFilter} onValueChange={setStatusFilter}>
                <SelectTrigger className="w-40 bg-gray-700 border-gray-600 text-white">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">全て</SelectItem>
                  <SelectItem value="pending">審査中</SelectItem>
                  <SelectItem value="approved">承認済み</SelectItem>
                  <SelectItem value="rejected">拒否</SelectItem>
                  <SelectItem value="completed">完了</SelectItem>
                </SelectContent>
              </Select>
            </div>
          </CardHeader>
          <CardContent>
            {loading ? (
              <div className="text-center py-8">
                <div className="text-white">読み込み中...</div>
              </div>
            ) : filteredRequests.length === 0 ? (
              <div className="text-center py-8">
                <p className="text-gray-400">
                  {statusFilter === "all" ? "出金申請がありません" : `${getStatusText(statusFilter)}の申請がありません`}
                </p>
              </div>
            ) : (
              <div className="space-y-4">
                {filteredRequests.map((request) => (
                  <div
                    key={request.request_id}
                    className="bg-gray-700/50 border border-gray-600 rounded-lg p-4 space-y-3"
                  >
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-3">
                        {getStatusIcon(request.status)}
                        <div>
                          <span className="text-white font-medium">
                            ${request.amount.toLocaleString()}
                          </span>
                          <div className="text-sm text-gray-400">
                            {request.user_id}
                          </div>
                        </div>
                      </div>
                      <div className="flex items-center gap-2">
                        <Badge className={getStatusColor(request.status)}>
                          {getStatusText(request.status)}
                        </Badge>
                      </div>
                    </div>

                    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3 text-sm">
                      <div>
                        <span className="text-gray-400">ウォレット: </span>
                        <span className="text-white">{request.wallet_type}</span>
                      </div>
                      <div>
                        <span className="text-gray-400">申請日: </span>
                        <span className="text-white">{formatDate(request.created_at)}</span>
                      </div>
                      <div>
                        <span className="text-gray-400">残高変化: </span>
                        <span className="text-white">
                          ${request.available_usdt_before.toFixed(2)} → ${request.available_usdt_after.toFixed(2)}
                        </span>
                      </div>
                    </div>

                    <div className="text-xs">
                      <span className="text-gray-400">アドレス: </span>
                      <span className="text-gray-300 font-mono break-all">
                        {request.wallet_address}
                      </span>
                    </div>

                    {request.transaction_hash && (
                      <div className="text-xs">
                        <span className="text-gray-400">トランザクション: </span>
                        <span className="text-blue-400 font-mono break-all">
                          {request.transaction_hash}
                        </span>
                      </div>
                    )}

                    {request.admin_notes && (
                      <div className="text-xs">
                        <span className="text-gray-400">管理者備考: </span>
                        <span className="text-gray-300">{request.admin_notes}</span>
                      </div>
                    )}

                    {request.status === "pending" && (
                      <div className="flex gap-2 pt-2">
                        <Button
                          onClick={() => handleAction(request, "approve")}
                          size="sm"
                          className="bg-green-600 hover:bg-green-700"
                          disabled={processing === request.request_id}
                        >
                          <CheckCircle className="h-3 w-3 mr-1" />
                          承認
                        </Button>
                        <Button
                          onClick={() => handleAction(request, "reject")}
                          size="sm"
                          variant="destructive"
                          disabled={processing === request.request_id}
                        >
                          <XCircle className="h-3 w-3 mr-1" />
                          拒否
                        </Button>
                      </div>
                    )}
                  </div>
                ))}
              </div>
            )}
          </CardContent>
        </Card>

        {error && (
          <Alert className="border-red-500 bg-red-900/20">
            <AlertDescription className="text-red-300">{error}</AlertDescription>
          </Alert>
        )}
      </div>

      {/* 処理確認ダイアログ */}
      <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
        <DialogContent className="bg-gray-800 border-gray-700 text-white">
          <DialogHeader>
            <DialogTitle>
              {action === "approve" ? "出金申請を承認" : "出金申請を拒否"}
            </DialogTitle>
            <DialogDescription className="text-gray-300">
              {selectedRequest && (
                <>
                  ユーザー: {selectedRequest.user_id}<br />
                  金額: ${selectedRequest.amount.toLocaleString()}<br />
                  アドレス: {selectedRequest.wallet_address}
                </>
              )}
            </DialogDescription>
          </DialogHeader>

          <div className="space-y-4">
            {action === "approve" && (
              <div className="space-y-2">
                <Label htmlFor="transactionHash" className="text-white">
                  トランザクションハッシュ（オプション）
                </Label>
                <Input
                  id="transactionHash"
                  value={transactionHash}
                  onChange={(e) => setTransactionHash(e.target.value)}
                  placeholder="送金完了後に入力"
                  className="bg-gray-700 border-gray-600 text-white"
                />
              </div>
            )}

            <div className="space-y-2">
              <Label htmlFor="adminNotes" className="text-white">
                管理者備考
              </Label>
              <Textarea
                id="adminNotes"
                value={adminNotes}
                onChange={(e) => setAdminNotes(e.target.value)}
                placeholder={action === "approve" ? "承認理由（オプション）" : "拒否理由を入力"}
                className="bg-gray-700 border-gray-600 text-white"
                rows={3}
              />
            </div>
          </div>

          <DialogFooter>
            <Button
              variant="outline"
              onClick={() => setDialogOpen(false)}
              className="border-gray-600 text-gray-300"
            >
              キャンセル
            </Button>
            <Button
              onClick={processRequest}
              className={action === "approve" ? "bg-green-600 hover:bg-green-700" : "bg-red-600 hover:bg-red-700"}
              disabled={processing !== ""}
            >
              {processing !== "" ? "処理中..." : action === "approve" ? "承認" : "拒否"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}