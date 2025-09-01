"use client"

import { useState, useEffect } from "react"
import { supabase } from "@/lib/supabase"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { ChevronDown, ChevronRight, Users, TrendingUp, AlertCircle, Loader2 } from "lucide-react"

interface TreeNode {
  user_id: string
  email: string
  level: number
  personalInvestment: number
  subtreeTotal: number
  totalAmount: number
  children: TreeNode[]
  expanded?: boolean
}

interface Props {
  userId: string
}

export function AdminReferralTreeSimple({ userId }: Props) {
  const [treeData, setTreeData] = useState<TreeNode | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [expandedNodes, setExpandedNodes] = useState<Set<string>>(new Set([userId]))
  const [stats, setStats] = useState<any>(null)
  
  useEffect(() => {
    fetchCompleteTree()
  }, [userId])
  
  const fetchCompleteTree = async () => {
    try {
      setLoading(true)
      setError(null)
      
      console.log(`[DEBUG] フェッチ開始: ユーザー ${userId}`)
      
      // 全ユーザーデータを取得
      const { data: allUsers, error: fetchError } = await supabase
        .from("users")
        .select("user_id, email, total_purchases, referrer_user_id")
        .order("created_at", { ascending: true })
      
      if (fetchError) throw fetchError
      if (!allUsers) throw new Error("データ取得失敗")
      
      console.log(`[DEBUG] 全ユーザー数: ${allUsers.length}`)
      
      // 完全なツリー構築（再帰的）
      const buildCompleteTree = (
        rootId: string, 
        level: number = 0,
        visited: Set<string> = new Set()
      ): TreeNode | null => {
        // 循環参照を防ぐ
        if (visited.has(rootId)) return null
        
        const user = allUsers.find(u => u.user_id === rootId)
        if (!user) return null
        
        // このノードを処理済みに追加
        const newVisited = new Set(visited)
        newVisited.add(rootId)
        
        console.log(`[DEBUG] ユーザー処理: ${user.user_id} (Lv.${level})`)
        
        const personalInvestment = Math.floor(user.total_purchases / 1100) * 1000
        const directReferrals = allUsers.filter(u => u.referrer_user_id === rootId)
        
        console.log(`[DEBUG] ${user.user_id} の直接紹介者: ${directReferrals.length}人`)
        if (level <= 2) { // レベル2までログ出力
          directReferrals.forEach((ref, i) => {
            console.log(`[DEBUG]   ${i+1}. ${ref.user_id} (${ref.email})`)
          })
        }
        
        const children: TreeNode[] = []
        let subtreeTotal = 0
        
        // 再帰的に全ての子ノードを構築
        for (const referral of directReferrals) {
          const childNode = buildCompleteTree(referral.user_id, level + 1, newVisited)
          if (childNode) {
            children.push(childNode)
            subtreeTotal += childNode.totalAmount
            console.log(`[DEBUG] 子ノード追加: ${childNode.user_id}`)
          }
        }
        
        const totalAmount = personalInvestment + subtreeTotal
        
        const result: TreeNode = {
          user_id: user.user_id,
          email: user.email,
          level,
          personalInvestment,
          subtreeTotal,
          totalAmount,
          children
        }
        
        console.log(`[DEBUG] ${user.user_id} 完了: children=${children.length}, total=$${totalAmount}`)
        
        return result
      }
      
      // ツリーを構築
      const tree = buildCompleteTree(userId)
      if (!tree) throw new Error("ツリー構築失敗")
      
      console.log(`[DEBUG] 最終ツリー: ${tree.user_id} - children: ${tree.children.length}`)
      
      setTreeData(tree)
      
      // 統計情報
      setStats({
        totalReferrals: tree.children.length,
        purchasedReferrals: tree.children.filter(c => c.personalInvestment > 0).length,
        totalInvestment: tree.subtreeTotal
      })
      
    } catch (err) {
      console.error("[DEBUG] エラー:", err)
      setError(err instanceof Error ? err.message : "エラーが発生しました")
    } finally {
      setLoading(false)
    }
  }
  
  const toggleNode = (nodeId: string) => {
    setExpandedNodes(prev => {
      const newSet = new Set(prev)
      if (newSet.has(nodeId)) {
        newSet.delete(nodeId)
      } else {
        newSet.add(nodeId)
      }
      return newSet
    })
  }
  
  const renderNode = (node: TreeNode, depth: number = 0) => {
    const hasChildren = node.children.length > 0
    const isExpanded = expandedNodes.has(node.user_id)
    const indentLevel = depth * 20
    
    console.log(`[DEBUG] renderNode: ${node.user_id} - children: ${node.children.length}`)
    
    return (
      <div key={node.user_id}>
        <div 
          className="border-l-4 border-blue-500 pl-4 py-2 mb-3"
          style={{ marginLeft: `${indentLevel}px` }}
        >
          <div className="bg-gray-700 rounded-lg p-4">
            <div className="flex items-start space-x-3">
              {hasChildren && (
                <button
                  onClick={() => toggleNode(node.user_id)}
                  className="mt-1 text-gray-400 hover:text-white transition-colors"
                >
                  {isExpanded ? <ChevronDown className="w-4 h-4" /> : <ChevronRight className="w-4 h-4" />}
                </button>
              )}
              {!hasChildren && <div className="w-4" />}
              
              <div className="flex-1">
                <div className="flex items-center justify-between mb-3">
                  <div className="flex items-center space-x-3">
                    {node.level > 0 && (
                      <Badge 
                        variant="outline" 
                        className={`
                          ${node.level === 1 ? 'bg-blue-600' : ''}
                          ${node.level === 2 ? 'bg-green-600' : ''}
                          ${node.level === 3 ? 'bg-purple-600' : ''}
                          ${node.level >= 4 ? 'bg-orange-600' : ''}
                          text-white
                        `}
                      >
                        Lv.{node.level}
                      </Badge>
                    )}
                    <div>
                      <div className="font-semibold text-white">{node.user_id}</div>
                      <div className="text-sm text-gray-300">{node.email}</div>
                    </div>
                  </div>
                  {hasChildren && (
                    <div className="text-xs text-gray-400">
                      {node.children.length}人の紹介
                    </div>
                  )}
                </div>
                
                <div className="grid grid-cols-3 gap-4 text-sm">
                  <div className="text-center">
                    <div className="text-gray-400">個人投資</div>
                    <div className={`font-semibold ${node.personalInvestment > 0 ? 'text-green-400' : 'text-gray-500'}`}>
                      ${node.personalInvestment.toLocaleString()}
                    </div>
                  </div>
                  <div className="text-center">
                    <div className="text-gray-400">下位合計</div>
                    <div className={`font-semibold ${node.subtreeTotal > 0 ? 'text-blue-400' : 'text-gray-500'}`}>
                      ${node.subtreeTotal.toLocaleString()}
                    </div>
                  </div>
                  <div className="text-center">
                    <div className="text-gray-400">総合計</div>
                    <div className={`font-semibold ${node.totalAmount > 0 ? 'text-yellow-400' : 'text-gray-500'}`}>
                      ${node.totalAmount.toLocaleString()}
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
        
        {isExpanded && hasChildren && (
          <div>
            {console.log(`[DEBUG] レンダリング中の子ノード数: ${node.children.length}`)}
            {node.children.map((child, index) => {
              console.log(`[DEBUG] 子ノード ${index + 1}/${node.children.length}: ${child.user_id}`)
              return renderNode(child, depth + 1)
            })}
          </div>
        )}
      </div>
    )
  }
  
  if (loading) {
    return (
      <Card className="bg-gray-800 border-gray-700">
        <CardContent className="p-6">
          <div className="flex items-center justify-center space-x-2">
            <Loader2 className="w-6 h-6 animate-spin text-blue-600" />
            <span className="text-white">紹介ツリーを読み込み中...</span>
          </div>
        </CardContent>
      </Card>
    )
  }
  
  if (error) {
    return (
      <Card className="bg-gray-800 border-gray-700">
        <CardHeader>
          <CardTitle className="text-red-400 flex items-center">
            <AlertCircle className="w-5 h-5 mr-2" />
            エラー
          </CardTitle>
        </CardHeader>
        <CardContent className="text-white">
          <p>{error}</p>
        </CardContent>
      </Card>
    )
  }
  
  return (
    <Card className="bg-gray-800 border-gray-700">
      <CardHeader>
        <CardTitle className="text-white text-lg flex items-center">
          <TrendingUp className="w-5 h-5 mr-2" />
          紹介ツリー（シンプル版）
        </CardTitle>
      </CardHeader>
      <CardContent>
        {stats && (
          <div className="mb-4 p-3 bg-gray-900 rounded-lg">
            <div className="grid grid-cols-3 gap-4 text-center text-sm">
              <div>
                <div className="text-2xl font-bold text-blue-400">{stats.totalReferrals}</div>
                <div className="text-gray-400">直接紹介者</div>
              </div>
              <div>
                <div className="text-2xl font-bold text-green-400">{stats.purchasedReferrals}</div>
                <div className="text-gray-400">購入済み</div>
              </div>
              <div>
                <div className="text-2xl font-bold text-yellow-400">${stats.totalInvestment.toLocaleString()}</div>
                <div className="text-gray-400">総投資額</div>
              </div>
            </div>
          </div>
        )}
        
        <div className="max-h-96 overflow-y-auto">
          {treeData ? renderNode(treeData) : (
            <div className="text-center py-8 text-gray-400">
              <Users className="w-12 h-12 mx-auto mb-4 opacity-50" />
              <p>ツリーデータがありません</p>
            </div>
          )}
        </div>
      </CardContent>
    </Card>
  )
}