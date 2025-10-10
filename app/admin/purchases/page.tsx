"use client"

import { useState, useEffect } from "react"
import { useRouter } from "next/navigation"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Label } from "@/components/ui/label"
import { Textarea } from "@/components/ui/textarea"
import { Input } from "@/components/ui/input"
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog"
import { CheckCircle, XCircle, Eye, RefreshCw, Shield, ExternalLink, Users, Copy, Edit, Download, Search, Zap } from "lucide-react"
import { supabase } from "@/lib/supabase"
import { sendApprovalEmailViaAuth } from "@/lib/send-approval-email"
import { OperationStatus } from "@/components/operation-status"

interface Purchase {
  id: string
  user_id: string
  email: string
  full_name: string | null
  coinw_uid: string | null
  nft_receive_address: string | null
  referrer_user_id: string | null
  referrer_email: string | null
  referrer_full_name: string | null
  nft_quantity: number
  amount_usd: number
  payment_status: string
  admin_approved: boolean
  admin_approved_at: string | null
  admin_approved_by: string | null
  payment_proof_url: string | null
  user_notes: string | null
  admin_notes: string | null
  created_at: string
  has_approved_nft: boolean
}

export default function AdminPurchasesPage() {
  const [purchases, setPurchases] = useState<Purchase[]>([])
  const [loading, setLoading] = useState(true)
  const [selectedPurchase, setSelectedPurchase] = useState<Purchase | null>(null)
  const [adminNotes, setAdminNotes] = useState("")
  const [actionLoading, setActionLoading] = useState(false)
  const [currentUser, setCurrentUser] = useState<any>(null)
  const [isAdmin, setIsAdmin] = useState(false)
  const [error, setError] = useState("")
  const router = useRouter()

  const [editingCoinwUid, setEditingCoinwUid] = useState<string | null>(null)
  const [newCoinwUid, setNewCoinwUid] = useState("")

  const [editingTransactionId, setEditingTransactionId] = useState<string | null>(null)
  const [newTransactionId, setNewTransactionId] = useState("")

  const [editingApprovalDate, setEditingApprovalDate] = useState<string | null>(null)
  const [newApprovalDate, setNewApprovalDate] = useState("")
  const [approvalChangeReason, setApprovalChangeReason] = useState("")
  const [searchTerm, setSearchTerm] = useState("")

  useEffect(() => {
    checkAdminAccess()
  }, [])

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

      // 緊急対応: basarasystems@gmail.com または support@dshsupport.biz のアクセス許可
      if (user.email === "basarasystems@gmail.com" || user.email === "support@dshsupport.biz") {
        setIsAdmin(true)
        fetchPurchases()
        return
      }

      // 管理者権限チェック
      const { data: adminCheck, error: adminError } = await supabase.rpc("is_admin", {
        user_email: user.email,
      })

      if (adminError) {
        console.error("Admin check error:", adminError)
        // フォールバック: usersテーブルのis_adminフィールドをチェック
        const { data: userCheck, error: userError } = await supabase
          .from("users")
          .select("is_admin")
          .eq("email", user.email)
          .single()
        
        if (!userError && userCheck?.is_admin) {
          setIsAdmin(true)
          fetchPurchases()
          return
        }
        
        setError("管理者権限の確認でエラーが発生しました")
        return
      }

      if (!adminCheck) {
        // フォールバック: usersテーブルのis_adminフィールドをチェック
        const { data: userCheck, error: userError } = await supabase
          .from("users")
          .select("is_admin")
          .eq("email", user.email)
          .single()
        
        if (!userError && userCheck?.is_admin) {
          setIsAdmin(true)
          fetchPurchases()
          return
        }
        
        alert("管理者権限がありません")
        router.push("/dashboard")
        return
      }

      setIsAdmin(true)
      fetchPurchases()
    } catch (error) {
      console.error("Admin access check error:", error)
      setError("管理者権限の確認でエラーが発生しました")
    }
  }

  const fetchPurchases = async () => {
    try {
      setLoading(true)
      setError("")

      // 更新されたビューを使用してデータを取得
      const { data, error } = await supabase
        .from("admin_purchases_view")
        .select("*")
        .order("created_at", { ascending: false })

      if (error) {
        console.error("Fetch purchases error:", error)
        throw error
      }

      setPurchases(data || [])
    } catch (error: any) {
      console.error("Error fetching purchases:", error)
      setError(`購入データの取得に失敗しました: ${error.message}`)
    } finally {
      setLoading(false)
    }
  }

  const confirmPayment = async (purchaseId: string) => {
    if (!confirm("この送金を確認して、ユーザーを有効化しますか？")) return

    setActionLoading(true)
    try {
      // 承認前に購入情報を取得
      const purchase = purchases.find(p => p.id === purchaseId)
      if (!purchase) {
        throw new Error("購入情報が見つかりません")
      }

      // 承認処理実行（purchaseIdが確実にUUID文字列として渡されるように）
      const { data: rpcResult, error } = await supabase.rpc("approve_user_nft", {
        p_purchase_id: purchaseId,
        p_admin_email: currentUser.email,
        p_admin_notes: adminNotes || "入金確認済み",
      })

      if (error) throw error

      // RPC関数の結果を確認
      console.log("RPC Result:", rpcResult)
      
      if (rpcResult && rpcResult[0]?.status === 'ERROR') {
        throw new Error(rpcResult[0].message)
      }

      // Edge Functionを使って承認完了メール送信
      try {
        const { data: emailResult, error: emailError } = await supabase.functions.invoke('send-approval-email', {
          body: {
            to_email: purchase.email,
            user_name: purchase.full_name,
            nft_quantity: purchase.nft_quantity,
            amount_usd: purchase.amount_usd,
            user_id: purchase.user_id,
            purchase_id: purchaseId
          }
        })

        if (emailError) {
          console.error("Edge Function メール送信エラー:", emailError)
          alert("入金を確認し、ユーザーを有効化しました。\n（メール送信でエラーが発生しましたが承認は完了しています）")
        } else {
          console.log("メール送信成功:", emailResult)
          alert("入金を確認し、ユーザーを有効化しました。\n承認完了メールを送信しました。")
        }
      } catch (emailError) {
        console.error("メール送信処理エラー:", emailError)
        alert("入金を確認し、ユーザーを有効化しました。\n（メール送信処理でエラーが発生しましたが承認は完了しています）")
      }

      fetchPurchases()
      setSelectedPurchase(null)
      setAdminNotes("")
    } catch (error: any) {
      console.error("Confirmation error:", error)
      alert(`入金確認エラー: ${error.message}`)
    } finally {
      setActionLoading(false)
    }
  }

  const deletePurchase = async (purchaseId: string) => {
    if (!confirm("この購入レコードを完全に削除しますか？この操作は取り消せません。")) return

    setActionLoading(true)
    try {
      const { error } = await supabase.rpc("delete_purchase_record", {
        purchase_id: purchaseId,
        admin_email: currentUser.email,
      })

      if (error) throw error

      alert("購入レコードを削除しました")
      fetchPurchases()
    } catch (error: any) {
      console.error("Delete error:", error)
      alert(`削除エラー: ${error.message}`)
    } finally {
      setActionLoading(false)
    }
  }

  const rejectPayment = async (purchaseId: string) => {
    if (!confirm("この送金を拒否しますか？")) return

    setActionLoading(true)
    try {
      const { error } = await supabase
        .from("purchases")
        .update({
          payment_status: "rejected",
          admin_notes: adminNotes || "送金が確認できませんでした",
          admin_approved_by: currentUser.email,
        })
        .eq("id", purchaseId)

      if (error) throw error

      alert("送金を拒否しました")
      fetchPurchases()
      setSelectedPurchase(null)
      setAdminNotes("")
    } catch (error: any) {
      console.error("Rejection error:", error)
      alert(`拒否エラー: ${error.message}`)
    } finally {
      setActionLoading(false)
    }
  }

  const updateCoinwUid = async (purchaseId: string, userId: string) => {
    if (!newCoinwUid.trim()) {
      alert("CoinW UIDを入力してください")
      return
    }

    setActionLoading(true)
    try {
      const { error } = await supabase.from("users").update({ coinw_uid: newCoinwUid.trim() }).eq("user_id", userId)

      if (error) throw error

      alert("CoinW UIDを更新しました")
      fetchPurchases()
      setEditingCoinwUid(null)
      setNewCoinwUid("")
    } catch (error: any) {
      console.error("CoinW UID update error:", error)
      alert(`CoinW UID更新エラー: ${error.message}`)
    } finally {
      setActionLoading(false)
    }
  }

  const updateTransactionId = async (purchaseId: string) => {
    if (!newTransactionId.trim()) {
      alert("トランザクションIDを入力してください")
      return
    }

    setActionLoading(true)
    try {
      const { error } = await supabase
        .from("purchases")
        .update({
          payment_proof_url: newTransactionId.trim(),
          admin_notes: `${adminNotes ? adminNotes + "\n" : ""}管理者によりトランザクションID更新: ${new Date().toLocaleString("ja-JP")}`,
        })
        .eq("id", purchaseId)

      if (error) throw error

      alert("トランザクションIDを更新しました")
      fetchPurchases()
      setEditingTransactionId(null)
      setNewTransactionId("")

      // 選択された購入情報も更新
      if (selectedPurchase && selectedPurchase.id === purchaseId) {
        setSelectedPurchase({
          ...selectedPurchase,
          payment_proof_url: newTransactionId.trim(),
        })
      }
    } catch (error: any) {
      console.error("Transaction ID update error:", error)
      alert(`トランザクションID更新エラー: ${error.message}`)
    } finally {
      setActionLoading(false)
    }
  }

  const updateApprovalDate = async (purchaseId: string) => {
    if (!newApprovalDate.trim()) {
      alert("承認日を入力してください")
      return
    }

    if (!approvalChangeReason.trim()) {
      alert("変更理由を入力してください")
      return
    }

    setActionLoading(true)
    try {
      // まず手動でデータベースの更新を試行（関数が存在しない場合のフォールバック）
      const newDate = new Date(newApprovalDate).toISOString()
      
      // 直接テーブルを更新する方法を使用
      const { data: purchaseData, error: fetchError } = await supabase
        .from("purchases")
        .select("admin_approved_at, admin_notes, user_id")
        .eq("id", purchaseId)
        .single()

      if (fetchError) throw fetchError

      const oldDate = purchaseData.admin_approved_at
      const currentNotes = purchaseData.admin_notes || ""
      
      const updateNote = `\n[${new Date().toISOString().split('T')[0]}] 承認日変更: ${oldDate ? new Date(oldDate).toISOString().split('T')[0] : 'NULL'} → ${new Date(newDate).toISOString().split('T')[0]} (変更者: ${currentUser.email}, 理由: ${approvalChangeReason.trim()})`

      const { error: updateError } = await supabase
        .from("purchases")
        .update({
          admin_approved_at: newDate,
          admin_notes: currentNotes + updateNote,
          updated_at: new Date().toISOString()
        })
        .eq("id", purchaseId)

      if (updateError) throw updateError

      // operation_start_dateを再計算して更新
      const { error: operationDateError } = await supabase.rpc('calculate_operation_start_date', {
        p_approved_at: newDate
      }).then(async (result) => {
        if (result.data) {
          // usersテーブルのoperation_start_dateを更新
          return await supabase
            .from('users')
            .update({ operation_start_date: result.data })
            .eq('user_id', purchaseData.user_id)
        }
        return { error: null }
      })

      if (operationDateError) {
        console.warn('operation_start_date更新エラー:', operationDateError)
      }

      // システムログに記録
      await supabase.from("system_logs").insert({
        log_type: 'SUCCESS',
        operation: 'modify_approval_date',
        user_id: purchaseData.user_id,
        message: '購入承認日を変更しました',
        details: {
          purchase_id: purchaseId,
          old_approval_date: oldDate,
          new_approval_date: newDate,
          admin_email: currentUser.email,
          reason: approvalChangeReason.trim()
        },
        created_at: new Date().toISOString()
      })

      alert(`承認日を更新しました\n旧: ${oldDate ? new Date(oldDate).toLocaleDateString('ja-JP') : 'なし'}\n新: ${new Date(newDate).toLocaleDateString('ja-JP')}\n\n運用開始日も自動更新されました`)
      fetchPurchases()
      setEditingApprovalDate(null)
      setNewApprovalDate("")
      setApprovalChangeReason("")

      // 選択された購入情報も更新
      if (selectedPurchase && selectedPurchase.id === purchaseId) {
        setSelectedPurchase({
          ...selectedPurchase,
          admin_approved_at: newDate,
        })
      }
    } catch (error: any) {
      console.error("Approval date update error:", error)
      alert(`承認日更新エラー: ${error.message || 'システムエラーが発生しました'}`)
    } finally {
      setActionLoading(false)
    }
  }

  const copyToClipboard = (text: string) => {
    navigator.clipboard.writeText(text)
    alert("コピーしました！")
  }

  const getStatusBadge = (status: string, approved: boolean) => {
    if (approved) {
      return <Badge className="bg-green-600 text-sm whitespace-nowrap">確認済み</Badge>
    }

    switch (status) {
      case "pending":
        return <Badge variant="secondary" className="text-sm whitespace-nowrap">注文作成</Badge>
      case "payment_sent":
        return <Badge className="bg-yellow-600 text-sm whitespace-nowrap">確認待ち</Badge>
      case "payment_confirmed":
        return <Badge className="bg-blue-600 text-sm whitespace-nowrap">確認済み</Badge>
      case "rejected":
        return <Badge variant="destructive" className="text-sm whitespace-nowrap">拒否</Badge>
      default:
        return <Badge variant="outline" className="text-sm whitespace-nowrap">{status}</Badge>
    }
  }

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleString("ja-JP")
  }

  const exportToCSV = () => {
    const csvHeaders = [
      "購入ID",
      "ユーザーID", 
      "メールアドレス",
      "フルネーム",
      "CoinW UID",
      "紹介者ID",
      "紹介者メール",
      "NFT数量",
      "金額(USD)",
      "ステータス",
      "管理者承認",
      "トランザクションID",
      "ユーザーメモ",
      "管理者メモ",
      "購入日時",
      "承認日時",
      "承認者"
    ]

    const csvData = purchases.map(purchase => [
      purchase.id,
      purchase.user_id,
      purchase.email,
      purchase.full_name || "",
      purchase.coinw_uid || "",
      purchase.referrer_user_id || "",
      purchase.referrer_email || "",
      purchase.nft_quantity,
      purchase.amount_usd,
      purchase.payment_status,
      purchase.admin_approved ? "承認済み" : "未承認",
      purchase.payment_proof_url || "",
      purchase.user_notes || "",
      purchase.admin_notes || "",
      formatDate(purchase.created_at),
      purchase.admin_approved_at ? formatDate(purchase.admin_approved_at) : "",
      purchase.admin_approved_by || ""
    ])

    const csvContent = [
      csvHeaders.join(","),
      ...csvData.map(row => 
        row.map(field => 
          typeof field === 'string' && field.includes(',') 
            ? `"${field.replace(/"/g, '""')}"` 
            : field
        ).join(",")
      )
    ].join("\n")

    const blob = new Blob(["\uFEFF" + csvContent], { type: "text/csv;charset=utf-8;" })
    const link = document.createElement("a")
    const url = URL.createObjectURL(blob)
    link.setAttribute("href", url)
    link.setAttribute("download", `purchases_${new Date().toISOString().split("T")[0]}.csv`)
    link.style.visibility = "hidden"
    document.body.appendChild(link)
    link.click()
    document.body.removeChild(link)
  }

  const openBlockchainExplorer = (txHash: string) => {
    if (!txHash) return

    // BSCScanでトランザクションを確認
    const url = `https://bscscan.com/tx/${txHash}`
    window.open(url, "_blank")
  }

  const truncateHash = (hash: string) => {
    if (!hash) return "未入力"
    if (hash.length <= 8) return hash
    return `${hash.substring(0, 4)}...${hash.substring(hash.length - 4)}`
  }

  if (loading) {
    return (
      <div className="min-h-screen bg-gray-900 flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto"></div>
          <p className="mt-4 text-white">管理者権限を確認中...</p>
        </div>
      </div>
    )
  }

  if (error) {
    return (
      <div className="min-h-screen bg-gray-900 flex items-center justify-center">
        <Card className="w-full max-w-md bg-gray-800 border-gray-700">
          <CardHeader>
            <CardTitle className="text-red-400">エラー</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <p className="text-white">{error}</p>
            <div className="flex space-x-2">
              <Button onClick={checkAdminAccess} className="flex-1">
                再試行
              </Button>
              <Button variant="outline" onClick={() => router.push("/dashboard")} className="flex-1">
                ダッシュボード
              </Button>
            </div>
          </CardContent>
        </Card>
      </div>
    )
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
            <Button onClick={() => router.push("/dashboard")} className="mt-4 w-full">
              ダッシュボードに戻る
            </Button>
          </CardContent>
        </Card>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gray-900 p-4">
      <div className="max-w-7xl mx-auto">
        <Card className="bg-gray-800 border-gray-700">
          <CardHeader>
            <div className="flex items-center justify-between">
              <CardTitle className="text-white flex items-center">
                <Shield className="w-5 h-5 mr-2" />
                NFT購入・入金確認 - {currentUser?.email}
              </CardTitle>
              <div className="flex space-x-2">
                <Button
                  onClick={() => router.push("/admin")}
                  variant="outline"
                  size="sm"
                  className="bg-blue-600 hover:bg-blue-700 text-white border-blue-600"
                >
                  管理者ダッシュボード
                </Button>
                <Button
                  onClick={() => router.push("/admin/auto-nft-grants")}
                  size="sm"
                  variant="outline"
                  className="bg-purple-600 hover:bg-purple-700 text-white border-purple-600"
                >
                  <Zap className="w-4 h-4 mr-2" />
                  自動NFT付与履歴
                </Button>
                <Button
                  onClick={exportToCSV}
                  size="sm"
                  variant="outline"
                  className="bg-green-600 hover:bg-green-700 text-white border-green-600"
                >
                  <Download className="w-4 h-4 mr-2" />
                  CSV出力
                </Button>
                <Button onClick={fetchPurchases} size="sm">
                  <RefreshCw className="w-4 h-4 mr-2" />
                  更新
                </Button>
              </div>
            </div>
          </CardHeader>
          <CardContent>
            <div className="mb-4 grid grid-cols-4 gap-4 text-center">
              <div className="bg-gray-700 p-3 rounded">
                <div className="text-2xl font-bold text-white">
                  {(() => {
                    const filteredPurchases = purchases.filter(purchase => {
                      if (!searchTerm) return true
                      const term = searchTerm.toLowerCase()
                      return (
                        purchase.user_id.toLowerCase().includes(term) ||
                        purchase.email.toLowerCase().includes(term) ||
                        (purchase.coinw_uid && purchase.coinw_uid.toLowerCase().includes(term)) ||
                        purchase.id.toLowerCase().includes(term) ||
                        (purchase.full_name && purchase.full_name.toLowerCase().includes(term))
                      )
                    })
                    return filteredPurchases.length
                  })()}
                </div>
                <div className="text-sm text-gray-400">{searchTerm ? '検索結果' : '総購入数'}</div>
              </div>
              <div className="bg-yellow-900 p-3 rounded">
                <div className="text-2xl font-bold text-yellow-400">
                  {(() => {
                    const filteredPurchases = purchases.filter(purchase => {
                      if (!searchTerm) return true
                      const term = searchTerm.toLowerCase()
                      return (
                        purchase.user_id.toLowerCase().includes(term) ||
                        purchase.email.toLowerCase().includes(term) ||
                        (purchase.coinw_uid && purchase.coinw_uid.toLowerCase().includes(term)) ||
                        purchase.id.toLowerCase().includes(term) ||
                        (purchase.full_name && purchase.full_name.toLowerCase().includes(term))
                      )
                    })
                    return filteredPurchases.filter((p) => p.payment_status === "payment_sent" && !p.admin_approved).length
                  })()}
                </div>
                <div className="text-sm text-yellow-200">入金確認待ち</div>
              </div>
              <div className="bg-green-900 p-3 rounded">
                <div className="text-2xl font-bold text-green-400">
                  {(() => {
                    const filteredPurchases = purchases.filter(purchase => {
                      if (!searchTerm) return true
                      const term = searchTerm.toLowerCase()
                      return (
                        purchase.user_id.toLowerCase().includes(term) ||
                        purchase.email.toLowerCase().includes(term) ||
                        (purchase.coinw_uid && purchase.coinw_uid.toLowerCase().includes(term)) ||
                        purchase.id.toLowerCase().includes(term) ||
                        (purchase.full_name && purchase.full_name.toLowerCase().includes(term))
                      )
                    })
                    return filteredPurchases.filter((p) => p.admin_approved).length
                  })()}
                </div>
                <div className="text-sm text-green-200">入金確認済み</div>
              </div>
              <div className="bg-red-900 p-3 rounded">
                <div className="text-2xl font-bold text-red-400">
                  {(() => {
                    const filteredPurchases = purchases.filter(purchase => {
                      if (!searchTerm) return true
                      const term = searchTerm.toLowerCase()
                      return (
                        purchase.user_id.toLowerCase().includes(term) ||
                        purchase.email.toLowerCase().includes(term) ||
                        (purchase.coinw_uid && purchase.coinw_uid.toLowerCase().includes(term)) ||
                        purchase.id.toLowerCase().includes(term) ||
                        (purchase.full_name && purchase.full_name.toLowerCase().includes(term))
                      )
                    })
                    return filteredPurchases.filter((p) => p.payment_status === "rejected").length
                  })()}
                </div>
                <div className="text-sm text-red-200">拒否</div>
              </div>
            </div>

            {/* 検索バー */}
            <div className="mb-4">
              <div className="relative">
                <Search className="h-4 w-4 absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400" />
                <input
                  type="text"
                  placeholder="ユーザーID、メールアドレス、CoinW UID、購入IDで検索..."
                  value={searchTerm}
                  onChange={(e) => setSearchTerm(e.target.value)}
                  className="w-full pl-10 pr-4 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white placeholder-gray-400 focus:outline-none focus:border-blue-500 focus:ring-1 focus:ring-blue-500"
                />
                {searchTerm && (
                  <button
                    onClick={() => setSearchTerm("")}
                    className="absolute right-3 top-1/2 transform -translate-y-1/2 text-gray-400 hover:text-white"
                  >
                    ×
                  </button>
                )}
              </div>
            </div>

            <div className="overflow-x-auto">
              <table className="w-full text-white min-w-[830px]">
                <thead>
                  <tr className="border-b border-gray-600">
                    <th className="text-left p-2 min-w-[160px] text-sm font-medium">ユーザー</th>
                    <th className="text-left p-2 min-w-[110px] text-sm font-medium">TX ID</th>
                    <th className="text-left p-2 min-w-[80px] text-sm font-medium">金額</th>
                    <th className="text-left p-2 min-w-[90px] text-sm font-medium">状態</th>
                    <th className="text-left p-2 min-w-[100px] text-sm font-medium">運用</th>
                    <th className="text-left p-2 min-w-[110px] text-sm font-medium">日時</th>
                    <th className="text-left p-2 min-w-[150px] w-[150px] text-sm font-medium">操作</th>
                  </tr>
                </thead>
                <tbody>
                  {purchases
                    .filter(purchase => {
                      if (!searchTerm) return true
                      const term = searchTerm.toLowerCase()
                      return (
                        purchase.user_id.toLowerCase().includes(term) ||
                        purchase.email.toLowerCase().includes(term) ||
                        (purchase.coinw_uid && purchase.coinw_uid.toLowerCase().includes(term)) ||
                        purchase.id.toLowerCase().includes(term) ||
                        (purchase.full_name && purchase.full_name.toLowerCase().includes(term))
                      )
                    })
                    .map((purchase) => (
                    <tr key={purchase.id} className="border-b border-gray-700 hover:bg-gray-750">
                      <td className="p-2">
                        <div>
                          <div className="font-semibold text-sm">{purchase.user_id}</div>
                          <div className="text-sm text-gray-400 break-all">{purchase.email}</div>
                        </div>
                      </td>
                      <td className="p-2">
                        {purchase.payment_proof_url ? (
                          <div className="flex items-center space-x-2">
                            <span className="font-mono text-sm text-yellow-400">
                              {truncateHash(purchase.payment_proof_url)}
                            </span>
                            <Button
                              size="sm"
                              variant="ghost"
                              onClick={() => copyToClipboard(purchase.payment_proof_url!)}
                              className="h-5 w-5 p-0 text-gray-400 hover:text-white"
                            >
                              <Copy className="w-3 h-3" />
                            </Button>
                          </div>
                        ) : (
                          <div className="text-sm text-gray-500">未入力</div>
                        )}
                      </td>
                      <td className="p-2">
                        <div className="font-bold text-green-600 text-sm">${purchase.amount_usd}</div>
                        <div className="text-sm text-gray-400">{purchase.nft_quantity}NFT</div>
                      </td>
                      <td className="p-2 whitespace-nowrap">{getStatusBadge(purchase.payment_status, purchase.admin_approved)}</td>
                      <td className="p-2 whitespace-nowrap">
                        <OperationStatus 
                          approvalDate={purchase.admin_approved ? purchase.admin_approved_at : null} 
                          variant="compact"
                        />
                      </td>
                      <td className="p-2">
                        <div className="text-sm">{new Date(purchase.created_at).toLocaleDateString('ja-JP')}</div>
                        {purchase.admin_approved_at && (
                          <div className="text-sm text-green-400">承認済み</div>
                        )}
                      </td>
                      <td className="p-2 whitespace-nowrap min-w-[150px] w-[150px]">
                        <div className="flex space-x-1">
                          <Dialog>
                            <DialogTrigger asChild>
                              <Button
                                size="sm"
                                className="bg-blue-600 hover:bg-blue-700 text-white border-0 text-sm px-3 py-2"
                                onClick={() => {
                                  setSelectedPurchase(purchase)
                                  setAdminNotes(purchase.admin_notes || "")
                                }}
                              >
                                <Eye className="w-4 h-4 mr-1 text-white" />
                                <span className="text-white">詳細</span>
                              </Button>
                            </DialogTrigger>
                            <DialogContent 
                              className="bg-gray-800 border-gray-700 text-white max-w-4xl max-h-[90vh] overflow-y-auto"
                              aria-describedby="purchase-dialog-description"
                            >
                              <DialogHeader>
                                <DialogTitle>購入詳細・入金確認 - {selectedPurchase?.user_id}</DialogTitle>
                              </DialogHeader>
                              <div id="purchase-dialog-description" className="text-gray-400 text-sm mb-4">
                                購入ID {selectedPurchase?.id} の詳細情報と管理機能
                              </div>
                              {selectedPurchase && (
                                <div className="space-y-6">
                                  <div className="grid grid-cols-2 gap-4">
                                    <div>
                                      <Label className="text-gray-300">購入ID</Label>
                                      <p className="font-mono text-sm bg-gray-700 p-2 rounded">{selectedPurchase.id}</p>
                                    </div>
                                    <div>
                                      <Label className="text-gray-300">ユーザーID</Label>
                                      <p className="font-mono text-sm bg-gray-700 p-2 rounded">
                                        {selectedPurchase.user_id}
                                      </p>
                                    </div>
                                    <div>
                                      <Label className="text-gray-300">メールアドレス</Label>
                                      <p className="bg-gray-700 p-2 rounded">{selectedPurchase.email}</p>
                                    </div>
                                    <div>
                                      <Label className="text-gray-300">フルネーム</Label>
                                      <p className="bg-gray-700 p-2 rounded">
                                        {selectedPurchase.full_name || "未入力"}
                                      </p>
                                    </div>
                                    <div className="col-span-2">
                                      <Label className="text-gray-300">NFT受取アドレス</Label>
                                      <p className="font-mono text-sm bg-gray-700 p-2 rounded break-all">
                                        {selectedPurchase.nft_receive_address || "未入力"}
                                      </p>
                                    </div>
                                  </div>

                                  {/* 紹介者情報セクション */}
                                  <div className="bg-blue-900/20 border border-blue-700 rounded-lg p-4">
                                    <Label className="text-blue-300 flex items-center mb-2">
                                      <Users className="w-4 h-4 mr-2" />
                                      紹介者情報
                                    </Label>
                                    {selectedPurchase.referrer_user_id ? (
                                      <div className="grid grid-cols-2 gap-4">
                                        <div>
                                          <Label className="text-gray-300 text-sm">紹介者ID</Label>
                                          <p className="font-mono text-sm bg-gray-700 p-2 rounded text-blue-400">
                                            {selectedPurchase.referrer_user_id}
                                          </p>
                                        </div>
                                        <div>
                                          <Label className="text-gray-300 text-sm">紹介者メール</Label>
                                          <p className="text-sm bg-gray-700 p-2 rounded text-blue-400">
                                            {selectedPurchase.referrer_email || "不明"}
                                          </p>
                                        </div>
                                      </div>
                                    ) : (
                                      <p className="text-gray-400 italic">直接登録（紹介者なし）</p>
                                    )}
                                  </div>

                                  {/* トランザクションID情報セクション */}
                                  <div className="bg-yellow-900/20 border border-yellow-700 rounded-lg p-4">
                                    <Label className="text-yellow-300 flex items-center mb-2">
                                      <ExternalLink className="w-4 h-4 mr-2" />
                                      トランザクション情報
                                    </Label>

                                    {editingTransactionId === selectedPurchase.id ? (
                                      <div className="space-y-3">
                                        <div>
                                          <Label className="text-gray-300 text-sm">トランザクションID編集</Label>
                                          <div className="flex items-center space-x-2">
                                            <Input
                                              value={newTransactionId}
                                              onChange={(e) => setNewTransactionId(e.target.value)}
                                              placeholder="トランザクションIDを入力"
                                              className="bg-gray-700 border-gray-600 text-white flex-1 font-mono text-sm"
                                            />
                                            <Button
                                              size="sm"
                                              onClick={() => updateTransactionId(selectedPurchase.id)}
                                              disabled={actionLoading}
                                              className="bg-green-600 hover:bg-green-700"
                                            >
                                              保存
                                            </Button>
                                            <Button
                                              size="sm"
                                              variant="outline"
                                              onClick={() => {
                                                setEditingTransactionId(null)
                                                setNewTransactionId("")
                                              }}
                                              className="bg-gray-600 hover:bg-gray-700 text-white border-gray-600"
                                            >
                                              キャンセル
                                            </Button>
                                          </div>
                                        </div>
                                      </div>
                                    ) : (
                                      <div className="space-y-3">
                                        <div>
                                          <Label className="text-gray-300 text-sm">トランザクションID</Label>
                                          <div className="flex items-center space-x-2">
                                            <p className="bg-gray-700 p-3 rounded font-mono text-sm break-all text-yellow-400 flex-1">
                                              {selectedPurchase.payment_proof_url || "未入力"}
                                            </p>
                                            <Button
                                              size="sm"
                                              variant="outline"
                                              onClick={() => {
                                                setEditingTransactionId(selectedPurchase.id)
                                                setNewTransactionId(selectedPurchase.payment_proof_url || "")
                                              }}
                                              className="bg-blue-600 hover:bg-blue-700 text-white border-blue-600"
                                            >
                                              <Edit className="w-4 h-4 mr-1" />
                                              編集
                                            </Button>
                                            {selectedPurchase.payment_proof_url && (
                                              <Button
                                                size="sm"
                                                onClick={() => copyToClipboard(selectedPurchase.payment_proof_url!)}
                                                className="bg-gray-600 hover:bg-gray-700 text-white"
                                              >
                                                <Copy className="w-4 h-4" />
                                              </Button>
                                            )}
                                          </div>
                                        </div>

                                        {selectedPurchase.payment_proof_url && (
                                          <div className="flex space-x-2">
                                            <Button
                                              size="sm"
                                              onClick={() =>
                                                openBlockchainExplorer(selectedPurchase.payment_proof_url!)
                                              }
                                              className="bg-yellow-600 hover:bg-yellow-700 text-white"
                                            >
                                              <ExternalLink className="w-4 h-4 mr-1" />
                                              BSCScan で確認
                                            </Button>
                                            <Button
                                              size="sm"
                                              onClick={() => {
                                                const tronUrl = `https://tronscan.org/#/transaction/${selectedPurchase.payment_proof_url}`
                                                window.open(tronUrl, "_blank")
                                              }}
                                              className="bg-red-600 hover:bg-red-700 text-white"
                                            >
                                              <ExternalLink className="w-4 h-4 mr-1" />
                                              TronScan で確認
                                            </Button>
                                          </div>
                                        )}

                                        <p className="text-xs text-gray-400">
                                          {selectedPurchase.payment_proof_url
                                            ? "ボタンをクリックしてブロックチェーンで送金を確認してください"
                                            : "編集ボタンをクリックしてトランザクションIDを入力してください"}
                                        </p>
                                      </div>
                                    )}
                                  </div>

                                  <div className="grid grid-cols-2 gap-4">
                                    <div>
                                      <Label className="text-gray-300">CoinW UID</Label>
                                      {editingCoinwUid === selectedPurchase.id ? (
                                        <div className="flex items-center space-x-2">
                                          <Input
                                            value={newCoinwUid}
                                            onChange={(e) => setNewCoinwUid(e.target.value)}
                                            placeholder="CoinW UIDを入力"
                                            className="bg-gray-700 border-gray-600 text-white flex-1"
                                          />
                                          <Button
                                            size="sm"
                                            onClick={() =>
                                              updateCoinwUid(selectedPurchase.id, selectedPurchase.user_id)
                                            }
                                            disabled={actionLoading}
                                            className="bg-green-600 hover:bg-green-700"
                                          >
                                            保存
                                          </Button>
                                          <Button
                                            size="sm"
                                            variant="outline"
                                            onClick={() => {
                                              setEditingCoinwUid(null)
                                              setNewCoinwUid("")
                                            }}
                                            className="bg-gray-600 hover:bg-gray-700 text-white border-gray-600"
                                          >
                                            キャンセル
                                          </Button>
                                        </div>
                                      ) : (
                                        <div className="flex items-center space-x-2">
                                          <p className="font-mono text-sm bg-gray-700 p-2 rounded flex-1">
                                            {selectedPurchase.coinw_uid || "未入力"}
                                          </p>
                                          <Button
                                            size="sm"
                                            variant="outline"
                                            onClick={() => {
                                              setEditingCoinwUid(selectedPurchase.id)
                                              setNewCoinwUid(selectedPurchase.coinw_uid || "")
                                            }}
                                            className="bg-blue-600 hover:bg-blue-700 text-white border-blue-600"
                                          >
                                            編集
                                          </Button>
                                        </div>
                                      )}
                                    </div>
                                    <div>
                                      <Label className="text-gray-300">金額・数量</Label>
                                      <p className="font-bold text-green-600 bg-gray-700 p-2 rounded">
                                        ${selectedPurchase.amount_usd} ({selectedPurchase.nft_quantity} NFT)
                                      </p>
                                    </div>
                                  </div>

                                  {selectedPurchase.user_notes && (
                                    <div>
                                      <Label className="text-gray-300">ユーザーメモ</Label>
                                      <p className="bg-gray-700 p-3 rounded text-sm">{selectedPurchase.user_notes}</p>
                                    </div>
                                  )}

                                  <div>
                                    <Label className="text-gray-300">管理者メモ</Label>
                                    <Textarea
                                      value={adminNotes}
                                      onChange={(e) => setAdminNotes(e.target.value)}
                                      placeholder="入金確認結果や備考を入力"
                                      className="bg-gray-700 border-gray-600 text-white"
                                      rows={3}
                                    />
                                  </div>

                                  {!selectedPurchase.admin_approved &&
                                    selectedPurchase.payment_status !== "rejected" && (
                                      <div className="flex space-x-2">
                                        <Button
                                          onClick={() => confirmPayment(selectedPurchase.id)}
                                          disabled={actionLoading}
                                          className="bg-green-600 hover:bg-green-700"
                                        >
                                          <CheckCircle className="w-4 h-4 mr-2" />
                                          {actionLoading ? "処理中..." : "入金確認・ユーザー有効化"}
                                        </Button>
                                        <Button
                                          onClick={() => rejectPayment(selectedPurchase.id)}
                                          disabled={actionLoading}
                                          variant="destructive"
                                        >
                                          <XCircle className="w-4 h-4 mr-2" />
                                          {actionLoading ? "処理中..." : "拒否"}
                                        </Button>
                                      </div>
                                    )}

                                  {selectedPurchase.admin_approved && (
                                    <div className="bg-green-900 border border-green-700 rounded-lg p-3">
                                      <div className="flex items-center justify-between mb-2">
                                        <p className="text-green-200">
                                          ✅ 入金確認済み・ユーザー有効化完了
                                        </p>
                                        {editingApprovalDate !== selectedPurchase.id && (
                                          <Button
                                            size="sm"
                                            variant="outline"
                                            onClick={() => {
                                              setEditingApprovalDate(selectedPurchase.id)
                                              setNewApprovalDate(selectedPurchase.admin_approved_at ? new Date(selectedPurchase.admin_approved_at).toISOString().slice(0, 16) : "")
                                              setApprovalChangeReason("")
                                            }}
                                            className="bg-yellow-600 hover:bg-yellow-700 text-white border-yellow-600 text-xs"
                                          >
                                            <Edit className="w-3 h-3 mr-1" />
                                            承認日編集
                                          </Button>
                                        )}
                                      </div>
                                      
                                      {editingApprovalDate === selectedPurchase.id ? (
                                        <div className="space-y-3">
                                          <div>
                                            <Label className="text-green-300 text-sm">承認日時</Label>
                                            <Input
                                              type="datetime-local"
                                              value={newApprovalDate}
                                              onChange={(e) => setNewApprovalDate(e.target.value)}
                                              className="bg-gray-700 border-gray-600 text-white mt-1"
                                            />
                                          </div>
                                          <div>
                                            <Label className="text-green-300 text-sm">変更理由（必須）</Label>
                                            <Input
                                              value={approvalChangeReason}
                                              onChange={(e) => setApprovalChangeReason(e.target.value)}
                                              placeholder="例: 承認漏れのため遡って設定"
                                              className="bg-gray-700 border-gray-600 text-white mt-1"
                                            />
                                          </div>
                                          <div className="flex space-x-2">
                                            <Button
                                              size="sm"
                                              onClick={() => updateApprovalDate(selectedPurchase.id)}
                                              disabled={actionLoading}
                                              className="bg-green-600 hover:bg-green-700 text-xs"
                                            >
                                              保存
                                            </Button>
                                            <Button
                                              size="sm"
                                              variant="outline"
                                              onClick={() => {
                                                setEditingApprovalDate(null)
                                                setNewApprovalDate("")
                                                setApprovalChangeReason("")
                                              }}
                                              className="bg-gray-600 hover:bg-gray-700 text-white border-gray-600 text-xs"
                                            >
                                              キャンセル
                                            </Button>
                                          </div>
                                        </div>
                                      ) : (
                                        <div>
                                          <p className="text-green-300 text-sm">
                                            承認日時: {formatDate(selectedPurchase.admin_approved_at!)}
                                          </p>
                                          {selectedPurchase.admin_approved_by && (
                                            <p className="text-sm text-green-300">
                                              確認者: {selectedPurchase.admin_approved_by}
                                            </p>
                                          )}
                                        </div>
                                      )}
                                    </div>
                                  )}

                                  {selectedPurchase.payment_status === "rejected" && (
                                    <div className="bg-red-900 border border-red-700 rounded-lg p-3">
                                      <p className="text-red-200">❌ 拒否済み</p>
                                      {selectedPurchase.admin_approved_by && (
                                        <p className="text-sm text-red-300">
                                          拒否者: {selectedPurchase.admin_approved_by}
                                        </p>
                                      )}
                                    </div>
                                  )}
                                </div>
                              )}
                            </DialogContent>
                          </Dialog>

                          <Button
                            size="sm"
                            variant="destructive"
                            onClick={() => deletePurchase(purchase.id)}
                            disabled={actionLoading}
                            className="bg-red-600 hover:bg-red-700 text-white text-sm px-3 py-2"
                          >
                            <XCircle className="w-4 h-4 mr-1" />
                            削除
                          </Button>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>

              {purchases.filter(purchase => {
                if (!searchTerm) return true
                const term = searchTerm.toLowerCase()
                return (
                  purchase.user_id.toLowerCase().includes(term) ||
                  purchase.email.toLowerCase().includes(term) ||
                  (purchase.coinw_uid && purchase.coinw_uid.toLowerCase().includes(term)) ||
                  purchase.id.toLowerCase().includes(term) ||
                  (purchase.full_name && purchase.full_name.toLowerCase().includes(term))
                )
              }).length === 0 && (
                <div className="text-center py-8 text-gray-400">
                  {searchTerm ? `"${searchTerm}"に一致する購入データがありません` : "購入データがありません"}
                </div>
              )}
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  )
}
