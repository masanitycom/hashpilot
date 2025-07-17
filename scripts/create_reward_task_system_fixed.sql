-- ========================================
-- 報酬受取りタスクシステムの実装（修正版）
-- ========================================

-- 1. 設問管理テーブル
CREATE TABLE IF NOT EXISTS reward_questions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    question TEXT NOT NULL,
    option_a TEXT NOT NULL,
    option_b TEXT NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    created_by UUID REFERENCES auth.users(id)
);

-- 2. ユーザーの月末タスク状況管理テーブル
CREATE TABLE IF NOT EXISTS monthly_reward_tasks (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id VARCHAR(6) NOT NULL,
    year INTEGER NOT NULL,
    month INTEGER NOT NULL,
    is_completed BOOLEAN DEFAULT false,
    completed_at TIMESTAMP NULL,
    questions_answered INTEGER DEFAULT 0,
    answers JSONB DEFAULT '[]',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    CONSTRAINT unique_user_month UNIQUE (user_id, year, month),
    CONSTRAINT fk_user_monthly_tasks FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- 3. 出金一覧にタスククリア状況を追加
ALTER TABLE monthly_withdrawals 
ADD COLUMN IF NOT EXISTS task_completed BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS task_completed_at TIMESTAMP NULL;

-- 4. インデックス作成
CREATE INDEX IF NOT EXISTS idx_reward_questions_active ON reward_questions(is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_monthly_reward_tasks_user_month ON monthly_reward_tasks(user_id, year, month);
CREATE INDEX IF NOT EXISTS idx_monthly_reward_tasks_completed ON monthly_reward_tasks(is_completed, year, month);
CREATE INDEX IF NOT EXISTS idx_monthly_withdrawals_task_status ON monthly_withdrawals(task_completed);

-- 5. RLS ポリシー設定
ALTER TABLE reward_questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE monthly_reward_tasks ENABLE ROW LEVEL SECURITY;

-- 管理者のみ設問の作成・編集が可能（メールアドレス直接チェック）
CREATE POLICY "admin_manage_questions" ON reward_questions
    FOR ALL
    TO authenticated
    USING (
        auth.jwt() ->> 'email' IN ('basarasystems@gmail.com', 'support@dshsupport.biz')
    );

-- 全ユーザーが設問を読み取り可能
CREATE POLICY "users_read_questions" ON reward_questions
    FOR SELECT
    TO authenticated
    USING (is_active = true);

-- ユーザーは自分のタスク状況のみアクセス可能
CREATE POLICY "users_own_tasks" ON monthly_reward_tasks
    FOR ALL
    TO authenticated
    USING (
        user_id = (
            SELECT u.user_id FROM users u 
            WHERE u.email = auth.jwt() ->> 'email'
        )
    );

-- 管理者は全てのタスク状況を閲覧可能
CREATE POLICY "admin_view_all_tasks" ON monthly_reward_tasks
    FOR SELECT
    TO authenticated
    USING (
        auth.jwt() ->> 'email' IN ('basarasystems@gmail.com', 'support@dshsupport.biz')
    );

-- 6. 初期データ投入（サンプル設問）
INSERT INTO reward_questions (question, option_a, option_b) VALUES
('朝はコーヒー派ですか？お茶派ですか？', 'コーヒー', 'お茶'),
('休日は家派ですか？外出派ですか？', '家でゆっくり', '外に出かける'),
('投資スタイルは保守派ですか？積極派ですか？', '保守的', '積極的'),
('ニュースはTV派ですか？ネット派ですか？', 'テレビ', 'インターネット'),
('買い物は実店舗派ですか？オンライン派ですか？', '実店舗', 'オンライン'),
('読書は紙派ですか？電子派ですか？', '紙の本', '電子書籍'),
('旅行は国内派ですか？海外派ですか？', '国内旅行', '海外旅行'),
('音楽はストリーミング派ですか？ダウンロード派ですか？', 'ストリーミング', 'ダウンロード'),
('料理は和食派ですか？洋食派ですか？', '和食', '洋食'),
('学習は独学派ですか？スクール派ですか？', '独学', 'スクール'),
('連絡手段はメール派ですか？メッセージ派ですか？', 'メール', 'メッセージアプリ'),
('交通手段は電車派ですか？車派ですか？', '電車', '車'),
('運動は室内派ですか？屋外派ですか？', '室内運動', '屋外運動'),
('映画は映画館派ですか？自宅派ですか？', '映画館', '自宅'),
('仕事は効率派ですか？丁寧派ですか？', '効率重視', '丁寧重視'),
('貯金は銀行派ですか？投資派ですか？', '銀行預金', '投資'),
('情報収集はSNS派ですか？ニュースサイト派ですか？', 'SNS', 'ニュースサイト'),
('スマホはiPhone派ですか？Android派ですか？', 'iPhone', 'Android'),
('ゲームはモバイル派ですか？PC/コンソール派ですか？', 'モバイル', 'PC/コンソール'),
('睡眠は早寝派ですか？夜更かし派ですか？', '早寝早起き', '夜更かし')
ON CONFLICT DO NOTHING;

-- 7. 月末処理時にタスクレコードを作成する関数
CREATE OR REPLACE FUNCTION create_monthly_reward_tasks(p_year INTEGER, p_month INTEGER)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_record RECORD;
    v_created_count INTEGER := 0;
BEGIN
    -- 全アクティブユーザーに対してタスクレコードを作成
    FOR v_user_record IN
        SELECT DISTINCT user_id
        FROM users
        WHERE has_approved_nft = true
        AND is_active = true
    LOOP
        INSERT INTO monthly_reward_tasks (
            user_id, year, month, is_completed, questions_answered
        )
        VALUES (
            v_user_record.user_id, p_year, p_month, false, 0
        )
        ON CONFLICT (user_id, year, month) DO NOTHING;
        
        v_created_count := v_created_count + 1;
    END LOOP;
    
    RETURN v_created_count;
END;
$$;

-- 8. タスククリア処理の関数
CREATE OR REPLACE FUNCTION complete_reward_task(p_user_id VARCHAR(6), p_answers JSONB)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_current_year INTEGER;
    v_current_month INTEGER;
    v_task_exists BOOLEAN;
BEGIN
    -- 現在の年月を取得
    v_current_year := EXTRACT(YEAR FROM CURRENT_DATE);
    v_current_month := EXTRACT(MONTH FROM CURRENT_DATE);
    
    -- タスクレコードの存在確認
    SELECT EXISTS(
        SELECT 1 FROM monthly_reward_tasks 
        WHERE user_id = p_user_id 
        AND year = v_current_year 
        AND month = v_current_month
    ) INTO v_task_exists;
    
    IF NOT v_task_exists THEN
        -- タスクレコードが存在しない場合は作成
        INSERT INTO monthly_reward_tasks (
            user_id, year, month, is_completed, questions_answered, answers, completed_at
        )
        VALUES (
            p_user_id, v_current_year, v_current_month, true, 
            jsonb_array_length(p_answers), p_answers, NOW()
        );
    ELSE
        -- 既存のタスクを完了状態に更新
        UPDATE monthly_reward_tasks 
        SET 
            is_completed = true,
            questions_answered = jsonb_array_length(p_answers),
            answers = p_answers,
            completed_at = NOW(),
            updated_at = NOW()
        WHERE user_id = p_user_id 
        AND year = v_current_year 
        AND month = v_current_month;
    END IF;
    
    -- 対応する出金レコードも更新
    UPDATE monthly_withdrawals 
    SET 
        task_completed = true,
        task_completed_at = NOW()
    WHERE user_id = p_user_id 
    AND withdrawal_month = DATE(v_current_year || '-' || LPAD(v_current_month::TEXT, 2, '0') || '-01');
    
    RETURN true;
END;
$$;

-- 9. ランダムな設問を取得する関数
CREATE OR REPLACE FUNCTION get_random_questions(p_count INTEGER DEFAULT 5)
RETURNS TABLE(
    id UUID,
    question TEXT,
    option_a TEXT,
    option_b TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        rq.id,
        rq.question,
        rq.option_a,
        rq.option_b
    FROM reward_questions rq
    WHERE rq.is_active = true
    ORDER BY RANDOM()
    LIMIT p_count;
END;
$$;

-- 10. 実行権限付与
GRANT EXECUTE ON FUNCTION create_monthly_reward_tasks(INTEGER, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION complete_reward_task(VARCHAR(6), JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION get_random_questions(INTEGER) TO authenticated;

SELECT 'Reward task system tables and functions created successfully (fixed version)' as status;