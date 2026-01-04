"use client"

import { useState, useEffect } from "react"
import { useRouter } from "next/navigation"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Badge } from "@/components/ui/badge"
import { Alert, AlertDescription } from "@/components/ui/alert"
import { Loader2, Users, Search, Edit, Trash2, ArrowLeft, RefreshCw, Download, ArrowUp } from "lucide-react"
import { supabase } from "@/lib/supabase"
import Link from "next/link"

interface User {
  id: string
  user_id: string
  email: string
  full_name: string | null
  coinw_uid: string | null
  nft_receive_address: string | null
  nft_distributed: boolean
  nft_distributed_at: string | null
  nft_distributed_by: string | null
  nft_distribution_notes: string | null
  total_purchases: number
  referrer_user_id: string | null
  created_at: string
  is_active: boolean
  is_operation_only: boolean
  is_pegasus_exchange?: boolean
  pegasus_exchange_date?: string | null
  pegasus_withdrawal_unlock_date?: string | null
  first_purchase_date?: string | null
  email_blacklisted?: boolean
  operation_start_date?: string | null
  is_active_investor?: boolean
  channel_linked_confirmed?: boolean
  // affiliate_cycleから取得
  auto_nft_count?: number
  manual_nft_count?: number
  total_nft_count?: number
  cum_usdt?: number
  phase?: string
}

export default function AdminUsersPage() {
  // 強制更新用バージョン - 古いキャッシュを無効化
  console.log("🚀🚀🚀 AdminUsersPage v2.5 - CACHE CLEARED 🚀🚀🚀")
  console.log("新しいコードが実行されています - " + new Date().toISOString())
  
  const [users, setUsers] = useState<User[]>([])
  const [filteredUsers, setFilteredUsers] = useState<User[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState("")
  const [searchTerm, setSearchTerm] = useState("")
  const [distributionFilter, setDistributionFilter] = useState<"all" | "distributed" | "not_distributed">("all")
  const [statusFilter, setStatusFilter] = useState<"all" | "active" | "cancelled">("all")
  const [editingUser, setEditingUser] = useState<User | null>(null)
  const [editForm, setEditForm] = useState({
    coinw_uid: "",
    referrer_user_id: "",
    nft_receive_address: "",
    is_operation_only: false,
    is_pegasus_exchange: false,
    email_blacklisted: false,
    operation_start_date: "",
    channel_linked_confirmed: false,
  })
  const [saving, setSaving] = useState(false)
  const [updatingDistribution, setUpdatingDistribution] = useState<string | null>(null)
  const [currentUser, setCurrentUser] = useState<any>(null)
  const router = useRouter()

  useEffect(() => {
    checkAdminAuth()
  }, [])

  useEffect(() => {
    filterUsers()
  }, [users, searchTerm, distributionFilter, statusFilter])

  const checkAdminAuth = async () => {
    try {
      const {
        data: { user },
      } = await supabase.auth.getUser()

      if (!user) {
        router.push("/admin-login")
        return
      }
      
      setCurrentUser(user)

      // 緊急対応: basarasystems@gmail.com または support@dshsupport.biz のアクセス許可
      if (user.email === "basarasystems@gmail.com" || user.email === "support@dshsupport.biz") {
        await fetchUsers()
        return
      }

      const { data: adminCheck, error: adminError } = await supabase.rpc("is_admin", {
        user_email: user.email,
        user_uuid: null,
      })

      if (adminError) {
        console.error("Admin check failed:", adminError)
        // フォールバック: usersテーブルのis_adminフィールドをチェック
        const { data: userCheck, error: userError } = await supabase
          .from("users")
          .select("is_admin")
          .eq("email", user.email)
          .single()
        
        if (!userError && userCheck?.is_admin) {
          await fetchUsers()
          return
        }
        
        router.push("/admin-login")
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
          await fetchUsers()
          return
        }
        
        router.push("/admin-login")
        return
      }

      await fetchUsers()
    } catch (error) {
      console.error("Admin auth check error:", error)
      router.push("/admin-login")
    }
  }

  const fetchUsers = async () => {
    try {
      setLoading(true)
      setError("")

      const { data: usersData, error: usersError } = await supabase
        .from("users")
        .select("*")
        .neq("email", "basarasystems@gmail.com")  // 管理者アカウントを除外
        .neq("email", "support@dshsupport.biz")  // 管理者アカウントを除外
        .order("created_at", { ascending: false })

      if (usersError) {
        throw usersError
      }

      // 購入日を取得（特別ユーザー用）
      const { data: purchasesData } = await supabase
        .from("purchases")
        .select("user_id, admin_approved_at")
        .eq("admin_approved", true)
        .order("admin_approved_at", { ascending: true })

      // ユーザーごとの最初の購入日をマップ
      const firstPurchaseMap = new Map<string, string>()
      if (purchasesData) {
        purchasesData.forEach(p => {
          if (p.user_id && p.admin_approved_at && !firstPurchaseMap.has(p.user_id)) {
            firstPurchaseMap.set(p.user_id, p.admin_approved_at)
          }
        })
      }

      // affiliate_cycleからNFT情報を取得
      const { data: cycleData } = await supabase
        .from("affiliate_cycle")
        .select("user_id, auto_nft_count, manual_nft_count, total_nft_count, cum_usdt, phase")

      // ユーザーIDでマップ化
      const cycleMap = new Map<string, any>()
      if (cycleData) {
        cycleData.forEach(c => {
          cycleMap.set(c.user_id, c)
        })
      }

      // ユーザーデータに購入日とNFT情報を追加
      const enrichedUsers = (usersData || []).map(user => {
        const cycle = cycleMap.get(user.user_id)
        return {
          ...user,
          first_purchase_date: firstPurchaseMap.get(user.user_id) || null,
          auto_nft_count: cycle?.auto_nft_count || 0,
          manual_nft_count: cycle?.manual_nft_count || 0,
          total_nft_count: cycle?.total_nft_count || 0,
          cum_usdt: cycle?.cum_usdt || 0,
          phase: cycle?.phase || null,
        }
      })

      setUsers(enrichedUsers)
    } catch (error: any) {
      console.error("Fetch users error:", error)
      setError(`ユーザーデータの取得に失敗しました: ${error.message}`)
    } finally {
      setLoading(false)
    }
  }

  const filterUsers = () => {
    let filtered = users

    // NFT配布状況フィルター
    if (distributionFilter === "distributed") {
      filtered = filtered.filter(user => user.nft_distributed === true)
    } else if (distributionFilter === "not_distributed") {
      filtered = filtered.filter(user => user.nft_distributed !== true)
    }

    // ステータスフィルター（解約済み/アクティブ）
    if (statusFilter === "cancelled") {
      filtered = filtered.filter(user => user.is_active_investor === false && user.operation_start_date)
    } else if (statusFilter === "active") {
      filtered = filtered.filter(user => user.is_active_investor !== false)
    }

    // 検索フィルター
    if (searchTerm) {
      filtered = filtered.filter(
        (user) =>
          user.user_id.toLowerCase().includes(searchTerm.toLowerCase()) ||
          user.email.toLowerCase().includes(searchTerm.toLowerCase()) ||
          (user.coinw_uid && user.coinw_uid.toLowerCase().includes(searchTerm.toLowerCase())) ||
          (user.full_name && user.full_name.toLowerCase().includes(searchTerm.toLowerCase())),
      )
    }

    setFilteredUsers(filtered)
  }

  const handleEdit = (user: User) => {
    setEditingUser(user)
    setEditForm({
      coinw_uid: user.coinw_uid || "",
      referrer_user_id: user.referrer_user_id || "",
      nft_receive_address: user.nft_receive_address || "",
      is_operation_only: user.is_operation_only || false,
      is_pegasus_exchange: user.is_pegasus_exchange || false,
      email_blacklisted: user.email_blacklisted || false,
      operation_start_date: user.operation_start_date || "",
      channel_linked_confirmed: user.channel_linked_confirmed || false,
    })
  }

  const handleSave = async () => {
    if (!editingUser) return

    try {
      setSaving(true)
      setError("")

      // 運用開始日が変更された場合は安全な更新関数を使用
      const oldOperationDate = editingUser.operation_start_date || ""
      const newOperationDate = editForm.operation_start_date || ""

      if (oldOperationDate !== newOperationDate) {
        // 運用開始日が変更された場合、不整合データを自動削除
        const { data: result, error: rpcError } = await supabase.rpc(
          "update_operation_start_date_safe",
          {
            p_user_id: editingUser.user_id,
            p_new_operation_start_date: newOperationDate || null,
            p_admin_email: currentUser?.email || "unknown"
          }
        )

        if (rpcError) {
          throw rpcError
        }

        if (result && result[0]) {
          if (result[0].status === "ERROR") {
            throw new Error(result[0].message)
          }
          // 削除されたデータがある場合は通知
          const details = result[0].details
          if (details?.deleted_profit?.count > 0 || details?.deleted_referral?.count > 0) {
            const profitInfo = details.deleted_profit?.count > 0
              ? `日利: ${details.deleted_profit.count}件 (${details.deleted_profit.sum})`
              : ""
            const referralInfo = details.deleted_referral?.count > 0
              ? `紹介報酬: ${details.deleted_referral.count}件 (${details.deleted_referral.sum})`
              : ""
            alert(`運用開始日変更に伴い、以下のデータを自動削除しました:\n${profitInfo}\n${referralInfo}`)
          }
        }
      }

      // その他のフィールドを更新
      const { error: updateError } = await supabase
        .from("users")
        .update({
          coinw_uid: editForm.coinw_uid || null,
          referrer_user_id: editForm.referrer_user_id || null,
          nft_receive_address: editForm.nft_receive_address || null,
          is_operation_only: editForm.is_operation_only,
          is_pegasus_exchange: editForm.is_pegasus_exchange,
          pegasus_withdrawal_unlock_date: null,  // 常にnull（出金解禁日は使わない）
          email_blacklisted: editForm.email_blacklisted,
          channel_linked_confirmed: editForm.channel_linked_confirmed,
          updated_at: new Date().toISOString(),
        })
        .eq("id", editingUser.id)

      if (updateError) {
        throw updateError
      }

      setEditingUser(null)
      await fetchUsers()
    } catch (error: any) {
      console.error("Save error:", error)
      setError(`更新に失敗しました: ${error.message}`)
    } finally {
      setSaving(false)
    }
  }

  const handleDelete = async (userId: string) => {
    console.log("🚨🚨🚨 NEW DELETE FUNCTION v2.1 EXECUTING 🚨🚨🚨")
    console.log("This is the new safe deletion code - if you see direct DELETE API calls, there's still old code running!")
    
    const user = users.find(u => u.id === userId)
    if (!user) {
      console.log("❌ User not found:", userId)
      return
    }

    console.log("削除対象ユーザー:", {
      uuid_id: user.id,
      user_id: user.user_id,
      email: user.email,
      timestamp: new Date().toISOString()
    })

    if (!confirm(`本当にユーザー "${user.email}" (ID: ${user.user_id}) を削除しますか？\n\nこの操作により以下のデータも削除されます：\n- 購入履歴\n- アフィリエイトサイクル\n- 出金履歴\n- 買い取り申請\n\nこの操作は取り消せません。`)) return

    // 古いDELETE方式を完全に無効化
    console.log("⚠️ 新しい安全な削除関数のみを使用します")

    try {
      setError("")
      setSaving(true)

      console.log("🔍 削除プロセス開始")

      // 現在のユーザーのメールアドレス取得
      console.log("🔍 管理者認証確認中...")
      const { data: { user: currentUser } } = await supabase.auth.getUser()
      if (!currentUser) {
        throw new Error("管理者認証が必要です")
      }
      console.log("✅ 管理者認証成功:", currentUser.email)

      // 安全な削除関数を使用（user_idを使用）
      console.log("🔍 安全な削除関数を呼び出し中:", {
        function: "delete_user_safely",
        p_user_id: user.user_id,
        p_admin_email: currentUser.email
      })

      const { data: result, error: deleteError } = await supabase.rpc("delete_user_safely", {
        p_user_id: user.user_id,
        p_admin_email: currentUser.email
      })

      console.log("📊 削除関数の結果:", { result, deleteError })

      if (deleteError) {
        console.error("❌ 削除関数でエラー:", deleteError)
        throw new Error(`削除関数エラー: ${deleteError.message}`)
      }

      console.log("✅ RPC関数実行完了 - 結果:", result)

      // 結果確認
      if (!result || result.length === 0) {
        throw new Error("削除関数から結果が返されませんでした")
      }

      if (result[0]?.status === 'ERROR') {
        throw new Error(`削除エラー: ${result[0].message}`)
      }

      if (result[0]?.status !== 'SUCCESS') {
        throw new Error(`予期しない結果: ${JSON.stringify(result[0])}`)
      }

      // 削除詳細を表示
      if (result && result[0]?.details) {
        const details = result[0].details
        const tableInfo = details.deleted_from_tables?.map((t: any) => 
          `  - ${t.table}: ${t.rows}件`
        ).join('\n')
        
        alert(`ユーザーの削除が完了しました\n\n${result[0].message}\n\n削除されたデータ:\n${tableInfo || 'なし'}`)
      } else {
        alert(`ユーザーの削除が完了しました\n${result?.[0]?.message || '正常に削除されました'}`)
      }
      
      await fetchUsers()
    } catch (error: any) {
      console.error("Delete error:", error)
      setError(`削除に失敗しました: ${error.message}`)
    } finally {
      setSaving(false)
    }
  }

  const handleNftDistribution = async (userId: string, isDistributed: boolean) => {
    if (!currentUser) {
      setError("管理者情報が取得できません")
      return
    }

    // 確認ダイアログを表示
    const actionText = isDistributed ? "配布済みに設定" : "配布状況をリセット"
    const confirmMessage = `NFT配布状況を「${actionText}」しますか？`

    if (!confirm(confirmMessage)) {
      return
    }

    try {
      setUpdatingDistribution(userId)
      setError("")

      const { data, error } = await supabase.rpc("update_nft_distribution_status", {
        p_user_id: userId,
        p_is_distributed: isDistributed,
        p_admin_user_id: currentUser.email,
        p_notes: isDistributed ? "NFT配布完了" : "配布状況をリセット"
      })

      if (error) {
        throw error
      }

      if (data && data[0]) {
        const result = data[0]
        if (result.success) {
          await fetchUsers()
          alert(result.message)
        } else {
          throw new Error(result.message)
        }
      }
    } catch (error: any) {
      console.error("NFT distribution update error:", error)
      setError(`NFT配布状況の更新に失敗しました: ${error.message}`)
    } finally {
      setUpdatingDistribution(null)
    }
  }

  const exportUsers = () => {
    // BOM付きUTF-8でExcelでも文字化けしないように
    const BOM = '\uFEFF'

    // CSVエスケープ関数
    const escapeCSV = (value: string | null | undefined): string => {
      if (value === null || value === undefined) return ""
      const str = String(value)
      // カンマ、ダブルクォート、改行が含まれる場合はダブルクォートで囲む
      if (str.includes(",") || str.includes('"') || str.includes("\n")) {
        return `"${str.replace(/"/g, '""')}"`
      }
      return str
    }

    const headers = [
      "ユーザーID",
      "メール",
      "氏名",
      "CoinW UID",
      "NFT受取アドレス",
      "投資額",
      "紹介者ID",
      "NFT配布状況",
      "NFT配布日",
      "NFT配布者",
      "運用開始日",
      "チャンネル紐付け",
      "ペガサス交換",
      "運用専用",
      "メール除外",
      "アクティブ投資家",
      "アカウント状態",
      "作成日",
    ]

    const csvContent = BOM + [
      headers.join(","),
      ...filteredUsers.map((user) =>
        [
          escapeCSV(user.user_id),
          escapeCSV(user.email),
          escapeCSV(user.full_name),
          escapeCSV(user.coinw_uid),
          escapeCSV(user.nft_receive_address),
          user.total_purchases,
          escapeCSV(user.referrer_user_id),
          user.nft_distributed ? "配布済み" : "未配布",
          user.nft_distributed_at ? new Date(user.nft_distributed_at).toLocaleDateString("ja-JP") : "",
          escapeCSV(user.nft_distributed_by),
          user.operation_start_date ? new Date(user.operation_start_date).toLocaleDateString("ja-JP") : "",
          user.channel_linked_confirmed ? "確認済み" : "未確認",
          user.is_pegasus_exchange ? "はい" : "いいえ",
          user.is_operation_only ? "はい" : "いいえ",
          user.email_blacklisted ? "はい" : "いいえ",
          user.is_active_investor === false ? "解約済み" : "アクティブ",
          user.is_active ? "有効" : "無効",
          new Date(user.created_at).toLocaleDateString("ja-JP"),
        ].join(","),
      ),
    ].join("\n")

    // BOM（Byte Order Mark）を追加してExcelで文字化けを防ぐ
    const bom = new Uint8Array([0xEF, 0xBB, 0xBF])
    const blob = new Blob([bom, csvContent], { type: "text/csv;charset=utf-8;" })
    const link = document.createElement("a")
    link.href = URL.createObjectURL(blob)
    link.download = `users_${new Date().toISOString().split("T")[0]}.csv`
    link.click()
  }

  if (loading) {
    return (
      <div className="min-h-screen bg-black flex items-center justify-center">
        <div className="flex items-center space-x-2 text-white">
          <Loader2 className="h-6 w-6 animate-spin" />
          <span>読み込み中...</span>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-black">
      {/* ヘッダー */}
      <header className="bg-gray-800/50 backdrop-blur-sm border-b border-gray-700">
        <div className="container mx-auto px-4 py-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-4">
              <Link href="/admin">
                <Button variant="ghost" size="sm" className="text-gray-300 hover:text-white">
                  <ArrowLeft className="h-4 w-4 mr-2" />
                  管理画面に戻る
                </Button>
              </Link>
              <div>
                <h1 className="text-xl font-bold text-white">ユーザー管理</h1>
                <p className="text-sm text-gray-400">全ユーザーの管理と編集</p>
              </div>
            </div>
            <div className="flex items-center space-x-2">
              <Button
                onClick={fetchUsers}
                variant="outline"
                size="sm"
                className="border-gray-600 text-gray-300 hover:bg-gray-700 bg-transparent"
              >
                <RefreshCw className="h-4 w-4 mr-2" />
                更新
              </Button>
              <Button
                onClick={exportUsers}
                variant="outline"
                size="sm"
                className="border-gray-600 text-gray-300 hover:bg-gray-700 bg-transparent"
              >
                <Download className="h-4 w-4 mr-2" />
                CSV出力
              </Button>
            </div>
          </div>
        </div>
      </header>

      <div className="container mx-auto px-4 py-8">
        {error && (
          <Alert className="mb-6 border-red-700 bg-red-900">
            <AlertDescription className="text-red-200">{error}</AlertDescription>
          </Alert>
        )}

        {/* 検索とフィルター */}
        <Card className="mb-6 bg-gray-800 border-gray-700">
          <CardHeader>
            <CardTitle className="text-white flex items-center">
              <Search className="h-5 w-5 mr-2" />
              ユーザー検索
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="flex items-center space-x-4">
              <div className="flex-1">
                <Input
                  placeholder="ユーザーID、メール、CoinW UID、氏名で検索..."
                  value={searchTerm}
                  onChange={(e) => setSearchTerm(e.target.value)}
                  className="bg-gray-700 border-gray-600 text-white"
                />
              </div>
              <div>
                <select
                  value={distributionFilter}
                  onChange={(e) => setDistributionFilter(e.target.value as "all" | "distributed" | "not_distributed")}
                  className="bg-gray-700 border border-gray-600 text-white rounded-md px-3 py-2 text-sm"
                >
                  <option value="all">NFT配布: 全て</option>
                  <option value="distributed">配布済み</option>
                  <option value="not_distributed">未配布</option>
                </select>
              </div>
              <div>
                <select
                  value={statusFilter}
                  onChange={(e) => setStatusFilter(e.target.value as "all" | "active" | "cancelled")}
                  className="bg-gray-700 border border-gray-600 text-white rounded-md px-3 py-2 text-sm"
                >
                  <option value="all">ステータス: 全て</option>
                  <option value="active">アクティブのみ</option>
                  <option value="cancelled">解約済みのみ</option>
                </select>
              </div>
              <Badge variant="outline" className="text-gray-300">
                {filteredUsers.length} / {users.length} ユーザー
              </Badge>
            </div>
          </CardContent>
        </Card>

        {/* ユーザーリスト */}
        <Card className="bg-gray-800 border-gray-700">
          <CardHeader>
            <CardTitle className="text-white flex items-center">
              <Users className="h-5 w-5 mr-2" />
              ユーザーリスト
            </CardTitle>
            <CardDescription className="text-gray-400">登録されている全ユーザーの一覧</CardDescription>
          </CardHeader>
          <CardContent>
            <div className="space-y-4">
              {filteredUsers.map((user) => (
                <div key={user.id} className="border border-gray-600 rounded-lg p-4">
                  <div className="flex items-center justify-between">
                    <div className="flex-1">
                      <div className="flex items-center space-x-4 mb-2">
                        <Badge className="bg-blue-600">{user.user_id}</Badge>
                        {user.is_active_investor === false && user.operation_start_date && <Badge className="bg-red-600 text-white font-semibold">解約済み</Badge>}
                        {user.is_pegasus_exchange && <Badge className="bg-yellow-600 text-white font-semibold">ペガサス</Badge>}
                        {user.coinw_uid && <Badge className="bg-green-600">CoinW: {user.coinw_uid}</Badge>}
                        {user.channel_linked_confirmed && <Badge className="bg-cyan-600 text-white">CH確認済</Badge>}
                        {!user.is_active && <Badge variant="destructive">非アクティブ</Badge>}
                      </div>

                      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-2 text-sm">
                        <div>
                          <span className="text-gray-400">メール: </span>
                          <span className="text-white">{user.email}</span>
                        </div>
                        <div>
                          <span className="text-gray-400">投資額: </span>
                          <span className="text-green-400">${user.total_purchases.toLocaleString()}</span>
                          {/* NFT数表示（手動+自動） */}
                          <span className="text-gray-500 ml-2">
                            ({user.manual_nft_count || Math.floor(user.total_purchases / 1100)}NFT
                            {(user.auto_nft_count || 0) > 0 && (
                              <span className="text-cyan-400"> +{user.auto_nft_count}自動</span>
                            )})
                          </span>
                        </div>
                        {user.referrer_user_id && (
                          <div>
                            <span className="text-gray-400">紹介者: </span>
                            <span className="text-yellow-400">{user.referrer_user_id}</span>
                          </div>
                        )}
                        {user.nft_receive_address && (
                          <div className="col-span-full mt-2">
                            <span className="text-gray-400">NFT受取アドレス: </span>
                            <span className="text-purple-400 font-mono text-xs break-all">{user.nft_receive_address}</span>
                          </div>
                        )}
                        <div className="col-span-full mt-2">
                          <div className="flex items-center space-x-2">
                            <span className="text-gray-400">NFT配布状況: </span>
                            {user.nft_distributed ? (
                              <div className="flex items-center space-x-2">
                                <span className="text-green-400 font-semibold">配布済み</span>
                                {user.nft_distributed_at && (
                                  <span className="text-xs text-gray-500">
                                    {new Date(user.nft_distributed_at).toLocaleDateString('ja-JP')}
                                  </span>
                                )}
                                {user.nft_distributed_by && (
                                  <span className="text-xs text-gray-500">
                                    by {user.nft_distributed_by}
                                  </span>
                                )}
                              </div>
                            ) : (
                              <span className="text-red-400 font-semibold">未配布</span>
                            )}
                          </div>
                        </div>
                        {user.is_pegasus_exchange === true && (
                          <div className="col-span-full mt-2">
                            <div className="flex items-center space-x-2">
                              <Badge className="bg-yellow-600 text-white">ペガサス交換ユーザー</Badge>
                              {user.first_purchase_date && (
                                <span className="text-xs text-gray-500">
                                  交換日（購入日）: {new Date(user.first_purchase_date).toLocaleDateString('ja-JP')}
                                </span>
                              )}
                              {user.pegasus_withdrawal_unlock_date && typeof user.pegasus_withdrawal_unlock_date === 'string' && user.pegasus_withdrawal_unlock_date.length > 0 && (
                                <span className="text-xs text-orange-400 font-semibold">
                                  出金制限: {new Date(user.pegasus_withdrawal_unlock_date).toLocaleDateString('ja-JP')}まで
                                </span>
                              )}
                            </div>
                          </div>
                        )}
                      </div>

                    </div>

                    <div className="flex items-center space-x-2">
                      <Button
                        onClick={() => handleEdit(user)}
                        variant="outline"
                        size="sm"
                        className="border-gray-600 text-gray-300 hover:bg-gray-700 bg-transparent"
                      >
                        <Edit className="h-4 w-4" />
                      </Button>
                      
                      {/* NFT配布状況ボタン */}
                      <Button
                        onClick={() => handleNftDistribution(user.user_id, !user.nft_distributed)}
                        variant="outline"
                        size="sm"
                        disabled={updatingDistribution === user.user_id}
                        className={`border-purple-600 text-purple-400 hover:bg-purple-900 bg-transparent disabled:opacity-50 ${
                          user.nft_distributed ? 'bg-purple-900/20' : ''
                        }`}
                      >
                        {updatingDistribution === user.user_id ? (
                          <Loader2 className="h-4 w-4 animate-spin" />
                        ) : (
                          <>{user.nft_distributed ? '配布リセット' : '配布済み'}</>
                        )}
                      </Button>
                      
                      <Button
                        onClick={() => {
                          console.log("🔴 削除ボタンクリック - 新しいコード実行中")
                          handleDelete(user.id)
                        }}
                        variant="outline"
                        size="sm"
                        disabled={saving}
                        className="border-red-600 text-red-400 hover:bg-red-900 bg-transparent disabled:opacity-50"
                      >
                        <Trash2 className="h-4 w-4" />
                        <span className="ml-1 text-xs">v2.5</span>
                      </Button>
                    </div>
                  </div>
                </div>
              ))}

              {filteredUsers.length === 0 && (
                <div className="text-center py-8 text-gray-400">
                  <Users className="h-16 w-16 mx-auto mb-4 opacity-50" />
                  <p className="text-xl mb-2">ユーザーが見つかりません</p>
                  <p>検索条件を変更してください。</p>
                </div>
              )}
            </div>
          </CardContent>
        </Card>

        {/* 編集モーダル */}
        {editingUser && (
          <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
            <Card className="w-full max-w-md bg-gray-800 border-gray-700 max-h-[90vh] flex flex-col">
              <CardHeader className="flex-shrink-0">
                <CardTitle className="text-white">ユーザー編集</CardTitle>
                <CardDescription className="text-gray-400">{editingUser.user_id} の情報を編集</CardDescription>
              </CardHeader>
              <CardContent className="space-y-4 overflow-y-auto flex-1">
                <div>
                  <Label className="text-gray-300">CoinW UID</Label>
                  <Input
                    value={editForm.coinw_uid}
                    onChange={(e) => setEditForm({ ...editForm, coinw_uid: e.target.value })}
                    className="bg-gray-700 border-gray-600 text-white"
                    placeholder="CoinW UID"
                  />
                </div>

                <div>
                  <Label className="text-gray-300">紹介者ユーザーID</Label>
                  <Input
                    value={editForm.referrer_user_id}
                    onChange={(e) => setEditForm({ ...editForm, referrer_user_id: e.target.value })}
                    className="bg-gray-700 border-gray-600 text-white"
                    placeholder="紹介者のユーザーID"
                  />
                </div>

                <div>
                  <Label className="text-gray-300">NFT受取アドレス</Label>
                  <Input
                    value={editForm.nft_receive_address}
                    onChange={(e) => setEditForm({ ...editForm, nft_receive_address: e.target.value })}
                    className="bg-gray-700 border-gray-600 text-white font-mono text-sm"
                    placeholder="NFT受取用のウォレットアドレス"
                  />
                  <p className="text-xs text-gray-500 mt-1">
                    管理者がNFTを送付する際に使用されます
                  </p>
                </div>

                <div className="bg-blue-900/20 border border-blue-600/30 rounded-lg p-3">
                  <div className="flex items-center space-x-2">
                    <input
                      type="checkbox"
                      id="is_operation_only"
                      checked={editForm.is_operation_only}
                      onChange={(e) => setEditForm({ ...editForm, is_operation_only: e.target.checked })}
                      className="w-4 h-4 rounded border-gray-600 bg-gray-700 text-blue-600 focus:ring-blue-600"
                    />
                    <Label htmlFor="is_operation_only" className="text-gray-300 cursor-pointer">
                      運用専用ユーザー
                    </Label>
                  </div>
                  <p className="text-xs text-gray-400 mt-2">
                    チェックすると、ダッシュボードから紹介関連のUIを全て非表示にします<br />
                    （紹介報酬の計算は通常通り行われます）
                  </p>
                </div>

                <div className="bg-green-900/20 border border-green-600/30 rounded-lg p-3">
                  <Label className="text-green-300 text-sm font-medium">運用開始日</Label>
                  <Input
                    type="date"
                    value={editForm.operation_start_date}
                    onChange={(e) => setEditForm({ ...editForm, operation_start_date: e.target.value })}
                    className="bg-gray-700 border-gray-600 text-white mt-2"
                  />
                  <p className="text-xs text-gray-400 mt-2">
                    ⚠️ 運用開始日を変更すると、新しい日付より前の日利・紹介報酬データは自動削除されます
                  </p>
                </div>

                <div className="bg-gray-700/50 rounded-lg p-3">
                  <Label className="text-gray-300 text-sm font-medium">NFT配布状況</Label>
                  <div className="mt-2 space-y-1">
                    <div className="flex items-center space-x-2">
                      <span className="text-gray-400">状況: </span>
                      <span className={`font-semibold ${
                        editingUser?.nft_distributed ? 'text-green-400' : 'text-red-400'
                      }`}>
                        {editingUser?.nft_distributed ? '配布済み' : '未配布'}
                      </span>
                    </div>
                    {editingUser?.nft_distributed && editingUser.nft_distributed_at && (
                      <div className="flex items-center space-x-2">
                        <span className="text-gray-400">配布日: </span>
                        <span className="text-gray-300 text-sm">
                          {new Date(editingUser.nft_distributed_at).toLocaleDateString('ja-JP')}
                        </span>
                      </div>
                    )}
                    {editingUser?.nft_distributed_by && (
                      <div className="flex items-center space-x-2">
                        <span className="text-gray-400">実行者: </span>
                        <span className="text-gray-300 text-sm">
                          {editingUser.nft_distributed_by}
                        </span>
                      </div>
                    )}
                  </div>
                </div>

                <div className="bg-yellow-900/20 border border-yellow-600/30 rounded-lg p-3">
                  <div className="space-y-3">
                    <div className="flex items-center space-x-2">
                      <input
                        type="checkbox"
                        id="is_pegasus_exchange"
                        checked={editForm.is_pegasus_exchange}
                        onChange={(e) => setEditForm({ ...editForm, is_pegasus_exchange: e.target.checked })}
                        className="w-4 h-4 rounded border-gray-600 bg-gray-700 text-yellow-600 focus:ring-yellow-600"
                      />
                      <Label htmlFor="is_pegasus_exchange" className="text-yellow-300 font-medium cursor-pointer">
                        ペガサス交換ユーザー
                      </Label>
                    </div>

                    {editForm.is_pegasus_exchange && (
                      <div className="bg-orange-900/20 border border-orange-600/30 rounded p-3 space-y-2">
                        <p className="text-xs text-orange-200">
                          ⚠️ チェックON中の制限:
                        </p>
                        <ul className="text-xs text-gray-300 space-y-1 ml-4 list-disc">
                          <li>個人運用（日利）: 停止</li>
                          <li>出金: 不可</li>
                          <li>紹介報酬: 通常通り加算</li>
                        </ul>
                        <p className="text-xs text-yellow-300 mt-2">
                          💡 チェックOFFで通常運用に戻ります
                        </p>
                      </div>
                    )}
                  </div>
                </div>

                <div className="bg-cyan-900/20 border border-cyan-600/30 rounded-lg p-3">
                  <div className="flex items-center space-x-2">
                    <input
                      type="checkbox"
                      id="channel_linked_confirmed"
                      checked={editForm.channel_linked_confirmed}
                      onChange={(e) => setEditForm({ ...editForm, channel_linked_confirmed: e.target.checked })}
                      className="w-4 h-4 rounded border-gray-600 bg-gray-700 text-cyan-600 focus:ring-cyan-600"
                    />
                    <Label htmlFor="channel_linked_confirmed" className="text-gray-300 cursor-pointer">
                      チャンネル紐付け確認済み
                    </Label>
                  </div>
                  <p className="text-xs text-gray-400 mt-2">
                    チェックすると一覧に「CH確認済」バッジを表示します<br />
                    （報酬等には一切影響しません）
                  </p>
                </div>

                <div className="bg-red-900/20 border border-red-600/30 rounded-lg p-3">
                  <div className="flex items-center space-x-2">
                    <input
                      type="checkbox"
                      id="email_blacklisted"
                      checked={editForm.email_blacklisted}
                      onChange={(e) => setEditForm({ ...editForm, email_blacklisted: e.target.checked })}
                      className="w-4 h-4 rounded border-gray-600 bg-gray-700 text-red-600 focus:ring-red-600"
                    />
                    <Label htmlFor="email_blacklisted" className="text-gray-300 cursor-pointer">
                      メール送信除外
                    </Label>
                  </div>
                  <p className="text-xs text-gray-400 mt-2">
                    チェックすると、一斉送信の対象外になります<br />
                    （他の機能には一切影響しません）
                  </p>
                </div>

              </CardContent>
              <div className="flex justify-end space-x-2 p-4 border-t border-gray-700 flex-shrink-0 bg-gray-800">
                <Button
                  onClick={() => setEditingUser(null)}
                  variant="outline"
                  className="border-gray-600 text-gray-300 hover:bg-gray-700 bg-transparent"
                >
                  キャンセル
                </Button>
                <Button onClick={handleSave} disabled={saving} className="bg-blue-600 hover:bg-blue-700 text-white">
                  {saving ? (
                    <>
                      <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                      保存中...
                    </>
                  ) : (
                    "保存"
                  )}
                </Button>
              </div>
            </Card>
          </div>
        )}

        {/* トップに戻るボタン */}
        <button
          onClick={() => window.scrollTo({ top: 0, behavior: 'smooth' })}
          className="fixed bottom-6 right-6 bg-blue-600 hover:bg-blue-700 text-white p-3 rounded-full shadow-lg z-50 transition-all"
          title="トップに戻る"
        >
          <ArrowUp className="h-5 w-5" />
        </button>
      </div>
    </div>
  )
}
