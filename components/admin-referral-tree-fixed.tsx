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

export function AdminReferralTreeFixed({ userId }: Props) {
  const [treeData, setTreeData] = useState<TreeNode | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [expandedNodes, setExpandedNodes] = useState<Set<string>>(new Set())
  const [stats, setStats] = useState<any>(null)
  
  useEffect(() => {
    fetchCompleteTree()
  }, [userId])
  
  const fetchCompleteTree = async () => {
    try {
      setLoading(true)
      setError(null)
      
      // 全ユーザーデータを取得
      const { data: allUsers, error: fetchError } = await supabase
        .from("users")
        .select("user_id, email, total_purchases, referrer_user_id")
        .order("created_at", { ascending: true })
      
      if (fetchError) throw fetchError
      if (!allUsers) throw new Error("データ取得失敗")
      
      // 再帰的にツリーを構築（下位合計を正しく計算）
      const buildTreeNode = (
        rootId: string, 
        level: number = 1, 
        visited: Set<string> = new Set()
      ): TreeNode | null => {
        // 循環参照を防ぐ
        if (visited.has(rootId)) return null
        
        const user = allUsers.find(u => u.user_id === rootId)
        if (!user) return null
        
        // このノードを処理済みに追加
        const newVisited = new Set(visited)
        newVisited.add(rootId)
        
        // 個人投資額（手数料除く）
        const personalInvestment = Math.floor(user.total_purchases / 1100) * 1000
        
        // 直接紹介者を取得
        const directReferrals = allUsers.filter(u => u.referrer_user_id === rootId)
        const children: TreeNode[] = []
        let subtreeTotal = 0
        
        // 各子ノードを再帰的に構築
        for (const referral of directReferrals) {
          const childNode = buildTreeNode(referral.user_id, level + 1, newVisited)
          if (childNode) {
            children.push(childNode)
            // 子ノードの総合計を下位合計に加算
            subtreeTotal += childNode.totalAmount
          }
        }
        
        const totalAmount = personalInvestment + subtreeTotal
        
        return {
          user_id: user.user_id,
          email: user.email,
          level,
          personalInvestment,
          subtreeTotal,
          totalAmount,
          children
        }
      }
      
      // ツリーを構築
      const tree = buildTreeNode(userId)
      if (!tree) throw new Error("ツリー構築失敗")
      
      setTreeData(tree)
      
      // 統計情報を計算
      const countNodes = (node: TreeNode): { total: number; purchased: number } => {
        let total = 1
        let purchased = node.personalInvestment > 0 ? 1 : 0
        
        for (const child of node.children) {
          const childStats = countNodes(child)
          total += childStats.total
          purchased += childStats.purchased
        }
        
        return { total, purchased }
      }
      
      const nodeStats = countNodes(tree)
      setStats({
        totalReferrals: nodeStats.total - 1, // ルートユーザーを除く
        purchasedReferrals: nodeStats.purchased - (tree.personalInvestment > 0 ? 1 : 0),
        totalInvestment: tree.subtreeTotal // 下位の総投資額
      })
      
    } catch (err) {
      console.error("ツリー取得エラー:", err)
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
            {node.children.map(child => renderNode(child, depth + 1))}
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
        <CardContent className="p-6">
          <div className="flex items-center space-x-2 text-red-400">
            <AlertCircle className="w-5 h-5" />
            <span>エラー: {error}</span>
          </div>
        </CardContent>
      </Card>
    )
  }
  
  if (!treeData) {
    return (
      <Card className="bg-gray-800 border-gray-700">
        <CardContent className="p-6">
          <div className="text-center text-gray-400">
            <Users className="w-12 h-12 mx-auto mb-4 opacity-50" />
            <p>紹介者がいません</p>
          </div>
        </CardContent>
      </Card>
    )
  }
  
  return (
    <Card className="bg-gray-800 border-gray-700">
      <CardHeader>
        <div className="flex items-center justify-between">
          <CardTitle className="text-white flex items-center">
            <TrendingUp className="w-5 h-5 mr-2" />
            紹介ツリー（修正版）
          </CardTitle>
          {stats && (
            <div className="flex space-x-4 text-sm">
              <div className="text-gray-300">
                <span className="text-gray-400">総紹介:</span>{" "}
                <span className="font-bold text-white">{stats.totalReferrals}人</span>
              </div>
              <div className="text-gray-300">
                <span className="text-gray-400">購入済み:</span>{" "}
                <span className="font-bold text-green-400">{stats.purchasedReferrals}人</span>
              </div>
              <div className="text-gray-300">
                <span className="text-gray-400">総投資額:</span>{" "}
                <span className="font-bold text-yellow-400">${stats.totalInvestment.toLocaleString()}</span>
              </div>
            </div>
          )}
        </div>
      </CardHeader>
      <CardContent>
        {/* 統計サマリー */}
        {stats && (
          <div className="bg-gray-700 rounded-lg p-4 mb-4">
            <div className="grid grid-cols-3 gap-4 text-center">
              <div>
                <div className="text-2xl font-bold text-blue-400">
                  {stats.totalReferrals}
                </div>
                <div className="text-sm text-gray-300">総紹介人数</div>
              </div>
              <div>
                <div className="text-2xl font-bold text-green-400">
                  {stats.purchasedReferrals}
                </div>
                <div className="text-sm text-gray-300">購入済み</div>
              </div>
              <div>
                <div className="text-2xl font-bold text-yellow-400">
                  ${stats.totalInvestment.toLocaleString()}
                </div>
                <div className="text-sm text-gray-300">総投資額</div>
              </div>
            </div>
          </div>
        )}
        
        {/* ツリー表示 */}
        <div className="max-h-[600px] overflow-y-auto">
          {renderNode(treeData)}
        </div>
      </CardContent>
    </Card>
  )
}