-- ========================================
-- text_to_html関数のURLリンク化バグを修正
-- ========================================

CREATE OR REPLACE FUNCTION text_to_html(p_text TEXT)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    v_html TEXT;
BEGIN
    -- すでにHTMLタグが含まれている場合はそのまま返す
    IF p_text ~ '<[a-zA-Z][\s\S]*>' THEN
        RETURN p_text;
    END IF;

    v_html := p_text;

    -- ⭐ 先にURLをリンク化（エスケープ前に実行）
    -- https:// または http:// で始まるURL
    v_html := REGEXP_REPLACE(
        v_html,
        '(https?://[^\s]+)',
        '<<<LINK:\1>>>',
        'g'
    );

    -- www. で始まるURL
    v_html := REGEXP_REPLACE(
        v_html,
        '([^/])(www\.[^\s]+)',
        '\1<<<LINK:http://\2>>>',
        'g'
    );

    -- エスケープ処理（XSS対策）
    v_html := REPLACE(v_html, '&', '&amp;');
    v_html := REPLACE(v_html, '<', '&lt;');
    v_html := REPLACE(v_html, '>', '&gt;');
    v_html := REPLACE(v_html, '"', '&quot;');
    v_html := REPLACE(v_html, '''', '&#039;');

    -- ⭐ プレースホルダーを実際のリンクに戻す
    v_html := REGEXP_REPLACE(
        v_html,
        '&lt;&lt;&lt;LINK:([^&]+)&gt;&gt;&gt;',
        '<a href="\1" style="color: #3b82f6; text-decoration: underline;">\1</a>',
        'g'
    );

    -- 改行を<br>に変換
    v_html := REPLACE(v_html, E'\n', '<br>');

    -- HTMLテンプレートでラップ
    RETURN '<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
        }
        .content {
            background: #f9f9f9;
            padding: 20px;
            border-radius: 8px;
        }
        a {
            color: #3b82f6;
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div class="content">
        ' || v_html || '
    </div>
    <div style="text-align: center; margin-top: 30px; color: #666; font-size: 12px;">
        <p>このメールは HASHPILOT システムから送信されています。</p>
        <p>© 2025 HASHPILOT. All rights reserved.</p>
    </div>
</body>
</html>';
END;
$$;

-- テスト
SELECT text_to_html('テスト

https://www.yahoo.co.jp/
www.google.com

よろしく') as html_output;

RAISE NOTICE '✅ text_to_html関数を修正しました（URLバグ修正）';
