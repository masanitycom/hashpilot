"use client"

import { useState, useEffect } from "react"
import { useRouter } from "next/navigation"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Input } from "@/components/ui/input"
import { Textarea } from "@/components/ui/textarea"
import { Checkbox } from "@/components/ui/checkbox"
import { 
  Loader2, 
  ArrowLeft, 
  Plus, 
  Edit, 
  Trash2,
  Save,
  X,
  BarChart3,
  CheckCircle,
  XCircle
} from "lucide-react"
import { supabase } from "@/lib/supabase"
import Link from "next/link"

interface Question {
  id: string
  question: string
  option_a: string
  option_b: string
  is_active: boolean
  created_at: string
  updated_at: string
}

export default function AdminTasksPage() {
  const [user, setUser] = useState<any>(null)
  const [questions, setQuestions] = useState<Question[]>([])
  const [loading, setLoading] = useState(true)
  const [processing, setProcessing] = useState(false)
  const [error, setError] = useState("")
  const [editingQuestion, setEditingQuestion] = useState<Question | null>(null)
  const [newQuestion, setNewQuestion] = useState({
    question: "",
    option_a: "",
    option_b: "",
    is_active: true
  })
  const [showCreateForm, setShowCreateForm] = useState(false)
  const router = useRouter()

  useEffect(() => {
    checkAuth()
  }, [])

  useEffect(() => {
    if (user) {
      fetchQuestions()
    }
  }, [user])

  const checkAuth = async () => {
    try {
      const { data: { session }, error: sessionError } = await supabase.auth.getSession()
      
      if (sessionError || !session?.user) {
        router.push("/login")
        return
      }

      setUser(session.user)
    } catch (error) {
      console.error("Auth check error:", error)
      router.push("/login")
    }
  }

  const fetchQuestions = async () => {
    try {
      setLoading(true)
      setError("")

      const { data, error } = await supabase
        .from("reward_questions")
        .select("*")
        .order("created_at", { ascending: false })

      if (error) {
        throw error
      }

      setQuestions(data || [])
    } catch (err: any) {
      console.error("Error fetching questions:", err)
      setError("設問データの取得に失敗しました")
    } finally {
      setLoading(false)
    }
  }

  const handleCreateQuestion = async () => {
    try {
      setProcessing(true)

      if (!newQuestion.question.trim() || !newQuestion.option_a.trim() || !newQuestion.option_b.trim()) {
        alert("すべての項目を入力してください")
        return
      }

      const { error } = await supabase
        .from("reward_questions")
        .insert([{
          question: newQuestion.question.trim(),
          option_a: newQuestion.option_a.trim(),
          option_b: newQuestion.option_b.trim(),
          is_active: newQuestion.is_active,
          created_by: user.id
        }])

      if (error) {
        throw error
      }

      alert("設問を作成しました")
      setNewQuestion({ question: "", option_a: "", option_b: "", is_active: true })
      setShowCreateForm(false)
      fetchQuestions()
    } catch (err: any) {
      console.error("Error creating question:", err)
      alert("設問の作成に失敗しました: " + err.message)
    } finally {
      setProcessing(false)
    }
  }

  const handleUpdateQuestion = async (questionId: string, updates: Partial<Question>) => {
    try {
      setProcessing(true)

      const { error } = await supabase
        .from("reward_questions")
        .update({
          ...updates,
          updated_at: new Date().toISOString()
        })
        .eq("id", questionId)

      if (error) {
        throw error
      }

      alert("設問を更新しました")
      setEditingQuestion(null)
      fetchQuestions()
    } catch (err: any) {
      console.error("Error updating question:", err)
      alert("設問の更新に失敗しました: " + err.message)
    } finally {
      setProcessing(false)
    }
  }

  const handleDeleteQuestion = async (questionId: string) => {
    if (!confirm("この設問を削除してもよろしいですか？")) {
      return
    }

    try {
      setProcessing(true)

      const { error } = await supabase
        .from("reward_questions")
        .delete()
        .eq("id", questionId)

      if (error) {
        throw error
      }

      alert("設問を削除しました")
      fetchQuestions()
    } catch (err: any) {
      console.error("Error deleting question:", err)
      alert("設問の削除に失敗しました: " + err.message)
    } finally {
      setProcessing(false)
    }
  }

  const toggleQuestionStatus = async (question: Question) => {
    await handleUpdateQuestion(question.id, { is_active: !question.is_active })
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
                  管理画面
                </Button>
              </Link>
              <div>
                <h1 className="text-xl font-bold text-white">報酬受取タスク管理</h1>
                <p className="text-sm text-gray-400">月末出金時のアンケートタスク設問管理</p>
              </div>
            </div>
            <Button
              onClick={() => setShowCreateForm(!showCreateForm)}
              className="bg-blue-600 hover:bg-blue-700"
            >
              <Plus className="h-4 w-4 mr-2" />
              新規設問
            </Button>
          </div>
        </div>
      </header>

      <div className="container mx-auto px-4 py-8">
        {/* 統計セクション */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
          <Card className="bg-blue-900/20 border-blue-700/50">
            <CardContent className="p-6">
              <div className="flex items-center space-x-3">
                <BarChart3 className="h-8 w-8 text-blue-400" />
                <div>
                  <p className="text-sm text-blue-300">総設問数</p>
                  <p className="text-2xl font-bold text-blue-400">
                    {questions.length}
                  </p>
                </div>
              </div>
            </CardContent>
          </Card>

          <Card className="bg-green-900/20 border-green-700/50">
            <CardContent className="p-6">
              <div className="flex items-center space-x-3">
                <CheckCircle className="h-8 w-8 text-green-400" />
                <div>
                  <p className="text-sm text-green-300">アクティブ</p>
                  <p className="text-2xl font-bold text-green-400">
                    {questions.filter(q => q.is_active).length}
                  </p>
                </div>
              </div>
            </CardContent>
          </Card>

          <Card className="bg-red-900/20 border-red-700/50">
            <CardContent className="p-6">
              <div className="flex items-center space-x-3">
                <XCircle className="h-8 w-8 text-red-400" />
                <div>
                  <p className="text-sm text-red-300">無効</p>
                  <p className="text-2xl font-bold text-red-400">
                    {questions.filter(q => !q.is_active).length}
                  </p>
                </div>
              </div>
            </CardContent>
          </Card>
        </div>

        {/* 新規作成フォーム */}
        {showCreateForm && (
          <Card className="bg-gray-800 border-gray-700 mb-6">
            <CardHeader>
              <CardTitle className="text-white">新規設問作成</CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <div>
                <label className="block text-sm text-gray-300 mb-2">設問文</label>
                <Textarea
                  placeholder="例: 朝はコーヒー派ですか？お茶派ですか？"
                  value={newQuestion.question}
                  onChange={(e) => setNewQuestion(prev => ({ ...prev, question: e.target.value }))}
                  className="bg-gray-700 border-gray-600 text-white"
                  rows={2}
                />
              </div>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm text-gray-300 mb-2">選択肢A</label>
                  <Input
                    placeholder="例: コーヒー"
                    value={newQuestion.option_a}
                    onChange={(e) => setNewQuestion(prev => ({ ...prev, option_a: e.target.value }))}
                    className="bg-gray-700 border-gray-600 text-white"
                  />
                </div>
                <div>
                  <label className="block text-sm text-gray-300 mb-2">選択肢B</label>
                  <Input
                    placeholder="例: お茶"
                    value={newQuestion.option_b}
                    onChange={(e) => setNewQuestion(prev => ({ ...prev, option_b: e.target.value }))}
                    className="bg-gray-700 border-gray-600 text-white"
                  />
                </div>
              </div>
              <div className="flex items-center space-x-2">
                <Checkbox
                  id="new-active"
                  checked={newQuestion.is_active}
                  onCheckedChange={(checked) => setNewQuestion(prev => ({ ...prev, is_active: !!checked }))}
                />
                <label htmlFor="new-active" className="text-sm text-gray-300">
                  作成時からアクティブにする
                </label>
              </div>
              <div className="flex space-x-2">
                <Button
                  onClick={handleCreateQuestion}
                  disabled={processing}
                  className="bg-blue-600 hover:bg-blue-700"
                >
                  {processing ? <Loader2 className="h-4 w-4 animate-spin mr-2" /> : <Save className="h-4 w-4 mr-2" />}
                  作成
                </Button>
                <Button
                  onClick={() => setShowCreateForm(false)}
                  className="bg-gray-600 hover:bg-gray-700 text-white"
                >
                  <X className="h-4 w-4 mr-2" />
                  キャンセル
                </Button>
              </div>
            </CardContent>
          </Card>
        )}

        {/* 設問一覧 */}
        <Card className="bg-gray-800 border-gray-700">
          <CardHeader>
            <CardTitle className="text-white">設問一覧</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-4">
              {questions.map((question) => (
                <div key={question.id} className="bg-gray-700/50 rounded-lg p-4 border border-gray-600">
                  {editingQuestion?.id === question.id ? (
                    // 編集モード
                    <div className="space-y-4">
                      <Textarea
                        value={editingQuestion.question}
                        onChange={(e) => setEditingQuestion(prev => prev ? { ...prev, question: e.target.value } : null)}
                        className="bg-gray-700 border-gray-600 text-white"
                        rows={2}
                      />
                      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                        <Input
                          value={editingQuestion.option_a}
                          onChange={(e) => setEditingQuestion(prev => prev ? { ...prev, option_a: e.target.value } : null)}
                          className="bg-gray-700 border-gray-600 text-white"
                        />
                        <Input
                          value={editingQuestion.option_b}
                          onChange={(e) => setEditingQuestion(prev => prev ? { ...prev, option_b: e.target.value } : null)}
                          className="bg-gray-700 border-gray-600 text-white"
                        />
                      </div>
                      <div className="flex items-center space-x-2">
                        <Checkbox
                          checked={editingQuestion.is_active}
                          onCheckedChange={(checked) => setEditingQuestion(prev => prev ? { ...prev, is_active: !!checked } : null)}
                        />
                        <label className="text-sm text-gray-300">アクティブ</label>
                      </div>
                      <div className="flex space-x-2">
                        <Button
                          onClick={() => handleUpdateQuestion(editingQuestion.id, editingQuestion)}
                          disabled={processing}
                          size="sm"
                          className="bg-green-600 hover:bg-green-700"
                        >
                          {processing ? <Loader2 className="h-4 w-4 animate-spin mr-2" /> : <Save className="h-4 w-4 mr-2" />}
                          保存
                        </Button>
                        <Button
                          onClick={() => setEditingQuestion(null)}
                          size="sm"
                          className="bg-gray-600 hover:bg-gray-700 text-white"
                        >
                          <X className="h-4 w-4 mr-2" />
                          キャンセル
                        </Button>
                      </div>
                    </div>
                  ) : (
                    // 表示モード
                    <div>
                      <div className="flex items-start justify-between mb-3">
                        <div className="flex-1">
                          <h3 className="text-white font-medium mb-2">{question.question}</h3>
                          <div className="flex space-x-4 text-sm">
                            <span className="text-blue-300">A: {question.option_a}</span>
                            <span className="text-green-300">B: {question.option_b}</span>
                          </div>
                        </div>
                        <div className="flex items-center space-x-2">
                          <Badge className={question.is_active ? "bg-green-600" : "bg-gray-600"}>
                            {question.is_active ? "アクティブ" : "無効"}
                          </Badge>
                          <Button
                            onClick={() => toggleQuestionStatus(question)}
                            size="sm"
                            className={`${
                              question.is_active 
                                ? "bg-red-600 hover:bg-red-700 text-white" 
                                : "bg-green-600 hover:bg-green-700 text-white"
                            }`}
                            disabled={processing}
                          >
                            {question.is_active ? "無効にする" : "有効にする"}
                          </Button>
                          <Button
                            onClick={() => setEditingQuestion(question)}
                            size="sm"
                            className="bg-blue-600 hover:bg-blue-700 text-white"
                          >
                            <Edit className="h-4 w-4" />
                          </Button>
                          <Button
                            onClick={() => handleDeleteQuestion(question.id)}
                            size="sm"
                            className="bg-red-600 hover:bg-red-700 text-white"
                            disabled={processing}
                          >
                            <Trash2 className="h-4 w-4" />
                          </Button>
                        </div>
                      </div>
                      <div className="text-xs text-gray-400">
                        作成: {new Date(question.created_at).toLocaleDateString('ja-JP')}
                        {question.updated_at !== question.created_at && (
                          <span> | 更新: {new Date(question.updated_at).toLocaleDateString('ja-JP')}</span>
                        )}
                      </div>
                    </div>
                  )}
                </div>
              ))}

              {questions.length === 0 && (
                <div className="text-center py-8 text-gray-400">
                  設問がありません。新規設問を作成してください。
                </div>
              )}
            </div>
          </CardContent>
        </Card>

        {error && (
          <div className="mt-4 p-4 bg-red-900/20 border border-red-500/50 rounded-lg">
            <p className="text-red-200">{error}</p>
          </div>
        )}
      </div>
    </div>
  )
}