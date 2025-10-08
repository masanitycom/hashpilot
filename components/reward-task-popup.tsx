"use client"

import { useState, useEffect } from "react"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { 
  CheckCircle, 
  Loader2,
  AlertTriangle,
  HelpCircle
} from "lucide-react"
import { supabase } from "@/lib/supabase"

interface Question {
  id: string
  question: string
  option_a: string
  option_b: string
}

interface RewardTaskPopupProps {
  userId: string
  isOpen: boolean
  onComplete: () => void
}

export function RewardTaskPopup({ userId, isOpen, onComplete }: RewardTaskPopupProps) {
  const [questions, setQuestions] = useState<Question[]>([])
  const [currentQuestionIndex, setCurrentQuestionIndex] = useState(0)
  const [answers, setAnswers] = useState<{ questionId: string, answer: string }[]>([])
  const [loading, setLoading] = useState(false)
  const [submitting, setSubmitting] = useState(false)
  const [error, setError] = useState("")
  const [completed, setCompleted] = useState(false)

  useEffect(() => {
    if (isOpen) {
      fetchQuestions()
    }
  }, [isOpen])

  const fetchQuestions = async () => {
    try {
      setLoading(true)
      setError("")

      const { data, error } = await supabase.rpc("get_random_questions", { p_count: 1 })

      if (error) {
        throw error
      }

      setQuestions(data || [])
      setCurrentQuestionIndex(0)
      setAnswers([])
      setCompleted(false)
    } catch (err: any) {
      console.error("Error fetching questions:", err)
      setError("設問の取得に失敗しました")
    } finally {
      setLoading(false)
    }
  }

  const handleAnswer = (answer: string) => {
    const currentQuestion = questions[currentQuestionIndex]
    if (!currentQuestion) return

    const newAnswers = [...answers]
    const existingIndex = newAnswers.findIndex(a => a.questionId === currentQuestion.id)
    
    if (existingIndex >= 0) {
      newAnswers[existingIndex] = { questionId: currentQuestion.id, answer }
    } else {
      newAnswers.push({ questionId: currentQuestion.id, answer })
    }
    
    setAnswers(newAnswers)

    // 次の質問に進む
    if (currentQuestionIndex < questions.length - 1) {
      setCurrentQuestionIndex(currentQuestionIndex + 1)
    } else {
      // 全ての質問が完了した場合は自動送信
      submitAnswers(newAnswers)
    }
  }

  const submitAnswers = async (finalAnswers = answers) => {
    try {
      setSubmitting(true)
      setError("")

      // 回答データをJSONB形式に変換
      const answersData = finalAnswers.map((answer, index) => ({
        question_id: answer.questionId,
        question_text: questions.find(q => q.id === answer.questionId)?.question || "",
        answer: answer.answer,
        order: index + 1
      }))

      const { error } = await supabase.rpc("complete_reward_task", {
        p_user_id: userId,
        p_answers: answersData
      })

      if (error) {
        throw error
      }

      setCompleted(true)
      setTimeout(() => {
        onComplete()
      }, 2000)

    } catch (err: any) {
      console.error("Error submitting answers:", err)
      setError("回答の送信に失敗しました: " + err.message)
    } finally {
      setSubmitting(false)
    }
  }

  const getCurrentAnswer = () => {
    const currentQuestion = questions[currentQuestionIndex]
    if (!currentQuestion) return null
    return answers.find(a => a.questionId === currentQuestion.id)?.answer || null
  }

  const goToPreviousQuestion = () => {
    if (currentQuestionIndex > 0) {
      setCurrentQuestionIndex(currentQuestionIndex - 1)
    }
  }

  if (!isOpen) return null

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
      <Card className="w-full max-w-md bg-gray-800 border-gray-700">
        <CardHeader className="pb-3">
          <div className="flex items-center justify-between">
            <CardTitle className="text-white flex items-center gap-2">
              <HelpCircle className="h-5 w-5 text-blue-400" />
              月末報酬受取タスク
            </CardTitle>
            <Badge className="bg-red-600 text-white text-xs">必須</Badge>
          </div>
          {!completed && questions.length > 0 && (
            <div className="flex items-center justify-between text-sm text-gray-400">
              <span>簡単なアンケートにお答えください</span>
              <Badge variant="outline" className="border-blue-600 text-blue-400">
                {currentQuestionIndex + 1} / {questions.length}
              </Badge>
            </div>
          )}
        </CardHeader>
        
        <CardContent className="space-y-4">
          {loading ? (
            <div className="text-center py-8">
              <Loader2 className="h-8 w-8 animate-spin mx-auto text-blue-400 mb-2" />
              <p className="text-gray-400">設問を読み込み中...</p>
            </div>
          ) : error ? (
            <div className="text-center py-8">
              <AlertTriangle className="h-8 w-8 mx-auto text-red-400 mb-2" />
              <p className="text-red-400 text-sm">{error}</p>
              <Button
                onClick={fetchQuestions}
                className="mt-4 bg-blue-600 hover:bg-blue-700"
              >
                再試行
              </Button>
            </div>
          ) : completed ? (
            <div className="text-center py-8">
              <CheckCircle className="h-12 w-12 mx-auto text-green-400 mb-4" />
              <h3 className="text-white font-medium mb-2">タスク完了！</h3>
              <p className="text-gray-400 text-sm">
                アンケートにご協力いただき、ありがとうございました。
                <br />月末報酬の出金処理が可能になりました。
              </p>
            </div>
          ) : submitting ? (
            <div className="text-center py-8">
              <Loader2 className="h-8 w-8 animate-spin mx-auto text-blue-400 mb-2" />
              <p className="text-gray-400">回答を送信中...</p>
            </div>
          ) : questions.length > 0 ? (
            <div>
              <div className="mb-6">
                <h3 className="text-white font-medium mb-4">
                  {questions[currentQuestionIndex]?.question}
                </h3>
                
                <div className="space-y-3">
                  <Button
                    onClick={() => handleAnswer('A')}
                    className={`w-full justify-start text-left ${
                      getCurrentAnswer() === 'A'
                        ? 'bg-blue-600 hover:bg-blue-700 text-white border-blue-600'
                        : 'bg-gray-800 border-2 border-gray-600 text-white hover:bg-gray-700 hover:border-gray-500'
                    }`}
                  >
                    A. {questions[currentQuestionIndex]?.option_a}
                  </Button>

                  <Button
                    onClick={() => handleAnswer('B')}
                    className={`w-full justify-start text-left ${
                      getCurrentAnswer() === 'B'
                        ? 'bg-blue-600 hover:bg-blue-700 text-white border-blue-600'
                        : 'bg-gray-800 border-2 border-gray-600 text-white hover:bg-gray-700 hover:border-gray-500'
                    }`}
                  >
                    B. {questions[currentQuestionIndex]?.option_b}
                  </Button>
                </div>
              </div>

              {/* ナビゲーションボタン */}
              <div className="flex justify-between">
                <Button
                  onClick={goToPreviousQuestion}
                  disabled={currentQuestionIndex === 0}
                  size="sm"
                  className="bg-gray-700 border-gray-600 text-white hover:bg-gray-600"
                >
                  前の問題
                </Button>
                
                <div className="flex space-x-2">
                  {answers.length === questions.length && (
                    <Button
                      onClick={() => submitAnswers()}
                      className="bg-green-600 hover:bg-green-700 text-white"
                      size="sm"
                    >
                      回答送信
                    </Button>
                  )}
                </div>
              </div>

              {/* 進捗インジケーター */}
              <div className="mt-4 bg-gray-700 rounded-full h-2">
                <div 
                  className="bg-blue-600 h-2 rounded-full transition-all duration-300"
                  style={{ width: `${((currentQuestionIndex + 1) / questions.length) * 100}%` }}
                />
              </div>
            </div>
          ) : (
            <div className="text-center py-8">
              <AlertTriangle className="h-8 w-8 mx-auto text-yellow-400 mb-2" />
              <p className="text-gray-400">設問がありません</p>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  )
}