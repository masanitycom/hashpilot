"use client"

import { useState, useEffect } from "react"
import { useRouter } from "next/navigation"
import Link from "next/link"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Textarea } from "@/components/ui/textarea"
import { Badge } from "@/components/ui/badge"
import { Alert, AlertDescription } from "@/components/ui/alert"
import {
  ArrowLeft,
  Plus,
  Edit,
  Trash2,
  Eye,
  EyeOff,
  Megaphone,
  AlertCircle,
  CheckCircle,
} from "lucide-react"
import { supabase } from "@/lib/supabase"

interface Announcement {
  id: number
  title: string
  content: string
  is_active: boolean
  priority: number
  created_at: string
}

export default function AnnouncementsAdminPage() {
  const [announcements, setAnnouncements] = useState<Announcement[]>([])
  const [loading, setLoading] = useState(true)
  const [isAdmin, setIsAdmin] = useState(false)
  const [showForm, setShowForm] = useState(false)
  const [editingId, setEditingId] = useState<number | null>(null)
  const [formData, setFormData] = useState({
    title: "",
    content: "",
    priority: 0,
  })
  const [message, setMessage] = useState<{ type: "success" | "error"; text: string } | null>(null)
  const router = useRouter()

  useEffect(() => {
    checkAdminAccess()
  }, [])

  const checkAdminAccess = async () => {
    try {
      const { data: { user } } = await supabase.auth.getUser()

      if (!user) {
        router.push("/login")
        return
      }

      if (user.email === "basarasystems@gmail.com" || user.email === "support@dshsupport.biz") {
        setIsAdmin(true)
        await fetchAnnouncements()
        return
      }

      const { data: adminCheck } = await supabase.rpc("is_admin", {
        user_email: user.email,
      })

      if (adminCheck) {
        setIsAdmin(true)
        await fetchAnnouncements()
      } else {
        router.push("/")
      }
    } catch (error) {
      console.error("Admin check error:", error)
      router.push("/login")
    } finally {
      setLoading(false)
    }
  }

  const fetchAnnouncements = async () => {
    try {
      const { data, error } = await supabase
        .from("announcements")
        .select("*")
        .order("priority", { ascending: false })
        .order("created_at", { ascending: false })

      if (error) throw error
      setAnnouncements(data || [])
    } catch (error) {
      console.error("お知らせ取得エラー:", error)
    }
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setMessage(null)

    try {
      if (editingId) {
        // 更新
        const { error } = await supabase
          .from("announcements")
          .update({
            title: formData.title,
            content: formData.content,
            priority: formData.priority,
            updated_at: new Date().toISOString(),
          })
          .eq("id", editingId)

        if (error) throw error
        setMessage({ type: "success", text: "お知らせを更新しました" })
      } else {
        // 新規作成
        const { error } = await supabase
          .from("announcements")
          .insert({
            title: formData.title,
            content: formData.content,
            priority: formData.priority,
            is_active: true,
          })

        if (error) throw error
        setMessage({ type: "success", text: "お知らせを作成しました" })
      }

      // フォームをリセット
      setFormData({ title: "", content: "", priority: 0 })
      setShowForm(false)
      setEditingId(null)
      await fetchAnnouncements()
    } catch (error: any) {
      console.error("お知らせ保存エラー:", error)
      setMessage({ type: "error", text: "保存に失敗しました" })
    }
  }

  const toggleActive = async (id: number, currentStatus: boolean) => {
    try {
      const { error } = await supabase
        .from("announcements")
        .update({ is_active: !currentStatus })
        .eq("id", id)

      if (error) throw error
      await fetchAnnouncements()
      setMessage({
        type: "success",
        text: !currentStatus ? "お知らせを表示しました" : "お知らせを非表示にしました",
      })
    } catch (error) {
      console.error("状態更新エラー:", error)
      setMessage({ type: "error", text: "状態の更新に失敗しました" })
    }
  }

  const handleEdit = (announcement: Announcement) => {
    setEditingId(announcement.id)
    setFormData({
      title: announcement.title,
      content: announcement.content,
      priority: announcement.priority,
    })
    setShowForm(true)
  }

  const handleDelete = async (id: number) => {
    if (!confirm("このお知らせを削除しますか？")) return

    try {
      const { error } = await supabase
        .from("announcements")
        .delete()
        .eq("id", id)

      if (error) throw error
      await fetchAnnouncements()
      setMessage({ type: "success", text: "お知らせを削除しました" })
    } catch (error) {
      console.error("削除エラー:", error)
      setMessage({ type: "error", text: "削除に失敗しました" })
    }
  }

  const cancelEdit = () => {
    setShowForm(false)
    setEditingId(null)
    setFormData({ title: "", content: "", priority: 0 })
  }

  if (loading) {
    return (
      <div className="min-h-screen bg-gray-900 flex items-center justify-center">
        <div className="text-white">読み込み中...</div>
      </div>
    )
  }

  if (!isAdmin) {
    return null
  }

  return (
    <div className="min-h-screen bg-gray-900 text-white p-6">
      <div className="max-w-6xl mx-auto">
        {/* ヘッダー */}
        <div className="flex items-center justify-between mb-6">
          <div className="flex items-center gap-4">
            <Link href="/admin">
              <Button variant="outline" size="sm">
                <ArrowLeft className="h-4 w-4 mr-2" />
                管理画面に戻る
              </Button>
            </Link>
            <h1 className="text-2xl font-bold flex items-center gap-2">
              <Megaphone className="h-6 w-6" />
              お知らせ管理
            </h1>
          </div>
          {!showForm && (
            <Button onClick={() => setShowForm(true)} className="bg-blue-600 hover:bg-blue-700">
              <Plus className="h-4 w-4 mr-2" />
              新規作成
            </Button>
          )}
        </div>

        {/* メッセージ */}
        {message && (
          <Alert className={`mb-4 ${message.type === "success" ? "bg-green-900/20 border-green-500/50" : "bg-red-900/20 border-red-500/50"}`}>
            {message.type === "success" ? (
              <CheckCircle className="h-4 w-4 text-green-400" />
            ) : (
              <AlertCircle className="h-4 w-4 text-red-400" />
            )}
            <AlertDescription className={message.type === "success" ? "text-green-400" : "text-red-400"}>
              {message.text}
            </AlertDescription>
          </Alert>
        )}

        {/* 作成/編集フォーム */}
        {showForm && (
          <Card className="bg-gray-800 border-gray-700 mb-6">
            <CardHeader>
              <CardTitle>{editingId ? "お知らせ編集" : "お知らせ作成"}</CardTitle>
            </CardHeader>
            <CardContent>
              <form onSubmit={handleSubmit} className="space-y-4">
                <div>
                  <Label htmlFor="title">タイトル</Label>
                  <Input
                    id="title"
                    value={formData.title}
                    onChange={(e) => setFormData({ ...formData, title: e.target.value })}
                    required
                    className="bg-gray-700 border-gray-600"
                    placeholder="お知らせのタイトルを入力"
                  />
                </div>

                <div>
                  <Label htmlFor="content">内容</Label>
                  <Textarea
                    id="content"
                    value={formData.content}
                    onChange={(e) => setFormData({ ...formData, content: e.target.value })}
                    required
                    rows={6}
                    className="bg-gray-700 border-gray-600"
                    placeholder="お知らせの内容を入力&#10;Enterキーで改行できます&#10;URLは自動的にリンクになります"
                  />
                  <p className="text-xs text-gray-400 mt-1">
                    改行: Enterキー / URLは自動リンク化されます
                  </p>
                </div>

                <div>
                  <Label htmlFor="priority">優先度（数字が大きいほど上に表示）</Label>
                  <Input
                    id="priority"
                    type="number"
                    value={formData.priority}
                    onChange={(e) => setFormData({ ...formData, priority: parseInt(e.target.value) || 0 })}
                    className="bg-gray-700 border-gray-600"
                  />
                </div>

                <div className="flex gap-2">
                  <Button type="submit" className="bg-blue-600 hover:bg-blue-700">
                    {editingId ? "更新" : "作成"}
                  </Button>
                  <Button type="button" onClick={cancelEdit} variant="outline">
                    キャンセル
                  </Button>
                </div>
              </form>
            </CardContent>
          </Card>
        )}

        {/* お知らせリスト */}
        <div className="space-y-4">
          <h2 className="text-xl font-semibold">お知らせ一覧</h2>
          {announcements.length === 0 ? (
            <Card className="bg-gray-800 border-gray-700">
              <CardContent className="p-6 text-center text-gray-400">
                お知らせがありません
              </CardContent>
            </Card>
          ) : (
            announcements.map((announcement) => (
              <Card
                key={announcement.id}
                className={`bg-gray-800 border-gray-700 ${!announcement.is_active ? "opacity-50" : ""}`}
              >
                <CardContent className="p-4">
                  <div className="flex items-start justify-between gap-4">
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2 mb-2">
                        <h3 className="text-lg font-semibold text-white">
                          {announcement.title}
                        </h3>
                        <Badge variant={announcement.is_active ? "default" : "secondary"}>
                          {announcement.is_active ? "表示中" : "非表示"}
                        </Badge>
                        {announcement.priority > 0 && (
                          <Badge variant="outline" className="text-yellow-400 border-yellow-400">
                            優先度: {announcement.priority}
                          </Badge>
                        )}
                      </div>
                      <p className="text-gray-300 text-sm whitespace-pre-wrap break-words mb-2">
                        {announcement.content}
                      </p>
                      <p className="text-xs text-gray-500">
                        {new Date(announcement.created_at).toLocaleString("ja-JP")}
                      </p>
                    </div>
                    <div className="flex gap-2 flex-shrink-0">
                      <Button
                        size="sm"
                        variant="outline"
                        onClick={() => toggleActive(announcement.id, announcement.is_active)}
                      >
                        {announcement.is_active ? (
                          <EyeOff className="h-4 w-4" />
                        ) : (
                          <Eye className="h-4 w-4" />
                        )}
                      </Button>
                      <Button
                        size="sm"
                        variant="outline"
                        onClick={() => handleEdit(announcement)}
                      >
                        <Edit className="h-4 w-4" />
                      </Button>
                      <Button
                        size="sm"
                        variant="outline"
                        onClick={() => handleDelete(announcement.id)}
                        className="text-red-400 hover:text-red-300"
                      >
                        <Trash2 className="h-4 w-4" />
                      </Button>
                    </div>
                  </div>
                </CardContent>
              </Card>
            ))
          )}
        </div>
      </div>
    </div>
  )
}
