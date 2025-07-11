"use client"

import { useState, useEffect } from "react"
import { useRouter } from "next/navigation"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Badge } from "@/components/ui/badge"
import { Alert, AlertDescription } from "@/components/ui/alert"
import { Loader2, Users, Search, Edit, Trash2, ArrowLeft, RefreshCw, Download } from "lucide-react"
import { supabase } from "@/lib/supabase"
import Link from "next/link"

interface User {
  id: string
  user_id: string
  email: string
  full_name: string | null
  coinw_uid: string | null
  total_purchases: number
  referrer_user_id: string | null
  created_at: string
  is_active: boolean
  reward_address_bep20: string | null
  nft_receive_address: string | null
}

export default function AdminUsersPage() {
  const [users, setUsers] = useState<User[]>([])
  const [filteredUsers, setFilteredUsers] = useState<User[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState("")
  const [searchTerm, setSearchTerm] = useState("")
  const [editingUser, setEditingUser] = useState<User | null>(null)
  const [editForm, setEditForm] = useState({
    coinw_uid: "",
    reward_address_bep20: "",
    nft_receive_address: "",
    referrer_user_id: "",
  })
  const [saving, setSaving] = useState(false)
  const router = useRouter()

  useEffect(() => {
    checkAdminAuth()
  }, [])

  useEffect(() => {
    filterUsers()
  }, [users, searchTerm])

  const checkAdminAuth = async () => {
    try {
      const {
        data: { user },
      } = await supabase.auth.getUser()

      if (!user) {
        router.push("/admin-login")
        return
      }

      // 緊急対応：管理者権限チェックを一時的に無効化
      /*
      const { data: adminCheck, error: adminError } = await supabase.rpc("is_admin", {
        user_email: user.email,
        user_uuid: null,
      })

      if (adminError || !adminCheck) {
        console.error("Admin check failed:", adminError)
        router.push("/admin-login")
        return
      }
      */

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
        .order("created_at", { ascending: false })

      if (usersError) {
        throw usersError
      }

      setUsers(usersData || [])
    } catch (error: any) {
      console.error("Fetch users error:", error)
      setError(`ユーザーデータの取得に失敗しました: ${error.message}`)
    } finally {
      setLoading(false)
    }
  }

  const filterUsers = () => {
    if (!searchTerm) {
      setFilteredUsers(users)
      return
    }

    const filtered = users.filter(
      (user) =>
        user.user_id.toLowerCase().includes(searchTerm.toLowerCase()) ||
        user.email.toLowerCase().includes(searchTerm.toLowerCase()) ||
        (user.coinw_uid && user.coinw_uid.toLowerCase().includes(searchTerm.toLowerCase())) ||
        (user.full_name && user.full_name.toLowerCase().includes(searchTerm.toLowerCase())),
    )
    setFilteredUsers(filtered)
  }

  const handleEdit = (user: User) => {
    setEditingUser(user)
    setEditForm({
      coinw_uid: user.coinw_uid || "",
      reward_address_bep20: user.reward_address_bep20 || "",
      nft_receive_address: user.nft_receive_address || "",
      referrer_user_id: user.referrer_user_id || "",
    })
  }

  const handleSave = async () => {
    if (!editingUser) return

    try {
      setSaving(true)
      setError("")

      const { error: updateError } = await supabase
        .from("users")
        .update({
          coinw_uid: editForm.coinw_uid || null,
          reward_address_bep20: editForm.reward_address_bep20 || null,
          nft_receive_address: editForm.nft_receive_address || null,
          referrer_user_id: editForm.referrer_user_id || null,
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
    if (!confirm("本当にこのユーザーを削除しますか？")) return

    try {
      setError("")

      const { error: deleteError } = await supabase.from("users").delete().eq("id", userId)

      if (deleteError) {
        throw deleteError
      }

      await fetchUsers()
    } catch (error: any) {
      console.error("Delete error:", error)
      setError(`削除に失敗しました: ${error.message}`)
    }
  }

  const exportUsers = () => {
    const csvContent = [
      ["ユーザーID", "メール", "CoinW UID", "投資額", "紹介者", "作成日", "報酬アドレス", "NFTアドレス"].join(","),
      ...filteredUsers.map((user) =>
        [
          user.user_id,
          user.email,
          user.coinw_uid || "",
          user.total_purchases,
          user.referrer_user_id || "",
          new Date(user.created_at).toLocaleDateString("ja-JP"),
          user.reward_address_bep20 || "",
          user.nft_receive_address || "",
        ].join(","),
      ),
    ].join("\n")

    const blob = new Blob([csvContent], { type: "text/csv;charset=utf-8;" })
    const link = document.createElement("a")
    link.href = URL.createObjectURL(blob)
    link.download = `users_${new Date().toISOString().split("T")[0]}.csv`
    link.click()
  }

  if (loading) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-gray-900 to-black flex items-center justify-center">
        <div className="flex items-center space-x-2 text-white">
          <Loader2 className="h-6 w-6 animate-spin" />
          <span>読み込み中...</span>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-900 to-black">
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
                        {user.coinw_uid && <Badge className="bg-green-600">CoinW: {user.coinw_uid}</Badge>}
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
                        </div>
                        {user.referrer_user_id && (
                          <div>
                            <span className="text-gray-400">紹介者: </span>
                            <span className="text-yellow-400">{user.referrer_user_id}</span>
                          </div>
                        )}
                      </div>

                      {(user.reward_address_bep20 || user.nft_receive_address) && (
                        <div className="mt-2 text-xs space-y-1">
                          {user.reward_address_bep20 && (
                            <div>
                              <span className="text-gray-400">報酬アドレス: </span>
                              <span className="text-blue-400 font-mono">{user.reward_address_bep20}</span>
                            </div>
                          )}
                          {user.nft_receive_address && (
                            <div>
                              <span className="text-gray-400">NFTアドレス: </span>
                              <span className="text-purple-400 font-mono">{user.nft_receive_address}</span>
                            </div>
                          )}
                        </div>
                      )}
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
                      <Button
                        onClick={() => handleDelete(user.id)}
                        variant="outline"
                        size="sm"
                        className="border-red-600 text-red-400 hover:bg-red-900 bg-transparent"
                      >
                        <Trash2 className="h-4 w-4" />
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
          <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
            <Card className="w-full max-w-md bg-gray-800 border-gray-700">
              <CardHeader>
                <CardTitle className="text-white">ユーザー編集</CardTitle>
                <CardDescription className="text-gray-400">{editingUser.user_id} の情報を編集</CardDescription>
              </CardHeader>
              <CardContent className="space-y-4">
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
                  <Label className="text-gray-300">報酬受け取りアドレス</Label>
                  <Input
                    value={editForm.reward_address_bep20}
                    onChange={(e) => setEditForm({ ...editForm, reward_address_bep20: e.target.value })}
                    className="bg-gray-700 border-gray-600 text-white"
                    placeholder="0x..."
                  />
                </div>

                <div>
                  <Label className="text-gray-300">NFT受取アドレス</Label>
                  <Input
                    value={editForm.nft_receive_address}
                    onChange={(e) => setEditForm({ ...editForm, nft_receive_address: e.target.value })}
                    className="bg-gray-700 border-gray-600 text-white"
                    placeholder="0x..."
                  />
                </div>

                <div className="flex justify-end space-x-2 pt-4">
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
              </CardContent>
            </Card>
          </div>
        )}
      </div>
    </div>
  )
}
